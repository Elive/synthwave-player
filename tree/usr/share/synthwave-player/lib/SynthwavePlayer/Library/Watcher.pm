package SynthwavePlayer::Library::Watcher;

use strict;
use warnings;
use utf8;
use feature 'state';
use Exporter 'import';
use Mojo::IOLoop;
use Linux::Inotify2 qw(IN_MOVED_TO IN_CLOSE_WRITE IN_CREATE IN_DELETE IN_MOVED_FROM IN_MODIFY IN_ATTRIB);
use File::Basename qw(basename dirname);
use File::Spec;
use Digest::SHA qw(sha1_hex);
use Encode qw(encode);
use Try::Tiny;
use File::Find::Rule;
use SynthwavePlayer::Config qw($USER_CONFIG_FILE $ENABLE_DEBUG_LOGGING $ENABLE_VERBOSE_LOGGING);
use SynthwavePlayer::Utils qw(realpath);
use SynthwavePlayer::Library::Scanner qw(_parse_playlists _process_file_chunk);

our @EXPORT_OK = qw(_setup_library_watcher _setup_config_watcher _setup_database_watcher);

sub _setup_database_watcher {
    my ($app) = @_;
    state $watcher_setup = 0;
    return if $watcher_setup;
    $watcher_setup = 1;

    my $cache_dir = SynthwavePlayer::Utils::_get_cache_dir();
    my $db_filename = 'library.db';
    return unless -d $cache_dir;

    my $inotify = Linux::Inotify2->new or return $app->log->error("Unable to create new inotify object for database: $!");
    $inotify->watch($cache_dir, IN_DELETE, sub {
        my $e = shift;
        return unless $e->name eq $db_filename;
        $app->log->warn("Database file '$db_filename' was deleted externally. Triggering re-initialization.");
        $app->db->{loading_status} = { done => 0, total => 0, processed => 0, message => "Database deleted externally. Re-initializing...", progress => 0 };
        SynthwavePlayer::Library::_broadcast_status_update($app);
        $app->db->{force_db_reconnect} = 1;
        $app->db->{is_loading} = 0;
        Mojo::IOLoop->singleton->next_tick(sub {
            my $music_dirs = \@SynthwavePlayer::Config::MUSIC_DIRECTORIES;
            my $friends_music = \@SynthwavePlayer::Config::FRIENDS_MUSIC;
            $app->sync_library_to_config([], $music_dirs, [], $friends_music);
            my $current_hash = SynthwavePlayer::Library::_get_config_hash($music_dirs, $friends_music);
            try { $app->sql->db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES ('config_hash', ?)", $current_hash) };
        });
    });
    Mojo::IOLoop->singleton->reactor->io($inotify->fh, sub { $inotify->poll });
}

sub _setup_config_watcher {
    my ($app) = @_;
    state $watcher_setup = 0;
    return if $watcher_setup;
    $watcher_setup = 1;

    my $config_dir = dirname($USER_CONFIG_FILE);
    my $config_filename = basename($USER_CONFIG_FILE);
    return unless -d $config_dir;

    my $inotify = Linux::Inotify2->new or return $app->log->error("Unable to create new inotify object: $!");
    state $reload_timer;
    $inotify->watch($config_dir, IN_MOVED_TO | IN_CLOSE_WRITE, sub {
        my $e = shift;
        return unless $e->name eq $config_filename;
        Mojo::IOLoop->singleton->remove($reload_timer) if $reload_timer;
        $reload_timer = Mojo::IOLoop->singleton->timer(2 => sub {
            my @old_dirs = @SynthwavePlayer::Config::MUSIC_DIRECTORIES;
            my @old_friends = @SynthwavePlayer::Config::FRIENDS_MUSIC;
            SynthwavePlayer::Config::_load_configuration($app);
            my $current_hash = SynthwavePlayer::Library::_get_config_hash(\@SynthwavePlayer::Config::MUSIC_DIRECTORIES, \@SynthwavePlayer::Config::FRIENDS_MUSIC);
            if ($app->can('sync_library_to_config')) {
                $app->sync_library_to_config(\@old_dirs, \@SynthwavePlayer::Config::MUSIC_DIRECTORIES, \@old_friends, \@SynthwavePlayer::Config::FRIENDS_MUSIC);
                try { $app->sql->db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES ('config_hash', ?)", $current_hash) };
            }
            unless ($app->db->{suppress_config_broadcast}) { SynthwavePlayer::Library::_broadcast_config_update($app) }
        });
    });
    Mojo::IOLoop->singleton->reactor->io($inotify->fh, sub { $inotify->poll });
}

sub _setup_library_watcher {
    my ($app) = @_;
    state $inotify;
    state %pending_paths;
    state %path_timestamps;  # Track when we first saw each path for stability check
    state $scan_timer;
    state %watched_dirs;
    state %polled_dirs;
    state $watcher_setup = 0;
    state $process_incremental_changes;

    # Extended temp file patterns - covers more editors and tools
    my $temp_file_regex = qr/^(?:
        sed[A-Za-z0-9]{6,}      |  # sed temp files
        \..*\.swp              |  # vim swap files
        \..*\.swo              |  # vim swap files (overflow)
        \.swx                  |  # vim swap files (overflow)
        ~$                     |  # backup files
        \.bak$                 |  # backup files
        \.tmp$                 |  # generic temp files
        \.temp$                |  # generic temp files
        \.part$                |  # partial downloads (browsers, wget, curl)
        \.crdownload$          |  # chrome partial downloads
        \.download$            |  # generic partial downloads
        \.partial$             |  # partial files
        \.filepart$            |  # some tools
        \.#.*                  |  # emacs lock files
        #.*#                   |  # emacs auto-save
        \.DS_Store             |  # macOS metadata
        Thumbs\.db             |  # Windows thumbnails
        desktop\.ini           |  # Windows metadata
        \.nfs.*               |  # NFS temp files
        \.fuse.*              |  # FUSE temp files
    )$/x;

    if (!$watcher_setup) {
        $inotify = Linux::Inotify2->new or return $app->log->error("Unable to create new inotify object for library: $!");
        Mojo::IOLoop->singleton->reactor->io($inotify->fh, sub { $inotify->poll });
        Mojo::IOLoop->singleton->recurring(3600 => sub {
            for my $dir (keys %polled_dirs) {
                my $dir_bytes = utf8::is_utf8($dir) ? encode('UTF-8', $dir) : $dir;
                next unless -d $dir_bytes;
                my $current_mtime = int((stat($dir_bytes))[9] || 0);
                my $stored_mtime_row = $app->sql->db->query("SELECT value FROM scan_state WHERE key = ?", "dir_mtime:" . $dir)->array;
                my $stored_mtime = $stored_mtime_row ? ($stored_mtime_row->[0] // 0) : 0;
                if ($current_mtime != int($stored_mtime)) {
                    $app->sql->db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)", "dir_mtime:" . $dir, $current_mtime);
                    $pending_paths{$dir} = 1;
                    Mojo::IOLoop->singleton->remove($scan_timer) if $scan_timer;
                    $scan_timer = Mojo::IOLoop->singleton->timer(5 => $process_incremental_changes);
                }
            }
        });
        $watcher_setup = 1;
    }

    $process_incremental_changes = sub {
        my @paths = keys %pending_paths;
        %pending_paths = ();
        %path_timestamps = ();  # Clear timestamps after processing
        return unless @paths;
        my (@to_update, @to_delete, @playlists_to_reparse);
        for my $path (@paths) {
            next if basename($path) =~ $temp_file_regex;

            # Skip paths that don't look like valid media files or directories
            my $path_bytes = utf8::is_utf8($path) ? encode('UTF-8', $path) : $path;

            if ($path =~ /\.(pls|m3u8?)$/i) {
                push @playlists_to_reparse, $path;
                next
            }

            if ($path =~ /\.(mp3|m4a|ogg|flac|wav|opus|aiff|aif|aac|wma|mka)$/i) {
                # Check if file exists and is stable (not being written to)
                if (-f $path_bytes) {
                    # Verify file is readable and has content
                    my $size = -s $path_bytes;
                    if ($size && $size > 0) {
                        push @to_update, $path;
                    } else {
                        $app->log->debug("Skipping empty or zero-size file: $path") if $ENABLE_DEBUG_LOGGING;
                    }
                } else {
                    push @to_delete, $path;
                }
            } elsif (-d $path_bytes) {
                # Directory changed - scan it
                push @to_update, File::Find::Rule->file()->name(qr/\.(mp3|m4a|ogg|flac|wav|opus|aiff|aif|aac|wma|mka)$/i)->in($path_bytes);
            } else {
                # Path doesn't exist - check if it was a song or directory
                my $norm_path = realpath($path) // $path;
                $norm_path =~ s{/+$}{};

                # Check if this was a known song
                my $song_row = $app->sql->db->query("SELECT 1 FROM songs WHERE location = ?", $norm_path)->array;
                if ($song_row) {
                    push @to_delete, $path;
                } else {
                    # Check if it was a directory containing songs
                    my $like_pattern = $norm_path . '/%';
                    my $dir_songs = $app->sql->db->query("SELECT COUNT(*) FROM songs WHERE location LIKE ?", $like_pattern)->array->[0] // 0;
                    if ($dir_songs > 0) {
                        $app->log->info("Detected removal of directory with $dir_songs songs: $norm_path");
                        $app->purge_removed_directory($path);
                    }
                }
            }
        }
        if (@to_delete) {
            my $tx;
            try {
                $tx = $app->sql->db->begin;
                for my $path (@to_delete) {
                    # Try realpath first, then fall back to rel2abs
                    my $path_bytes = utf8::is_utf8($path) ? encode('UTF-8', $path) : $path;
                    my $resolved_path = realpath($path_bytes) // realpath($path) // File::Spec->rel2abs($path);
                    $resolved_path =~ s{/+$}{};
                    my $id = substr(sha1_hex(encode('UTF-8', $resolved_path)), 0, 16);

                    # Check if song exists before deleting
                    if ($app->sql->db->query('SELECT 1 FROM songs WHERE id = ?', $id)->array) {
                        $app->sql->db->query('DELETE FROM playlist_songs WHERE song_id = ?', $id);
                        $app->sql->db->query('DELETE FROM songs WHERE id = ?', $id);
                        $app->log->debug("Deleted song: $resolved_path (ID: $id)") if $ENABLE_DEBUG_LOGGING;
                    }
                }
                $tx->commit;
            } catch {
                $app->log->error("Failed to delete songs: $_");
                $tx->rollback if $tx;
            };
        }
        if (@to_update) {
            $app->sql->db->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());
            $app->db->{is_loading} = 1;
            _process_file_chunk($app, \@to_update, 0, { is_incremental => 1, playlists_changed => 0 }, sub {
                if (@playlists_to_reparse) {
                    my $id_map = SynthwavePlayer::Library::_get_location_id_map($app);
                    SynthwavePlayer::Library::Scanner::_process_playlist_chunk($app, \@playlists_to_reparse, 0, { is_reload => 1, id_map => $id_map }, sub { SynthwavePlayer::Library::_check_and_set_idle_state($app) });
                } else { SynthwavePlayer::Library::_check_and_set_idle_state($app) }
            });
        } elsif (@playlists_to_reparse) {
            $app->sql->db->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());
            my $id_map = SynthwavePlayer::Library::_get_location_id_map($app);
            SynthwavePlayer::Library::Scanner::_process_playlist_chunk($app, \@playlists_to_reparse, 0, { is_reload => 1, id_map => $id_map }, sub { SynthwavePlayer::Library::_check_and_set_idle_state($app) });
        } elsif (@to_delete) {
            $app->sql->db->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());
            _parse_playlists($app, { is_reload => 1 });
        } else {
            SynthwavePlayer::Library::_check_and_set_idle_state($app);
            SynthwavePlayer::Library::_broadcast_library_update($app);
        }
    };

    my $schedule_path;
    $schedule_path = sub {
        my ($path) = @_;
        my $real_path = realpath($path) || $path;

        # Check if path is in ignored_paths (recently modified by tag editor)
        my $ignored = $app->sql->db->query('SELECT timestamp FROM ignored_paths WHERE path = ?', $real_path)->hash;
        if ($ignored) {
            # Increased timeout from 20 to 60 seconds for large file operations
            if (time() - $ignored->{timestamp} > 60) {
                $app->sql->db->query('DELETE FROM ignored_paths WHERE path = ?', $real_path)
            } else {
                $app->log->debug("Ignoring change to recently modified path: $real_path") if $ENABLE_DEBUG_LOGGING;
                return
            }
        }

        my $path_bytes = utf8::is_utf8($path) ? encode('UTF-8', $path) : $path;
        if (-d $path_bytes) {
            my $resolved = realpath($path) // $path;
            my $current_mtime = int((stat($path_bytes))[9] || 0);
            $app->sql->db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)", "dir_mtime:" . $resolved, $current_mtime);
            try {
                my @dirs = File::Find::Rule->directory->in($path_bytes);
                for my $d (@dirs) {
                    my $dir_to_watch = realpath($d) || $d;
                    next if $dir_to_watch =~ m{/\.} || $dir_to_watch =~ m{/(?:Cache|Album\sArtwork|Artwork|Covers|Playlists|Thumbnails|\.thumbnails|__pycache__|\.git)/}i;
                    if (!$watched_dirs{$dir_to_watch}) {
                        try {
                            my $dir_to_watch_bytes = utf8::is_utf8($dir_to_watch) ? encode('UTF-8', $dir_to_watch) : $dir_to_watch;
                            # Added IN_MODIFY and IN_ATTRIB for better coverage
                            my $w = $inotify->watch($dir_to_watch_bytes, IN_MOVED_TO | IN_CLOSE_WRITE | IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MODIFY | IN_ATTRIB, sub {
                                my $e = shift;

                                # Skip temp files
                                return if $e->name =~ $temp_file_regex;

                                my $parent = dirname($e->fullname);
                                my $resolved_parent = realpath($parent) // $parent;
                                my $parent_bytes = utf8::is_utf8($parent) ? encode('UTF-8', $parent) : $parent;
                                my $new_mtime = int((stat($parent_bytes))[9] || 0);
                                $app->sql->db->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)", "dir_mtime:" . $resolved_parent, $new_mtime);

                                if ($e->IN_ISDIR && ($e->IN_CREATE || $e->IN_MOVED_TO)) {
                                    $schedule_path->($e->fullname);
                                } else {
                                    # Track when we first saw this path for stability check
                                    $path_timestamps{$e->fullname} //= time();

                                    # For IN_MODIFY events, require file to be stable
                                    if ($e->IN_MODIFY) {
                                        # Don't process immediately on MODIFY, wait for stability
                                        $pending_paths{$e->fullname} = 1;
                                        Mojo::IOLoop->singleton->remove($scan_timer) if $scan_timer;
                                        # Longer debounce for MODIFY events (5 seconds)
                                        $scan_timer = Mojo::IOLoop->singleton->timer(5 => $process_incremental_changes);
                                    } else {
                                        $pending_paths{$e->fullname} = 1;
                                        Mojo::IOLoop->singleton->remove($scan_timer) if $scan_timer;
                                        # Standard debounce for other events (3 seconds)
                                        $scan_timer = Mojo::IOLoop->singleton->timer(3 => $process_incremental_changes);
                                    }
                                }
                            });
                            $watched_dirs{$dir_to_watch} = $w;
                            delete $polled_dirs{$dir_to_watch};
                        } catch {
                            $polled_dirs{$dir_to_watch} = 1;
                            $app->log->debug("Failed to watch directory $dir_to_watch, using polling: $_") if $ENABLE_DEBUG_LOGGING;
                        };
                    }
                }
            } catch {
                $app->log->debug("Error scanning directory $path_bytes: $_") if $ENABLE_DEBUG_LOGGING;
            };
        }
        $pending_paths{$path} = 1;
        Mojo::IOLoop->singleton->remove($scan_timer) if $scan_timer;
        # Increased debounce from 2 to 3 seconds for better stability
        $scan_timer = Mojo::IOLoop->singleton->timer(3 => $process_incremental_changes);
    };

    my %current_config_dirs = map { $_ => 1 } grep { defined } map { my $p = realpath($_) // $_; $p =~ s{/+$}{} if defined $p; $p } grep { defined } (@SynthwavePlayer::Config::MUSIC_DIRECTORIES, @SynthwavePlayer::Config::PLAYLISTS_DIRECTORIES);
    for my $watched (keys %watched_dirs) {
        my $still_valid = 0;
        my $watched_bytes = utf8::is_utf8($watched) ? encode('UTF-8', $watched) : $watched;
        if (-d $watched_bytes) {
            for my $cfg_dir (keys %current_config_dirs) {
                if ($watched eq $cfg_dir || $watched =~ /^\Q$cfg_dir\E\//) { $still_valid = 1; last }
            }
        }
        unless ($still_valid) {
            my $w = delete $watched_dirs{$watched};
            try { $w->cancel if ref $w && $w->can('cancel') };
            for my $pending (keys %pending_paths) { delete $pending_paths{$pending} if $pending =~ /^\Q$watched\E/ }
        }
    }
    for my $polled (keys %polled_dirs) {
        my $still_valid = 0;
        for my $cfg_dir (keys %current_config_dirs) {
            if ($polled eq $cfg_dir || $polled =~ /^\Q$cfg_dir\E\//) { $still_valid = 1; last }
        }
        delete $polled_dirs{$polled} unless $still_valid;
    }

    for my $dir (@SynthwavePlayer::Config::MUSIC_DIRECTORIES, @SynthwavePlayer::Config::PLAYLISTS_DIRECTORIES) {
        next unless defined $dir;
        my $norm_dir = realpath($dir) // $dir; $norm_dir =~ s{/+$}{};
        my $dir_bytes = utf8::is_utf8($norm_dir) ? encode('UTF-8', $norm_dir) : $norm_dir;
        next unless -d $dir_bytes;
        try {
            my @dirs = File::Find::Rule->directory->in($dir_bytes);
            for my $d (@dirs) {
                my $dir_to_watch = realpath($d) || $d;
                next if $watched_dirs{$dir_to_watch} || $dir_to_watch =~ m{/\.} || $dir_to_watch =~ m{/(?:Cache|Album\sArtwork|Artwork|Covers|Playlists|Thumbnails|\.thumbnails|__pycache__|\.git)/}i;
                my $dir_to_watch_bytes = utf8::is_utf8($dir_to_watch) ? encode('UTF-8', $dir_to_watch) : $dir_to_watch;
                try {
                    my $w = $inotify->watch($dir_to_watch_bytes, IN_MOVED_TO | IN_CLOSE_WRITE | IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MODIFY | IN_ATTRIB, sub {
                        my $e = shift;
                        return if $e->name =~ $temp_file_regex;
                        $schedule_path->($e->fullname);
                    });
                    $watched_dirs{$dir_to_watch} = $w;
                    delete $polled_dirs{$dir_to_watch};
                } catch {
                    $polled_dirs{$dir_to_watch} = 1;
                    $app->log->debug("Failed to watch $dir_to_watch, using polling: $_") if $ENABLE_DEBUG_LOGGING;
                };
            }
        } catch { };
    }
}

1;
