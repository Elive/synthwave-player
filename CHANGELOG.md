# Synthwave Music Player Changelog

## v3.8 - The Independent (Jan 15, 2026)
- ⚡ **Rhythmbox Independence**: The player no longer depends on the Rhythmbox database; it can now scan and manage music libraries on its own, making it a standalone music server and player.
- 📦 **Code Cleanup & Modularization**: Split Config, Lyrics, Network, Library, Search, Utils into separate modules for cleaner, maintainable code.
- 🔗 **Open Graph Meta Tags**: Added OG tags for better song link previews on social media.
- ⚡ **Async and Reactive Improvements**: Replaced blocking sleep with non-blocking timers on admin login; delayed autoplay until UI fully renders to boost responsiveness.
- 🗂️ **Song Metadata Modal**: Added context menu option to show song metadata in modal with copy-to-clipboard for file path.
- 🆔 **ID Handling Enhancements**: Shortened song IDs to 16 chars with partial ID matching in APIs for better speed and usability.
- 📈 **Library Scan Progress**: Added real-time terminal progress and more accurate, frequent web UI progress updates during scans.
- 🔍 **URL Parameter Parsing & Formatting**: New standardized delimiter (`|`) for lists.
- ⚠️ **Format Compatibility Warning**: Detect MPEG version/layer during scans; warn on MPEG 1 Layer 2 files and suggest re-encoding.

- More Changes, Improvements, and Bug Fixes:
    - 🚀 **Admin & Server Management**: Added prompt to handle running servers with continue/restart/configure options; switched systemd service to simple foreground mode for easier control.
    - 🐞 **Bug Reporting UI**: Premium users can now choose reporting core or PRO-specific issues, streamlining feedback.
    - 🖥️ **UI/UX Improvements**: Disabled global text selection to avoid accidental highlights; sidebar collapse default on mobile; fixed mobile pull-to-refresh and notification popup positioning; hide fullscreen cover when interacting with lyrics modal on mobile.
    - 🧹 **Cache Busting for Static Assets**: Added `?v=version` query parameters to CSS/JS for fresh content after updates.
    - 🔧 **Configuration Handling**: Centralized atomic config saving with safe temp file writes; moved config logic to a dedicated module; switched to JSON configs to enhance security.
    - 🎯 **Context Menu Positioning**: Fixed horizontal centering on desktop/mobile and vertical overflow clipping.
    - 📚 **Documentation & Media**: Major README overhaul with updated PRO features, reordered lists, better screenshots/video sizing, clearer descriptions, and added missing images.
    - ⏱️ **Duration Display and Sorting**: Show empty durations as blank, radio streams as infinity; fixed sorting warnings by avoiding numeric compares.
    - 🔗 **Enhanced Sharing Features**: Share URLs now pass current song IDs, support `autoplay=yes` param to auto-start playback, and encode/order parameters correctly.
    - 🎤 **Karaoke Lyrics Timing**: Limited karaoke scroll offsets to max 30 seconds for smoother sync.
    - 🎵 **Lyrics Handling Fixes**: Fixed radio song lyrics updates; parsed out “Instrumental” tags; increased HTTP timeouts; improved error handling and logging.
    - 📝 **Lyrics Module Refactor**: Isolated lyrics fetching/caching in own module; dropped exiftool, kept eyeD3; refined parsing and added debug logs for lyrics char counts.
    - 🎼 **Metadata Handling**: Improved MP3 tag reads using TIT2 frame and high-level APIs to avoid bleed; enhanced extraction of titles, artists, albums, genres, tracks, durations, and bitrate.
    - 🛠️ **Miscellaneous Fixes**: Fixed fractional track number sorting; prevented lyrics disappearing on replay; refined mobile autoplay detection; improved clipboard fallback; enhanced lyrics fetch debug output.
    - 🌐 **Network Module Refactor**: Moved network code to module; adjusted port checks to avoid binds in multi-worker setups; improved private IP and UPnP handling.
    - ⚡ **Performance Optimizations**: Reduced library chunk sizes for UI smoothness; sped up web UI load checks; removed fake loading indicators.
    - ▶️ **Playback Controls**: Fixed stop/start logic to halt previous audio cleanly; silenced abort errors; fixed context menu on currently playing songs.

