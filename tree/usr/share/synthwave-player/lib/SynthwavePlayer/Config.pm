package SynthwavePlayer::Config;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use File::HomeDir;
use File::Spec;
use File::Basename qw(dirname basename);
use Mojo::File qw(path);
use Mojo::JSON qw(decode_json);
use JSON::PP ();
use Try::Tiny;
use Config;
use Mojo::UserAgent; # For update checking
use version;         # For update checking
use Digest::SHA qw(sha256_hex);

our @EXPORT = qw(
    %CONFIG_VARS
    $APP_VERSION
    $APP_PORT
    $EYED3_AVAILABLE
    $LYRICS_CACHE_DIR
    $LYRICS_FAIL_CACHE_DIR
    $LYRICS_INSTRUMENTAL_CACHE_DIR
    $USER_FULL_NAME
    @MUSIC_DIRECTORIES
    $WEBSITE_TITLE
    $WELCOME_MESSAGE
    $UI_FONT_SIZE_DESKTOP
    $UI_FONT_SIZE_MOBILE
    $UI_FONT_FAMILY
    $LYRICS_FONT_SIZE_DESKTOP
    $LYRICS_FONT_SIZE_MOBILE
    $LYRICS_FONT_FAMILY
    $ENABLE_COVER_ART
    $ENABLE_RADIO_STATIONS_HTTP
    $ENABLE_ONLINE_LYRICS_SEARCH
    $ENABLE_DEBUG_LOGGING
    $ENABLE_VERBOSE_LOGGING
    $SERVER_PORT
    $SERVER_WORKERS
    $DEFAULT_SORT_BY
    $DEFAULT_SORT_ORDER
    $SCROLL_TO_SONG_ALIGN_MOBILE
    $SCROLL_TO_SONG_ALIGN_DESKTOP
    $SONGS_PER_PAGE
    $MIN_SEARCH_LENGTH
    $PREVIOUS_BUTTON_RESTART_SECONDS
    $IGNORE_PLAYBACK_ERRORS_MS
    $NOTIFICATION_VISIBLE_MS
    $SIDEBAR_AUTO_COLLAPSE_DELAY_MS
    $INITIAL_SONGS_TO_LOAD_MOBILE
    $INITIAL_SONGS_TO_LOAD_DESKTOP
    $SONGS_TO_LOAD_ON_SCROLL_MOBILE
    $SONGS_TO_LOAD_ON_SCROLL_DESKTOP
    $SONGS_PER_PAGE
    $SHOW_PLAYBACK_SPEED_MIN_MINUTES
    @FRIENDS_MUSIC
    $USER_CONFIG_FILE
    @PLAYLISTS_DIRECTORIES
    $ENABLE_UPNP
    @IGNORE_PLAYLISTS_MATCHING
    @IGNORE_GENRES_MATCHING
    $RATE_LIMIT_REQUESTS
    $RATE_LIMIT_WINDOW
    $GLOBAL_RATE_LIMIT_REQUESTS
    $GLOBAL_RATE_LIMIT_WINDOW
    $MAX_SIMULTANEOUS_IPS
    @PRIVATE_NETWORKS
    $UPNP_ERROR_MESSAGE
    $PERIODIC_UPDATE_CHECK_HOURS
    $ADMIN_PASSWORD
    $ALLOW_ADMIN_FROM_ANY_NETWORK
    $ALLOW_LOCAL_NETWORK_EDITING
    $UPNP_CHECK_INTERVAL_HOURS
    @BLACKLIST_PLAYLISTS_MATCHING
    @BLACKLIST_GENRES_MATCHING
    @BLACKLIST_ARTISTS_MATCHING
    $SHOW_PLAYLISTS_OUT_OF_DATE_WARNING
    _get_user_full_name
    _get_cache_dir
    _get_xdg_dir
    _get_default_config_values
    _load_configuration
    _generate_config_content
    _save_configuration_file
    _get_config_values_for_client
    _update_config
    _check_dependencies
);

