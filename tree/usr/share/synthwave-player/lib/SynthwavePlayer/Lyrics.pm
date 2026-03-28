package SynthwavePlayer::Lyrics;

use strict;
use warnings;
use feature 'state';
use Exporter 'import';
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON qw(decode_json to_json);
use Mojo::File qw(path);
use URI::Escape qw(uri_escape_utf8);
use Try::Tiny;
use Encode qw(decode encode);
use File::Spec;
use MP3::Tag;

our @EXPORT_OK = qw(fetch_online_lyrics_async get_local_lyrics_data clean_lyrics_text);

my %LYRICS_PROVIDER_BLACKLIST;
my %LYRICS_PROVIDER_FAIL_COUNT;

my @providers = (
    {
        name => 'genius.com',
        builder => sub {
            my ($artist_str, $title_str, $attempt) = @_;
            $attempt //= 1;

            my ($artist_var, $title_var);

            if ($attempt == 1) {
                # Attempt 1: Keep title punctuation. Genius.com is case-insensitive.
                $artist_var = $artist_str;
                $title_var = $title_str;
            } elsif ($attempt == 2) {
                # Attempt 2: Strip leading/trailing non-alphanumeric characters (like "...")
                $artist_var = $artist_str;
                $title_var = $title_str;
                $title_var =~ s/^[^a-zA-Z0-9]+//;
                $title_var =~ s/[^a-zA-Z0-9]+$//;
            } elsif ($attempt == 3) {
                # Attempt 3: Remove all punctuation from title.
                $artist_var = $artist_str;
                $title_var = $title_str;
                $title_var =~ s/[^a-z0-9\s]+//gi;
            } else {
                return undef; # No more variations
            }

            my $path_part = "$artist_var $title_var";

            # Diacritics from https://en.wikipedia.org/wiki/Diacritic, with /i for artist part
            $path_part =~ s/[àáâãäåāăą]/a/gi;
            $path_part =~ s/[èéêëēĕėęě]/e/gi;
            $path_part =~ s/[ìíîïĩīĭįı]/i/gi;
            $path_part =~ s/[òóôõöōŏő]/o/gi;
            $path_part =~ s/[ùúûüũūŭůűų]/u/gi;
            $path_part =~ s/[çćĉċč]/c/gi;
            $path_part =~ s/ñ/n/gi;
            $path_part =~ s/ý/y/gi;
            $path_part =~ s/ż/z/gi;
            $path_part =~ s/'//g; # e.g. "don't" -> "dont"
            $path_part =~ s/&/and/g;
            $path_part =~ s/[^a-zA-Z0-9]+/-/g;
            $path_part =~ s/^-+|-+$//g;
            return "https://genius.com/$path_part-lyrics";
        },
        is_html => 1,
        parser => sub {
            my ($dom, $res) = @_;
            my $lyrics_containers = $dom->find('div[data-lyrics-container="true"]');
            return undef unless $lyrics_containers->size;

            my $lyrics = "";
            $lyrics_containers->each(sub {
                my $container = shift;

                # Remove header elements that Genius sometimes includes inside the container.
                $container->find('div[data-exclude-from-selection="true"]')->each(sub { $_->remove });

                # Genius uses <br> tags for line breaks. Replace with newlines.
                $container->find('br')->each(sub { $_->replace("\n") });

                # Unwrap formatting tags and links to get their text content.
                # We also unwrap <a> and <span> which Genius uses for annotations.
                $container->find('i, b, strong, em, a, span')->each(sub { $_->strip });

                # Now, extract all the text from the cleaned container.
                $lyrics .= $container->all_text . "\n";
            });
            return $lyrics;
        }
    },
    # sometimes offline, ovh seems to be an unstable hosting!
    {
        name => 'lyrics.ovh',
        builder => sub {
            my ($artist_str, $title_str, $attempt) = @_;
            $attempt //= 1;

            my $title_var = $title_str;
            if ($attempt == 2) {
                # Attempt 2: Strip leading/trailing non-alphanumeric characters (like "...")
                $title_var =~ s/^[^a-zA-Z0-9]+//;
                $title_var =~ s/[^a-zA-Z0-9]+$//;
            } elsif ($attempt > 2) {
                return undef;
            }

            return sprintf('https://api.lyrics.ovh/v1/%s/%s', uri_escape_utf8($artist_str), uri_escape_utf8($title_var));
        },
        parser => sub {
            my ($data, $res) = @_;
            my $lyrics = $data->{lyrics};
            return undef if !$lyrics;
            return $lyrics;
        }
    },
);