## v3.6 - The Archivist (Sep 17, 2025)
- 📜 **Undocumented Features Documented**: This special release catalogues numerous features developed over time that were not previously listed in the changelog.
- ✨ **UI/UX Enhancements**:
    - **Right-Click Context Menus**: Access quick actions for songs, playlists, and genres (share, download, show cover art).
    - **Advanced Mouse Wheel Controls**: Use the mouse wheel to adjust playback rate and crossfade duration, in addition to volume and progress.
    - **Configurable Sidebars**: Customize and save which content appears in each of the two sidebars (Playlists, Genres, Artists, Albums).
    - **Welcome Tour**: Greets new users with a flying welcome message and an introductory modal highlighting key features.
    - **"Comet" Share Hint**: A visual animation guides users from the context menu to the main share button.
    - **Natural Sorting**: Lists are sorted intelligently, correctly handling numbers in names (e.g., "Playlist 2" before "Playlist 10").
    - **Intelligent "Previous" Button**: Restarts the current track if played briefly; otherwise, navigates to the actual previous song in your listening history.
    - **"Friends' Music" Links**: Add and access a list of links to your friends' music players directly from the UI.
- 🎨 **Visual Polish**:
    - **Cover Art Shine**: A glossy shine effect on cover art when hovering.
    - **Micro-animations**: Subtle jiggle/pulse effects on buttons and selected songs.
    - **Header/Footer Effects**: An animated underline for the main title and a glowing footer border during playback.
    - **Custom Lyrics View**: A retro-style lyrics display with a monospace font and custom scrollbar.
- ⚙️ **System & Configuration**:
    - **Automatic Update Checks**: The player periodically checks for new versions in the background.
    - **Real-time WebSocket Notifications**: Receive instant alerts for library updates and when lyrics are found, without needing to reload.
    - **Grouped Settings UI**: Server settings are now organized into logical groups like General, Library, and Performance for easier management.
- 🎵 **Backend & Internals**:
    - **Dependency Checker**: On startup, the server verifies that all required system dependencies (Perl modules and external commands like `file`, `eyeD3`) are present, ensuring stability and providing clear error messages on failure.
    - **Port Conflict Prevention**: The server intelligently checks if its configured port is already in use and prevents a second instance from running, avoiding conflicts.
    - **Non-Blocking Library Scan**: The music library is scanned asynchronously in chunks, allowing the server to be responsive immediately at startup, even with massive music collections.
    - **Advanced Filter Logic**: When combining filters (e.g., a playlist and a genre), the server performs a true intersection of the sets, enabling precise and powerful music discovery.
    - **Hierarchical Lyrics Engine**: The system uses a sophisticated multi-step process to find lyrics: it first checks its local cache, then performs a deep scan of the audio file's metadata (checking `eyeD3`, multiple ID3v2 tag frames, and only then searches multiple online providers as a last resort.
    - **Resilient Online Fetching**: The online lyrics search is built for robustness, with fallbacks to multiple providers, temporary blacklisting of failing services, and intelligent URL variations to maximize success.
- 🛡️ **Security**:
    - **Multi-Layer File Access Security**: Every request for an audio file is validated through a chain of security checks, including preventing path traversal, blocking malicious characters, ensuring the file is within a whitelisted directory, and verifying its MIME type to serve only legitimate audio.
- 📱 **Mobile UX Refinements**:
    - **Persistent Cover Art State**: Remembers if you've hidden the fullscreen mobile cover art.
    - **Dynamic Sidebar Visibility**: Sidebars auto-hide during search on mobile to maximize screen space.
- 🛠 **Dropdown Clipping Fix**: Removed `overflow-hidden` from main container to stop dropdowns being cut off by content area.
- 🔄 **Malformed Sort Parameter Handling**: Added server fallback to default sort if `sort` param is invalid, improving stability.
- 🎵 **Player Border Fix in Standalone Mode**: Tweaked `.footer-player` CSS to fix player borders in PWA or standalone windows.
- 📻 **Radio Playback Stability**: Reset autoplay flags and source to ensure reliable radio stream playback after reloads.
- 🎯 **Radio Stream Detection Improvement**: Server now detects radio streams by HTTP/HTTPS URLs instead of `-1` duration for accuracy.
- ⏳ **Radio Stream UI Improvements**: Show infinite duration and hide progress bars for continuous radio streams.
- 🚫 **Radio Track Duration Handling**: Hide zero/null durations for radio tracks in tracklist to avoid confusion.
- ⚙ **Server-side Query Parsing Fixes**: Updated parsing to use `~` delimiter instead of `|||` and split ratings by spaces, syncing backend with frontend.
- ↕ **Sorting Parameters Enhancement**: Added `track_number` to sortable columns and split sorting into `sort_by` and `sort_dir` params for clarity.
- 🔗 **URL Parameter Formatting Refactor**: Replaced `|||` with `~` for list params and spaces for ratings, improving URL readability and parsing.


