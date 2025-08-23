# Synthwave Music Player Changelog

## v2.9 - "The Terminator"
🎛 **Configuration:** Introduced typed, dynamic, and saved user and server settings that reload instantly. Redesigned the interface into a “Server Settings” popup with grouped input fields and automatic creation of default settings, including logging options.

🎚 **Equalizer & Audio:** Built a complete equalizer using the Web Audio API featuring a preamp, 9 frequency bands, bass boost, and enhanced stereo effects. Users can toggle it on/off during playback, save custom presets, enjoy glowing controls, layered popup windows, and separate control sections for each effect.

🚨 **Error Handling:** Detected playback errors on the server side using HTTP headers. The client now shows clear, user-friendly alerts when files are missing or unsupported.

🐞 **Logging & Debug:** Added detailed debug and verbose logging for playlist actions, blacklist filtering, and configuration changes to help track issues and improve troubleshooting.

🔧 **Misc Fixes & Enhancements:** Renamed application and configuration files for clarity. Fixed typos, improved user interface and README, optimized URL handling, playback, playlists, fullscreen mode, and worker processes; centralized default settings and expanded options for user configuration overrides.

📂 **Music & Playlist Paths:** Added editable whitelists allowing multiple music and playlist directories with checks to ensure paths exist. Fixed playlist loading problems across all directories. Enhanced shell command escaping, encoding detection, and improved blacklist regular expressions by adding string flags and error messages.

▶ **Playback & UI:** Redesigned the playback speed control widget with configurable options, smooth animations, and saved preferences. Improved mobile autoplay bypass and error handling. Added automatic scrolling to the current song, fullscreen cover toggle, refined volume and mute controls with tooltips and layout improvements, better context menu positioning, support for multiple audio formats, and richer notifications including clickable links, timed fades, and adaptive display durations.

🛡 **Rate Limiting & Security:** Implemented detailed IP and global rate limits with connection caps displayed in HTTP headers. Added whitelisting for local and private IP addresses and improved IPv4/IPv6 validation. Server provides warnings when rate limits are reached or large libraries are used. Strengthened security by whitelisting MIME types, validating file paths to prevent traversal attacks, and sanitizing shell commands.

📊 **Rhythmbox DB Status:** Enabled live detection of Rhythmbox database and playlist updates through the server API (restricted to private IPs). The client regularly checks the status and shows popup warnings prompting users to update the database if playback errors occur.

🎨 **UI/UX Upgrades:** Made sliders, buttons, and popup windows larger with neon glow effects and smooth fade animations. Adjusted fonts and margins differently for mobile and desktop views. Added sticky headers and compact vertical spacing on mobile devices. Improved sidebar collapse buttons and separated mouse events for playlists and genres. Introduced premium menus for “Upgrade to PRO” and “Report a Bug” linking to GitHub and Patreon. Fixed accidental clicks on the main title and polished notification styles and consistent widths.


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