our %CONFIG_VARS;
BEGIN {
    %CONFIG_VARS = (
        # Group: General
        'USER_FULL_NAME' => {
            type    => 'scalar',
            comment => q{Your full name for the website title (e.g., 'John Smith'). Leave empty to use system lookup.},
            group   => 'General',
            order   => 1,
        },
        'WELCOME_MESSAGE' => {
            type    => 'scalar',
            comment => q{A welcome message to display on startup. Set to '' to disable.},
            group   => 'General',
            order   => 2,
        },
        'UI_FONT_FAMILY' => {
            type    => 'scalar',
            comment => q{The font family for the user interface (e.g., 'Sans', 'monospace'). Any Google Font name can be used here.},
            group   => 'General',
            order   => 3.0,
        },
        'UI_FONT_SIZE_DESKTOP' => {
            type    => 'scalar',
            comment => q{The base font size for the user interface on desktop devices.},
            group   => 'General',
            order   => 3.2,
        },
        'UI_FONT_SIZE_MOBILE' => {
            type    => 'scalar',
            comment => q{The base font size for the user interface on mobile devices.},
            group   => 'General',
            order   => 3.4,
        },
        'LYRICS_FONT_FAMILY' => {
            type    => 'scalar',
            comment => q{The font family for the lyrics display (e.g., 'Overlock', 'serif'). Any Google Font name can be used here.},
            group   => 'General',
            order   => 4.0,
        },
        'LYRICS_FONT_SIZE_DESKTOP' => {
            type    => 'scalar',
            comment => q{The font size for the lyrics display on desktop devices (e.g., '1.25em' or '18px').},
            group   => 'General',
            order   => 4.2,
        },
        'LYRICS_FONT_SIZE_MOBILE' => {
            type    => 'scalar',
            comment => q{The font size for the lyrics display on mobile devices.},
            group   => 'General',
            order   => 4.4,
        },
        'ENABLE_COVER_ART' => {
            type    => 'boolean',
            comment => q{Set to 0 to disable loading and displaying of album cover art.},
            group   => 'General',
            order   => 5,
        },
        'ENABLE_RADIO_STATIONS_HTTP' => {
            type    => 'boolean',
            comment => q{Enable support for non-SSL radio stations (add them in your playlist files as .m3u, .pls). When enabled, a less strict Content-Security-Policy is used to allow streaming from insecure (http) sources, which many radio streams still use.},
            group   => 'Playback',
            order   => 15.5,
        },
        'ENABLE_ONLINE_LYRICS_SEARCH' => {
            type    => 'boolean',
            comment => q{If lyrics are not found in a song's metadata, attempt to fetch them from an online service. For local lyrics embedded in your audio files, installing 'eyeD3' is highly recommended for the best results. Lyrics are cached in ~/.cache/synthwave-player/lyrics/},
            group   => 'Playback',
            order   => 15.6,
        },
        'NOTIFICATION_VISIBLE_MS' => {
            type    => 'scalar',
            comment => q{Base time (in milliseconds) notification messages are displayed. Extra time is automatically added based on message length.},
            group   => 'General',
            order   => 7,
        },
        'SIDEBAR_AUTO_COLLAPSE_DELAY_MS' => {
            type    => 'scalar',
            comment => q{How long (in milliseconds) to wait before collapsing sidebars on mouse-out (desktop only).},
            group   => 'General',
            order   => 8,
        },
        'PERIODIC_UPDATE_CHECK_HOURS' => {
            type    => 'scalar',
            comment => q{How often (in hours) to periodically check for new updates.},
            group   => 'General',
            order   => 9,
        },

        # Group: Playback
        'DEFAULT_SORT_BY' => {
            type    => 'scalar',
            comment => q{Default sorting criteria for the song list ('title', 'artist', 'album', 'genre', 'duration', 'rating', 'track_number').},
            group   => 'Playback',
            order   => 10,
        },
        'DEFAULT_SORT_ORDER' => {
            type    => 'scalar',
            comment => q{Default sorting order ('asc' for ascending, 'desc' for descending).},
            group   => 'Playback',
            order   => 11,
        },
        'PREVIOUS_BUTTON_RESTART_SECONDS' => {
            type    => 'scalar',
            comment => q{If a song has played for more seconds than this value, the 'previous' button restarts it instead of playing the previous song.},
            group   => 'Playback',
            order   => 13,
        },
        'SHOW_PLAYBACK_SPEED_MIN_MINUTES' => {
            type    => 'scalar',
            comment => q{Minimum song duration in minutes to show the playback speed control (e.g., 20 for 20 mins).},
            group   => 'Playback',
            order   => 14,
        },
        'IGNORE_PLAYBACK_ERRORS_MS' => {
            type    => 'scalar',
            comment => q{Time in milliseconds to ignore playback errors after a song change, to avoid warnings from rapid track skipping.},
            group   => 'Playback',
            order   => 15,
        },

        'MIN_SEARCH_LENGTH' => {
            type    => 'scalar',
            comment => q{Minimum number of characters needed to trigger a search.},
            group   => 'Playback',
            order   => 16,
        },

        'FRIENDS_MUSIC' => {
            type    => 'list_name_value',
            comment => "A list of your friend's music servers, which will be displayed in the player's menu for easy access.",
            group   => 'Friends',
            order   => 60,
        },

        # Group: Performance
        'INITIAL_SONGS_TO_LOAD_DESKTOP' => {
            type    => 'scalar',
            comment => q{Initial number of songs to display in the list on desktop devices.},
            group   => 'Performance',
            order   => 23,
        },
        'INITIAL_SONGS_TO_LOAD_MOBILE' => {
            type    => 'scalar',
            comment => q{Initial number of songs to display in the list on mobile devices.},
            group   => 'Performance',
            order   => 24,
        },
        'SONGS_TO_LOAD_ON_SCROLL_DESKTOP' => {
            type    => 'scalar',
            comment => q{How many more songs to load at a time when scrolling down on desktop.},
            group   => 'Performance',
            order   => 25,
        },
        'SONGS_TO_LOAD_ON_SCROLL_MOBILE' => {
            type    => 'scalar',
            comment => q{How many more songs to load at a time when scrolling down on mobile.},
            group   => 'Performance',
            order   => 26,
        },
        'SCROLL_TO_SONG_ALIGN_DESKTOP' => {
            type    => 'scalar',
            comment => q{Vertical alignment of the selected song in the list on desktop.},
            group   => 'Performance',
            order   => 27,
        },
        'SCROLL_TO_SONG_ALIGN_MOBILE' => {
            type    => 'scalar',
            comment => q{Vertical alignment of the selected song in the list on mobile (0.0=top, 0.5=center, 1.0=bottom).},
            group   => 'Performance',
            order   => 28,
        },
        'SERVER_WORKERS' => {
            type    => 'scalar',
            comment => q{Number of server workers for production mode. Increase for high-traffic servers.},
            group   => 'Networking',
            order   => 36,
        },

        'PRIVATE_NETWORKS' => {
            type    => 'array',
            comment => q{A list of IP address patterns (regular expressions) that are considered private. Connections from these IPs bypass rate limiting and can access settings.},
            group   => 'Networking',
            order   => 37,
        },
        'ALLOW_ADMIN_FROM_ANY_NETWORK' => {
            type    => 'boolean',
            comment => q{Allow entering Admin Mode from any network (public internet). By default, Admin Mode is only accessible from private/local networks for security.},
            group   => 'Networking',
            order   => 38,
        },

        # Group: Networking
        'ENABLE_UPNP' => {
            type    => 'boolean',
            comment => q{Enable UPnP to automatically configure port forwarding on common home routers (if supported). This allows your music server to be accessible from the internet without manual router configuration.},
            group   => 'Networking',
            order   => 35,
        },

        'UPNP_CHECK_INTERVAL_HOURS' => {
            type    => 'scalar',
            comment => q{How often (in hours) to check that the UPnP port forwarding is still active. Set to 0 to disable periodic checks.},
            group   => 'Networking',
            order   => 35.2,
        },

        'SERVER_PORT' => {
            type    => 'scalar',
            comment => q{The port number for the web server to listen on. You must restart the server for changes to take effect.},
            group   => 'Networking',
            order   => 35.5,
        },

        # Group: Music Library
        'PLAYLISTS_DIRECTORIES' => {
            type    => 'array',
            comment => q{A list of directories where your .pls, .m3u, and .m3u8 playlist files are stored.},
            group   => 'Music Library',
            order   => 42,
        },
        'MUSIC_DIRECTORIES' => {
            type    => 'array',
            comment => q{List of directories allowed to share. The player will scan these directories recursively for music files.},
            group   => 'Music Library',
            order   => 41,
        },

        'IGNORE_PLAYLISTS_MATCHING' => {
            type    => 'array',
            comment => q{A list of regular expressions to ignore matching playlist names (one per line). Slashes for flags like /i are supported.},
            group   => 'Music Library',
            order   => 43,
        },
        'IGNORE_GENRES_MATCHING' => {
            type    => 'array',
            comment => q{A list of regular expressions to ignore matching genre names (one per line). Slashes for flags like /i are supported.},
            group   => 'Music Library',
            order   => 44,
        },
        'BLACKLIST_PLAYLISTS_MATCHING' => {
            type    => 'array',
            comment => q{A list of regular expressions to completely hide matching playlists from the UI (one per line). Slashes for flags like /i are supported.},
            group   => 'Music Library',
            order   => 44.1,
        },
        'BLACKLIST_GENRES_MATCHING' => {
            type    => 'array',
            comment => q{A list of regular expressions to completely hide matching genres from the UI and the track list. Slashes for flags like /i are supported.},
            group   => 'Music Library',
            order   => 44.2,
        },
        'BLACKLIST_ARTISTS_MATCHING' => {
            type    => 'array',
            comment => q{A list of regular expressions to completely hide matching artists from the track list (one per line). Slashes for flags like /i are supported.},
            group   => 'Music Library',
            order   => 44.3,
        },

        # Group: Security
        'RATE_LIMIT_REQUESTS' => {
            type    => 'scalar',
            comment => q{Number of requests allowed per IP in the time window (to avoid bots).},
            group   => 'Security',
            order   => 45,
        },
        'RATE_LIMIT_WINDOW' => {
            type    => 'scalar',
            comment => q{Time window in seconds for the rate limit per IP.},
            group   => 'Security',
            order   => 46,
        },
        'GLOBAL_RATE_LIMIT_REQUESTS' => {
            type    => 'scalar',
            comment => q{Global number of requests allowed from all IPs in the time window.},
            group   => 'Security',
            order   => 47,
        },
        'GLOBAL_RATE_LIMIT_WINDOW' => {
            type    => 'scalar',
            comment => q{Global time window in seconds for the rate limit.},
            group   => 'Security',
            order   => 48,
        },
        'MAX_SIMULTANEOUS_IPS' => {
            type    => 'scalar',
            comment => q{Max number of unique IPs allowed to connect in a time window.},
            group   => 'Security',
            order   => 49,
        },
        'ADMIN_PASSWORD' => {
            type    => 'scalar',
            comment => q{The password for the 'admin' user to access Admin Mode. Leave empty to be prompted on first run.},
            group   => 'Security',
            order   => 50,
        },
        'ALLOW_LOCAL_NETWORK_EDITING' => {
            type    => 'boolean',
            comment => q{Allow editing song tags and ratings from any device on the local network without being in Admin Mode.},
            group   => 'Security',
            order   => 50.5,
        },

        # Group: Debugging
        'ENABLE_DEBUG_LOGGING' => {
            type    => 'boolean',
            comment => q{Enable verbose logging for debugging purposes.},
            group   => 'Debugging',
            order   => 51,
        },
        'ENABLE_VERBOSE_LOGGING' => {
            type    => 'boolean',
            comment => q{Show app usage in the terminal, like song requests, searches, and filter selections.},
            group   => 'Debugging',
            order   => 52,
        },
        'SHOW_PLAYLISTS_OUT_OF_DATE_WARNING' => {
            type    => 'boolean',
            comment => q{Show a warning modal if songs in a playlist are not found in the music library.},
            group   => 'Debugging',
            order   => 54,
        },
    );
}

our %IP_CACHE;
our %COMPILED_REGEX_CACHE;


# Get user full name from system
sub _get_user_full_name {
    my $user_full_name = '';
    if (my $user = $ENV{USER}) {
        if (open my $fh, '<', '/etc/passwd') {
            while (my $line = <$fh>) {
                chomp $line;
                my @fields = split ':', $line;
                if (@fields >= 5 && $fields[0] eq $user) {
                    ($user_full_name) = split ',', $fields[4];
                    $user_full_name =~ s/^\s+|\s+$//g;
                    last;
                }
            }
            close $fh;
        }
        $user_full_name ||= $user;
    }
    return $user_full_name || 'My';
}

# --- Port and Configuration Setup ---
our $APP_VERSION = 'v3.6';
our $APP_PORT;
our $EYED3_AVAILABLE; # Explicitly declare for use within this package
our $LYRICS_CACHE_DIR;
our $LYRICS_FAIL_CACHE_DIR;
our $LYRICS_INSTRUMENTAL_CACHE_DIR;

# Global package variables for configuration, to be populated by _load_configuration
our ($USER_FULL_NAME, @MUSIC_DIRECTORIES, $WEBSITE_TITLE, $WELCOME_MESSAGE, $UI_FONT_SIZE_DESKTOP, $UI_FONT_SIZE_MOBILE, $UI_FONT_FAMILY, $LYRICS_FONT_SIZE_DESKTOP, $LYRICS_FONT_SIZE_MOBILE, $LYRICS_FONT_FAMILY,
     $ENABLE_COVER_ART, $ENABLE_EQUALIZER, $ENABLE_RADIO_STATIONS_HTTP, $ENABLE_ONLINE_LYRICS_SEARCH, $ENABLE_DEBUG_LOGGING, $ENABLE_VERBOSE_LOGGING, $SERVER_PORT, $SERVER_WORKERS, $DEFAULT_SORT_BY, $DEFAULT_SORT_ORDER,
     $SCROLL_TO_SONG_ALIGN_MOBILE, $SCROLL_TO_SONG_ALIGN_DESKTOP, $SONGS_PER_PAGE, $MIN_SEARCH_LENGTH,
     $PREVIOUS_BUTTON_RESTART_SECONDS, $IGNORE_PLAYBACK_ERRORS_MS, $NOTIFICATION_VISIBLE_MS,
     $SIDEBAR_AUTO_COLLAPSE_DELAY_MS, $INITIAL_SONGS_TO_LOAD_MOBILE, $INITIAL_SONGS_TO_LOAD_DESKTOP,
     $SONGS_TO_LOAD_ON_SCROLL_MOBILE, $SONGS_TO_LOAD_ON_SCROLL_DESKTOP,
     $SHOW_PLAYBACK_SPEED_MIN_MINUTES, @FRIENDS_MUSIC, $USER_CONFIG_FILE, @PLAYLISTS_DIRECTORIES,
     $ENABLE_UPNP, @IGNORE_PLAYLISTS_MATCHING, @IGNORE_GENRES_MATCHING, $RATE_LIMIT_REQUESTS, $RATE_LIMIT_WINDOW,
     $GLOBAL_RATE_LIMIT_REQUESTS, $GLOBAL_RATE_LIMIT_WINDOW, $MAX_SIMULTANEOUS_IPS, @PRIVATE_NETWORKS, $UPNP_ERROR_MESSAGE, $PERIODIC_UPDATE_CHECK_HOURS,
     $ADMIN_PASSWORD, $ALLOW_ADMIN_FROM_ANY_NETWORK, $ALLOW_LOCAL_NETWORK_EDITING, $UPNP_CHECK_INTERVAL_HOURS, @BLACKLIST_PLAYLISTS_MATCHING, @BLACKLIST_GENRES_MATCHING, @BLACKLIST_ARTISTS_MATCHING, $SHOW_PLAYLISTS_OUT_OF_DATE_WARNING,
     $_CONFIG_LAST_MTIME);

# Get XDG Cache directory or fallback to a default
sub _get_cache_dir {
    my $xdg_cache_home = $ENV{XDG_CACHE_HOME} || File::Spec->catdir(File::HomeDir->my_home, '.cache');
    return File::Spec->catdir($xdg_cache_home, 'synthwave-player');
}

# Get XDG directory or fallback to a default
sub _get_xdg_dir {
    my ($dir_type) = @_; # e.g., 'MUSIC'
    # Try to get from XDG user dirs
    my $xdg_config_home = $ENV{XDG_CONFIG_HOME} || File::Spec->catdir(File::HomeDir->my_home, '.config');
    my $user_dirs_file = File::Spec->catfile($xdg_config_home, 'user-dirs.dirs');

    my $uc_dir_type = uc($dir_type);
    my $fallback_dir_name = ucfirst(lc($dir_type)); # Music, Videos, etc.
    my $fallback_path = File::Spec->catdir(File::HomeDir->my_home, $fallback_dir_name);

    if (-f $user_dirs_file) {
        open my $fh, '<', $user_dirs_file or return $fallback_path;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
            if ($line =~ /^XDG_${uc_dir_type}_DIR="(.*)"$/) {
                my $dir_path = $1;
                $dir_path =~ s/\$HOME/File::HomeDir->my_home/eg;
                close $fh;
                return $dir_path;
            }
        }
        close $fh;
    }
    return $fallback_path;
}