## v3.5 - The Stabilizer (Sep 12, 2025)
- 🎵 **Auto-Scroll Fix**: Disabled auto-scroll when manually selecting songs to improve navigation control.
- 🖥️ **Browser Launch Improvements**: Dynamically size player window by screen; prefer `surf` on Debian 13+ (v2.2+), fallback to Chrome/Firefox, passing window size when supported.
- 🔗 **Embed Mode Initialization**: Detect embed mode via URL; hide sidebars, welcome messages, and adjust layout for embedded use.
- 🎨 **Embed Mode Styles**: Added CSS with transparent backgrounds and adjusted footer/tracklist for embeds.
- 📤 **Embed Player**: New embed mode supports playlist sharing; improved embed code comments with size and height options.
- 🔍 **Exact Match Search Priority**: Search highlights exact matches over fuzzy ones, preventing fuzzy overrides.
- 🌈 **Fuzzy Search Highlighting**: Mixed cyan (exact) and orange (fuzzy) highlight colors clarify search results.
- 🧠 **Improved Fuzzy Search Logic**: Better highlighting of insertions, deletions, substitutions; fallback for complex cases.
- ⚡ **Instant Cancellable Search**: Search-as-you-type with cancelable prior requests improves speed and reduces load.
- 🎤 **Karaoke Indicator Removal**: Removed imprecise karaoke line; replaced with smooth auto-scrolling for lyrics progress.
- ✋ **Lyrics Auto-Scroll Interruption**: Detect manual lyric scroll to pause auto-scroll and avoid interruptions.
- 🚫 **Lyrics Fetch Control**: Disabled online lyrics fetching if server config turns off the feature.
- 📐 **Lyrics Modal Positioning**: Fixed modal position to prevent visual clipping and enhance readability.
- 🎨 **Lyrics Progress Gradient**: Changed lyric highlight from line color to subtle vertical gradient.
- 👁️ **Lyrics Setting Visibility**: Show or hide ‘Enable Lyrics’ UI setting based on server flags.
- 🔒 **Network Security Fix**: Limit server update checks to private IP ranges to block external queries.
- 🖼️ **Open Graph Preview Image**: Updated social preview image to a current Synthwave Player screenshot.
- 🔓 **Search Length Relaxation**: Server accepts any non-empty query, removing minimum length limits.
- ⏯️ **Server Connection Prompt**: Prompt user to start server if installed but unreachable; option for auto-start on boot.
- ⚙️ **Settings Menu Fix**: Raised settings menu z-index to appear above lyrics modal for better access.
- 🔘 **Sidebar Selection Enhancement**: Alt+click selects single sidebar item exclusively, improving filtering and toggling.
- 🛠️ **Systemd Service for Server**: Added systemd user service for easy server management and auto-restart.
- 🌐 **UTF-8 Lyrics Reading**: All lyrics now read and cached in UTF-8 for proper international character support.

## v3.4 - The EvenBetter (Aug 30, 2025)
- 🎨 **Application Icons Added**: Replaced generic icons with custom ones for player and server apps, giving a cleaner look.
- 🛠️ **CI Build Enhancements**: Automated builds now produce RPM and AppImage packages, broadening distribution options.
- 🧹 **Code Cleanup**: Removed unused configs and redundant display settings to simplify the codebase.
- 🔽 **Custom Styled Select Dropdowns**: Improved select menus with custom arrows and styling for better usability.
- 🌑 **Dark Theme for Dropdowns**: Applied a uniform dark theme to all select dropdowns for visual consistency.
- 💰 **Donation Link for Non-Premium Users**: Added a clickable donation prompt in settings to support future updates.
- 🎚️ **Equalizer Presets Tuning**: Tweaked presets to cut minor bass distortion, enhancing sound quality.
- 🖼️ **Fullscreen Cover Art Toggle Fix**: Fixed toggle allowing hiding fullscreen cover art even when no song plays.
- 🔗 **Prevent Playlist Reordering on URL Load**: Fixed bug where loading a song via URL reordered playlist unnecessarily.
- 🔍 **Sidebar Search Filtering**: Added a sidebar search to dynamically filter playlists, genres, artists, and albums.