sub clean_lyrics_text {
    my ($lyrics) = @_;
    return undef unless defined $lyrics && length $lyrics;

    # --- Final Cleanup ---
    # 1. Remove "X Contributors" and song title header (Genius-specific).
    $lyrics =~ s/^\d+\s*Contributors.*?Lyrics//s;

    # 2. Ensure section headers like [Intro] are separated by a blank line.
    $lyrics =~ s/(\])(\S)/$1\n$2/g;
    $lyrics =~ s/(\[)/\n\n$1/g;

    # 3. Trim leading/trailing whitespace from the entire block.
    $lyrics =~ s/^\s+|\s+$//g;

    # 3.5. Remove "(Grazie a Cloud per questo testo)" and similar footers from non-English lyrics.
    $lyrics =~ s/\(.*?(Grazie|Gracias|Thank|Merci).*\)\s*$//i;

    # 4. Collapse multiple consecutive blank lines.
    $lyrics =~ s/\n{3,}/\n\n/g;

    return $lyrics;
}

sub get_local_lyrics_data {
    my ($app, $id, $safe_path, $eyed3_available, $enable_debug) = @_;

    return undef unless defined $safe_path;

    my $lyrics_text;
    my $logger = $app->log;

    # --- Method 1: eyeD3 ---
    if ($eyed3_available) {
        my $shell_safe_path = $safe_path;
        $shell_safe_path =~ s/'/'\\''/g;
        my $eyed3_output_raw = `eyeD3 --no-color '$shell_safe_path' 2>/dev/null`;

        my $eyed3_output;
        if (defined $eyed3_output_raw && length $eyed3_output_raw) {
            try {
                $eyed3_output = decode('UTF-8', $eyed3_output_raw, Encode::FB_CROAK);
            } catch {
                $logger->warn("Lyrics: Failed to decode eyeD3 output from UTF-8 for song ID $id: $_");
                $eyed3_output = $eyed3_output_raw; # Fallback to raw
            };
        }

        if ($eyed3_output) {
            my @lines = split /\n/, $eyed3_output;
            my $in_lyrics_section = 0;
            my @lyrics_lines;
            for my $line (@lines) {
                if ($in_lyrics_section) {
                    # Stop if we hit a separator or one of the known eyeD3 tags.
                    # This is a specific list to avoid misinterpreting lines within the lyrics (like chapter titles) as tags.
                    if ($line =~ /^-{10,}$/ || $line =~ /^(?:album|artist|Description|FRONT_COVER Image|ID3 v2\.\d|Lyrics|recording date|Time|title|track|UserTextFrame):/) {
                        last;
                    }
                    push @lyrics_lines, $line;
                } elsif ($line =~ /^Lyrics:/) {
                    $in_lyrics_section = 1;
                }
            }

            if (@lyrics_lines) {
                $lyrics_text = join("\n", @lyrics_lines);
                $lyrics_text =~ s/^\s+|\s+$//g; # Trim leading/trailing whitespace
                # $logger->debug("Lyrics: eyeD3 found " . length($lyrics_text) . " characters for song ID $id.") if $enable_debug;
                if (length($lyrics_text) < 100) {
                    undef $lyrics_text;
                }
            }
        }
    }

    # --- Method 2: MP3::Tag ---
    unless (defined $lyrics_text && length $lyrics_text) {
        try {
            my $mp3 = MP3::Tag->new($safe_path, { ignore_bad_frames => 1 });
            if ($mp3) {
                $mp3->get_tags();
                my $id3v2 = $mp3->{ID3v2};
                if ($id3v2) {
                    my $version = $id3v2->version() || '3.0';
                    my $encoding = ($version =~ /^4/) ? 'UTF-8' : 'ISO-8859-1';

                    # Helper to process a frame's data
                    my $process_frame = sub {
                        my ($frame, $frame_name) = @_;
                        return undef unless ref($frame) eq 'HASH' && exists $frame->{'_Data'};
                        my $data = $frame->{'_Data'};
                        $data = join("\n", @$data) if ref $data eq 'ARRAY';
                        return undef unless defined $data && length $data;
                        try {
                            return decode($encoding, $data, Encode::FB_CROAK);
                        } catch {
                            $logger->warn("Lyrics: Failed to decode lyrics from $encoding for song ID $id in $frame_name frame: $_");
                            return undef;
                        };
                    };

                    # 1. Standard Lyrics Frames (USLT, SYLT)
                    FRAME_TYPE: for my $frame_type ('USLT', 'SYLT') {
                        for my $frame ($id3v2->get_frames($frame_type)) {
                            if (my $text = $process_frame->($frame, $frame_type)) {
                                if (length($text) >= 100) {
                                    $lyrics_text = $text;
                                    last FRAME_TYPE;
                                }
                            }
                        }
                    }

                    # 2. Custom TXXX Lyrics Frame
                    unless (defined $lyrics_text) {
                        for my $frame ($id3v2->get_frames('TXXX')) {
                            if (ref($frame) eq 'HASH' && lc($frame->{'_Description'} || '') =~ /lyrics/) {
                                if (my $text = $process_frame->($frame, 'TXXX')) {
                                    if (length($text) >= 100) {
                                        $lyrics_text = $text;
                                        last;
                                    }
                                }
                            }
                        }
                    }

                    # 3. Comment Frames (COMM)
                    unless (defined $lyrics_text) {
                        my @comm_frames = $id3v2->get_frames('COMM');
                        my $longest_comm_text;
                        my $longest_comm_len = 0;

                        # First pass: check for explicit "lyrics" descriptions
                        for my $frame (@comm_frames) {
                            if (ref($frame) eq 'HASH' && (lc($frame->{'_Description'} || '') =~ /lyrics/ || ($frame->{'_Description'} || '') eq 'eng')) {
                                if (my $text = $process_frame->($frame, 'COMM')) {
                                    $lyrics_text = $text;
                                    last;
                                }
                            }
                        }

                        # Second pass (fallback): find the longest comment
                        unless (defined $lyrics_text) {
                            for my $frame (@comm_frames) {
                                if (my $text = $process_frame->($frame, 'COMM')) {
                                    if (length($text) > $longest_comm_len) {
                                        $longest_comm_text = $text;
                                        $longest_comm_len  = length($text);
                                    }
                                }
                            }
                            if (defined $longest_comm_text && $longest_comm_len >= 100) {
                                $lyrics_text = $longest_comm_text;
                            }
                        }
                    }
                }
                $mp3->close();
            }
        } catch {
            $logger->error("MP3::Tag processing failed for song ID $id ($safe_path): $_");
        };
    }

    if (defined $lyrics_text && length($lyrics_text) >= 100) {
        $lyrics_text =~ s/\r\n?/\n/g; # Normalize line endings
        return $lyrics_text;
    }

    return undef;
}