# Returns a hash of default configuration values.
sub _get_default_config_values {
    my @music_dirs;
    my $xdg_music_dir = _get_xdg_dir('MUSIC');
    push @music_dirs, $xdg_music_dir if $xdg_music_dir && -d $xdg_music_dir;

    my $elive_demo_music_dir = '/usr/share/elive-demo-files-skel/Music';
    push @music_dirs, $elive_demo_music_dir if -d $elive_demo_music_dir;

    my @playlist_dirs;
    my $default_playlist_dir = File::Spec->catdir(File::HomeDir->my_home, 'Music', 'playlists');
    push @playlist_dirs, $default_playlist_dir if $default_playlist_dir && -d $default_playlist_dir;

    my $elive_demo_playlist_dir = '/usr/share/elive-demo-files-skel/Music';
    push @playlist_dirs, $elive_demo_playlist_dir if -d $elive_demo_playlist_dir;

    return {
        USER_FULL_NAME => '',
        MUSIC_DIRECTORIES => \@music_dirs,
        WELCOME_MESSAGE => 'Fsck Spotify',
        UI_FONT_FAMILY => 'Roboto',
        UI_FONT_SIZE_DESKTOP => '1.00em',
        UI_FONT_SIZE_MOBILE => '0.95em',
        LYRICS_FONT_FAMILY => 'Overlock',
        LYRICS_FONT_SIZE_DESKTOP => '1.15em',
        LYRICS_FONT_SIZE_MOBILE => '1.00em',
        ENABLE_COVER_ART => 1,
        ENABLE_RADIO_STATIONS_HTTP => 0,
        ENABLE_ONLINE_LYRICS_SEARCH => 1,
        ENABLE_DEBUG_LOGGING => 0,
        ENABLE_VERBOSE_LOGGING => 0,
        SERVER_WORKERS => 1,
        DEFAULT_SORT_BY => 'rating',
        DEFAULT_SORT_ORDER => 'desc',
        SCROLL_TO_SONG_ALIGN_MOBILE => 0.50,
        SCROLL_TO_SONG_ALIGN_DESKTOP => 0.25,
        MIN_SEARCH_LENGTH => 2,
        PREVIOUS_BUTTON_RESTART_SECONDS => 20,
        IGNORE_PLAYBACK_ERRORS_MS => 300,
        NOTIFICATION_VISIBLE_MS => 6000,
        SIDEBAR_AUTO_COLLAPSE_DELAY_MS => 2000,
        PERIODIC_UPDATE_CHECK_HOURS => 72, # 3 days
        INITIAL_SONGS_TO_LOAD_DESKTOP => 60,
        INITIAL_SONGS_TO_LOAD_MOBILE => 30,
        SONGS_TO_LOAD_ON_SCROLL_DESKTOP => 100,
        SONGS_TO_LOAD_ON_SCROLL_MOBILE => 50,
        SHOW_PLAYBACK_SPEED_MIN_MINUTES => 20,
        SERVER_PORT => 8160,
        ENABLE_UPNP => 0,
        UPNP_CHECK_INTERVAL_HOURS => 2,
        FRIENDS_MUSIC => [
            { name => '🧙 Thanatermesis', value => 'https://music.home.thanatermesis.org' },
            { name => '🫥 John Smith', value => 'https://placehold.co/500x500/1a0e2a/ff00ff?text=John+Smith+doesnt+exist' },
            { name => '🏍 Nightride FM', value => 'https://nightride.fm/eq?station=nightride' },
        ],
        PLAYLISTS_DIRECTORIES => \@playlist_dirs,
        IGNORE_PLAYLISTS_MATCHING => [ 'ORD', '^tmp/i', 'temporal/i', 'stars/i', 'iphone/i', 'AI', 'Recently/i' ],
        IGNORE_GENRES_MATCHING => [ '^AI$/i', '^rare$/i', '^other$/i' ],
        BLACKLIST_PLAYLISTS_MATCHING => [],
        BLACKLIST_GENRES_MATCHING => [],
        BLACKLIST_ARTISTS_MATCHING => [],
        RATE_LIMIT_REQUESTS => 240,
        RATE_LIMIT_WINDOW => 60,
        GLOBAL_RATE_LIMIT_REQUESTS => 1000,
        GLOBAL_RATE_LIMIT_WINDOW => 60,
        MAX_SIMULTANEOUS_IPS => 50,
        PRIVATE_NETWORKS => [
            # IPv4 loopback
            '^127\.0\.0\.1(:[0-9]+)?$',
            # IPv6 loopback
            '^::1(:[0-9]+)?$',
            # RFC1918 private networks
            '^10\.',
            '^172\.(1[6-9]|2[0-9]|3[0-1])\.',
            '^192\.168\.',
            # Link-local (APIPA)
            '^169\.254\.',
            # Tailscale CGNAT range (100.64.0.0/10)
            '^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.',
            # IPv6 Unique Local Unicast (fc00::/7)
            '^f[cd][0-9a-f]{2}:/i',
            # IPv6 Link-local (fe80::/10)
            '^fe[89ab][0-9a-f]:/i',
        ],
        ADMIN_PASSWORD => '',
        ALLOW_ADMIN_FROM_ANY_NETWORK => 0,
        ALLOW_LOCAL_NETWORK_EDITING => 0,
        SHOW_PLAYLISTS_OUT_OF_DATE_WARNING => 0,
    };
}