## v3.3 - The Featurer (Aug 29, 2025)
- ⚙️ **Reworked** server settings for reliability with atomic saving, auto-reloads, and an improved UI.
- 📱 **Enhanced** background playback on mobile with improved MediaSession API controls and continuous playback fixes.
- #️⃣ **Added** a toggleable track number column to the playlist.
- 💾 **Persisted** UI settings and song playback position between sessions.
- 📻 **Implemented** radio stream support with a proxy, improved error handling, and a new themed icon.
- 📂 **Added** support for multiple playlist directories and formats (M3U, M3U8).
- 🚫 **Added** blacklisting for playlists, genres, and artists.
- 🎵 **Clarified** music player origin in the UI, crediting Elive Linux.
- 🎛️ **Disabled** equalizer and crossfade on mobile devices for better performance.
- 🍏 **Added** support for displaying cover art on the iOS lock screen.
- 🔔 **Refactored** notification system to be client-side, reducing duplicate alerts.
- ⌨️  **Fixed** a debounce issue with the spacebar key for play/pause.
- ➕ Added AIFF, AAC, WMA, MKA support and Opus MIME type.
- 🎵 Added option to stop preloading audio and reset sources to fix loading hangs.
- 🎨 Animated gradient backgrounds, scanlines, pulsing headers, and flicker effects added to modals.
- 🎞️ Animation on mobile cover art only triggers on changes.
- 🎧 **Audio Playback Fixes and Features:**
- 🗂️ Centralized social platform definitions; simplified share item creation for easier extension.
- 📡 Client-side radio stream playback implemented, removing server proxy.
- 🧹 **Code Refactoring and Cleanup:**
- 🎨 Consolidated gradients; simplified song filtering and social sharing code.
- 🖼️ **Cover Art Handling Improvements:**
- ⏱️ Delayed revoking old cover art blobs to avoid file-not-found errors.
- 🚫 Disabled playback speed controls on radio streams.
- 🖥️ Enlarged sidebar widths on large screens for balanced layout.
- 🎚️ Equalizer auto-disables on radio streams with user alerts and player reloads to avoid issues.
- 📻 Fallback cover art for radio streams added.
- 🐞 Fixed cover art display bugs on mobile/desktop.
- ⬇️ Fixed download button logic to enable downloads for non-radio tracks.
- 🧩 Fixed encoding detection errors with "binary" encodings.
- 🔀 Fixed filter delimiters from commas to triple-pipe (`|||`) for accurate filtering.
- 🔍 Fixed server-side filtering to properly intersect category filters.
- 🖱️ Fixed sidebar click and scroll with dynamic lists.
- 🔓 Full support for non-SSL radio stations with CSP tweaks for insecure streams.
- 🔎 **Fuzzy Search Highlighting:**
- 🔍 Highlights search matches in title, artist, album; fuzzy matches allow 1-char typos with Levenshtein distance.
- ⚡ Improved sidebar fetch order for better performance.
- 🔢 Item counts shown next to titles, moved beside collapse arrows for clarity.
- 🎶 **Media Format Support:**
- 🛠️ **Miscellaneous Fixes:**
- 📂 Moved Alpine.js scripts to external JS file.
- 🎨 Moved embedded CSS to external stylesheets with CSS variables for easier theming.
- 📂 Multiple playlists can share names with appended counters.
- 🌟 Neon flicker animation on sidebar titles on hover for synthwave style.
- 🔶 Orange neon shadow highlights only differing chars in fuzzy matches; exact matches not highlighted to reduce clutter.
- ⚙️ **Performance & Accessibility Features:**
- 🔄 **Playlist and Library Filtering Fixes:**
- 🚫 Prevented page reloads on radio autoplay if equalizer was active; equalizer restored after.
- 📻 **Radio Stream Support:**
- ⬆️ Raised header z-index for proper settings menu display.
- 🔕 Removed unnecessary audio error console warnings.
- 🗑️ Removed unused dependencies and obsolete premium/fuzzy search UI elements.
- 🔀 Reordered sidebar options; removed parentheses from item counts for cleaner look.
- ✨ **Search Term Highlighting in Metadata:**
- 🌐 Server config now passed to client JS via global object for consistency.
- ✂️ Shortened "All Tracks" label to "All".
- 📚 **Sidebar Enhancements:**
- 🔗 Sidebar filtering supports cascading genre filters for artists/albums and filtering by selected playlists.
- ❌ Sidebar selections clear when switching types; config menu auto-closes on changes.
- 👻 Silent checks for cover art existence prevent 404 errors and console noise.
- 🔤 Smaller fonts and scrolling enabled for artist and album lists.
- 🤝 **Social Sharing Improvements:**
- 🧡 Songs loaded via URL but not in current list highlight in orange for visibility.
- 🔢 Sorted album tracks by track number when album names are identical.
- 🔍 Special search queries “radio” and “stream” list all radio entries.
- ⏳ Stream loading timeout with user notification on radio load failure.
- 🚫 Suppressed benign audio playback errors from rapid source changes or empty sources.
- ⚙️ Toggle visual effects (shadows, animations, blurs) to improve performance on low-end devices.
- 🔤 Tracklist title font size adjusts dynamically for long titles.
- 🔶 **Unlisted Active Songs Highlight:**
- 📻 Updated cover art logic to avoid fallback images for radio streams; mobile shows cover art only if available.
- 📢 Updated to version 3.3 "The Featurer" with many new features and fixes.
- 📋 Verbose logging added for radio playback and track navigation.
- 🎨 **Visual and UI Improvements:**

