package SynthwavePlayer::Library;

use strict;
use warnings;
use utf8;
use feature 'state';
use Exporter 'import';
use File::Find::Rule; # For scanning music directories
use MP3::Tag; # For reading / writing tags
use Mojo::IOLoop;
use Mojo::JSON;
use Linux::Inotify2 qw(IN_MOVED_TO IN_CLOSE_WRITE IN_CREATE IN_DELETE IN_MOVED_FROM);
use File::Spec;
use File::Basename qw(basename dirname fileparse);
use URI::Escape qw(uri_unescape);
use Digest::SHA qw(sha1_hex);
use Encode qw(encode decode);
use Try::Tiny;
use SynthwavePlayer::Lyrics qw(fetch_online_lyrics_async get_local_lyrics_data);
use Mojo::File qw(path);
use SynthwavePlayer::Config;
use SynthwavePlayer::Utils qw(:DEFAULT _is_matched _natural_compare realpath SONG_TITLE SONG_ARTIST _get_safe_song_path _stash_notification _extract_metadata);
use SynthwavePlayer::Network qw(compile_regex is_private_ip setup_upnp check_port_is_available);
use SynthwavePlayer::Library::Scanner qw(_start_library_parsing _parse_playlists _scan_music_directories _process_playlist_chunk);
use SynthwavePlayer::Library::Watcher qw(_setup_library_watcher _setup_config_watcher _setup_database_watcher);
use Mojolicious::Controller;

our @EXPORT_OK = qw(
    _broadcast_lyrics_update
    _broadcast_config_update
    _get_config_hash
    _broadcast_status_update
    _broadcast_library_update
    _find_song_id_by_path _process_playlist_entry
    _find_song_by_partial_id
    _update_song_stats _get_location_id_map
    _check_and_set_idle_state
    _start_task_processor
    _get_lyrics
    get_artists get_albums get_genres get_playlists get_playlist_songs
    register_library_features
    init_database
    init_sql_handle
);