# Centralized function to load all configurations
sub _load_configuration {
    my ($app) = @_;

    my $user_config_dir = File::Spec->catdir(File::HomeDir->my_home, '.config', 'synthwave-player');
    $USER_CONFIG_FILE = File::Spec->catfile($user_config_dir, 'server-config.json');

    # Check if config file has changed since last load
    # Use stat on the file to get mtime
    my $mtime = (stat($USER_CONFIG_FILE))[9] || 0;

    # In multi-worker mode, each worker has its own memory, so we need to
    # check the mtime every time but only reload if it actually changed
    # We also check if the file exists to handle deletion/recreation
    if (defined $_CONFIG_LAST_MTIME && $_CONFIG_LAST_MTIME == $mtime && $mtime != 0) {
        return; # No changes
    }

    # Log when config is being reloaded (only if this isn't the first load)
    if (defined $_CONFIG_LAST_MTIME && $app && $app->can('log')) {
        $app->log->info("Configuration file changed (mtime: $mtime), reloading...");
    }

    $_CONFIG_LAST_MTIME = $mtime;

    %IP_CACHE = (); # Clear cache on config reload
    %COMPILED_REGEX_CACHE = ();

    # --- Initialize with default values ---
    # This ensures that we always have a baseline configuration, even if the user's config file is missing or broken.
    my $default_values = _get_default_config_values();
    for my $var (keys %$default_values) {
        # This is a bit of metaprogramming to assign to our package variables (e.g., $USER_FULL_NAME) by name.
        my $info = $CONFIG_VARS{$var};
        next unless $info; # Should not happen

        my $full_var_name = __PACKAGE__ . '::' . $var;
        no strict 'refs';
        if ($info->{type} eq 'array' || $info->{type} eq 'list_name_value' || $info->{type} eq 'list_name_password') {
            @{$full_var_name} = @{$default_values->{$var}};
        } else {
            ${$full_var_name} = $default_values->{$var};
        }
    }

    # --- User Configuration File Handling ---
    path($user_config_dir)->make_path;
    my $user_config = {};
    my $is_new_file = !-f $USER_CONFIG_FILE;

    if (!$is_new_file) {
        try {
            my $content = path($USER_CONFIG_FILE)->slurp;
            $user_config = decode_json($content);
        } catch {
            warn "Could not read or parse user configuration file '$USER_CONFIG_FILE': $_. Using defaults.";
        };
    }

    my @new_vars_added;
    my $needs_save = $is_new_file;

    # Merge user config into package variables and check for missing ones
    for my $var (sort { ($CONFIG_VARS{$a}{order} || 99) <=> ($CONFIG_VARS{$b}{order} || 99) } keys %CONFIG_VARS) {
        next if $var eq 'IS_PRO';

        my $info = $CONFIG_VARS{$var};
        my $full_var_name = __PACKAGE__ . '::' . $var;
        no strict 'refs';

        if (exists $user_config->{$var}) {
            # Migration: Hash passwords if they look like plain text (not 64 chars hex)
            if ($var eq 'ADMIN_PASSWORD' && $user_config->{$var} && length($user_config->{$var}) != 64) {
                $user_config->{$var} = sha256_hex($user_config->{$var});
                $needs_save = 1;
            }

            if ($info->{type} eq 'array' || $info->{type} eq 'list_name_value' || $info->{type} eq 'list_name_password') {
                if ($info->{type} eq 'list_name_password') {
                    for my $item (@{$user_config->{$var}}) {
                        if ($item->{value} && length($item->{value}) != 64) {
                            $item->{value} = sha256_hex($item->{value});
                            $needs_save = 1;
                        }
                    }
                }
                @{$full_var_name} = @{$user_config->{$var}};
            } else {
                ${$full_var_name} = $user_config->{$var};
            }
        } else {
            # Variable missing from config file, use default and mark for saving
            push @new_vars_added, $var;
            $user_config->{$var} = $default_values->{$var};
            $needs_save = 1;
        }
    }

    if ($needs_save) {
        try {
            my $json_text = JSON::PP->new->utf8->pretty->canonical->encode($user_config);
            _save_configuration_file($app, $json_text);
        } catch {
            warn "Could not write to user configuration file '$USER_CONFIG_FILE': $!";
        };
    }

    if (!$is_new_file) {
        $app->log->debug("Loaded user configuration from: $USER_CONFIG_FILE");
    }

    # Update secrets if the admin password changed.
    if ($app && $app->can('secrets')) {
        my $secret = $ADMIN_PASSWORD || 'synthwave-player-default-secret';
        # Use a combination of the password and a static salt for better security
        $app->secrets([$secret, 'synthwave-static-salt-v2']);
    }

    # Calculate dynamic SONGS_PER_PAGE based on the largest possible initial load
    my $max_initial = $INITIAL_SONGS_TO_LOAD_DESKTOP > $INITIAL_SONGS_TO_LOAD_MOBILE
                      ? $INITIAL_SONGS_TO_LOAD_DESKTOP : $INITIAL_SONGS_TO_LOAD_MOBILE;
    $SONGS_PER_PAGE = $max_initial > 100 ? $max_initial : 100;

    # Enforce minimums
    if (defined $PERIODIC_UPDATE_CHECK_HOURS && $PERIODIC_UPDATE_CHECK_HOURS < 2) {
        $app->log->warn("PERIODIC_UPDATE_CHECK_HOURS is set to $PERIODIC_UPDATE_CHECK_HOURS which is less than the minimum of 2. Forcing to 2 hours.");
        $PERIODIC_UPDATE_CHECK_HOURS = 2;
    }

    # --- Derived Configuration & Logging ---
    my $user_full_name;
    if ($USER_FULL_NAME) {
        $user_full_name = $USER_FULL_NAME;
    } else {
        # Fetch user full name from system
        $user_full_name = _get_user_full_name();

        # If this is not a new config file but USER_FULL_NAME is empty,
        # update the config file with the fetched name
        if (!$is_new_file) {
            $user_config->{USER_FULL_NAME} = $user_full_name;
            try {
                my $json_text = JSON::PP->new->utf8->pretty->canonical->encode($user_config);
                _save_configuration_file($app, $json_text);
            } catch {
                warn "Could not write to user configuration file '$USER_CONFIG_FILE': $!";
            };
        }
    }
    $WEBSITE_TITLE = "$user_full_name Music";

    # Visual logging for configuration status
    if ($is_new_file) {
        $app->log->info("-----------------------------------------------------------------");
        $app->log->info("---       USER CONFIGURATION CREATED                        ---");
        $app->log->info("---                                                         ---");
        $app->log->info("--- A new configuration file has been created for you.      ---");
        $app->log->info("--- You can customize your settings by editing this file:   ---");
        $app->log->info("--- $USER_CONFIG_FILE");
        $app->log->info("-----------------------------------------------------------------");
    } elsif (@new_vars_added) {
        $app->log->info("-----------------------------------------------------------------");
        $app->log->info("---       USER CONFIGURATION UPDATED                        ---");
        $app->log->info("---                                                         ---");
        $app->log->info("--- New settings have been added to your personal config:   ---");
        for my $var (@new_vars_added) {
            $app->log->info("---   - $var");
        }
        $app->log->info("--- You can customize them by editing this file:            ---");
        $app->log->info("--- $USER_CONFIG_FILE");
        $app->log->info("-----------------------------------------------------------------");
    }

    $LYRICS_CACHE_DIR = File::Spec->catdir(_get_cache_dir(), 'lyrics');
    try {
        path($LYRICS_CACHE_DIR)->make_path;
    } catch {
        $app->log->error("Could not create lyrics cache directory '$LYRICS_CACHE_DIR': $_");
    };

    $LYRICS_FAIL_CACHE_DIR = File::Spec->catdir(_get_cache_dir(), 'lyrics-fail');
    try {
        path($LYRICS_FAIL_CACHE_DIR)->make_path;
    } catch {
        $app->log->error("Could not create lyrics failure cache directory '$LYRICS_FAIL_CACHE_DIR': $_");
    };

    $LYRICS_INSTRUMENTAL_CACHE_DIR = File::Spec->catdir(_get_cache_dir(), 'lyrics-instrumental');
    try {
        path($LYRICS_INSTRUMENTAL_CACHE_DIR)->make_path;
    } catch {
        $app->log->error("Could not create lyrics instrumental cache directory '$LYRICS_INSTRUMENTAL_CACHE_DIR': $_");
    };
}

