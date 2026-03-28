package SynthwavePlayer::Utils;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(fileparse basename);
use Try::Tiny;
use MP3::Tag;
use Mojo::UserAgent;
use Mojo::Util qw(url_escape);
use URI::Escape qw(uri_escape);
use Mojo::File qw(path);
use SynthwavePlayer::Network qw(is_private_ip compile_regex);
use SynthwavePlayer::Config;
use version;
use Encode qw(decode encode);
use Digest::SHA;

our @EXPORT = qw(
    SONG_ID SONG_TITLE SONG_ARTIST SONG_ALBUM SONG_GENRE
    SONG_DURATION SONG_RATING SONG_LOCATION SONG_TRACKNUM SONG_BITRATE
);

our @EXPORT_OK = qw(
    _natural_compare _is_matched realpath
    _get_safe_song_path _get_cover_art_data _markdown_to_html_basic
    _get_update_info _stash_notification
    _extract_metadata _check_dependencies _calculate_source_hash
);

use constant {
    SONG_ID       => 0,
    SONG_TITLE    => 1,
    SONG_ARTIST   => 2,
    SONG_ALBUM    => 3,
    SONG_GENRE    => 4,
    SONG_DURATION => 5,
    SONG_RATING   => 6,
    SONG_LOCATION => 7,
    SONG_TRACKNUM => 8,
    SONG_BITRATE  => 9,
    SONG_COMMENT  => 10,
    SONG_YEAR     => 11,
};

# Compares two strings using natural sorting order (handles numbers correctly).
sub _natural_compare {
    my ($str_a, $str_b) = @_;
    # Prepare strings for comparison by removing non-alphanumeric chars (except space)
    (my $clean_a = $str_a) =~ s/[^a-zA-Z0-9\s]//g;
    (my $clean_b = $str_b) =~ s/[^a-zA-Z0-9\s]//g;
    my @parts_a = split /(\d+)/, $clean_a;
    my @parts_b = split /(\d+)/, $clean_b;

    for (my $i = 0; $i < @parts_a && $i < @parts_b; $i++) {
        my ($part_a, $part_b) = ($parts_a[$i], $parts_b[$i]);
        my $res;
        if ($part_a =~ /^\d+$/ && $part_b =~ /^\d+$/) {
            $res = $part_a <=> $part_b; # numeric comparison
        } else {
            $res = lc($part_a) cmp lc($part_b); # string comparison
        }
        return $res if $res != 0;
    }
    # If one string is a prefix of the other, the shorter one comes first.
    return @parts_a <=> @parts_b;
}

# Checks if a string matches any of a list of regex patterns.
sub _is_matched {
    my ($app, $string, $patterns_ref, $config_name) = @_;
    for my $pattern_str (@$patterns_ref) {
        my $pattern = compile_regex($pattern_str);
        if (!$pattern) {
            $app->log->error("Invalid regex in $config_name: '$pattern_str'.");
            next;
        }
        return 1 if defined $string && $string =~ $pattern;
    }
    return 0;
}


# Helper to get the real path, resolving symlinks robustly.
# Returns a decoded UTF-8 string.
sub realpath {
    my $path = shift;
    return undef unless defined $path;
    try {
        # abs_path expects bytes on Linux. Ensure we pass bytes.
        my $path_bytes = utf8::is_utf8($path) ? encode('UTF-8', $path) : $path;
        my $abs_bytes = abs_path($path_bytes);
        return defined $abs_bytes ? decode('UTF-8', $abs_bytes) : undef;
    } catch {
        # abs_path can die if a path component doesn't exist
        return undef;
    };
}

# Stashes a notification for the current request. Client-side handles deduplication.
sub _stash_notification {
    my ($c, $key, $message) = @_;

    # Always stash for the current request, so it can be picked up by the caller.
    $c->stash($key => $message);

    # All deduplication is now handled on the client-side to avoid issues with
    # multi-worker server environments where memory is not shared.
}