## v3.2 - The Conductor (Aug 27, 2025)
- 🔐 **Automatically** opens settings after initial admin password setup to simplify configuration.
- ⏳ **Fixed** crossfade logic to correctly handle zero duration when disabled.
- 🚪 **Replaced** the "Exit Admin Mode" icon with a clearer logout symbol.
- 🔀 **Clarified** the shuffle mode tooltip for better understanding.
- 📡 **Enhanced** UPnP port forwarding with configurable periodic checks.
- 🔌 **Made** server port configurable via the UI, with a watcher to ensure it remains set.

## v3.1 - The Guardian (Aug 24, 2025)
- 🔐 **Admin Mode**: Introduced a secure, local network-only admin mode for privileged settings, protected by configurable passwords, brute-force rate limiting, and debug logging.
- 🌐 **Network Security**: Added configurable private IP network detection (including Tailscale support) to control admin access; client IP is now cached and cleared on disconnect for better privacy.
- 🛡️ **Browser Hardening**: Implemented measures across login forms to prevent browsers from saving, suggesting, or auto-filling passwords, enhancing security.
- 🖥️ **User Interface**: Masked admin password fields and cleared them on focus; moved the 'Exit Admin Mode' option to the end of the settings menu for a clearer workflow.
- ⚙️ **Configuration Management**: The server now automatically watches for changes to its config file and reloads without a restart; ensured configs load reliably on startup.
- 🎉 **Viral Banner UI**: Added a new animated viral banner that appears after 15 seconds, with smooth fade effects and remembers when users dismiss it.
- 📂 **Playlist & Genre Cache Fix**: Fixed issues where playlists and genres didn’t update properly by removing overly long cache-control headers.
- 📣 **UI Notification on Config Update**: Clients now show a notification and automatically reload the page when server configuration changes.
- 🖥️ **Server Connectivity Prompt**: Improved launcher so if connecting to default server IP/port fails, it prompts users for server details with helpful hostname tips and fallback warnings.
- 📶 **IP Address Caching & Private Network Detection**: Cached results of IP privacy checks to speed up detection and improved private network logging accuracy.

## v3.0 - The Refactor (Aug 24, 2025)
- 🐛 **Application Restructuring**: Changed the organization of files by separating executable programs, templates, and desktop configuration files; moved HTML templates out of embedded Perl code to make maintenance easier.
- 📦 **Debian Packaging** & **Build System**: Made Debian packages from GitHub Actions to automatically build packages, upload build files, and create releases based on tags and changelogs.
- 🎧 **Rhythmbox Integration**: Automated updates and reloads of the Rhythmbox music library to keep it in sync smoothly.
- 🔄 **Updater Tool**: Made significant improvements to make the update process more reliable and stable.
- 💎 **Premium Mode**: Turned premium mode back on to unlock exclusive features for users.
- 💻 **Command-Line Interface**: Improved command-line help and option handling; added support for `--help`, `--foreground`, and `--debug`; now shows errors if unknown options are used.
- 🚀 **Server Startup**: On first run, the server starts in the foreground to help with debugging; after that, it runs as a background service by default; added command-line options for foreground and debug modes.
- 🖥 **Desktop Integration**: Updated player and server desktop shortcut launchers with descriptions.
- 🎶 **File Filtering**: Limited the supported audio file types to only MP3, FLAC, OGG, WAV, M4A, and OPUS formats.