# Helper to save configuration file atomically
sub _save_configuration_file {
    my ($app, $content) = @_;
    my $config_dir = dirname($USER_CONFIG_FILE);
    path($config_dir)->make_path;

    # Write to a temporary file and then atomically rename it.
    # This prevents the file watcher from reading a partially written file.
    my $temp_file_path = path($config_dir, basename($USER_CONFIG_FILE) . ".tmp.$$");
    try {
        # IMPORTANT: Use always standard open/print for robustness, as spew_utf8 was causing issues.
        # Since $content is already UTF-8 encoded bytes (from encode_json), we write it raw.
        open my $fh, '>:raw', $temp_file_path->to_string
            or die "Cannot open temp config file '$temp_file_path': $!";
        print $fh $content;
        close $fh;

        $temp_file_path->move_to($USER_CONFIG_FILE);
        return 1;
    } catch {
        $app->log->error("Failed to save configuration: $_") if $app && $app->can('log');
        # Clean up temp file on failure
        $temp_file_path->remove if -f $temp_file_path;
        die $_;
    };
}

# Generates the content for the server-config.json file from a hash of values.
sub _generate_config_content {
    my ($config_values) = @_;
    # Filter out variables that shouldn't be in the config
    my $to_save = {};
    for my $var (keys %CONFIG_VARS) {
        next if $var eq 'IS_PRO';
        if (exists $config_values->{$var}) {
            my $val = $config_values->{$var};
            if ($CONFIG_VARS{$var}{type} eq 'boolean') {
                $to_save->{$var} = $val ? 1 : 0;
            } else {
                $to_save->{$var} = $val;
            }
        }
    }
    return JSON::PP->new->utf8->pretty->canonical->encode($to_save);
}