# A centralized security checker for file paths.
# Returns the canonical, safe path on success, or undef on failure.
sub _get_safe_song_path {
    my ($c, $id, $opts) = @_;
    my $silent = $opts && $opts->{silent};

    # 1. Get song from DB
    my $row = $c->app->sql->db->query('SELECT location FROM songs WHERE id = ?', $id)->hash;
    unless ($row && $row->{location}) {
        $c->app->log->debug("Path validation failed: song or location not found for ID '$id'.") if $ENABLE_DEBUG_LOGGING;
        _stash_notification($c, 'error_notification', "Playback error: Song not found in library") unless $silent;
        return undef;
    }
    my $file_path = $row->{location};

    # 2. Basic path validation & traversal check
    if (
        !defined $file_path ||            # Path must be defined
        $file_path eq '' ||               # Path must not be empty
        $file_path =~ m/\0/ ||            # Prevent null byte injection
        $file_path =~ /[\x00-\x1f\x7f]/ || # Prevent control characters
        (grep { $_ eq '..' } File::Spec->splitdir($file_path)) # Prevent directory traversal
    ) {
        $c->app->log->error("Security violation: Invalid characters or path traversal attempt for song ID '$id': '$file_path'");
        _stash_notification($c, 'error_notification', "Playback error: Invalid file path for song ID '$id'") unless $silent;
        return undef;
    }

    # 3. Resolve to a canonical path
    my $real_path = realpath($file_path);
    unless ($real_path) {
        # realpath() can fail if a path component doesn't exist.
        $c->app->log->debug("Path validation failed: file does not exist. Song ID '$id': '$file_path'") if $ENABLE_DEBUG_LOGGING;
        _stash_notification($c, 'error_notification', "Playback error: File does not exist for song ID '$id'") unless $silent;
        return undef;
    }

    # As a secondary defense, re-check for traversal sequences in the resolved path.
    if (grep { $_ eq '..' } File::Spec->splitdir($real_path)) {
        $c->app->log->error("Security violation: Directory traversal detected in resolved path for song ID '$id': '$real_path'");
        _stash_notification($c, 'error_notification', "Playback error: Directory traversal detected in file path") unless $silent;
        return undef;
    }

    # 4. Enforce that the path is within one of the whitelisted music directories.
    # This is the primary defense against path traversal.
    my $is_whitelisted = 0;
    for my $music_dir (@MUSIC_DIRECTORIES) {
        my $real_music_dir = realpath($music_dir);
        if ($real_music_dir && $real_path =~ /^\Q$real_music_dir\E/) {
            $is_whitelisted = 1;
            last;
        }
    }

    unless ($is_whitelisted) {
        $c->app->log->error("Security violation: Path for song ID '$id' is outside whitelisted directories. Add in in your 'Share Directories' Settings. Path: '$real_path'");
        _stash_notification($c, 'error_notification', "Playback error: File location not permitted. Access to this file is restricted.") unless $silent;
        return undef;
    }

    # 5. Enforce file type and existence as a regular file
    # Stricter validation: ensure file has a valid audio extension and verify MIME type
    # Use File::Basename::fileparse for a more robust extension check.
    # This correctly handles filenames with multiple dots.
    my %allowed_extensions = map { $_ => 1 } ('.mp3', '.m4a', '.ogg', '.flac', '.wav', '.opus', '.aiff', '.aif', '.aac', '.wma', '.mka');
    my ($filename, $dirs, $suffix) = fileparse($real_path, qr/\.[^.]*$/);
    unless (defined $suffix && exists $allowed_extensions{lc($suffix)}) {
        $c->app->log->error("Security violation: File for song ID '$id' does not have a valid audio extension: '$real_path'");
        _stash_notification($c, 'error_notification', "Playback error: File is not a supported audio format for song ID '$id'") unless $silent;
        return undef;
    }

    unless (-f $real_path) {
        $c->app->log->debug("Path validation failed: song ID not found '$id': '$real_path'") if $ENABLE_DEBUG_LOGGING;
        _stash_notification($c, 'error_notification', "Playback error: File not found for song ID '$id'") unless $silent;
        return undef;
    }

    # Additional check: verify MIME type of the file
    # Ensure we use bytes for shell commands
    my $real_path_bytes = utf8::is_utf8($real_path) ? encode('UTF-8', $real_path) : $real_path;
    my $shell_safe_path = $real_path_bytes;
    $shell_safe_path =~ s/'/'\\''/g;
    my $mime_type = `file -b --mime-type '$shell_safe_path' 2>/dev/null`;
    chomp $mime_type;

    # The `file` command can misidentify valid MP3s. We'll trust our other checks
    # (like file extension) and only warn if the MIME type is not audio/*.
    # Whitelist known false positives:
    # - application/vnd.hp-HPGL: Some HP printer files misidentified
    # - application/octet-stream: Generic binary, common false positive for MP3s
    # - image/jxl: JPEG XL, sometimes misidentified
    # - application/ogg: OGG container format
    # - application/x-flac: FLAC audio
    # - video/mp4: M4A files are MP4 containers
    # - empty MIME type: file command failed or unknown
    # IMPORTANT: We only warn, we don't block, because file(1) is unreliable
    unless ($mime_type =~ m{^(?:audio/.*|application/(?:vnd\.hp-HPGL|octet-stream|ogg|x-flac)|image/jxl|video/mp4|)$}) {
        $c->app->log->warn("Security warning: File for song ID '$id' has a non-audio MIME type ('$mime_type') but is being allowed. Path: '$real_path'");
    }

    # If all checks pass, return the safe, canonical path
    return $real_path;
}