- 🌐 **Network**: Improved server startup logs by showing clear URLs and hostnames; enabled local network mDNS access if the libnss-mdns package is installed.
- 🔔 **Notification System**: Moved notification duplicate filtering to the client side to fix issues with multiple workers; improved popup delay and memory cleanup; ensured error notifications are unique per song; added an API to clear stored notifications.
- 📄 **PID File Management**: Fixed the file paths where process ID (PID) files for Hypnotoad processes are stored to better manage running processes.
- 🚪 **UPnP Error Handling**: Detects when UPnP port forwarding fails; shows users a warning with a modal dialog and instructions for manually setting up ports if necessary.
- 🖼 **User Interface**: Added a user interface tip recommending Picard software for automatic music tagging and cover art downloads to help keep the music library organized.

## v2.9 - The Alchemist (Aug 22, 2025)
- 🎛️ **Audio Alchemy**: A brand new 10-band audio equalizer with preamp, bass boost, stereo controls, and savable presets to perfectly shape your sound.
- ⚙️ **Server-Side Sorcery**: Take full control with a new server settings for deep customization.
- 📂 **Smarter Library Paths**: Configure multiple music and playlist directories, with improved parsing and validation for flexible library management.
- 🛡️ **Robust Playback & Security**: Enhanced error notifications that tell you what's wrong, plus new rate-limiting and security hardening to keep things running smoothly.
- 🔄 **Rhythmbox Sync Sense**: Get automatic warnings when your Rhythmbox database is out of sync, preventing playback mysteries.
- ✨ **UI & UX Elixirs**: Polished UI with better sliders, improved mobile layout, refined neon glows, and a more intuitive playback speed widget.

<details>
<summary>FULL VERSION details</summary>

- 🎛 **Configuration**: Introduced typed, dynamic, and saved user and server settings that reload instantly. Redesigned the interface into a “Server Settings” popup with grouped input fields and automatic creation of default settings, including logging options.
- 🎚 **Equalizer & Audio**: Built a complete equalizer using the Web Audio API featuring a preamp, 9 frequency bands, bass boost, and enhanced stereo effects. Users can toggle it on/off during playback, save custom presets, enjoy glowing controls, layered popup windows, and separate control sections for each effect.
- 🚨 **Error Handling**: Detected playback errors on the server side using HTTP headers. The client now shows clear, user-friendly alerts when files are missing or unsupported.
- 🐞 **Logging & Debug**: Added detailed debug and verbose logging for playlist actions, blacklist filtering, and configuration changes to help track issues and improve troubleshooting.
- 🔧 **Misc Fixes & Enhancements**: Renamed application and configuration files for clarity. Fixed typos, improved user interface and README, optimized URL handling, playback, playlists, fullscreen mode, and worker processes; centralized default settings and expanded options for user configuration overrides.
- 📂 **Music & Playlist Paths**: Added editable whitelists allowing multiple music and playlist directories with checks to ensure paths exist. Fixed playlist loading problems across all directories. Enhanced shell command escaping, encoding detection, and improved blacklist regular expressions by adding string flags and error messages.
- ▶ **Playback & UI**: Redesigned the playback speed control widget with configurable options, smooth animations, and saved preferences. Improved mobile autoplay bypass and error handling. Added automatic scrolling to the current song, fullscreen cover toggle, refined volume and mute controls with tooltips and layout improvements, better context menu positioning, support for multiple audio formats, and richer notifications including clickable links, timed fades, and adaptive display durations.
- 🛡 **Rate Limiting & Security**: Implemented detailed IP and global rate limits with connection caps displayed in HTTP headers. Added whitelisting for local and private IP addresses and improved IPv4/IPv6 validation. Server provides warnings when rate limits are reached or large libraries are used. Strengthened security by whitelisting MIME types, validating file paths to prevent traversal attacks, and sanitizing shell commands.
- 📊 **Rhythmbox DB Status**: Enabled live detection of Rhythmbox database and playlist updates through the server API (restricted to private IPs). The client regularly checks the status and shows popup warnings prompting users to update the database if playback errors occur.
- 🎨 **UI/UX Upgrades**: Made sliders, buttons, and popup windows larger with neon glow effects and smooth fade animations. Adjusted fonts and margins differently for mobile and desktop views. Added sticky headers and compact vertical spacing on mobile devices. Improved sidebar collapse buttons and separated mouse events for playlists and genres. Introduced premium menus for “Upgrade to PRO” and “Report a Bug” linking to GitHub and Patreon. Fixed accidental clicks on the main title and polished notification styles and consistent widths.