sub init_sql_handle {
    my ($sql) = @_;

    $sql->on(connection => sub {
        my ($sql, $dbh) = @_;
        # WAL mode and busy_timeout are crucial for multi-worker SQLite access
        $dbh->do('PRAGMA journal_mode = WAL');
        $dbh->do('PRAGMA synchronous = NORMAL');
        $dbh->do('PRAGMA busy_timeout = 120000');
        $dbh->do('PRAGMA foreign_keys = ON');
        $dbh->sqlite_create_function('regexp', 2, sub {
            my ($regex, $string) = @_;
            return 0 unless defined $string;
            return $string =~ /$regex/i ? 1 : 0;
        });

        $dbh->sqlite_create_collation('SYNTH_SORT', sub {
            my ($a, $b) = @_;
            my $clean = sub {
                my $s = shift // '';
                $s = decode('UTF-8', $s) unless utf8::is_utf8($s);
                $s =~ s/[\x{0300}-\x{036f}]//g; # Simple diacritic removal
                $s =~ s/["'«»„“]//g;           # Remove quotes
                $s =~ s/[^a-zA-Z0-9\s]//g;     # Remove other special chars
                return lc($s);
            };
            return _natural_compare($clean->($a), $clean->($b));
        });
    });

    return $sql;
}

sub _get_config_hash {
    my ($music_dirs, $friends_music) = @_;

    my @norm_dirs = sort grep { defined } map {
        my $p = realpath($_) // $_;
        $p =~ s{/+$}{} if defined $p;
        $p
    } grep { defined } @$music_dirs;

    my @norm_friends = sort grep { defined } map {
        ref $_ eq 'HASH' ? $_->{value} : $_;
    } grep { defined } @$friends_music;

    my $config_str = join('|', @norm_dirs) . '||' . join('|', @norm_friends);
    return Digest::SHA::sha1_hex($config_str);
}

sub register_library_features {
    my ($app) = @_;

# --- Startup Actions ---
# This block runs once when the application starts.
# It parses the databases and sets up UPnP.
$app->hook(before_server_start => sub {
    my ($server) = @_;
    my $app = $server->app;
    $app->log->level('debug');

    unless (check_port_is_available($APP_PORT, $app->log, $app->mode eq 'development')) {
        print "already running\n";
        exit 0;
    }

    $app->log->info("$WEBSITE_TITLE Player starting up...");
    print "$WEBSITE_TITLE Player starting up...\n";

    # Check for required dependencies
    SynthwavePlayer::Utils::_check_dependencies($app);

    # Non-blocking library loading
    Mojo::IOLoop->singleton->next_tick(sub {
        # Clean up old ignored paths on startup
        try {
            $app->sql->db->query('DELETE FROM ignored_paths WHERE timestamp < ?', time() - 3600);
        } catch {
            $app->log->error("Failed to clean ignored_paths: $_");
        };

        my $db = $app->sql->db;

        # 1. Clean up any URL entries that were incorrectly stored in configured_directories
        # URLs should never be in this table as they are not local directories to scan
        try {
            my $url_count = $app->sql->db->query("SELECT COUNT(*) FROM configured_directories WHERE path LIKE 'http%'")->array->[0] // 0;
            if ($url_count > 0) {
                $app->log->info("Cleaning up $url_count URL entries from configured_directories (URLs should not be scanned)");
                $app->sql->db->query("DELETE FROM configured_directories WHERE path LIKE 'http%'");
                # Also clean up any associated scan tasks
                $app->sql->db->query("DELETE FROM scan_state WHERE key LIKE 'task:http%'");
            }
        } catch {
            $app->log->error("Failed to cleanup URL entries: $_");
        };

        # 2. Synchronize configuration with database state
        # Pass empty arrays for old dirs/friends - this means we compare DB state against current config
        # This catches directories that were removed while the server was stopped
        $app->log->info("Synchronizing library with current configuration...");
        $app->sync_library_to_config([], \@MUSIC_DIRECTORIES, [], \@FRIENDS_MUSIC);
        my $current_hash = _get_config_hash(\@MUSIC_DIRECTORIES, \@FRIENDS_MUSIC);
        $db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES ('config_hash', ?)", $current_hash);

        # 3. Verify existing directories for offline changes
        my $tasks_queued = $app->verify_library_integrity();

        # 4. Start the single task processor if we have work to do
        if ($tasks_queued) {
            $app->log->info("Integrity check queued $tasks_queued tasks. Starting processor.");
            _start_task_processor($app);
        } else {
            _check_and_set_idle_state($app);
        }
    });

    # Periodically clean up ignored paths and stale scan tasks
    Mojo::IOLoop->singleton->recurring(300 => sub {
        # Clean up ignored paths after 5 minutes (increased from 1 minute)
        $app->sql->db->query('DELETE FROM ignored_paths WHERE timestamp < ?', time() - 300);

        # Recover stuck tasks that haven't updated their heartbeat in 25 minutes
        # (longer than safety timer to avoid race conditions)
        try {
            my $twentyfive_mins_ago = time() - 1500;
            $app->sql->db->query(
                "UPDATE scan_state SET value = 'pending' WHERE (key LIKE 'task:%' OR key LIKE 'purge_task:%') AND value = 'processing' AND timestamp < ?",
                $twentyfive_mins_ago
            );
            $app->sql->db->query("UPDATE configured_directories SET status = 'pending' WHERE status = 'scanning' AND path IN (SELECT SUBSTR(key, 6) FROM scan_state WHERE key LIKE 'task:%' AND value = 'pending')");
        } catch {
            $app->log->error("Failed to recover stuck tasks: $_");
        };

        # If we are idle but there are tasks, it means a worker died or was interrupted
        my $status = $app->sql->db->query("SELECT value FROM scan_state WHERE key = 'scan_status'")->array->[0] // 'idle';
        if ($status eq 'idle') {
            my $tasks = $app->sql->db->query("SELECT COUNT(*) FROM configured_directories WHERE status != 'scanned'")->array->[0] // 0;
            $tasks += $app->sql->db->query("SELECT COUNT(*) FROM scan_state WHERE key LIKE 'purge_task:%'")->array->[0] // 0;
            if ($tasks > 0 && !$app->db->{is_loading}) {
                $app->log->info("Stale scan tasks detected. Triggering background resumption.");
                # Trigger a dummy update to kickstart the logic in before_dispatch or similar
                _broadcast_status_update($app);
            }
        }
    });

    # Setup config file watcher
    SynthwavePlayer::Library::Watcher::_setup_config_watcher($app);

    # Setup database file watcher
    SynthwavePlayer::Library::Watcher::_setup_database_watcher($app);

    # Debounced library update broadcaster
    state $library_needs_update = 0;
    $app->helper(mark_library_dirty => sub { $library_needs_update = 1 });
    Mojo::IOLoop->singleton->recurring(3 => sub {
        if ($library_needs_update) {
            _broadcast_library_update($app);
            $library_needs_update = 0;
        }
    });


    $app->log->info("Server started. Library loading in background. Ready to ride the synth waves.");

    # Get hostname for alternative access methods
    my $hostname = `hostname`;
    chomp $hostname;

    $app->log->info("");
    $app->log->info("Web available on: http://localhost:$APP_PORT/");
    $app->log->info("                  http://127.0.0.1:$APP_PORT/");
    $app->log->info("                  http://$hostname:$APP_PORT/");
    $app->log->info("");
    $app->log->info("TIP: If libnss-mdns is installed in your machines, you can also access it from your network via:");
    $app->log->info("     http://$hostname.local:$APP_PORT/");
    $app->log->info("");
});


# Helper to synchronize library state with configuration changes
$app->helper(sync_library_to_config => sub {
    my ($c, $old_dirs, $new_dirs, $old_friends, $new_friends) = @_;
    my $app = $c->app;

    # Use a transaction to atomically check and set scanning status to prevent race conditions
    try {
        my $db = $app->sql->db;
        my $tx = $db->begin('immediate');
        my $row = $db->query("SELECT value, timestamp FROM scan_state WHERE key = 'scan_status'")->hash;
        my $status = $row ? ($row->{value} // 'idle') : 'idle';
        my $ts = $row ? ($row->{timestamp} // 0) : 0;

        # If a scan is active and fresh, we defer. If it's stale (> 15 mins), we take over.
        if ($status eq 'scanning' && $ts > time() - 900) {
            $app->log->info("Another worker is currently scanning. Deferring configuration sync.");
            return 0;
        }
        $db->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());
        $tx->commit;
    } catch {
        $app->log->error("Failed to acquire scan lock: $_");
        return 0;
    };

    $app->db->{loading_status}{message} = "Synchronizing library with configuration...";

    # Normalize paths for consistent comparison
    my %new_dir_map = map { $_ => 1 } grep { defined } map { my $p = realpath($_) // $_; $p =~ s{/+$}{} if defined $p; $p } grep { defined } @$new_dirs;
    my %new_friend_map = map { $_ => 1 } grep { defined } map {
        ref $_ eq 'HASH' ? $_->{value} : $_;
    } grep { defined } @$new_friends;

    # Also build old maps for comparison (useful for logging what changed)
    my %old_dir_map = map { $_ => 1 } grep { defined } map { my $p = realpath($_) // $_; $p =~ s{/+$}{} if defined $p; $p } grep { defined } @$old_dirs;
    my %old_friend_map = map { $_ => 1 } grep { defined } map {
        ref $_ eq 'HASH' ? $_->{value} : $_;
    } grep { defined } @$old_friends;

    my @to_purge;
    my @to_scan;

    # 1. Identify removed directories from the database registry
    # This catches directories removed while server was running OR while it was stopped
    my $db_dirs = $app->sql->db->query("SELECT path FROM configured_directories")->arrays->map(sub { $_->[0] })->to_array;

    for my $old_path (@$db_dirs) {
        next unless defined $old_path;

        # Skip URLs that were incorrectly stored in configured_directories
        # They should be removed from the table but not purged as songs
        if ($old_path =~ m{^https?://}i) {
            $app->log->info("Removing URL from configured_directories (should not have been stored): $old_path");
            $app->sql->db->query('DELETE FROM configured_directories WHERE path = ?', $old_path);
            next;
        }

        # Use the path as stored in DB (should already be normalized)
        # realpath may fail if directory was deleted, but DB path is our source of truth
        my $norm_old_path = $old_path;
        $norm_old_path =~ s{/+$}{};

        # If the directory is in the DB but no longer in the new config, mark it for purging
        if (!$new_dir_map{$norm_old_path} && !$new_friend_map{$norm_old_path}) {
            $app->log->info("Directory removed from config, scheduling purge: $norm_old_path");
            # Store normalized path to ensure task key matches
            push @to_purge, $norm_old_path;
        }
    }

    # 2. Identify added directories and update registry
    # Only process local paths (not URLs from friends list)
    for my $new_path (@$new_dirs) {
        next unless defined $new_path;

        # Skip URLs - they are cosmetic links only, not directories to scan
        if ($new_path =~ m{^https?://}i) {
            $app->log->debug("Skipping URL from music directories (not a local path): $new_path") if $ENABLE_DEBUG_LOGGING;
            next;
        }

        my $norm_new_path = realpath($new_path) // $new_path;
        $norm_new_path =~ s{/+$}{};

        my $dir_row = $app->sql->db->query("SELECT status FROM configured_directories WHERE path = ?", $norm_new_path)->hash;
        if (!$dir_row) {
            $app->sql->db->query("INSERT INTO configured_directories (path, status) VALUES (?, ?)", $norm_new_path, 'pending');
            push @to_scan, $norm_new_path;
            $app->log->info("New directory added to config, scheduling scan: $norm_new_path");
        } elsif ($dir_row->{status} ne 'scanned') {
            push @to_scan, $norm_new_path;
            $app->log->info("Directory needs re-scan (status: $dir_row->{status}): $norm_new_path");
        }
    }

    # Friends music URLs are cosmetic links only - do NOT add them to configured_directories
    # They are displayed in the UI for users to click manually
    for my $friend_path (@$new_friends) {
        my $url = ref $friend_path eq 'HASH' ? $friend_path->{value} : $friend_path;
        next unless defined $url;

        if ($url =~ m{^https?://}i) {
            $app->log->debug("Friends URL (cosmetic link, not scanned): $url") if $ENABLE_DEBUG_LOGGING;
            next;
        }

        # If it's a local path in friends, treat it as a music directory
        my $norm_new_path = realpath($url) // $url;
        $norm_new_path =~ s{/+$}{};

        my $dir_row = $app->sql->db->query("SELECT status FROM configured_directories WHERE path = ?", $norm_new_path)->hash;
        if (!$dir_row) {
            $app->sql->db->query("INSERT INTO configured_directories (path, status) VALUES (?, ?)", $norm_new_path, 'pending');
            push @to_scan, $norm_new_path;
            $app->log->info("Friends local path added to config, scheduling scan: $norm_new_path");
        } elsif ($dir_row->{status} ne 'scanned') {
            push @to_scan, $norm_new_path;
        }
    }

    # Log summary of changes
    if (@to_purge || @to_scan) {
        $app->log->info("Config sync: " . scalar(@to_purge) . " directories to purge, " . scalar(@to_scan) . " directories to scan");
    }

    unless (@to_purge || @to_scan) {
        # Reset scanning status if no work is needed
        $app->sql->db->query("UPDATE scan_state SET value = 'idle', timestamp = 0 WHERE key = 'scan_status'");
        _parse_playlists($app, { is_reload => 1 }, sub {
            _check_and_set_idle_state($app);
        });
        return 1;
    }

    # Ensure we are marked as loading so the UI reflects the activity
    $app->db->{is_loading} = 1;

    # If we have changes, we will need to force a playlist re-scan later
    # because relative path resolution might have changed.
    $app->db->{force_playlist_rescan} = 1;

    # 3. Record tasks atomically in DB
    # Note: @to_purge and @to_scan already contain normalized paths
    # The startup hook's process_next_task will process these tasks
    try {
        my $tx = $app->sql->db->begin;
        for my $norm_p (@to_purge) {
            $app->sql->db->query('INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)', "purge_task:$norm_p", 'pending');
            $app->sql->db->query('DELETE FROM scan_state WHERE key = ?', "cleandir:$norm_p");
            $app->sql->db->query('DELETE FROM scan_state WHERE key = ?', "task:$norm_p");
            $app->log->info("Queued purge task for: $norm_p");
        }
        for my $norm_p (@to_scan) {
            $app->sql->db->query('INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)', "task:$norm_p", 'pending');
            $app->log->info("Queued scan task for: $norm_p");
        }
        $tx->commit;
    } catch {
        $app->log->error("Failed to record sync tasks: $_");
        return 0;
    };

    $app->log->info("Config sync queued " . scalar(@to_purge) . " purge tasks and " . scalar(@to_scan) . " scan tasks");

    # Trigger the task processor to handle the newly queued tasks
    Mojo::IOLoop->singleton->next_tick(sub { _start_task_processor($app) });

    return 1;
});

# Helper to verify library integrity on startup (detects offline deletions/moves)
$app->helper(verify_library_integrity => sub {
    my ($c) = @_;
    my $app = $c->app;
    my $db = $app->sql->db;
    my $tasks_found = 0;

    $app->log->info("Verifying library integrity for offline changes...");

    try {
        # 1. Check top-level configured directories for deletions
        my $db_dirs = $db->query("SELECT path FROM configured_directories")->arrays->map(sub { $_->[0] })->to_array;
        for my $path (@$db_dirs) {
            next unless defined $path;
            my $norm_path = $path; $norm_path =~ s{/+$}{};
            my $path_bytes = utf8::is_utf8($norm_path) ? encode('UTF-8', $norm_path) : $norm_path;

            if (!-d $path_bytes) {
                $app->log->warn("Configured directory missing on startup, scheduling purge: $norm_path");
                $db->query('INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)', "purge_task:$norm_path", 'pending');
                $tasks_found++;
            }
        }

        # 2. Check ALL known sub-directories for mtime changes (deep integrity check)
        my $mtime_rows = $db->query("SELECT key, value FROM scan_state WHERE key LIKE 'dir_mtime:%'")->hashes;
        for my $row (@$mtime_rows) {
            my $path = substr($row->{key}, 10); # Remove 'dir_mtime:' prefix
            my $stored_mtime = int($row->{value} // 0);
            my $path_bytes = utf8::is_utf8($path) ? encode('UTF-8', $path) : $path;

            my $exists = -d $path_bytes;
            my $current_mtime = $exists ? int((stat($path_bytes))[9] || 0) : -1;

            if (!$exists || $current_mtime != $stored_mtime) {
                if (!$exists) {
                    $app->log->info("Sub-directory missing offline, scheduling re-scan of parent: $path");
                } else {
                    $app->log->info("Directory mtime changed offline, scheduling re-scan: $path");
                }

                # Queue the specific sub-directory that changed instead of the whole root
                my $is_pending = $db->query("SELECT 1 FROM scan_state WHERE key = ? AND value = 'pending'", "task:$path")->array;
                if (!$is_pending) {
                    $app->log->info("Scheduling targeted scan for: $path");
                    $db->query('INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)', "task:$path", 'pending');
                    $tasks_found++;
                }

                # If it was deleted, remove its specific mtime tracker so we don't check it again next boot
                $db->query("DELETE FROM scan_state WHERE key = ?", $row->{key}) unless $exists;
            }
        }

        if ($tasks_found) {
            $db->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());
        }
    } catch {
        $app->log->error("Failed during library integrity check: $_");
    };

    return $tasks_found;
});

# Helper to synchronize in-memory loading state with the database truth
$app->helper(sync_loading_state_from_db => sub {
    my ($c) = @_;
    my $app = $c->app;
    try {
        my $db_status_row = $app->sql->db->query("SELECT value FROM scan_state WHERE key = 'scan_status'")->array;
        my $db_status = $db_status_row ? ($db_status_row->[0] // 'idle') : 'idle';
        my $pending_tasks = $app->sql->db->query("SELECT COUNT(*) FROM configured_directories WHERE status != 'scanned'")->array->[0] // 0;
        $pending_tasks += $app->sql->db->query("SELECT COUNT(*) FROM scan_state WHERE key LIKE 'purge_task:%'")->array->[0] // 0;

        if ($db_status eq 'scanning' || $pending_tasks > 0) {
            $app->db->{is_loading} = 1;
            $app->db->{loading_status} //= { done => 0, total => 0, processed => 0, message => 'Synchronizing...', progress => 0 };
            $app->db->{loading_status}{done} = 0;
            # If we are scanning but progress is 100, it means we just finished or are about to.
            # We keep it at 99 to show it's still working until 'idle' is set.
            if ($app->db->{loading_status}{progress} >= 100) {
                $app->db->{loading_status}{progress} = 99;
            }
        } elsif ($db_status eq 'idle' && (!defined $app->db->{loading_status} || !$app->db->{loading_status}{done})) {
            $app->db->{is_loading} = 0;
            $app->db->{loading_status}{done} = \1;
            $app->db->{loading_status}{progress} = 100;
            $app->db->{loading_status}{message} = 'Idle';
        }
    } catch {
        # If DB is busy, don't crash, just skip sync this time
        $app->log->debug("Database busy during state sync: $_");
    };
});

# Helper to purge data when a music directory is removed from config
$app->helper(purge_removed_directory => sub {
    my ($c, $path) = @_;
    my $app = $c->app;

    # Ensure path is normalized (remove trailing slashes)
    my $normalized_path = $path;
    $normalized_path =~ s{/+$}{};

    $app->log->info("Removing directory from library: $normalized_path");

    try {
        # Safety check: Only abort if the path is missing AND the root / is inaccessible (extreme disk failure)
        # Otherwise, if it's removed from config, we want it out of the DB.
        # Note: We don't require the directory to exist on disk to purge it from DB
        # (it might have been deleted before being removed from config)
        my $path_bytes = utf8::is_utf8($normalized_path) ? encode('UTF-8', $normalized_path) : $normalized_path;
        if (!-d $path_bytes && !-d "/") {
            $app->log->error("Abort purge: Root filesystem inaccessible. Possible disk disconnection.");
            return;
        }

        # Escape special characters for LIKE
        my $escaped_path = $normalized_path;
        $escaped_path =~ s/([%_])/\\$1/g;
        my $like_pattern = $escaped_path . '/%';

        my $sql = $app->sql;
        my $db = $sql->db;

        # Purge in chunks to avoid long locks.
        # We identify all songs that match the path prefix.
        my $deleted_count = 0;

        # Get other active directories to check for overlaps.
        # CRITICAL: We must exclude any directory that is a PARENT of the one being purged,
        # otherwise the overlap check will always 'keep' the songs because they match the parent.
        my $other_dirs = $db->query(
            "SELECT path FROM configured_directories WHERE path != ? AND ? NOT LIKE path || '/%'",
            $normalized_path, $normalized_path
        )->arrays->map(sub { $_->[0] })->to_array;

        my $offset = 0;
        while (1) {
            # Find songs that match the prefix of the directory being removed
            my $candidates = $db->query(
                "SELECT id, location FROM songs WHERE (location LIKE ? ESCAPE '\\' OR location = ? OR location = ?) LIMIT 500 OFFSET ?",
                $like_pattern, $normalized_path, $normalized_path . '/', $offset
            )->hashes;
            last unless $candidates->size;

            my @to_delete;
            my $skipped_in_this_batch = 0;
            for my $song (@$candidates) {
                my $keep = 0;
                my $loc = $song->{location};

                for my $other (@$other_dirs) {
                    if ($loc eq $other || $loc =~ /^\Q$other\E\//) {
                        $keep = 1;
                        last;
                    }
                }

                if ($keep) {
                    $skipped_in_this_batch++;
                } else {
                    push @to_delete, $song->{id};
                }
            }

            if (@to_delete) {
                my $tx = $db->begin;
                my $placeholders = join ',', ('?') x @to_delete;
                $db->query("DELETE FROM songs WHERE id IN ($placeholders)", @to_delete);
                $tx->commit;
                $deleted_count += scalar @to_delete;
            }

            # If we skipped files (overlaps), we must increment offset to reach next batch
            $offset += $skipped_in_this_batch;

            # If we didn't delete anything and didn't skip anything, we are done
            last if scalar @to_delete == 0 && $skipped_in_this_batch == 0;
            last if $candidates->size < 500;
        }
        $app->log->info("Purged $deleted_count songs from database for path: $path");

        # Clean up orphaned playlist entries (songs that no longer exist)
        my $orphaned_links = 0;
        while (1) {
            my $tx = $db->begin;
            # We use a subquery to find song_ids that don't exist in the songs table
            my $rows = $db->query('DELETE FROM playlist_songs WHERE song_id NOT IN (SELECT id FROM songs) LIMIT 500')->rows;
            $tx->commit;
            $orphaned_links += $rows;
            last if $rows < 500;
        }
        $app->log->info("Removed $orphaned_links orphaned playlist entries.") if $orphaned_links;

        # Final cleanup
        {
            my $tx = $db->begin;
            # Clean up empty playlists that might have resulted from the purge (excluding radio ones)
            $db->query("DELETE FROM playlists WHERE name NOT IN (SELECT DISTINCT playlist_name FROM playlist_songs) AND type != 'radio'");

            # Clean up ignored paths and scan state markers for the removed directory
            $db->query("DELETE FROM ignored_paths WHERE (path LIKE ? ESCAPE '\\' OR path = ? OR path = ?)", $like_pattern, $normalized_path, $normalized_path . '/');
            $db->query('DELETE FROM scan_state WHERE key = ?', "cleandir:$normalized_path");
            $db->query('DELETE FROM configured_directories WHERE path = ?', $normalized_path);
            $tx->commit;
        }

        # Mark playlists as potentially out of date in the database for multi-worker consistency.
        # This ensures that if a song was removed from one directory but exists in another,
        # the playlist will be updated to point to the remaining copy.
        try {
            $db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES ('playlists_out_of_date', '1')");
        } catch {
            $app->log->error("Failed to mark playlists out of date in DB: $_");
        };

        # Trigger a playlist re-scan to ensure they are consistent with the new library state
        Mojo::IOLoop->singleton->next_tick(sub {
            $app->log->info("Revalidating playlists after directory purge...");
            _parse_playlists($app, { is_reload => 1, force => 1 }, sub {
                # Broadcast update to clients after playlists are also updated
                $app->mark_library_dirty;
            });
        });
    } catch {
        $app->log->error("Failed to purge directory data for $path: $_");
    };
});

# API: POST /api/library/rescan - Triggers a full deep re-scan of the library
$app->routes->post('/api/library/rescan' => sub {
    my ($c) = @_;
    # Reset status for all directories to force re-scan
    $c->app->sql->db->query("UPDATE configured_directories SET status = 'pending'");
    my $address = $c->remote_address_with_port;
    my $is_private = is_private_ip($address, \@PRIVATE_NETWORKS, $c->app->log);
    my $is_admin = $c->is_admin;

    unless ($is_admin || ($is_private && $ALLOW_LOCAL_NETWORK_EDITING && $ADMIN_PASSWORD)) {
        return $c->render(text => 'Forbidden', status => 403);
    }

    $c->app->log->info("Manual deep re-scan triggered by admin.");

    # Reset scan state and trigger parsing with force_deep_scan
    _start_library_parsing($c->app, { is_reload => 1, force_deep_scan => 1, force => 1 });

    $c->render(json => { success => 1, message => 'Deep re-scan started.' });
});

# API: POST /api/song/:id/update_tag - Updates a specific metadata tag
$app->routes->post('/api/song/:id/update_tag' => sub {
    my ($c) = @_;
    my $params = $c->req->json;
    my $tag_name = $params->{tag_name};

    # Authorization check
    my $address = $c->remote_address_with_port;
    my $is_private = is_private_ip($address, \@PRIVATE_NETWORKS, $c->app->log);
    my $is_admin = $c->is_admin;

    my $local_bypass = ($is_private && $ALLOW_LOCAL_NETWORK_EDITING && $ADMIN_PASSWORD);

    unless ($is_admin || $local_bypass) {
        return $c->render(json => { success => 0, message => 'Forbidden: You do not have permission to perform this action.' }, status => 403);
    }

    my $partial_id = $c->param('id');
    unless ($partial_id && $partial_id =~ /^[0-9a-f]{1,16}$/i) {
        $c->app->log->error("Invalid song ID format for tag update: '$partial_id'");
        return $c->render(json => { success => 0, message => 'Invalid song ID' });
    }

    my ($song, $full_id) = _find_song_by_partial_id($c, $partial_id);

    if (!$song) {
        my $resolved_path = realpath($partial_id) // File::Spec->rel2abs($partial_id);
        $resolved_path =~ s{/+$}{}; # Ensure no trailing slash for consistency
        my $calculated_id = substr(sha1_hex(encode('UTF-8', $resolved_path)), 0, 16);
        $song = $c->app->sql->db->query('SELECT * FROM songs WHERE id = ?', $calculated_id)->hash;
        $full_id = $calculated_id if $song;
    }

    unless ($song) {
        $c->app->log->warn("API request to update unknown song ID: $partial_id");
        return $c->render(json => { success => 0, message => 'Song not found' });
    }

    my $tag_value = $params->{tag_value};

    unless (defined $tag_name && defined $tag_value) {
        return $c->render(json => { success => 0, message => 'Missing tag_name or tag_value' });
    }

    my $safe_path = _get_safe_song_path($c, $full_id);
    unless ($safe_path) {
        $c->app->log->error("Failed to get safe path for song ID '$full_id' for tag update.");
        return $c->render(json => { success => 0, message => 'Could not access file path for song' });
    }

    my $db = $c->app->db;
    my $updated_in_memory = 0;
    my $tag_updated_on_file = 0;
    my $error;

    # Mark this path to be ignored by the watcher (shared across processes via DB)
    my $real_path = realpath($safe_path) || $safe_path;
    $real_path =~ s{/+$}{}; # Ensure no trailing slash for consistency
    {
        my $tx = $c->app->sql->db->begin;
        $c->app->sql->db->query('INSERT OR REPLACE INTO ignored_paths (path, timestamp) VALUES (?, ?)', $real_path, time());
        $tx->commit;
    }

    # Capture sidebar counts before update to decide if UI refresh is needed
    my $count_before = 0;
    if ($tag_name =~ /^(artist|album|genre)$/i) {
        $count_before += scalar @{get_artists($c->app)};
        $count_before += scalar @{get_albums($c->app)};
        $count_before += scalar @{get_genres($c->app)};
    }

    try {
        # Update SQLite DB first
        my %tag_to_col = (
            rating       => 'rating',
            title        => 'title',
            artist       => 'artist',
            album        => 'album',
            genre        => 'genre',
            track_number => 'track_number',
            year         => 'year',
            comment      => 'comment',
            album_artist => 'album_artist',
            composer     => 'composer',
            disc_number  => 'disc_number',
            play_count   => 'play_count',
            skip_count   => 'skip_count',
        );

        if (my $col = $tag_to_col{$tag_name}) {
            # Update SQLite DB first
            $c->app->sql->db->query("UPDATE songs SET $col = ? WHERE id = ?", $tag_value, $full_id);
            $updated_in_memory = 1;

            # Only attempt to write to file for actual ID3 tags
            if (!($tag_name eq 'play_count' || $tag_name eq 'skip_count')) {
                my $safe_path_bytes = utf8::is_utf8($safe_path) ? encode('UTF-8', $safe_path) : $safe_path;
                my $mp3 = MP3::Tag->new($safe_path_bytes, { ignore_bad_frames => 1 });
                unless ($mp3) {
                    die "Failed to open MP3::Tag for file '$safe_path'";
                }
                $mp3->config(decode_encoding_v2 => 'utf-8', decode_encoding_v1 => 'utf-8');
                $mp3->get_tags();

                try {
                    # Update tags (prefer ID3v2, create if missing)
                    my $id3v2 = $mp3->{ID3v2} || $mp3->new_tag("ID3v2");
                    if ($id3v2) {
                        if ($tag_name eq 'rating') {
                            # ID3v2.3/4 POPM frame: Popularimeter. Value is 0-255.
                            my %rating_map = (
                                0 => 0,
                                1 => 1,
                                2 => 64,
                                3 => 128,
                                4 => 196,
                                5 => 255,
                            );
                            my $popm_value = $rating_map{$tag_value} // 0;

                            $id3v2->remove_frame('POPM');
                            if ($tag_value > 0) {
                                my $user_email = $db->{current_user_email} || 'user';
                                $id3v2->add_frame('POPM', $user_email, $popm_value, 0); # 0 for play count
                            }

                            $id3v2->remove_frame('TXXX', 'rating');
                            if ($tag_value > 0) {
                                $id3v2->add_frame('TXXX', 'rating', $tag_value);
                            }
                        } elsif ($tag_name eq 'title') {
                            $id3v2->title($tag_value);
                        } elsif ($tag_name eq 'artist') {
                            $id3v2->artist($tag_value);
                        } elsif ($tag_name eq 'album') {
                            $id3v2->album($tag_value);
                        } elsif ($tag_name eq 'genre') {
                            $id3v2->genre($tag_value);
                        } elsif ($tag_name eq 'year') {
                            $id3v2->year($tag_value);
                        } elsif ($tag_name eq 'comment') {
                            $id3v2->comment($tag_value);
                        } elsif ($tag_name eq 'album_artist') {
                            # TPE2 (Band/orchestra/accompaniment) for album artist
                            $id3v2->frame_set('TPE2', $tag_value);
                        } elsif ($tag_name eq 'composer') {
                            $id3v2->composer($tag_value);
                        } elsif ($tag_name eq 'disc_number') {
                            # TPOS (Part of a set) for disc number
                            $id3v2->frame_set('TPOS', $tag_value);
                        } elsif ($tag_name eq 'track_number') {
                            # TRCK (Track number/Position in set)
                            $id3v2->frame_set('TRCK', $tag_value);
                        }
                        $id3v2->write_tag();
                        $tag_updated_on_file = 1;
                    }

                    my $id3v1 = $mp3->{ID3v1};
                    if ($id3v1) {
                        if ($tag_name eq 'title') {
                            $id3v1->title($tag_value);
                        } elsif ($tag_name eq 'artist') {
                            $id3v1->artist($tag_value);
                        } elsif ($tag_name eq 'album') {
                            $id3v1->album($tag_value);
                        } elsif ($tag_name eq 'genre') {
                            $id3v1->genre($tag_value);
                        } elsif ($tag_name eq 'track_number') {
                            $id3v1->track($tag_value);
                        } elsif ($tag_name eq 'year') {
                            $id3v1->year($tag_value);
                        }
                        $id3v1->write_tag();
                    }

                    $c->app->log->info("Updated tag '$tag_name' for song '$song->{title}' to '$tag_value'.") if $ENABLE_VERBOSE_LOGGING;

                    # Update database with the new file mtime to prevent re-scan conflicts
                    # and ensure the specific tag is updated in the DB record
                    my $new_mtime = (stat($safe_path_bytes))[9] || time();
                    my $col = $tag_to_col{$tag_name};
                    $c->app->sql->db->query("UPDATE songs SET $col = ?, date_modified = ? WHERE id = ?", $tag_value, $new_mtime, $full_id);

                    # Only refresh UI if sidebar counts changed
                    if ($tag_name =~ /^(artist|album|genre)$/i) {
                        my $count_after = scalar @{get_artists($c->app)} + scalar @{get_albums($c->app)} + scalar @{get_genres($c->app)};
                        $c->app->mark_library_dirty if $count_before != $count_after;
                    }
                } catch {
                    $error = $_;
                } finally {
                    $mp3->close() if $mp3;
                };
            } else {
                # For play_count and skip_count, only DB is updated.
                $c->app->log->info("Updated DB-only tag '$tag_name' for song '$song->{title}' to '$tag_value'.") if $ENABLE_VERBOSE_LOGGING;
            }
        }
    } catch {
        $error = $_;
    };

    if (defined $error) {
        $c->app->sql->db->query('DELETE FROM ignored_paths WHERE path = ?', $real_path);
        my $error_msg = "Failed to update tag '$tag_name' for '$song->{title}': $error";
        $c->app->log->error($error_msg);
        return $c->render(json => { success => 0, message => $error_msg }, status => 500);
    }

    return $c->render(json => {
        success => 1,
        message => "Tag updated successfully.",
        updated_in_memory => $updated_in_memory,
        tag_updated_on_file => $tag_updated_on_file,
    });
});


}

sub _broadcast_lyrics_update {
    my ($app, $id, $lyrics) = @_;
    my $db = $app->db;
    return unless $db->{websockets} && ref $db->{websockets} eq 'HASH' && scalar(keys %{$db->{websockets}});

    for my $tx (values %{$db->{websockets}}) {
        $tx->send(Mojo::JSON::to_json({ event => 'lyrics_update', id => $id, lyrics => $lyrics }));
    }
}

sub _broadcast_status_update {
    my ($app) = @_;
    my $db = $app->db;
    return unless $db->{websockets} && ref $db->{websockets} eq 'HASH' && scalar(keys %{$db->{websockets}});
    for my $tx (values %{$db->{websockets}}) {
        $tx->send(Mojo::JSON::to_json({ event => 'status_update', status => $db->{loading_status} }));
    }
}

sub _broadcast_library_update {
    my ($app) = @_;
    my $db = $app->db;
    return unless $db->{websockets} && ref $db->{websockets} eq 'HASH' && scalar(keys %{$db->{websockets}});
    state $broadcast_timer;
    if ($broadcast_timer) { Mojo::IOLoop->singleton->remove($broadcast_timer); undef $broadcast_timer }
    $broadcast_timer = Mojo::IOLoop->singleton->timer(2 => sub {
        undef $broadcast_timer;
        for my $tx (values %{$db->{websockets}}) { $tx->send(Mojo::JSON::to_json({ event => 'library_updated' })) }
    });
}

sub _broadcast_config_update {
    my ($app) = @_;
    my $db = $app->db;
    return unless $db->{websockets} && ref $db->{websockets} eq 'HASH' && scalar(keys %{$db->{websockets}});
    for my $tx (values %{$db->{websockets}}) { $tx->send(Mojo::JSON::to_json({ event => 'config_updated' })) }
}

sub _get_location_id_map {
    my ($app) = @_;
    my $results = $app->sql->db->query('SELECT id, location FROM songs');
    my %map;
    while (my $row = $results->hash) {
        $map{$row->{location}} = $row->{id};
    }
    return \%map;
}

# Finds a song ID by its path, handling various path formats.
sub _find_song_id_by_path {
    my ($app, $path, $playlist_name, $id_map) = @_;
    my $db = $app->db;

    return undef unless defined $path && $path ne '';

    # Clean whitespace and handle URI encoding
    $path =~ s/^\s+|\s+$//g;
    $path = uri_unescape($path);
    $path =~ s/^file:\/\///i;

    # Fast path: check if the raw path is in our map
    if ($id_map && ref $id_map eq 'HASH' && exists $id_map->{$path}) {
        return $id_map->{$path};
    }

    # Some playlists might have relative paths. Try to resolve them.
    my $abs_path_found;
    if (!File::Spec->file_name_is_absolute($path)) {
        for my $music_dir (@SynthwavePlayer::Config::MUSIC_DIRECTORIES) {
            next unless defined $music_dir && $music_dir ne '';
            my $abs_path = File::Spec->catfile($music_dir, $path);
            # -f expects bytes on Linux.
            my $abs_path_bytes = utf8::is_utf8($abs_path) ? encode('UTF-8', $abs_path) : $abs_path;
            if (-f $abs_path_bytes) {
                $abs_path_found = $abs_path;
                last;
            }
        }
    }
    my $lookup_path = $abs_path_found // $path;

    # Check map again with absolute path
    if ($id_map && ref $id_map eq 'HASH' && exists $id_map->{$lookup_path}) {
        return $id_map->{$lookup_path};
    }

    # Resolve symlinks/relative dots to match DB storage format
    my $resolved_path = realpath($lookup_path) // File::Spec->rel2abs($lookup_path);
    $resolved_path =~ s{/+$}{}; # Ensure no trailing slash for consistency

    # Check map again with resolved path
    if ($id_map && ref $id_map eq 'HASH' && exists $id_map->{$resolved_path}) {
        return $id_map->{$resolved_path};
    }

    my $id_from_path = substr(sha1_hex(encode('UTF-8', $resolved_path)), 0, 16);
    if ($id_map) {
        # We don't have a reverse map for IDs, but we can check if this ID exists in the values
        # However, it's faster to just check the DB if the map failed
    }

    # Try finding by the calculated ID (most reliable) or location
    # We only check resolved_path for location as we now store realpaths
    if (my $row = $app->sql->db->query('SELECT id FROM songs WHERE id = ? OR location = ?', $id_from_path, $resolved_path)->hash) {
        return $row->{id};
    }

    # Try with normalization for special characters
    my $normalized_path = $resolved_path;
    $normalized_path =~ s/⧸/\//g;
    $normalized_path =~ s/⧹/\\/g;
    if (my $row = $app->sql->db->query('SELECT id FROM songs WHERE location = ?', $normalized_path)->hash) {
        return $row->{id};
    }

    $app->log->debug("Song '$path' from playlist '$playlist_name' not found in library.") if $ENABLE_DEBUG_LOGGING;
    $db->{playlists_out_of_date}->{$playlist_name} = 1 if defined $playlist_name;
    return undef;
}

sub _process_playlist_entry {
    my ($app, $path, $title, $playlist_name, $id_map) = @_;
    my $db = $app->db;

    my $trimmed_path = $path;
    $trimmed_path =~ s/^\s+|\s+$//g;

    # Check if it's a URL (radio stream)
    if ($trimmed_path =~ /^(https?):\/\/(.*)$/i) {

        my $scheme = lc($1);
        my $rest = $2;
        $rest =~ s/\s//g; # remove any whitespace from URL
        my $clean_url = "$scheme://$rest";
        my $id = substr(sha1_hex($clean_url), 0, 16);

        try {
            my $db_h = $app->sql->db;
            unless ($db_h->query('SELECT id FROM songs WHERE id = ?', $id)->hash) {
                $db_h->query(
                    'INSERT OR IGNORE INTO songs (id, title, artist, album, genre, duration, rating, location, track_number, bitrate, date_added, date_modified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    $id, $title || '', $playlist_name, 'Radio', 'Radio', 999999999, 0, $clean_url, 0, 0, time(), time()
                );
            }
            return { id => $id, type => 'radio' };
        } catch {
            $app->log->error("Failed to insert radio stream '$clean_url': $_");
            return undef;
        };
    }
    # Otherwise, treat as a local file path
    else {
        my $id = _find_song_id_by_path($app, $path, $playlist_name, $id_map);
        return $id ? { id => $id, type => 'file' } : undef;
    }
}

sub get_playlists {
    my ($app, $initial_ids, $ratings_filter_str) = @_;

    my $query = "SELECT DISTINCT p.name, p.type FROM playlists p";
    my @bind;

    if (($initial_ids && @$initial_ids) || (defined $ratings_filter_str && length $ratings_filter_str)) {
        $query .= " JOIN playlist_songs ps ON p.name = ps.playlist_name";
        $query .= " JOIN songs s ON ps.song_id = s.id";
        $query .= " WHERE 1=1";

        if ($initial_ids && @$initial_ids) {
            $query .= " AND s.id IN (" . join(',', ('?') x @$initial_ids) . ")";
            push @bind, @$initial_ids;
        }

        if (defined $ratings_filter_str && length $ratings_filter_str) {
            my @ratings = split /\|/, $ratings_filter_str;
            @ratings = grep { /^\d+$/ && $_ >= 0 && $_ <= 5 } @ratings;
            if (@ratings) {
                $query .= " AND (s.rating IN (" . join(',', ('?') x @ratings) . ")";
                if (grep { $_ == 0 } @ratings) {
                    $query .= " OR s.rating IS NULL";
                }
                $query .= ")";
                push @bind, @ratings;
            }
        }
    }

    my $playlists = $app->sql->db->query($query, @bind)->hashes;
    my @names = sort { _natural_compare($a, $b) } map { $_->{name} } @$playlists;
    my %info = map { $_->{name} => { type => $_->{type} } } @$playlists;
    return { names => \@names, info => \%info };
}

sub get_playlist_songs {
    my ($app, $name) = @_;
    return $app->sql->db->query(
        'SELECT song_id FROM playlist_songs WHERE playlist_name = ? ORDER BY position',
        $name
    )->arrays->map(sub { $_->[0] })->to_array;
}

sub _apply_rating_filter_to_query {
    my ($query_ref, $bind_ref, $ratings_filter_str) = @_;
    return unless defined $ratings_filter_str && length $ratings_filter_str;

    my @ratings = split /\|/, $ratings_filter_str;
    @ratings = grep { /^\d+$/ && $_ >= 0 && $_ <= 5 } @ratings;
    if (@ratings) {
        $$query_ref .= " AND (rating IN (" . join(',', ('?') x @ratings) . ")";
        if (grep { $_ == 0 } @ratings) {
            $$query_ref .= " OR rating IS NULL";
        }
        $$query_ref .= ")";
        push @$bind_ref, @ratings;
    }
}

sub get_genres {
    my ($app, $initial_ids, $ratings_filter_str) = @_;
    my $query = "SELECT DISTINCT genre FROM songs WHERE genre IS NOT NULL AND genre != ''";
    my @bind;
    if ($initial_ids && @$initial_ids) {
        $query .= " AND id IN (" . join(',', ('?') x @$initial_ids) . ")";
        push @bind, @$initial_ids;
    }
    _apply_rating_filter_to_query(\$query, \@bind, $ratings_filter_str);

    my $genres = $app->sql->db->query($query, @bind)->arrays->map(sub { $_->[0] })->to_array;
    return [ sort { _natural_compare($a, $b) } grep {
        !_is_matched($app, $_, \@SynthwavePlayer::Config::IGNORE_GENRES_MATCHING, 'IGNORE_GENRES_MATCHING') &&
        !_is_matched($app, $_, \@SynthwavePlayer::Config::BLACKLIST_GENRES_MATCHING, 'BLACKLIST_GENRES_MATCHING')
    } @$genres ];
}

sub get_artists {
    my ($app, $initial_ids, $ratings_filter_str) = @_;
    my $query = "SELECT DISTINCT artist FROM songs WHERE artist IS NOT NULL AND artist != ''";
    my @bind;
    if ($initial_ids && @$initial_ids) {
        $query .= " AND id IN (" . join(',', ('?') x @$initial_ids) . ")";
        push @bind, @$initial_ids;
    }
    _apply_rating_filter_to_query(\$query, \@bind, $ratings_filter_str);

    my $artists = $app->sql->db->query($query, @bind)->arrays->map(sub { $_->[0] })->to_array;
    return [ sort { _natural_compare($a, $b) } grep {
        !_is_matched($app, $_, \@SynthwavePlayer::Config::BLACKLIST_ARTISTS_MATCHING, 'BLACKLIST_ARTISTS_MATCHING')
    } @$artists ];
}

sub get_albums {
    my ($app, $initial_ids, $ratings_filter_str) = @_;
    my $query = "SELECT DISTINCT album FROM songs WHERE album IS NOT NULL AND album != ''";
    my @bind;
    if ($initial_ids && @$initial_ids) {
        $query .= " AND id IN (" . join(',', ('?') x @$initial_ids) . ")";
        push @bind, @$initial_ids;
    }
    _apply_rating_filter_to_query(\$query, \@bind, $ratings_filter_str);

    my $albums = $app->sql->db->query($query, @bind)->arrays->map(sub { $_->[0] })->to_array;
    return [ sort { _natural_compare($a, $b) } @$albums ];
}

# Updates song statistics (play count, skip count, etc.)
sub _update_song_stats {
    my ($app, $id, $type) = @_;
    my $now = time();

    try {
        my $db = $app->sql->db;
        my $tx = $db->begin;

        if ($type eq 'play') {
            $db->query(
                'UPDATE songs SET last_played = ?, play_count = play_count + 1 WHERE id = ?',
                $now, $id
            );
        } elsif ($type eq 'skip') {
            $db->query(
                'UPDATE songs SET last_skipped = ?, skip_count = skip_count + 1 WHERE id = ?',
                $now, $id
            );
        }

        $tx->commit;
    } catch {
        $app->log->error("Failed to update song stats for $id: $_");
    };
}

# Single task processor - processes one task at a time from the queue
sub _start_task_processor {
    my ($app) = @_;
    state $is_processing_task = 0;

    return if $is_processing_task;

    # Check if there are any pending tasks
    my $pending_count = $app->sql->db->query(
        "SELECT COUNT(*) FROM scan_state WHERE (key LIKE 'task:%' OR key LIKE 'purge_task:%') AND value = 'pending'"
    )->array->[0] // 0;

    if ($pending_count == 0) {
        $app->log->info("No pending tasks found.");

        # Check if we're truly done (no processing tasks either)
        my $processing_count = $app->sql->db->query(
            "SELECT COUNT(*) FROM scan_state WHERE (key LIKE 'task:%' OR key LIKE 'purge_task:%') AND value = 'processing'"
        )->array->[0] // 0;

        if ($processing_count == 0) {
            # All done - check playlists and set idle
            $app->log->info("All tasks completed. Checking for playlist updates.");

            my $playlists_changed = 0;
            for my $p_dir (@PLAYLISTS_DIRECTORIES) {
                next unless $p_dir;
                my $norm_p_dir = realpath($p_dir) // $p_dir;
                $norm_p_dir =~ s{/+$}{};
                my $p_dir_bytes = utf8::is_utf8($norm_p_dir) ? encode('UTF-8', $norm_p_dir) : $norm_p_dir;
                next unless -d $p_dir_bytes;
                my $resolved = realpath($norm_p_dir) // $norm_p_dir;
                my $current_mtime = int((stat($p_dir_bytes))[9] || 0);
                my $stored_mtime_row = $app->sql->db->query("SELECT value FROM scan_state WHERE key = ?", "dir_mtime:" . $resolved)->array;
                my $stored_mtime = $stored_mtime_row ? ($stored_mtime_row->[0] // 0) : 0;
                if ($current_mtime != int($stored_mtime)) {
                    $playlists_changed = 1;
                    last;
                }
            }

            if ($playlists_changed) {
                _parse_playlists($app, {}, sub {
                    SynthwavePlayer::Library::Watcher::_setup_library_watcher($app);
                    _check_and_set_idle_state($app);
                });
            } else {
                SynthwavePlayer::Library::Watcher::_setup_library_watcher($app);
                _check_and_set_idle_state($app);
            }
        } else {
            # Some tasks are still processing, wait and check again
            $app->log->debug("Waiting for $processing_count tasks to complete...") if $ENABLE_DEBUG_LOGGING;
            Mojo::IOLoop->singleton->timer(2 => sub { _start_task_processor($app) });
        }
        return;
    }

    $app->log->info("Found $pending_count pending tasks to process");

    # Get and claim the next task atomically
    my $task_key;
    my $task_path;
    my $is_purge = 0;

    try {
        my $db_h = $app->sql->db;
        my $tx = $db_h->begin('immediate');

        # Prioritize purge tasks
        my $row = $db_h->query(
            "SELECT key FROM scan_state WHERE key LIKE 'purge_task:%' AND value = 'pending' LIMIT 1"
        )->array;

        if ($row) {
            $is_purge = 1;
        } else {
            $row = $db_h->query(
                "SELECT key FROM scan_state WHERE key LIKE 'task:%' AND value = 'pending' LIMIT 1"
            )->array;
        }

        if ($row) {
            $task_key = $row->[0];
            $task_path = $task_key;
            $task_path =~ s/^(task|purge_task)://;

            # Mark as processing
            $db_h->query("UPDATE scan_state SET value = 'processing', timestamp = ? WHERE key = ?", time(), $task_key);

            # Set global scanning state
            $db_h->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());

            if (!$is_purge) {
                $db_h->query("UPDATE configured_directories SET status = 'scanning' WHERE path = ?", $task_path);
            }
        }

        $tx->commit;
    } catch {
        $app->log->error("Failed to claim task: $_");
        # Wait and retry
        Mojo::IOLoop->singleton->timer(2 => sub { _start_task_processor($app) });
        return;
    };

    unless ($task_key) {
        $app->log->warn("No task claimed, retrying...");
        Mojo::IOLoop->singleton->timer(1 => sub { _start_task_processor($app) });
        return;
    }

    # Skip URL tasks
    if ($task_path =~ m{^https?://}i) {
        $app->log->warn("Skipping URL task (not a local directory): $task_key");
        try {
            $app->sql->db->query('DELETE FROM scan_state WHERE key = ?', $task_key);
            $app->sql->db->query('DELETE FROM configured_directories WHERE path = ?', $task_path);
        } catch {};
        Mojo::IOLoop->singleton->next_tick(sub { _start_task_processor($app) });
        return;
    }

    $app->log->info("Processing task: $task_key");
    $is_processing_task = 1;

    if ($is_purge) {
        # Handle purge task
        $app->db->{loading_status}{message} = "Purging removed directory: $task_path";
        $app->db->{loading_status}{done} = \0;
        _broadcast_status_update($app);

        $app->purge_removed_directory($task_path);

        try {
            $app->sql->db->query('DELETE FROM scan_state WHERE key = ?', $task_key);
        } catch {
            $app->log->error("Failed to remove completed purge task: $_");
        };

        $app->log->info("Purge task completed: $task_key");

        # Process next task
        $is_processing_task = 0;
        Mojo::IOLoop->singleton->next_tick(sub { _start_task_processor($app) });
        return;
    }

    # Handle scan task
    my $path_bytes = utf8::is_utf8($task_path) ? encode('UTF-8', $task_path) : $task_path;
    if (!-d $path_bytes) {
        $app->log->warn("Directory no longer exists: $task_path");
        try {
            $app->sql->db->query('DELETE FROM scan_state WHERE key = ?', $task_key);
            $app->sql->db->query("UPDATE configured_directories SET status = 'scanned' WHERE path = ?", $task_path);
        } catch {};
        Mojo::IOLoop->singleton->next_tick(sub { _start_task_processor($app) });
        return;
    }

    # Pre-scan files
    my @files = _scan_music_directories($app, { target_path => $task_path });
    my $file_count = scalar @files;

    $app->log->info("Found $file_count files in $task_path");
    $app->db->{loading_status}{message} = "Scanning $task_path ($file_count files)";
    $app->db->{loading_status}{total} = $file_count;
    $app->db->{loading_status}{processed} = 0;
    $app->db->{loading_status}{done} = \0;
    _broadcast_status_update($app);

    # Safety timer
    my $safety_timer_id;
    my $safety_active = 1;
    $safety_timer_id = Mojo::IOLoop->timer(1200 => sub {
        $safety_active = 0;
        $app->log->error("Task $task_key timed out!");
        _start_task_processor($app);
    });

    _start_library_parsing($app, {
        is_reload => 1,
        force_deep_scan => 1,
        target_path => $task_path,
        task_key => $task_key,
        pre_scanned_files => \@files
    }, sub {
        my ($app, $options) = @_;

        # Cancel safety timer
        if ($safety_active && defined $safety_timer_id) {
            Mojo::IOLoop->singleton->remove($safety_timer_id);
        }

        # Mark task as complete
        try {
            my $db_h = $app->sql->db;
            my $tx = $db_h->begin;
            $db_h->query('DELETE FROM scan_state WHERE key = ?', $task_key);
            my $norm_path = realpath($task_path) // $task_path;
            $norm_path =~ s{/+$}{};
            $db_h->query('INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)', "cleandir:$norm_path", time());
            $db_h->query("UPDATE configured_directories SET status = 'scanned', last_scanned = ? WHERE path = ?", time(), $norm_path);
            $tx->commit;
            $app->log->info("Scan task completed: $task_key");
        } catch {
            $app->log->error("Failed to finalize task $task_key: $_");
        };

        # Process next task
        $is_processing_task = 0;
        Mojo::IOLoop->singleton->next_tick(sub { _start_task_processor($app) });
    });
}

sub _check_and_set_idle_state {
    my ($app) = @_;
    # Only set idle if no tasks are pending
    my $row = $app->sql->db->query("SELECT COUNT(*) FROM configured_directories WHERE status != 'scanned'")->array;
    my $remaining = $row ? ($row->[0] // 0) : 0;
    $remaining += $app->sql->db->query("SELECT COUNT(*) FROM scan_state WHERE key LIKE 'purge_task:%'")->array->[0] // 0;

    if ($remaining == 0) {
        try {
            my $db = $app->sql->db;
            my $tx = $db->begin;
            $db->query("UPDATE scan_state SET value = 'idle', timestamp = 0 WHERE key = 'scan_status'");
            $db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES ('last_scan_completed_at', ?)", time());
            # Clean up old cleandir markers (older than 90 days) to force periodic re-verification
            $db->query("DELETE FROM scan_state WHERE key LIKE 'cleandir:%' AND CAST(value AS INTEGER) < ?", time() - (90 * 86400));
            $tx->commit;
        } catch {
            $app->log->error("Failed to set idle state: $_");
        };

        # Ensure memory state reflects idle after DB update to prevent UI flickering
        $app->db->{is_loading} = 0;
        $app->db->{loading_status}{done} = \1;  # Use reference for JSON boolean
        $app->db->{loading_status}{progress} = 100;

        if (($app->db->{loading_status}{total} // 0) == 0 && ($app->db->{loading_status}{processed} // 0) == 0) {
            $app->db->{loading_status}{message} = 'Library is empty';
        } else {
            $app->db->{loading_status}{message} = 'Idle';
        }

        _broadcast_status_update($app);
    }
}

sub _get_lyrics {
    my ($app, $id, $song) = @_;

    my $lyrics;

    # --- Step 1: Check for cached lyrics ---
    if ($LYRICS_CACHE_DIR) {
        my $cache_file_path = File::Spec->catfile($LYRICS_CACHE_DIR, "$id.txt");
        if (-f $cache_file_path) {
            my $cached_lyrics;
            try {
                $cached_lyrics = decode('UTF-8', path($cache_file_path)->slurp, Encode::FB_CROAK);
            } catch {
                $app->log->error("API: Failed to read cached lyrics file '$cache_file_path': $_");
            };

            # Accept cached lyrics if they exist and have meaningful content
            # Use configurable minimum length or default to 10 chars (allows short lyrics/interludes)
            my $min_lyrics_length = $app->config->{min_lyrics_cache_length} // 10;
            if (defined $cached_lyrics && length($cached_lyrics) >= $min_lyrics_length) {
                $lyrics = $cached_lyrics;
                $app->log->debug("API: Found cached lyrics for song ID: $id.") if $ENABLE_DEBUG_LOGGING;
                if ($ENABLE_VERBOSE_LOGGING) {
                    if ($song) {
                        $app->log->debug(" -> Lyrics found on cache for song: \"$song->{title}\" by \"$song->{artist}\"");
                    }
                }
            }
        }
    }

    # --- Step 1.5: Check for instrumental cache ---
    if (!defined $lyrics && $LYRICS_INSTRUMENTAL_CACHE_DIR) {
        my $inst_file_path = File::Spec->catfile($LYRICS_INSTRUMENTAL_CACHE_DIR, "$id.txt");
        if (-f $inst_file_path) {
            $app->log->debug("API: Song ID $id is known instrumental.") if $ENABLE_DEBUG_LOGGING;
            return undef;
        }
    }

    # --- Step 2: Check for local lyrics if not found in cache ---
    unless (defined $lyrics) {
        my $local_lyrics;
        if ($song && !($song->{location} =~ /^https?:\/\//i)) {
            my $file_path = $song->{location};
            my $real_path = realpath($file_path);

            if ($real_path) {
                my $real_path_bytes = utf8::is_utf8($real_path) ? encode('UTF-8', $real_path) : $real_path;
                if (-f $real_path_bytes) {
                    $local_lyrics = get_local_lyrics_data($app, $id, $real_path_bytes, $EYED3_AVAILABLE, $ENABLE_DEBUG_LOGGING);
                }
            }
        }

        if (defined $local_lyrics) {
            $lyrics = $local_lyrics;
            $app->log->debug("API: Local lyrics found for song ID: $id.") if $ENABLE_DEBUG_LOGGING;

            # Cache the locally found lyrics for future requests
            if ($LYRICS_CACHE_DIR) {
                my $cache_file_path = File::Spec->catfile($LYRICS_CACHE_DIR, "$id.txt");
                try {
                    path($LYRICS_CACHE_DIR)->make_path;
                    path($cache_file_path)->spew(encode('UTF-8', $lyrics . "\n"));
                    $app->log->debug("API: Cached locally-found lyrics to '$cache_file_path'.") if $ENABLE_DEBUG_LOGGING;
                } catch {
                    $app->log->error("API: Failed to write locally-found lyrics to cache file '$cache_file_path': $_");
                };
            }
        }
    }

    # --- Step 3: Return lyrics if found, otherwise trigger online search ---
    if (defined $lyrics) {
        return $lyrics;
    }

    return undef unless $ENABLE_ONLINE_LYRICS_SEARCH;

    if ($song && !($song->{location} =~ /^https?:\/\//i)) {
        my $config = {
            LYRICS_FAIL_CACHE_DIR => $LYRICS_FAIL_CACHE_DIR,
            LYRICS_CACHE_DIR => $LYRICS_CACHE_DIR,
            LYRICS_INSTRUMENTAL_CACHE_DIR => $LYRICS_INSTRUMENTAL_CACHE_DIR,
            ENABLE_VERBOSE_LOGGING => $ENABLE_VERBOSE_LOGGING,
            ENABLE_DEBUG_LOGGING => $ENABLE_DEBUG_LOGGING,
        };
        fetch_online_lyrics_async($app, $id, $song->{title}, $song->{artist}, $config, sub {
            my ($id, $lyrics) = @_;
            _broadcast_lyrics_update($app, $id, $lyrics);
        });
    }
    return undef;
}

# Finds a song by a partial ID (prefix match).
# Returns the song hash and the full ID on success.
sub _find_song_by_partial_id {
    my ($c, $partial_id) = @_;
    my $db = $c->app->db;

    return (undef, undef) unless $db->{loading_status}{done};

    if (my $row = $c->app->sql->db->query('SELECT * FROM songs WHERE id LIKE ? LIMIT 1', lc($partial_id) . '%')->hash) {
        return ($row, $row->{id});
    }
    return (undef, undef);
}

sub init_database {
    my ($db) = @_;

    # Use a transaction for atomic schema creation
    my $tx = $db->begin;

    $db->query('CREATE TABLE IF NOT EXISTS songs (
        id TEXT PRIMARY KEY,
        title TEXT, artist TEXT, album TEXT, genre TEXT, duration INTEGER, rating INTEGER, location TEXT UNIQUE, track_number INTEGER, bitrate TEXT,
        album_artist TEXT, bpm TEXT, channels TEXT, comment TEXT, composer TEXT, date_added INTEGER, date_modified INTEGER, description TEXT, disc_number INTEGER, episode_number TEXT, keywords TEXT, sample_rate INTEGER, season_number TEXT, show_name TEXT, source TEXT, year TEXT, replaygain TEXT, file_format TEXT,
        last_played INTEGER, last_skipped INTEGER, play_count INTEGER DEFAULT 0, skip_count INTEGER DEFAULT 0
    )');
    $db->query('CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist)');
    $db->query('CREATE INDEX IF NOT EXISTS idx_songs_album ON songs(album)');
    $db->query('CREATE INDEX IF NOT EXISTS idx_songs_genre ON songs(genre)');
    # Add index for location lookups (used in playlist parsing)
    $db->query('CREATE INDEX IF NOT EXISTS idx_songs_location ON songs(location)');

    $db->query('CREATE TABLE IF NOT EXISTS playlists (name TEXT PRIMARY KEY, type TEXT, mtime INTEGER DEFAULT 0)');
    try { $db->query('ALTER TABLE playlists ADD COLUMN mtime INTEGER DEFAULT 0') } catch {};

    $db->query('CREATE TABLE IF NOT EXISTS playlist_songs (
        playlist_name TEXT, song_id TEXT, position INTEGER,
        PRIMARY KEY (playlist_name, position),
        FOREIGN KEY (playlist_name) REFERENCES playlists(name) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
    )');
    $db->query('CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_id ON playlist_songs(song_id)');

    $db->query('CREATE TABLE IF NOT EXISTS ignored_paths (path TEXT PRIMARY KEY, timestamp INTEGER)');

    $db->query('CREATE TABLE IF NOT EXISTS scan_state (key TEXT PRIMARY KEY, value TEXT, timestamp INTEGER DEFAULT 0)');
    $db->query('CREATE TABLE IF NOT EXISTS configured_directories (path TEXT PRIMARY KEY, status TEXT, last_scanned INTEGER DEFAULT 0)');

    $db->query('INSERT OR IGNORE INTO scan_state (key, value) VALUES (?, ?)', 'scan_status', 'idle');
    $db->query('INSERT OR IGNORE INTO scan_state (key, value) VALUES (?, ?)', 'last_scan_completed_at', '0');
    $db->query('INSERT OR IGNORE INTO scan_state (key, value) VALUES (?, ?)', 'config_hash', '');

    # Ensure columns from later updates exist (for existing databases)
    try { $db->query('ALTER TABLE scan_state ADD COLUMN timestamp INTEGER DEFAULT 0') };
    for my $col (qw(album_artist bpm channels comment composer date_added date_modified description disc_number episode_number keywords sample_rate season_number show_name source year replaygain file_format last_played last_skipped)) {
        try { $db->query("ALTER TABLE songs ADD COLUMN $col TEXT") };
    }
    try { $db->query('ALTER TABLE songs ADD COLUMN play_count INTEGER DEFAULT 0') };
    try { $db->query('ALTER TABLE songs ADD COLUMN skip_count INTEGER DEFAULT 0') };

    $tx->commit;
}