# Helper to get cover art data for a song ID.
# Returns a hash { data => ..., mime_type => ... } on success, undef on failure.
sub _get_cover_art_data {
    my ($c, $id) = @_;

    return undef unless $ENABLE_COVER_ART;

    my $row = $c->app->sql->db->query('SELECT location FROM songs WHERE id = ?', $id)->hash;
    return undef unless $row;

    # Radio streams don't have embedded cover art
    if ($row->{location} =~ /^https?:\/\//i) {
        return undef;
    }

    # Use a silent check to avoid stashing notifications on the client
    my $safe_path = _get_safe_song_path($c, $id, { silent => 1 });
    return undef unless $safe_path;

    my $mp3;
    try {
        # MP3::Tag expects bytes for the file path
        my $safe_path_bytes = utf8::is_utf8($safe_path) ? encode('UTF-8', $safe_path) : $safe_path;
        $mp3 = MP3::Tag->new($safe_path_bytes, { ignore_bad_frames => 1 });
    } catch {
        # This can be noisy for non-MP3 files, log as debug.
        $c->app->log->debug("MP3::Tag failed to open file '$safe_path': $_") if $ENABLE_DEBUG_LOGGING;
        return undef;
    };
    return undef unless $mp3;

    $mp3->config(decode_encoding_v2 => 'utf-8', decode_encoding_v1 => 'utf-8');
    $mp3->get_tags();
    unless (exists $mp3->{ID3v2}) {
        $mp3->close();
        return undef;
    }

    my $id3v2 = $mp3->{ID3v2};
    my @apic_frames = $id3v2->get_frames('APIC');
    $mp3->close();

    return undef unless @apic_frames;

    my $cover_frame;
    for my $frame (@apic_frames) {
        if (ref($frame) eq 'HASH' && exists($frame->{'_Data'}) && length($frame->{'_Data'})) {
            $cover_frame = $frame;
            last;
        }
    }
    return undef unless $cover_frame;

    my $image_data = $cover_frame->{'_Data'};
    my $mime_type = $cover_frame->{'MIME type'} || 'image/jpeg';

    return undef unless ($image_data && length $image_data);

    return { data => $image_data, mime_type => $mime_type };
}

# Converts basic Markdown to HTML using regex
sub _markdown_to_html_basic {
    my ($markdown) = @_;
    return '' unless defined $markdown;

    # my $html = Mojo::Util::decode('UTF-8', $markdown);
    my $html = $markdown;

    # Remove the V from the version names
    $html =~ s/^## v(\d+\.\d+\.\d+)/## $1/g;

    # Titles and subtitles
    $html =~ s/^###\s+(.*)/<h3 style='font-size: revert; font-weight: revert;'>$1<\/h3>/gm;
    $html =~ s/^##\s+(.*)/<h2 style='font-size: revert; font-weight: revert;'>$1<\/h2>/gm;
    $html =~ s/^#\s+(.*)/<h1 style='font-size: revert; font-weight: revert;'>$1<\/h1>/gm;

    # Bold and Italic
    $html =~ s/\*\*(.*?)\*\*/<strong>$1<\/strong>/g;
    # Italic with _..._ , avoiding matches inside words like my_file.txt
    $html =~ s/(?<!\w)_(.+?)_(?!\w)/<em>$1<\/em>/g;

    # List items (- item)
    $html =~ s/^\s*-\s+(.*)/<li>$1<\/li>/gm;
    $html =~ s/((?:<li>.*?<\/li>\s*)+)/<ul>$1<\/ul>/gs;

    # newlines
    $html =~ s/^$/<br\/>/gm;

    return $html;
}