sub fetch_online_lyrics_async {
    my ($app, $id, $song_title, $song_artist, $config, $callback) = @_;
    # $config needs: LYRICS_FAIL_CACHE_DIR, LYRICS_CACHE_DIR, LYRICS_INSTRUMENTAL_CACHE_DIR, ENABLE_VERBOSE_LOGGING, ENABLE_DEBUG_LOGGING
    # $callback is to broadcast update: sub { my ($id, $lyrics) = @_; ... }

    if ($config->{LYRICS_INSTRUMENTAL_CACHE_DIR}) {
        my $inst_file = File::Spec->catfile($config->{LYRICS_INSTRUMENTAL_CACHE_DIR}, "$id.txt");
        if (-f $inst_file) {
            # $app->log->debug(" -> Skipping online lyrics search for \"$song_title\" (ID: $id), known instrumental.") if $config->{ENABLE_DEBUG_LOGGING};
            return;
        }
    }

    if ($config->{LYRICS_FAIL_CACHE_DIR}) {
        my $fail_file = File::Spec->catfile($config->{LYRICS_FAIL_CACHE_DIR}, "$id.txt");
        if (-f $fail_file) {
            # Check if we actually have it in cache now (maybe it was added manually or by another process)
            my $cache_file = File::Spec->catfile($config->{LYRICS_CACHE_DIR}, "$id.txt");
            if ($config->{LYRICS_CACHE_DIR} && -f $cache_file) {
                try {
                    my $lyrics = decode('UTF-8', path($cache_file)->slurp, Encode::FB_CROAK);
                    if (defined $lyrics && length($lyrics) >= 100) {
                        $app->log->info(" -> Found cached lyrics for \"$song_title\" despite previous failure flag. Removing failure flag.") if $config->{ENABLE_VERBOSE_LOGGING};
                        unlink $fail_file;
                        $callback->($id, $lyrics);
                        return;
                    }
                } catch {
                    $app->log->error(" -> Failed to read cached lyrics from $cache_file: $_");
                };
            }

            # $app->log->debug(" -> Skipping online lyrics search for \"$song_title\" (ID: $id), previously failed.") if $config->{ENABLE_DEBUG_LOGGING};
            return;
        }
    }

    $app->log->info(" -> No local lyrics found for \"$song_title\". Searching online (async)...") if $config->{ENABLE_VERBOSE_LOGGING};

    my $artist_clean = $song_artist;
    $artist_clean =~ s/\s+\(feat\..*\)//i;
    $artist_clean =~ s/\s+\&.*//;
    $artist_clean =~ s/^\s+|\s+$//g;

    my $title_clean = $song_title;
    $title_clean =~ s/\s+\(.*version\)//i;
    $title_clean =~ s/\s+\(.*remix\)//i;
    $title_clean =~ s/\s+-\s+.*remix//i;
    $title_clean =~ s/\s+-\s+.*edit//i;
    $title_clean =~ s/^\s+|\s+$//g;

    my $artist = uri_escape_utf8($artist_clean);
    my $title  = uri_escape_utf8($title_clean);

    my @all_tried_urls; # Array of hashes: { url => ..., status => ... }
    my $provider_index = 0;
    my $try_next_provider;
    $try_next_provider = sub {
        if ($provider_index >= @providers) {
            $app->log->info(" -> Online lyrics search for \"$song_title\" finished, no lyrics found from any provider.") if $config->{ENABLE_VERBOSE_LOGGING};
            if ($config->{LYRICS_FAIL_CACHE_DIR}) {
                my $fail_file = File::Spec->catfile($config->{LYRICS_FAIL_CACHE_DIR}, "$id.txt");
                try {
                    path($config->{LYRICS_FAIL_CACHE_DIR})->make_path;
                    my $fail_content = "Title: $song_title\nArtist: $song_artist\n";
                    for (my $i=0; $i < @all_tried_urls; $i++) {
                        my $entry = $all_tried_urls[$i];
                        $fail_content .= "URL" . ($i+1) . ": [" . ($entry->{status} // 'N/A') . "] " . $entry->{url} . "\n";
                    }
                    path($fail_file)->spew(encode('UTF-8', $fail_content));
                    # $app->log->debug(" -> Cached lyrics search failure to $fail_file") if $config->{ENABLE_DEBUG_LOGGING};
                } catch {
                    $app->log->error(" -> Failed to write lyrics failure cache file '$fail_file': $_");
                };
            }
            $callback->($id, undef);
            return;
        }
        my $provider = $providers[$provider_index++];

        # Check blacklist
        if (exists $LYRICS_PROVIDER_BLACKLIST{$provider->{name}} && time() < $LYRICS_PROVIDER_BLACKLIST{$provider->{name}}) {
            # $app->log->debug(" -> Lyrics provider '$provider->{name}' is temporarily blacklisted. Skipping.") if $config->{ENABLE_DEBUG_LOGGING};
            return $try_next_provider->();
        }

        my %tried_urls;
        my $url;
        if ($provider->{builder}) {
            $url = $provider->{builder}->($artist_clean, $title_clean);
            $tried_urls{$url} = 1 if defined $url;
        } else {
            $url = sprintf($provider->{url_template}, $artist, $title);
        }

        unless (defined $url) {
            return $try_next_provider->();
        }

        push @all_tried_urls, { url => $url, status => undef };
        my $current_entry_idx = $#all_tried_urls;

        my $redirect_count = 0;
        my $max_redirects = 5;
        my $make_request;
        $make_request = sub {
            my ($current_url, $attempt, $entry_idx) = @_;
            $attempt //= 1;

            if ($redirect_count == 0) {
                my $attempt_str = $provider->{builder} ? " (attempt $attempt)" : "";
                # $app->log->debug(" -> Fetching online lyrics$attempt_str from: $current_url") if $config->{ENABLE_DEBUG_LOGGING};
            }

            $app->ua->get($current_url => sub {
            my ($ua, $tx) = @_;
            my $res = $tx->res;

            # Update status and URL in @all_tried_urls
            if (defined $entry_idx && $entry_idx >= 0) {
                $all_tried_urls[$entry_idx]{url} = $current_url;
                $all_tried_urls[$entry_idx]{status} = $res->code;
            }

            if (!$tx->error || defined $tx->error->{code}) {
                    # Handle redirects if UA doesn't
                    if ($res->is_redirect && $redirect_count < $max_redirects) {
                        $redirect_count++;
                        my $new_url = Mojo::URL->new($res->headers->location)->to_abs(Mojo::URL->new($current_url));
                        # $app->log->debug(" -> Following redirect ($redirect_count/$max_redirects) for '$provider->{name}' to: $new_url") if $config->{ENABLE_DEBUG_LOGGING};
                        $make_request->($new_url, $attempt, $entry_idx);
                        return;
                    }

                    # On 404, try variations for specific providers
                    if ($res->code == 404 && $provider->{builder}) {
                        my $next_attempt = $attempt + 1;
                        my $next_url = $provider->{builder}->($artist_clean, $title_clean, $next_attempt);
                        if (defined $next_url && !exists $tried_urls{$next_url}) {
                            # $app->log->debug(" -> Got 404, trying variation #$next_attempt for '$provider->{name}': $next_url") if $config->{ENABLE_DEBUG_LOGGING};
                            $tried_urls{$next_url} = 1;
                            push @all_tried_urls, { url => $next_url, status => undef };
                            $redirect_count = 0; # Reset redirect count for new attempt
                            return $make_request->($next_url, $next_attempt, $#all_tried_urls);
                        }
                    }

                # Blacklist on server errors (5xx) or rate limiting / access denied (403, 429)
                if ($res->code >= 500 || $res->code == 403 || $res->code == 429) {
                    $LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}}++;
                    if ($LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}} >= 12) {
                        $app->log->warn(" -> Lyrics provider '$provider->{name}' returned error ($res->code) 12 times in a row. Blacklisting for 24 hours.");
                        $LYRICS_PROVIDER_BLACKLIST{$provider->{name}} = time() + 86400;
                    } else {
                        # $app->log->debug(" -> Lyrics provider '$provider->{name}' returned error ($res->code). Fail count: $LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}}") if $config->{ENABLE_DEBUG_LOGGING};
                    }
                    return $try_next_provider->();
                }

                # If we are here, the provider responded successfully (even if 404)
                # Reset fail count on any successful response (including 404)
                $LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}} = 0;

                my $lyrics_text;
                my $is_instrumental = 0;
                if ($res->is_success) {
                    try {
                        if ($provider->{is_html}) {
                            $lyrics_text = $provider->{parser}->($res->dom, $res);
                        }
                        elsif ($res->headers->content_type =~ /json/) {
                            $lyrics_text = $provider->{parser}->($res->json, $res);
                        }

                        if (defined $lyrics_text && $lyrics_text =~ /.*(song|music) (is|are).*instrumental/i) {
                            $is_instrumental = 1;
                            $lyrics_text = undef;
                        } else {
                            $lyrics_text = clean_lyrics_text($lyrics_text);
                        }
                    } catch {
                        $app->log->warn(" -> Lyrics parser for '$provider->{name}' failed: $_");
                    };

                    # If too few contents, check raw body for "instrumental"
                    if (!$is_instrumental && (!defined $lyrics_text || length($lyrics_text) < 100)) {
                        if ($res->body =~ /instrumental/i) {
                            $is_instrumental = 1;
                            $lyrics_text = undef;
                        }
                    }
                }

                if ($is_instrumental) {
                    $app->log->info(" -> Song \"$song_title\" identified as instrumental via '$provider->{name}'.") if $config->{ENABLE_VERBOSE_LOGGING};
                    if ($config->{LYRICS_INSTRUMENTAL_CACHE_DIR}) {
                        my $inst_file = File::Spec->catfile($config->{LYRICS_INSTRUMENTAL_CACHE_DIR}, "$id.txt");
                        try {
                            path($config->{LYRICS_INSTRUMENTAL_CACHE_DIR})->make_path;
                            path($inst_file)->spew("Instrumental: $song_title by $song_artist\nURL: $current_url\n");
                            # $app->log->debug(" -> Cached instrumental status to $inst_file") if $config->{ENABLE_DEBUG_LOGGING};
                        } catch {
                            $app->log->error(" -> Failed to write instrumental cache file '$inst_file': $_");
                        };
                    }
                    $callback->($id, undef);
                    return;
                }

                my $is_valid_lyrics = defined $lyrics_text && length($lyrics_text) >= 100;

                if ($is_valid_lyrics) {
                    # Reset fail count on success
                    $LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}} = 0;

                    $lyrics_text =~ s/\r\n?/\n/g;
                    $app->log->info(" -> Lyrics found online via '$provider->{name}' for song: \"$song_title\" by \"$song_artist\"") if $config->{ENABLE_VERBOSE_LOGGING};

                    # Cache the lyrics
                    if ($config->{LYRICS_CACHE_DIR}) {
                        my $cache_file = File::Spec->catfile($config->{LYRICS_CACHE_DIR}, "$id.txt");
                        try {
                            path($config->{LYRICS_CACHE_DIR})->make_path;
                            path($cache_file)->spew(encode('UTF-8', $lyrics_text . "\n"));
                            # $app->log->debug(" -> Cached lyrics to $cache_file") if $config->{ENABLE_DEBUG_LOGGING};
                        } catch {
                            $app->log->error(" -> Failed to write lyrics to cache file '$cache_file': $_");
                        };
                    }

                    $callback->($id, $lyrics_text);
                    # Success, we're done.
                } else {
                    my $reason = "No lyrics found after parsing.";
                    if (defined $lyrics_text) {
                        my $lyrics_preview = substr($lyrics_text, 0, 500);
                        $lyrics_preview =~ s/\n/\\n/g;
                        $reason = "Lyrics found but too short (" . length($lyrics_text) . " chars). Content preview: '$lyrics_preview...'";
                    }

                    # $app->log->debug(" -> Failed Online Lyrics search for \"$song_title\" from '$provider->{name}':") if $config->{ENABLE_DEBUG_LOGGING};
                    # $app->log->debug("    - Status: " . $res->code . " " . $res->message) if $config->{ENABLE_DEBUG_LOGGING};
                    # $app->log->debug("    - Content-Type: " . ($res->headers->content_type || 'N/A')) if $config->{ENABLE_DEBUG_LOGGING};
                    # $app->log->debug("    - Reason: $reason") if $config->{ENABLE_DEBUG_LOGGING};
                    $try_next_provider->();
                }
            } else {
                # Update status in @all_tried_urls for network errors
                if (defined $entry_idx && $entry_idx >= 0) {
                    $all_tried_urls[$entry_idx]{status} = 'ERR';
                }

                # Blacklist on network/timeout errors (connection refused, timeout, etc.)
                my $error_msg = ($tx->error && $tx->error->{message}) ? $tx->error->{message} : 'Unknown error';
                # $app->log->debug(" -> Failed Online Lyrics search for \"$song_title\" from '$provider->{name}'. Reason: $error_msg") if $config->{ENABLE_DEBUG_LOGGING};
                $LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}}++;
                if ($LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}} >= 12) {
                    $app->log->warn(" -> Lyrics provider '$provider->{name}' failed 12 times in a row due to connection errors. Blacklisting for 24 hours.");
                    $LYRICS_PROVIDER_BLACKLIST{$provider->{name}} = time() + 86400;
                } else {
                    # $app->log->debug(" -> Lyrics provider '$provider->{name}' failed due to connection error. Fail count: $LYRICS_PROVIDER_FAIL_COUNT{$provider->{name}}") if $config->{ENABLE_DEBUG_LOGGING};
                }
                $try_next_provider->();
            }
        });
        };
        $make_request->($url, 1, $current_entry_idx);
    };
    $try_next_provider->();
}

1;
