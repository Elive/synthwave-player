package SynthwavePlayer::Library::Scanner;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use File::Find::Rule;
use MP3::Tag;
use Mojo::IOLoop;
use Mojo::JSON;
use File::Spec;
use File::Basename qw(fileparse);
use Encode qw(encode decode);
use Try::Tiny;
use Digest::SHA qw(sha1_hex);
use SynthwavePlayer::Config qw(@IGNORE_PLAYLISTS_MATCHING @BLACKLIST_PLAYLISTS_MATCHING);
use SynthwavePlayer::Utils qw(:DEFAULT _is_matched _natural_compare realpath _extract_metadata);

our @EXPORT_OK = qw(
    _start_library_parsing _process_file_chunk _scan_music_directories
    _parse_playlists _process_playlist_chunk _finish_library_loading
    _process_playlist_entry
);

sub _start_library_parsing {
    my ($app, $options, $callback) = @_;
    my $is_reload = $options->{is_reload} || 0;
    my $db = $app->db;

    # Skip if target_path is a URL (not a local directory)
    if ($options->{target_path} && $options->{target_path} =~ m{^https?://}i) {
        $app->log->warn("Skipping scan of URL (not a local directory): $options->{target_path}");
        # Clean up the task if it exists
        if (my $tk = $options->{task_key}) {
            try {
                $app->sql->db->query('DELETE FROM scan_state WHERE key = ?', $tk);
            } catch {};
        }
        $callback->($app, $options) if $callback;
        return 0;
    }

    my $cleanup_on_error = sub {
        $db->{is_loading} = 0;
        SynthwavePlayer::Library::_check_and_set_idle_state($app);
    };

    my $sql_db;
    try {
        $sql_db = $app->sql->db;
        my $tx = $sql_db->begin('immediate');

        if (my $tk = $options->{task_key}) {
            $sql_db->query(
                "UPDATE scan_state SET value = 'processing', timestamp = ? WHERE key = ?",
                time(), $tk
            );
            my $path = $tk; $path =~ s/^task://;
            $sql_db->query("UPDATE configured_directories SET status = 'scanning' WHERE path = ?", $path);
        }

        $sql_db->query("UPDATE scan_state SET value = 'scanning', timestamp = ? WHERE key = 'scan_status'", time());
        $tx->commit;
    } catch {
        $app->log->error("Failed to set scanning state: $_");
        $cleanup_on_error->();
        $callback->($app, $options) if $callback;
        return;
    };

    $db->{is_loading} = 1;
    $db->{loading_status} = { done => \0, total => 0, processed => 0, message => 'Initializing...', progress => 0 };
    $db->{playlists_out_of_date} = {};
    SynthwavePlayer::Library::_broadcast_status_update($app);

    my $dir_prefix = "";
    if ($options->{current_dir_no} && $options->{total_dirs}) {
        $dir_prefix = sprintf("[%d/%d] ", $options->{current_dir_no}, $options->{total_dirs});
    }

    my $song_count_row = $app->sql->db->query('SELECT COUNT(*) FROM songs')->array;
    my $is_first_scan = ($song_count_row && $song_count_row->[0] == 0) ? 1 : 0;
    my $action_verb = $is_first_scan ? "Scanning" : "Synchronizing";

    if (!$options->{task_key} && (!$db->{loading_status}{total} || $db->{loading_status}{total} == 0)) {
        $db->{loading_status}{total} = 0;
        $db->{loading_status}{processed} = 0;
        $db->{loading_status}{done} = \0;
    }

    $app->log->info("$action_verb music library... $dir_prefix");
    print "$action_verb music library... $dir_prefix\n";
    $db->{loading_status}{message} = "$action_verb music library... $dir_prefix";
    SynthwavePlayer::Library::_broadcast_status_update($app);

    my @music_files;
    if ($options->{pre_scanned_files}) {
        @music_files = @{$options->{pre_scanned_files}};
    } elsif ($options->{target_path}) {
        @music_files = _scan_music_directories($app, $options);
    } else {
        my $dirs = $app->sql->db->query("SELECT path FROM configured_directories")->arrays->map(sub { $_->[0] })->to_array;
        for my $dir (@$dirs) {
            push @music_files, _scan_music_directories($app, { target_path => $dir });
        }
    }

    # Reset counters for the specific task to prevent percentage overflow
    $db->{loading_status}{total} = scalar @music_files;
    $db->{loading_status}{processed} = 0;
    $db->{loading_status}{progress} = 0;

    if (scalar @music_files == 0) {
        $app->log->info("No music files found in " . ($options->{target_path} // 'configured directories'));
        # Even if no files found, we must finalize the task to avoid 'processing' loops
        if ($options->{task_key}) {
            _process_file_chunk($app, [], 0, { is_reload => $is_reload, %$options }, $callback);
        } else {
            $callback->($app, $options) if $callback;
        }
        return;
    }

    $app->log->info(sprintf("Processing %d music files in %s", scalar @music_files, $options->{target_path} // 'configured directories'));
    _process_file_chunk($app, \@music_files, 0, { is_reload => $is_reload, %$options }, $callback);
    return 1;
}

sub _scan_music_directories {
    my ($app, $options) = @_;
    my @allowed_extensions = (
        '.mp3', '.m4a', '.ogg', '.flac', '.wav', '.opus',
        '.aiff', '.aif', '.aac', '.wma', '.mka'
    );

    my $target = $options->{target_path};
    return () unless $target;
    my $target_bytes = utf8::is_utf8($target) ? encode('UTF-8', $target) : $target;
    return () unless -d $target_bytes;

    my @music_files = File::Find::Rule->file()
                                     ->name(map { '*' . $_ } @allowed_extensions)
                                     ->in($target_bytes);

    return @music_files;
}

sub _process_file_chunk {
    my ($app, $music_files_ref, $index, $options, $callback) = @_;
    unless ($music_files_ref && ref $music_files_ref eq 'ARRAY' && @$music_files_ref) {
        _parse_playlists($app, $options, $callback);
        return;
    }
    my $is_reload = $options->{is_reload} || 0;
    my $db = $app->db;
    my $chunk_size = 100;
    my $limit = $index + $chunk_size;
    $limit = @$music_files_ref if $limit > @$music_files_ref;

    for my $i ($index .. $limit - 1) {
        my $file_path_bytes = $music_files_ref->[$i];
        my $file_path = decode('UTF-8', $file_path_bytes);

        if ($i > $index && $i % 10 == 0) {
            $db->{loading_status}{processed} = $i;
            if ($db->{loading_status}{total} > 0) {
                my $prog = int(($db->{loading_status}{processed} / $db->{loading_status}{total}) * 100);
                $db->{loading_status}{progress} = $prog > 100 ? 100 : $prog;
            }
            SynthwavePlayer::Library::_broadcast_status_update($app);

            try {
                my $db_h = $app->sql->db;
                $db_h->query('UPDATE scan_state SET timestamp = ? WHERE key = ?', time(), 'scan_status');
                if (my $tk = $options->{task_key}) {
                    $db_h->query('UPDATE scan_state SET timestamp = ? WHERE key = ?', time(), $tk);
                    my $path = $tk; $path =~ s/^task://;
                    $db_h->query("UPDATE configured_directories SET status = 'scanning' WHERE path = ?", $path);
                }
            } catch {};
        }
        my $resolved_path = realpath($file_path) // decode('UTF-8', File::Spec->rel2abs($file_path_bytes));
        $resolved_path =~ s{/+$}{};
        my $id = substr(sha1_hex(encode('UTF-8', $resolved_path)), 0, 16);

        my $disk_mtime = (stat($file_path_bytes))[9] || 0;

        # Optimization: Check if file mtime matches DB before extracting metadata
        my $db_row = $app->sql->db->query('SELECT date_modified FROM songs WHERE id = ?', $id)->array;
        my $db_mtime = $db_row ? ($db_row->[0] || 0) : 0;

        if (!$options->{force_deep_scan} && $db_mtime > 0 && $disk_mtime == $db_mtime) {
            $app->log->debug("Skipping unchanged file: $file_path") if $SynthwavePlayer::Config::ENABLE_DEBUG_LOGGING;
            next;
        }

        my $meta = _extract_metadata($file_path_bytes, $app->log);

        try {
            my $db_handle = $app->sql->db;
            my $tx = $db_handle->begin;
            $db_handle->query(
                'INSERT INTO songs (id, title, artist, album, genre, duration, rating, location, track_number, bitrate, album_artist, bpm, channels, comment, composer, date_added, date_modified, description, disc_number, episode_number, keywords, sample_rate, season_number, show_name, source, year, replaygain, file_format) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET title=excluded.title, artist=excluded.artist, album=excluded.album, genre=excluded.genre, duration=excluded.duration, rating=excluded.rating, location=excluded.location, track_number=excluded.track_number, bitrate=excluded.bitrate, album_artist=excluded.album_artist, bpm=excluded.bpm, channels=excluded.channels, comment=excluded.comment, composer=excluded.composer, date_added=excluded.date_added, date_modified=excluded.date_modified, description=excluded.description, disc_number=excluded.disc_number, episode_number=excluded.episode_number, keywords=excluded.keywords, sample_rate=excluded.sample_rate, season_number=excluded.season_number, show_name=excluded.show_name, source=excluded.source, year=excluded.year, replaygain=excluded.replaygain, file_format=excluded.file_format',
                $id, $meta->{title}, $meta->{artist}, $meta->{album}, $meta->{genre}, $meta->{duration}, $meta->{rating}, $resolved_path, $meta->{track_number}, $meta->{bitrate}, $meta->{album_artist}, $meta->{bpm}, $meta->{channels}, $meta->{comment_text}, $meta->{composer}, $meta->{date_added}, $meta->{date_modified}, $meta->{description}, $meta->{disc_number}, $meta->{episode_number}, $meta->{keywords}, $meta->{sample_rate}, $meta->{season_number}, $meta->{show_name}, $meta->{source}, $meta->{year_text}, $meta->{replaygain}, $meta->{file_format}
            );
            $tx->commit;
        } catch {
            $app->log->error("Failed to update DB for $file_path: $_");
        };
    }

    unless ($options->{is_incremental}) {
        $db->{loading_status}{processed} = $limit;
        if ($db->{loading_status}{total} > 0) {
            my $prog = int(($db->{loading_status}{processed} / $db->{loading_status}{total}) * 100);
            $db->{loading_status}{progress} = $prog > 100 ? 100 : $prog;
        }
        my $dir_prefix = "";
        if ($options->{current_dir_no} && $options->{total_dirs}) {
            $dir_prefix = sprintf("[%d/%d]", $options->{current_dir_no}, $options->{total_dirs});
        }
        my $action_verb = ($db->{loading_status}{total} > 0 && $db->{loading_status}{processed} == 0) ? "Scanning" : "Processing";
        my $target_name = $options->{target_path} // '';
        $db->{loading_status}{message} = sprintf("%s music %s... (%d/%d)\n%s", $action_verb, $dir_prefix, $db->{loading_status}{processed}, $db->{loading_status}{total}, $target_name);
        printf("\r%s music %s... (%d/%d) %d%%   ", $action_verb, $dir_prefix, $db->{loading_status}{processed}, $db->{loading_status}{total}, $db->{loading_status}{progress});
        local $| = 1;
        SynthwavePlayer::Library::_broadcast_status_update($app);
    }

    if ($limit < @$music_files_ref) {
        Mojo::IOLoop->singleton->timer(0 => sub {
            _process_file_chunk($app, $music_files_ref, $limit, $options, $callback);
        });
    } else {
        my $found_count = scalar @$music_files_ref;
        @$music_files_ref = ();
        if (!$options->{task_key}) {
            $app->sql->db->query("UPDATE configured_directories SET status = 'scanned', last_scanned = ?", time());
        }

        if ($options->{is_incremental}) {
            $app->log->info("Incremental library update complete.");
            if (my $tk = $options->{task_key}) {
                my $path = $tk; $path =~ s/^task://;
                my $db = $app->sql->db;
                my $tx = $db->begin;
                $db->query('DELETE FROM scan_state WHERE key = ?', $tk);
                $db->query("UPDATE configured_directories SET status = 'scanned', last_scanned = ? WHERE path = ?", time(), $path);
                $tx->commit;
            }
            SynthwavePlayer::Library::_check_and_set_idle_state($app);
            if ($options->{playlists_changed}) {
                _parse_playlists($app, { is_reload => 1 }, sub {
                    SynthwavePlayer::Library::_broadcast_library_update($app);
                    $callback->($app, $options) if $callback;
                });
            } else {
                SynthwavePlayer::Library::_broadcast_library_update($app);
                $callback->($app, $options) if $callback;
            }
            return;
        }

        if ($is_reload) {
            my $db_handle = $app->sql->db;
            my $should_abort = 0;

            if (!$options->{target_path}) {
                # Full library scan - be more conservative
                my $db_count = $db_handle->query("SELECT COUNT(*) FROM songs WHERE location NOT LIKE 'http%'")->array->[0] // 0;
                if ($db_count > 100 && $found_count < ($db_count * 0.05)) {
                    $should_abort = 1;
                    $app->log->error("CRITICAL: Full scan found only $found_count files but DB has $db_count entries. Aborting cleanup to prevent data loss.");
                } elsif ($found_count == 0 && $db_count > 0) {
                    $should_abort = 1;
                    $app->log->error("CRITICAL: Full scan found 0 files but DB has $db_count entries. Aborting cleanup to prevent data loss.");
                }
            } else {
                # Targeted scan - only abort if directory doesn't exist
                my $tp = $options->{target_path};
                my $target_bytes = utf8::is_utf8($tp) ? encode('UTF-8', $tp) : $tp;
                if (!-d $target_bytes) {
                    $should_abort = 1;
                    $app->log->error("CRITICAL: Target directory does not exist: $tp. Aborting cleanup.");
                } else {
                    # Check how many songs we currently have in DB for THIS specific path
                    my $norm_tp = realpath($tp) // $tp;
                    $norm_tp =~ s{/+$}{};
                    my $escaped_tp = $norm_tp;
                    $escaped_tp =~ s/([%_\\])/\\$1/g;

                    my $local_db_count = $db_handle->query(
                        "SELECT COUNT(*) FROM songs WHERE (location LIKE ? ESCAPE '\\' OR location = ? OR location = ?)",
                        $escaped_tp . '/%', $norm_tp, $norm_tp . '/'
                    )->array->[0] // 0;

                    # Log if we found significantly fewer files than expected for this directory
                    if ($local_db_count > 50 && $found_count < ($local_db_count * 0.1)) {
                        $app->log->warn("Warning: Targeted scan found $found_count files in $tp, but DB previously had $local_db_count for this path. Proceeding with targeted cleanup.");
                    }
                }
            }

            if ($should_abort) {
                # Don't proceed with cleanup, but still finish the scan
                $app->log->error("Skipping orphan cleanup due to abort condition.");
            } else {
                try {
                    # Ensure we are not already in a transaction before starting cleanup
                    # Use a temporary table to track what we found in THIS scan
                    $db_handle->query('CREATE TEMPORARY TABLE IF NOT EXISTS current_scan_ids (id TEXT PRIMARY KEY)');
                    $db_handle->query('DELETE FROM current_scan_ids');

                    # Use already scanned files if available, otherwise rescan
                    my @all_files;
                    if ($options->{target_path} && $music_files_ref && @$music_files_ref) {
                        # For targeted scans, use the files we already found
                        @all_files = @$music_files_ref;
                    } else {
                        @all_files = _scan_music_directories($app, $options);
                    }

                    try {
                        my $tx_inner = $db_handle->begin;
                        for my $file_path_bytes (@all_files) {
                            my $file_path = decode('UTF-8', $file_path_bytes);
                            my $resolved_path = realpath($file_path) // decode('UTF-8', File::Spec->rel2abs($file_path_bytes));
                            $resolved_path =~ s{/+$}{};
                            my $id = substr(sha1_hex(encode('UTF-8', $resolved_path)), 0, 16);
                            $db_handle->query('INSERT OR IGNORE INTO current_scan_ids (id) VALUES (?)', $id);
                        }
                        $tx_inner->commit;
                    } catch {
                        $app->log->error("Failed to populate current_scan_ids: $_");
                    };

                    my $delete_where = 'id NOT IN (SELECT id FROM current_scan_ids) AND location NOT LIKE \'http%\'';
                    my @bind;
                    if (my $tp = $options->{target_path}) {
                        my $norm_tp = realpath($tp) // $tp;
                        $norm_tp =~ s{/+$}{};
                        my $escaped_tp = $norm_tp;
                        $escaped_tp =~ s/([%_\\])/\\$1/g;
                        $delete_where .= ' AND (location LIKE ? ESCAPE \'\\\' OR location = ? OR location = ?)';
                        push @bind, $escaped_tp . '/%', $norm_tp, $norm_tp . '/';
                    }

                    # Delete in chunks to avoid long locks
                    my $deleted_songs = 0;
                    my $deleted_playlist_entries = 0;
                    while (1) {
                        my $chunk_tx = $db_handle->begin;
                        my $rows = $db_handle->query("DELETE FROM playlist_songs WHERE song_id IN (SELECT id FROM songs WHERE $delete_where LIMIT 500)", @bind)->rows;
                        $deleted_playlist_entries += $rows;
                        $rows = $db_handle->query("DELETE FROM songs WHERE $delete_where LIMIT 500", @bind)->rows;
                        $deleted_songs += $rows;
                        $chunk_tx->commit;
                        last if $rows < 500;
                    }

                    $db_handle->query('DROP TABLE current_scan_ids');

                    if ($deleted_songs > 0 || $deleted_playlist_entries > 0) {
                        $app->log->info("Cleanup complete: removed $deleted_songs orphaned songs and $deleted_playlist_entries playlist entries.");
                    }
                } catch {
                    $app->log->error("Failed to cleanup orphaned songs: $_");
                };
            }
        }
        $callback->($app, $options) if $callback;
    }
}

sub _parse_playlists {
    my ($app, $options, $callback) = @_;
    my $db = $app->db;
    $options //= {};
    $db->{playlist_info} = {};

    try {
        $app->sql->db->query("DELETE FROM scan_state WHERE key = 'playlists_out_of_date'");
    } catch {};
    $db->{playlists_out_of_date} = {};

    my @playlist_files;
    my @p_dirs = @SynthwavePlayer::Config::PLAYLISTS_DIRECTORIES;
    if (@p_dirs) {
        for my $playlist_dir (@p_dirs) {
            next unless defined $playlist_dir;
            my $norm_p_dir = realpath($playlist_dir) // $playlist_dir;
            $norm_p_dir =~ s{/+$}{};
            my $playlist_dir_bytes = utf8::is_utf8($norm_p_dir) ? encode('UTF-8', $norm_p_dir) : $norm_p_dir;
            if (-d $playlist_dir_bytes) {
                push @playlist_files, glob "$playlist_dir_bytes/*.{pls,m3u,m3u8}";
            }
        }
    }

    my @playlists_to_process;
    my $db_handle = $app->sql->db;
    my $db_playlists = $db_handle->query('SELECT name, type, mtime FROM playlists')->hashes->to_array;
    my %db_playlist_map = map { $_->{name} => $_ } @$db_playlists;

    {
        my %disk_playlists = map { my ($name) = fileparse(decode('UTF-8', $_), qr/\.[^.]*$/); $name =~ s/_/ /g; $name => 1 } @playlist_files;
        try {
            my $tx = $db_handle->begin;
            for my $p (@$db_playlists) {
                next if $p->{type} eq 'radio';
                unless ($disk_playlists{$p->{name}}) {
                    $db_handle->query('DELETE FROM playlist_songs WHERE playlist_name = ?', $p->{name});
                    $db_handle->query('DELETE FROM playlists WHERE name = ?', $p->{name});
                }
            }
            $tx->commit;
        } catch { $app->log->error("Failed to cleanup deleted playlists: $_") };

        my $force = $options->{force} || 0;
        for my $file (@playlist_files) {
            my ($name) = fileparse(decode('UTF-8', $file), qr/\.[^.]*$/);
            $name =~ s/_/ /g;
            my $disk_mtime = int((stat($file))[9] || 0);
            my $db_entry = $db_playlist_map{$name};
            if (!$force && $db_entry && int($db_entry->{mtime} // 0) == $disk_mtime) { next }
            push @playlists_to_process, $file;
        }
    }

    my $total_p = scalar @playlists_to_process;
    $db->{loading_status}{total} = $total_p;

    if ($total_p == 0) {
        _finish_library_loading($app, $options, $callback);
        return;
    }

    $db->{loading_status}{message} = 'Initializing playlist parsing...';
    $db->{loading_status}{processed} = 0;
    $db->{loading_status}{progress} = 0;
    print "Parsing playlists...\n";
    SynthwavePlayer::Library::_broadcast_status_update($app);

    my $id_map = SynthwavePlayer::Library::_get_location_id_map($app);
    _process_playlist_chunk($app, \@playlists_to_process, 0, { %$options, id_map => $id_map }, sub {
        undef $id_map;
        $callback->(@_) if $callback;
    });
}

sub _process_playlist_chunk {
    my ($app, $playlist_files_ref, $index, $options, $callback) = @_;
    unless ($playlist_files_ref && ref $playlist_files_ref eq 'ARRAY' && @$playlist_files_ref) {
        _finish_library_loading($app, $options, $callback);
        return;
    }
    my $db = $app->db;
    my $chunk_size = 1;
    my $limit = $index + $chunk_size;
    $limit = @$playlist_files_ref if $limit > @$playlist_files_ref;

    for my $i ($index .. $limit - 1) {
        my $playlist_file = $playlist_files_ref->[$i];
        if ($i >= $index) {
            $db->{loading_status}{processed} = $i;
            my $total_p = $db->{loading_status}{total} || scalar @$playlist_files_ref;
            if ($total_p > 0) {
                $db->{loading_status}{progress} = int(($db->{loading_status}{processed} / $total_p) * 100);
            }
            SynthwavePlayer::Library::_broadcast_status_update($app);
        }
        my $playlist_file_bytes = utf8::is_utf8($playlist_file) ? encode('UTF-8', $playlist_file) : $playlist_file;
        my ($playlist_name, $dirs, $suffix) = fileparse($playlist_file, qr/\.[^.]*$/);
        $playlist_name =~ s/_/ /g;
        my $current_mtime = int((stat($playlist_file_bytes))[9] || 0);

        if (_is_matched($app, $playlist_name, \@IGNORE_PLAYLISTS_MATCHING, 'IGNORE_PLAYLISTS_MATCHING')) { next }
        if (_is_matched($app, $playlist_name, \@BLACKLIST_PLAYLISTS_MATCHING, 'BLACKLIST_PLAYLISTS_MATCHING')) { next }

        my $shell_safe_playlist_file = $playlist_file;
        $shell_safe_playlist_file =~ s/'/'\\''/g;

        my $encoding = '';
        try {
            open(my $fh, "-|", "file", "-bi", $playlist_file_bytes) or die $!;
            $encoding = <$fh>;
            close($fh);
            chomp $encoding if $encoding;
            $encoding =~ s/.*charset=// if $encoding;
        } catch {};
        $encoding ||= 'utf-8';

        my $content;
        if ($encoding eq 'utf-8' || $encoding eq 'us-ascii') {
            if (open my $fh, '<:encoding(UTF-8)', $playlist_file_bytes) {
                local $/; $content = <$fh>; close $fh;
            } else { next }
        } else {
            my $detected_encoding = $encoding eq 'binary' || $encoding eq '' ? 'ISO-8859-1' : $encoding;
            my @encodings_to_try = ($detected_encoding, 'ISO-8859-15', 'ISO-8859-1', 'Windows-1252', 'UTF-8');
            for my $enc (@encodings_to_try) {
                my $iconv_output = `cat '$shell_safe_playlist_file' | iconv -f "$enc" -t utf8 2>/dev/null`;
                if ($? == 0 && defined $iconv_output && length $iconv_output) {
                    $content = decode('UTF-8', $iconv_output); last;
                }
            }
            unless (defined $content) { next }
        }

        $content =~ s/\r\n?/\n/g;
        my @lines = split /\n/, $content;
        my @song_ids;
        my ($http_count, $file_count) = (0, 0);

        if (lc($suffix) eq '.pls') {
            my %playlist_entries;
            for my $line (@lines) {
                if ($line =~ /^File(\d+)=(.*)$/) { $playlist_entries{$1}{path} = $2 }
                elsif ($line =~ /^Title(\d+)=(.*)$/) { $playlist_entries{$1}{title} = $2 }
            }
            for my $num (sort { $a <=> $b } keys %playlist_entries) {
                next unless $playlist_entries{$num}{path};
                my $entry_info = _process_playlist_entry($app, $playlist_entries{$num}{path}, $playlist_entries{$num}{title}, $playlist_name, $options->{id_map});
                if ($entry_info) {
                    push @song_ids, $entry_info->{id};
                    $entry_info->{type} eq 'radio' ? $http_count++ : $file_count++;
                }
            }
        } elsif (lc($suffix) eq '.m3u' || lc($suffix) eq '.m3u8') {
            my $current_title;
            for my $line (@lines) {
                next if $line =~ /^\s*$/;
                if ($line =~ /^#EXTINF:(-?\d+),(.*)$/) { $current_title = $2; next }
                next if $line =~ /^\s*#/;
                my $entry_info = _process_playlist_entry($app, $line, $current_title, $playlist_name, $options->{id_map});
                if ($entry_info) {
                    push @song_ids, $entry_info->{id};
                    $entry_info->{type} eq 'radio' ? $http_count++ : $file_count++;
                }
                $current_title = undef;
            }
        }

        if (@song_ids) {
            my $db_handle = $app->sql->db;
            try {
                my $tx = $db_handle->begin;
                $db_handle->query('DELETE FROM playlist_songs WHERE playlist_name = ?', $playlist_name);
                $db_handle->query('DELETE FROM playlists WHERE name = ?', $playlist_name);
                my $type = ($http_count > 0 && $http_count > $file_count) ? 'radio' : 'file';
                $db_handle->query('INSERT INTO playlists (name, type, mtime) VALUES (?, ?, ?)', $playlist_name, $type, $current_mtime);
                my $pos = 0;
                for my $sid (@song_ids) { $db_handle->query('INSERT INTO playlist_songs (playlist_name, song_id, position) VALUES (?, ?, ?)', $playlist_name, $sid, $pos++) }
                $tx->commit;
            } catch { $app->log->error("Failed to update playlist $playlist_name: $_") };
        }

        $db->{loading_status}{processed} = $i + 1;
        my $total_p = $db->{loading_status}{total} || scalar @$playlist_files_ref;
        $db->{loading_status}{message} = sprintf('Parsing playlist: %s (%d/%d)', $playlist_name, $db->{loading_status}{processed}, $total_p);
        printf("\rParsing playlists: %d%% (%d/%d)   ", int(($db->{loading_status}{processed}/$total_p)*100), $db->{loading_status}{processed}, $total_p);
        local $| = 1;
        SynthwavePlayer::Library::_broadcast_status_update($app);
    }

    if ($limit < @$playlist_files_ref) {
        Mojo::IOLoop->singleton->timer(0 => sub { _process_playlist_chunk($app, $playlist_files_ref, $limit, $options, $callback) });
    } else {
        print "\n";
        _finish_library_loading($app, $options, $callback);
    }
}

sub _process_playlist_entry {
    my ($app, $path, $title, $playlist_name, $id_map) = @_;
    my $trimmed_path = $path; $trimmed_path =~ s/^\s+|\s+$//g;
    if ($trimmed_path =~ /^(https?):\/\/(.*)$/i) {
        my $scheme = lc($1); my $rest = $2; $rest =~ s/\s//g;
        my $clean_url = "$scheme://$rest";
        my $id = substr(sha1_hex($clean_url), 0, 16);
        try {
            my $db_h = $app->sql->db;
            unless ($db_h->query('SELECT id FROM songs WHERE id = ?', $id)->hash) {
                $db_h->query('INSERT OR IGNORE INTO songs (id, title, artist, album, genre, duration, rating, location, track_number, bitrate, date_added, date_modified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', $id, $title || '', $playlist_name, 'Radio', 'Radio', 999999999, 0, $clean_url, 0, 0, time(), time());
            }
            return { id => $id, type => 'radio' };
        } catch { return undef };
    } else {
        my $id = SynthwavePlayer::Library::_find_song_id_by_path($app, $path, $playlist_name, $id_map);
        return $id ? { id => $id, type => 'file' } : undef;
    }
}

sub _finish_library_loading {
    my ($app, $options, $callback) = @_;
    my $db = $app->db;
    delete $app->db->{force_playlist_rescan};
    my $is_reload = $options->{is_reload} || 0;

    my $s_count_row = $app->sql->db->query('SELECT COUNT(*) FROM songs')->array;
    my $song_count = $s_count_row ? $s_count_row->[0] : 0;
    my $p_count_row = $app->sql->db->query('SELECT COUNT(*) FROM playlists')->array;
    my $playlist_count = $p_count_row ? $p_count_row->[0] : 0;

    $db->{is_loading} = 0;
    $db->{loading_status}{done} = \1;
    $db->{loading_status}{progress} = 100;
    $db->{loading_status}{message} = sprintf('Loaded %d songs and %d playlists. Library loading complete.', $song_count, $playlist_count);

    {
        my $db_handle = $app->sql->db;
        try {
            my $tx = $db_handle->begin;
            my $pending_count = $db_handle->query("SELECT COUNT(*) FROM configured_directories WHERE status != 'scanned'")->array->[0] // 0;
            $pending_count += $db_handle->query("SELECT COUNT(*) FROM scan_state WHERE key LIKE 'purge_task:%'")->array->[0] // 0;
            if ($pending_count == 0) { $db_handle->query("UPDATE scan_state SET value = 'idle', timestamp = 0 WHERE key = 'scan_status'") }
            $db_handle->query("UPDATE scan_state SET value = ? WHERE key = 'last_scan_completed_at'", time());
            for my $target (@SynthwavePlayer::Config::MUSIC_DIRECTORIES, @SynthwavePlayer::Config::PLAYLISTS_DIRECTORIES) {
                next unless $target;
                my $norm_target = realpath($target) // $target;
                $norm_target =~ s{/+$}{};
                my $target_bytes = utf8::is_utf8($norm_target) ? encode('UTF-8', $norm_target) : $norm_target;
                next unless -d $target_bytes;
                $db_handle->query("UPDATE configured_directories SET status = 'scanned', last_scanned = ? WHERE path = ?", time(), $norm_target);

                # Record mtime for the root directory itself
                my $root_mtime = int((stat($target_bytes))[9] || 0);
                $db_handle->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)", "dir_mtime:" . $norm_target, $root_mtime);

                my @sub_dirs = File::Find::Rule->directory->in($target_bytes);
                for my $dir (@sub_dirs) {
                    my $resolved = realpath($dir) // $dir;
                    my $dir_bytes = utf8::is_utf8($dir) ? encode('UTF-8', $dir) : $dir;
                    my $current_mtime = int((stat($dir_bytes))[9] || 0);
                    $db_handle->query("INSERT OR REPLACE INTO scan_state (key, value) VALUES (?, ?)", "dir_mtime:" . $resolved, $current_mtime);
                }
            }
            $tx->commit;
        } catch { $app->log->error("Failed to finalize library loading state: $_") };
    }

    SynthwavePlayer::Library::_broadcast_status_update($app);
    $app->log->info("Library loading complete.");
    try { $app->sql->db->query('PRAGMA shrink_memory') };

    # Always broadcast library update when finishing a scan/reload/purge task
    # to ensure frontend tracklists are synchronized.
    SynthwavePlayer::Library::_broadcast_library_update($app);

    $callback->($app, $options) if $callback;
}

1;