# Returns a hash of current configuration values prepared for the client
sub _get_config_values_for_client {
    my %current_config;
    for my $var (sort keys %CONFIG_VARS) {
        my $info = $CONFIG_VARS{$var};
        my $full_var_name = __PACKAGE__ . '::' . $var;
        no strict 'refs';
        if ($info->{type} eq 'scalar' || $info->{type} eq 'boolean') {
            # Security: Don't send the admin password to the client, just an indicator it's set
            if ($var eq 'ADMIN_PASSWORD') {
                $current_config{$var} = ${$full_var_name} ? '********' : ''; # Send placeholder if set
                next;
            }
            $current_config{$var} = ${$full_var_name};
        } elsif ($info->{type} eq 'array' || $info->{type} eq 'list_name_value' || $info->{type} eq 'list_name_password') {
            $current_config{$var} = [@{$full_var_name}];
        }
    }
    return \%current_config;
}

# Updates the configuration with new values and saves it to the file
sub _update_config {
    my ($app, $new_values) = @_;

    # 1. Build the complete configuration based on current state + user changes.
    my %current_config;
    for my $var (keys %CONFIG_VARS) {
        my $info = $CONFIG_VARS{$var};
        my $full_var_name = __PACKAGE__ . '::' . $var;
        no strict 'refs';
        if ($info->{type} eq 'scalar' || $info->{type} eq 'boolean') {
            $current_config{$var} = ${$full_var_name};
        } elsif ($info->{type} eq 'array' || $info->{type} eq 'list_name_value' || $info->{type} eq 'list_name_password') {
            $current_config{$var} = [@{$full_var_name}];
        }
    }

    for my $var_name (keys %$new_values) {
        if ($var_name eq 'ADMIN_PASSWORD') {
            my $pass = $new_values->{$var_name};
            if (defined $pass && $pass ne '' && $pass ne '********') {
                # If it's not already a 64-char hash, hash it now (manual API calls)
                if (length($pass) != 64) {
                    $pass = sha256_hex($pass);
                }
                $current_config{$var_name} = $pass;
            }
        } else {
            $current_config{$var_name} = $new_values->{$var_name};
        }
    }

    # 2. Generate the new config file content.
    my $new_content = _generate_config_content(\%current_config);

    # 3. Write to the configuration file atomically.
    _save_configuration_file($app, $new_content);

    # Reload configuration in current process
    _load_configuration($app);

    return \%current_config;
}

