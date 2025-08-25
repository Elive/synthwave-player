# Synthwave Music Player Changelog

## v3.1 - The Guardian
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

## v3.0 - "The Refactor"
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

## v2.9 - "The Alchemist"
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

## v2.8 - "The Decoder"
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

## v2.7 - "Smooth Operator"
- 🛡️ **Path traversal protection**: Comprehensive security fixes for audio and cover art endpoints
- 🎛️ **Crossfading enhancements**: Improved crossfade behavior with instant full volume start
- ⚡ **Shuffle fix**: Correct handling of shuffle seed value 0
- 🚦 **Rate limiting**: Global and IP-based rate limiting to prevent brute force and DoS attacks
- 🎵 **MIME validation**: Whitelist application/vnd.hp-HPGL and loosen MP3 MIME type checks
- 👥 **Social features**: Add friends music icon before settings icon
- 📈 **Viral discovery**: Personal Spotify banner with localStorage persistence

## v2.6 - "The Configurator"
- ⚙️ **Settings takeover**: New gear-icon config menu (next to stop button)
- 🖱️ **Scroll magic**: Mouse wheel controls progress bar & volume
- 🔇 **Mute mutiny**: Toggleable mute with stateful speaker icon
- 📚 **Library linguistics**: "Add Music" → "Manage Music Library" (+helpful modal)

## v2.5 - "Social Butterfly"
- 🎵 **Smart sorting**: Selected playlists/genres jump to top
- ✌️ **Multi-select magic**: Combine genres (OR) and playlists (AND)
- 📢 **Share evolution**: Timestamped song links + social media refinements
- 🎨 **Neon dreams**: Cyan borders and glow shadows for all menus

## v2.4 - "Shuffle Supreme"
- 🔀 **3-state shuffle**: Off / List / Chaos modes with pink "R" icon
- ♾️ **Infinite scroll**: Server-side pagination and filtering
- 🔍 **Search party**: Server-side search with empty result handling
- 📱 **Mobile MVP**: Mini-player interface for small screens

## v2.2 - "Finder Keeper"
- 🕵️ **Fuzzy finding**: Improved multi-word search with special char support
- 📱 **Tap context**: Song menu on mini-view tap
- 🌈 **WhatsApp glam**: Gradient icons for sharing
- 🚚 **On-demand tracks**: Performance-focused loading

## v2.0 - "Mobile Majesty"
- 📲 **Micro-player**: Compact interface for phones
- 🎮 **One-hand mode**: Redesigned mobile controls
- 🌌 **Always-on cover art**: No more disappearing mobile artwork
- 🤝 **Sidebar sync**: Coordinated playlist/genre expansion

## v1.0 - "Synthwave Origins"
- 🌠 **Neon debut**: Initial synthwave-themed player
- 🎧 **Autoplay hustle**: Workarounds for browser restrictions
- 💿 **Disco inferno**: Glowing spinning disc animations
- 📱 **Mobile first**: Responsive design from day one
