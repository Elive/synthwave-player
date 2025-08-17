# Synthwave Music Player Changelog

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