# Checks for required Perl modules and external commands
sub _check_dependencies {
    my ($app) = @_; # Declare $app as a lexical variable
    my @modules = qw(
        Mojolicious::Lite File::HomeDir File::Basename File::Spec File::Find::Rule Digest::SHA
        URI::Escape IO::Socket::INET Mojo::File
        Try::Tiny Mojo::JSON JSON::PP Linux::Inotify2 Mojo::UserAgent version
        Mojo::SQLite MP3::Tag MP3::Info
    );
    for my $module (@modules) {
        try {
            eval "require $module";
            $@ and die $@;
        } catch {
            $app->log->fatal("Required Perl module '$module' is not installed. Please install it, e.g., 'cpanm $module'");
            exit 1;
        };
    }
    $app->log->info("All required Perl modules are installed.");

    # Check for required external commands
    my @commands = qw(file);
    for my $cmd (@commands) {
        my $found = 0;
        for my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
            if (-x File::Spec->catfile($dir, $cmd)) {
                $found = 1;
                last;
            }
        }
        unless ($found) {
            my $reason = "It's used for secure MIME type validation.";
            $app->log->fatal("Required command '$cmd' not found in PATH. Please install it. $reason");
            exit 1;
        }
    }
    $app->log->info("All required external commands are found.");

    # Check for optional command: eyeD3
    my $found_eyed3 = 0;
    for my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
        if (-x File::Spec->catfile($dir, 'eyeD3')) {
            $found_eyed3 = 1;
            last;
        }
    }
    if ($found_eyed3) {
        $SynthwavePlayer::Config::EYED3_AVAILABLE = 1;
    } else {
        $app->log->warn("Optional command 'eyeD3' not found. Lyrics fetching will rely on fallback methods. For better results, please install it (e.g., 'sudo apt install eyed3').");
        $SynthwavePlayer::Config::EYED3_AVAILABLE = 0;
    }
}

1;