</details>

## v2.8 - The Decoder (Aug 14, 2025)
- 🎶 **Playlist Prodigy**: Drastically improved `.pls` file parsing. The player now expertly handles various character encodings (ISO-8859-15, Windows-1252) and special characters in file paths, ensuring your curated lists load correctly.
- 🚀 **Playback Power-Up**: Take control of your tempo with a new playback speed button, featuring pitch preservation for a natural sound at any speed. Especially useful for audiobooks and automatically loaded widget for them.
- 📚 **Smarter Library Scanning**:
    - Music is now located using the XDG standard directory, with support for multiple whitelisted locations for better security and flexibility.
    - The genre list is now populated from your entire Rhythmbox library, not just from playlists, for a more complete overview.
- ✨ **UI & UX Refinements**:
    - A new progress bar appears when loading large tracklists, so you're never left guessing.
    - The crossfade configuration is now more compact and intuitive in the settings menu.
    - Added user-facing notifications for common playback errors.
- 🛠️ **Robustness Fixes**: Loosened MIME type validation to correctly handle MP3s sometimes identified as `application/octet-stream`.

## v2.7 - Smooth Operator (Aug 12, 2025)
- 🛡️ **Path traversal protection**: Comprehensive security fixes for audio and cover art endpoints
- 🎛️ **Crossfading enhancements**: Improved crossfade behavior with instant full volume start
- ⚡ **Shuffle fix**: Correct handling of shuffle seed value 0
- 🚦 **Rate limiting**: Global and IP-based rate limiting to prevent brute force and DoS attacks
- 🎵 **MIME validation**: Whitelist application/vnd.hp-HPGL and loosen MP3 MIME type checks
- 👥 **Social features**: Add friends music icon before settings icon
- 📈 **Viral discovery**: Personal Spotify banner with localStorage persistence

## v2.6 - The Configurator (Aug 11, 2025)
- ⚙️ **Settings takeover**: New gear-icon config menu (next to stop button)
- 🖱️ **Scroll magic**: Mouse wheel controls progress bar & volume
- 🔇 **Mute mutiny**: Toggleable mute with stateful speaker icon
- 📚 **Library linguistics**: "Add Music" → "Manage Music Library" (+helpful modal)

## v2.5 - Social Butterfly (Aug 11, 2025)
- 🎵 **Smart sorting**: Selected playlists/genres jump to top
- ✌️ **Multi-select magic**: Combine genres (OR) and playlists (AND)
- 📢 **Share evolution**: Timestamped song links + social media refinements
- 🎨 **Neon dreams**: Cyan borders and glow shadows for all menus

## v2.4 - Shuffle Supreme (Aug 7, 2025)
- 🔀 **3-state shuffle**: Off / List / Chaos modes with pink "R" icon
- ♾️ **Infinite scroll**: Server-side pagination and filtering
- 🔍 **Search party**: Server-side search with empty result handling
- 📱 **Mobile MVP**: Mini-player interface for small screens

## v2.2 - Finder Keeper (Aug 6, 2025)
- 🕵️ **Fuzzy finding**: Improved multi-word search with special char support
- 📱 **Tap context**: Song menu on mini-view tap
- 🌈 **WhatsApp glam**: Gradient icons for sharing
- 🚚 **On-demand tracks**: Performance-focused loading

## v2.0 - Mobile Majesty (Aug 6, 2025)
- 📲 **Micro-player**: Compact interface for phones
- 🎮 **One-hand mode**: Redesigned mobile controls
- 🌌 **Always-on cover art**: No more disappearing mobile artwork
- 🤝 **Sidebar sync**: Coordinated playlist/genre expansion

## v1.0 - Synthwave Origins (Aug 6, 2025)
- 🌠 **Neon debut**: Initial synthwave-themed player
- 🎧 **Autoplay hustle**: Workarounds for browser restrictions
- 💿 **Disco inferno**: Glowing spinning disc animations
- 📱 **Mobile first**: Responsive design from day one