# Retrieves update information from GitHub
sub _get_update_info {
    my ($app) = @_;
    my $ua = Mojo::UserAgent->new;
    $ua->transactor->name('Mozilla/5.0');

    my $repo_url = "https://github.com/Elive/synthwave-player";
    # Always check the tags on the non-premium version since its a public repo and the premium one is not reachable from here
    my $tags_url = 'https://github.com/Elive/synthwave-player/tags';

    my $res;
    try {
        $res = $ua->get($tags_url)->result;
    } catch {
        $app->log->debug("GitHub update check failed (offline?): $_");
        return { error => "Could not connect to GitHub." };
    };
    return { error => "Could not connect to GitHub." } unless $res && $res->is_success;

    my $dom = $res->dom;
    my $latest_tag_node = $dom->at('a[href*="/releases/tag/"], a[href*="/tree/"]');
    my $latest_tag = $latest_tag_node ? $latest_tag_node->text : '';
    $latest_tag =~ s/^\s+|\s+$//g;

    return { update_available => 0, latest_version => 'v0.0.0' } unless $latest_tag;

    my $update_available = 0;
    try {
        if (version->parse($latest_tag) > version->parse($APP_VERSION)) {
            $update_available = 1;
        }
    } catch {
        $app->log->error("Failed to parse version strings for comparison: '$latest_tag' vs '$APP_VERSION'. Error: $_");
    };

    my $latest_version_no_v = $latest_tag;
    $latest_version_no_v =~ s/^v//;

    my $info = {
        update_available => $update_available,
        latest_version   => $latest_version_no_v,
        current_version  => $APP_VERSION,
        url              => "$repo_url/releases/latest",
    };

    if ($update_available) {
        # always retrieve public content from the public repo
        my $changelog_url = 'https://raw.githubusercontent.com/Elive/synthwave-player/refs/heads/main/CHANGELOG.md';
        my $changelog_res;
        try {
            $changelog_res = $ua->get($changelog_url)->result;
        } catch {
            $app->log->debug("Could not fetch changelog (offline): $_");
        };

        if ($changelog_res && $changelog_res->is_success) {
            my $markdown_text = $changelog_res->text; # Use ->text for UTF-8 decoding
            $markdown_text =~ s/^#.*?\n//; # remove the title

            my @sections = split(/(?=^##\s+v[\d\.]+)/m, $markdown_text);
            my $new_changes_md = '';
            my $previous_changes_md = '';

            for my $section (@sections) {
                if ($section =~ /^##\s+(v[\d\.]+)/) {
                    my $section_version = $1;
                    try {
                        if (version->parse($section_version) > version->parse($APP_VERSION)) {
                            $new_changes_md .= $section;
                        } else {
                            $previous_changes_md .= $section;
                        }
                    } catch {
                        $app->log->error("Failed to parse version for changelog section: '$section_version'. Error: $_");
                    };
                }
            }

            if ($new_changes_md) {
                $info->{changelog_html} = _markdown_to_html_basic($new_changes_md);
            }
            if ($previous_changes_md) {
                $info->{previous_changelog_html} = _markdown_to_html_basic($previous_changes_md);
            }
        } else {
            $app->log->warn("Could not fetch changelog from $changelog_url");
        }

        # Construct download URL for .deb
        my $version_no_v_for_filename = $latest_tag;
        $version_no_v_for_filename =~ s/^v//;
        # URL release is like: https://github.com/Elive/synthwave-player/releases/download/v3.0/synthwave-player-server_3.0_all.deb
        my $deb_filename = "synthwave-player-server_${version_no_v_for_filename}_all.deb";
        $info->{download_url} = "https://github.com/Elive/synthwave-player/releases/download/$latest_tag/$deb_filename";
    }

    return $info;
}

# Calculates a SHA-256 hash of the server source code and modules.
# Used for zero-downtime automatic updates.
sub _calculate_source_hash {
    my ($script_path, $lib_dir) = @_;
    my $sha = Digest::SHA->new(256);

    # List of files to hash: main script + core modules
    my @files = ($script_path);
    my @modules = qw(Config.pm Network.pm Lyrics.pm Utils.pm Library.pm Search.pm);

    for my $mod (@modules) {
        my $path = File::Spec->catfile($lib_dir, 'SynthwavePlayer', $mod);
        push @files, $path if -f $path;
    }

    for my $file (sort @files) {
        if (-f $file) {
            try {
                open my $fh, '<', $file or next;
                binmode($fh);
                $sha->addfile($fh);
                close $fh;
            } catch {
                # Ignore errors reading files
            };
        }
    }
    return $sha->hexdigest;
}

# Extracts metadata from a music file using MP3::Tag.
# Expects $file_path as bytes.
sub _extract_metadata {
    my ($file_path, $log) = @_;
    my $meta = {};
    $meta->{title} = '';
    $meta->{artist} = '';
    $meta->{album} = '';
    $meta->{genre} = '';
    $meta->{duration} = 999999998;
    $meta->{rating} = 0;
    $meta->{track_number} = 0;
    $meta->{bitrate} = 0;
    $meta->{album_artist} = '';
    $meta->{bpm} = '';
    $meta->{channels} = '';
    $meta->{comment_text} = '';
    $meta->{composer} = '';
    my $stats = [stat($file_path)];
    $meta->{date_added} = $stats->[10];
    $meta->{date_modified} = $stats->[9];
    $meta->{description} = '';
    $meta->{disc_number} = 0;
    $meta->{episode_number} = '';
    $meta->{keywords} = '';
    $meta->{sample_rate} = 0;
    $meta->{season_number} = '';
    $meta->{show_name} = '';
    $meta->{source} = '';
    $meta->{year_text} = '';
    $meta->{replaygain} = '';
    $meta->{file_format} = '';

    my $mp3;
    try {
        $mp3 = MP3::Tag->new($file_path, { ignore_bad_frames => 1 });
        if ($mp3) {
            $mp3->config('v2title', 'TIT2');
            $mp3->config(decode_encoding_v2 => 'utf-8', decode_encoding_v1 => 'utf-8');
            $mp3->get_tags();

            my $t  = $mp3->title();
            my $ar = $mp3->artist();
            my $al = $mp3->album();
            my $g  = $mp3->genre();

            $meta->{title}  = $t  if defined $t  && $t  ne '';
            $meta->{artist} = $ar if defined $ar && $ar ne '';
            $meta->{album}  = $al if defined $al && $al ne '';
            $meta->{genre}  = $g  if defined $g  && $g  ne '';

            if ($mp3->can('track1')) {
                my $tn = $mp3->track1();
                if (defined $tn && $tn ne '') {
                    $tn =~ s/\D.*//; # Keep only leading digits
                    $meta->{track_number} = 0 + $tn if $tn =~ /^\d+$/;
                }
            } else {
                my $tr = $mp3->track();
                if (defined $tr && $tr ne '') {
                    $tr =~ s|/.*||;
                    $tr =~ s/\D.*//;
                    $meta->{track_number} = 0 + $tr if $tr =~ /^\d+$/;
                }
            }

            if ($mp3->can('total_secs')) {
                my $s = $mp3->total_secs();
                $meta->{duration} = 0 + $s if defined $s && $s > 0 && $s ne '00:00';
            }

            if ($mp3->can('bitrate_kbps')) {
                my $b = $mp3->bitrate_kbps();
                if (defined $b && $b > 0) {
                    $meta->{bitrate} = int($b);
                    $meta->{bitrate} .= '~' if $mp3->can('is_vbr') && $mp3->is_vbr();
                }
            }

            if (exists $mp3->{ID3v2}) {
                my $r = $mp3->select_id3v2_frame_by_descr('TXXX[rating]');
                $r = $mp3->select_id3v2_frame_by_descr('TXXX[RATING]') if !defined $r || $r eq '';
                $meta->{rating} = 0 + $r if defined $r && $r =~ /^\d+$/;
            }

            $meta->{album_artist} = $mp3->interpolate('%{TXXX[album artist]|TPE2}') || '';
            $meta->{bpm} = $mp3->interpolate('%{TBPM}') || '';
            $meta->{channels} = $mp3->interpolate('%o') || '';
            $meta->{comment_text} = $mp3->comment() || '';
            $meta->{composer} = $mp3->composer() || '';
            $meta->{description} = $mp3->interpolate('%{TIT3}') || '';
            if ($mp3->can('disk1')) {
                my $dn = $mp3->disk1();
                if (defined $dn && $dn ne '') {
                    $dn =~ s/\D.*//;
                    $meta->{disc_number} = 0 + $dn if $dn =~ /^\d+$/;
                }
            }
            $meta->{episode_number} = $mp3->interpolate('%{TXXX[episode_number]}') || '';
            $meta->{keywords} = $mp3->interpolate('%{TXXX[keywords]}') || '';
            $meta->{sample_rate} = $mp3->frequency_Hz() || 0 if $mp3->can('frequency_Hz');
            $meta->{season_number} = $mp3->interpolate('%{TXXX[season_number]}') || '';
            $meta->{show_name} = $mp3->interpolate('%{TXXX[show_name]}') || '';
            $meta->{source} = $mp3->interpolate('%{TXXX[source]}') || '';
            my $y = $mp3->year() || '';
            if ($y =~ /^(\d{4}(?:[-\/.]\d{2}[-\/.]\d{2})?)/) { $meta->{year_text} = $1 }
            elsif ($y =~ /(\d{4})/) { $meta->{year_text} = $1 }
            $meta->{replaygain} = $mp3->interpolate('%{TXXX[replaygain_track_gain]}') || '';
            $meta->{file_format} = $mp3->interpolate('%e') || '';

            $mp3->close();
        }
    } catch {
        $log->warn("Failed to parse MP3 tags for '$file_path': $_") if $log && $ENABLE_DEBUG_LOGGING;
    };

    return $meta;
}

