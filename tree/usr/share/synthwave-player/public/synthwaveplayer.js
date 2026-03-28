document.addEventListener('alpine:init', () => {
    Alpine.data('musicPlayer', () => ({
        // --- START MERGED DATA ---
        _lastPlaybackSaveTime: 0,
        _isReloading: false,
        resizeCounter: 0,
        shareIcons: {
            embed: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" /></svg>`,
            share: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path d="M15 8a3 3 0 10-2.977-2.63l-4.94 2.47a3 3 0 100 4.319l4.94 2.47a3 3 0 10.895-1.789l-4.94-2.47a3.027 3.027 0 000-.74l4.94-2.47C13.456 7.68 14.19 8 15 8z" /></svg>`,
            song: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 1.343-3 3s1.343 3 3 3 3-1.343 3-3V7.82l8-1.6v5.894A4.369 4.369 0 0015 12c-1.657 0-3 1.343-3 3s1.343 3 3 3 3-1.343 3-3V3z" /></svg>`,
            clock: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.414-1.414L11 9.586V6z" clip-rule="evenodd" /></svg>`,
            download: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clip-rule="evenodd" /></svg>`,
            cover: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>`,
            x: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>`,
            facebook: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M22 12c0-5.523-4.477-10-10-10S2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878V14.89h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v7.01C18.343 21.128 22 16.991 22 12z"/></svg>`,
            whatsapp: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.894 11.892-1.99 0-3.903-.52-5.587-1.455l-6.323 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.608-.916-2.206-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01s-.52.074-.792.372c-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.626.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z"/></svg>`,
            telegram: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="m9.417 15.181-.397 5.584c.568 0 .814-.244 1.109-.537l2.663-2.545 5.518 4.041c1.012.564 1.725.267 1.998-.931L22.43 3.948c.346-1.616-.559-2.251-1.583-1.816L2.859 8.283c-1.616.666-1.602 1.565-.29 1.944l5.42 1.693L18.754 5.9c.846-.533 1.617.031.95.517l-10.28 6.743z"/></svg>`,
            open: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>`,
            info: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>`,
            star: `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg>`
        },
        menuPopup: null,
        menuData: { type: null, data: null },
        showPlaylistsWarning: false,
        outOfDatePlaylists: [],
        showLyricsModal: localStorage.getItem('showLyricsModal') === 'true',
        lyricsModalContent: '',
        showMetadataModal: false,
        metadataSong: null, // Holds the original song data for display and comparison
        metadataEditForm: {}, // Holds the actively edited values from the modal form
        editingTag: { songId: null, field: null, value: '' },
        savingTag: false,
        savingMetadata: false,
        userPausedDisc: false,
        isStopping: false,
        userClosedLyricsModal: false,
        userScrolledLyrics: false,
        showAddMusicModal: false,
        showOnlineServerModal: false,
        showUpnpErrorModal: false,
        showReportBugPremiumModal: false,
        showUserSettingsModal: false,
        showUpdateModal: false,
        showInstallModal: false,
        updateInfo: null,
        showAdminLoginModal: false,
        is_pro: !!window.SWP_CONFIG.is_pro,
        is_elive: !!window.SWP_CONFIG.is_elive,
        _adminMode: !!window.SWP_CONFIG.is_admin,
        get adminMode() {
            if (this._adminMode) return true;
            if (window.SWP_CONFIG.is_admin) return true;
            return false;
        },
        set adminMode(val) { this._adminMode = val; },
        adminPassword: '',
        adminLoginError: '',
        adminLoginLoading: false,
        adminLockoutUntil: localStorage.getItem('adminLockoutUntil') || 0,
        showSetInitialPasswordModal: false,
        initialAdminPassword: '',
        initialAdminPasswordConfirm: '',
        initialPasswordError: '',
        initialPasswordLoading: false,
        userSettings: { settings: {}, values: {}, path: '', default_music_dir: '' },
        initialMusicDirectories: [],
        configLoading: false,
        originalServerPort: null,
        columnOrder: ['track_number', 'title', 'artist', 'album', 'genre', 'rating', 'bitrate', 'duration'],
        draggedColumn: null,
        dragOverColumn: null,
        isResizingColumn: false,
        get isMobileMode() {
            this.resizeCounter; // Dependency for reactivity
            return window.innerWidth < 1024;
        },
        get isMobileModeTiny() {
            this.resizeCounter; // Dependency for reactivity
            return window.innerWidth < 800;
        },
        get canListen() {
            return true;
        },
        get canEditTags() {
            if (this.adminMode) return true;
            return (window.SWP_CONFIG.is_private_network && !!window.SWP_CONFIG.allow_local_network_editing);
        },
        get canRateSongs() {
            if (this.adminMode) return true;
            return (window.SWP_CONFIG.is_private_network && !!window.SWP_CONFIG.allow_local_network_editing);
        },
        get isModalOpen() {
            return this.showAddMusicModal ||
                   this.showOnlineServerModal ||
                   this.showUpnpErrorModal ||
                   this.showReportBugPremiumModal ||
                   this.showUserSettingsModal ||
                   this.showUpdateModal ||
                   this.showAdminLoginModal ||
                   this.showSetInitialPasswordModal ||
                   this.showAutoplayModal ||
                   this.showMetadataModal;
        },
        get groupedSettings() {
            if (!this.userSettings || !this.userSettings.settings) return {};

            const sortedKeys = Object.keys(this.userSettings.values)
                .filter(key => this.userSettings.settings[key] && (this.userSettings.settings[key].type === 'scalar' || this.userSettings.settings[key].type === 'array' || this.userSettings.settings[key].type === 'boolean' || this.userSettings.settings[key].type === 'list_name_value' || this.userSettings.settings[key].type === 'list_name_password'))
                .sort((a, b) => {
                    const settingA = this.userSettings.settings[a] || {};
                    const settingB = this.userSettings.settings[b] || {};
                    const orderA = settingA.order || 99;
                    const orderB = settingB.order || 99;
                    if (orderA !== orderB) {
                        return orderA - orderB;
                    }
                    return a.localeCompare(b);
                });

            const groupOrder = ['General', 'Music Library', 'Playback', 'Accounts', 'Performance', 'Friends', 'Networking', 'Security', 'Debugging', 'Other'];
            const orderedGroups = {};

            for (const key of sortedKeys) {
                const setting = this.userSettings.settings[key];
                const groupName = setting.group || 'Other';
                if (!orderedGroups[groupName]) {
                    orderedGroups[groupName] = [];
                }
                orderedGroups[groupName].push(key);
            }

            const result = {};
            for (const groupName of groupOrder) {
                if (orderedGroups[groupName]) {
                    result[groupName] = orderedGroups[groupName];
                }
            }
            // Add any groups not in the explicit order
            for (const groupName in orderedGroups) {
                if (!result[groupName]) {
                    result[groupName] = orderedGroups[groupName];
                }
            }

            return result;
        },
        get karaokePossible() {
            // FIX: Added isFinite check to prevent errors on Radio streams (Infinite duration)
            return this.currentSong && this.currentSong.lyrics && isFinite(this.duration) && this.duration > 0 && this.lyricsLines.length > 0 && this.lyricsLineElements.length > 0 && this.isPlaying;
        },
        get shareMenuItems() {
            const items = [];
            items.push({ actionId: 'share-list', label: 'Share Actual List', icon: this.shareIcons.share, action: () => this.shareLink('list') });
            items.push({ actionId: 'share-song', label: 'Share Playing Song URL', icon: this.shareIcons.song, action: () => this.shareLink('song', this.currentSong.id), disabled: !this.currentSong });
            items.push({ actionId: 'share-song-time', label: `Share Playing Song at this Position (${this.formatTime(this.currentTime)})`, icon: this.shareIcons.clock, action: () => this.shareLink('song', this.currentSong.id, true), disabled: !this.currentSong || this.currentTime === 0 || this.currentSong.is_radio });
            items.push({ actionId: 'share-sep-1', type: 'separator' });
            items.push({ actionId: 'download', label: 'Download Song', icon: this.shareIcons.download, action: () => this.downloadSong(this.currentSong), disabled: !this.currentSong || this.currentSong.is_radio });
            items.push({ actionId: 'share-sep-2', type: 'separator' });
            items.push(...this.getSocialShareItems(this.currentSong, 'playing song'));
            return items;
        },
        get showPlaybackSpeedControl() {
            if (this.currentSong && this.currentSong.is_radio) return false;
            if (this.playbackSpeedControl === 'disabled') return false;
            if (this.playbackSpeedControl === 'enabled') return true;
            return this.duration >= this.playbackSpeedMinDuration;
        },
        startEditingTag(song, field, event) {
            if (this.savingTag) return;
            if (this.editingTag.songId === song.id && this.editingTag.field === field) return;
            if (!this.canEditTags) {
                this.showNotification("Your user has no permission to edit tags.", "warning");
                return;
            }
            if (song.is_radio) {
                this.showNotification("Cannot edit tags for radio streams.", "info");
                return;
            }

            this.editingTag = {
                songId: song.id,
                field: field,
                value: song[field] || ''
            };

            this.$nextTick(() => {
                const td = event.target.closest('td');
                const input = td ? td.querySelector('input') : null;
                if (input) {
                    input.focus();
                    if (input.type !== 'number' && input.setSelectionRange) {
                        const length = input.value.length;
                        input.setSelectionRange(length, length);
                    }
                }
            });
        },
        async saveTag() {
            if (!this.editingTag.songId || this.savingTag) return;

            // FIX: Capture editing state immediately to prevent race conditions with cancelEditingTag
            const { songId, field, value } = this.editingTag;
            
            const song = this.allSongs.find(s => s.id === songId);
            if (!song) {
                this.savingTag = false;
                return;
            }

            const originalValue = song[field] || '';

            if (value === originalValue) {
                this.cancelEditingTag();
                return;
            }

            this.savingTag = true;
            try {
                const res = await fetch(`/api/song/${songId}/update_tag`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ tag_name: field, tag_value: value })
                });
                const data = await res.json();
                if (res.ok && data.success) {
                    this.showNotification(data.message || "Tag updated.", "success");
                    // Update local state
                    song[field] = value;
                    // If it's title/artist/album, we need to clear the highlighted HTML to force re-render with new value
                    if (['title', 'artist', 'album'].includes(field)) {
                        delete song[field + '_html'];
                        delete song['highlighted_' + field];
                    }
                    this.allSongs = [...this.allSongs];
                } else {
                    this.showNotification(data.message || "Failed to update tag.", "error");
                }
            } catch (e) {
                console.error("Error saving tag:", e);
                this.showNotification("An error occurred while saving the tag.", "error");
            } finally {
                this.savingTag = false;
                this.cancelEditingTag();
            }
        },
        async setSongRating(song, rating) {
            if (!this.canRateSongs) {
                this.showNotification("Your user has no permission to rate the music.", "warning");
                return;
            }
            if (song.is_radio) {
                this.showNotification("Cannot rate radio streams.", "info");
                return;
            }

            // Find the original song in allSongs because filteredSongs uses copies
            const originalSong = this.allSongs.find(s => s.id === song.id);
            if (!originalSong) return;

            // Toggle rating: if clicking the same rating, clear it (set to 0)
            const currentRating = parseInt(originalSong.rating) || 0;
            const newRating = rating === currentRating ? 0 : rating;
            const oldRating = originalSong.rating;

            // Optimistic update for immediate UI feedback and to prevent race conditions
            originalSong.rating = newRating;
            song.rating = newRating; // Update the copy too for immediate UI feedback in the row
            this.allSongs = [...this.allSongs];

            try {
                const res = await fetch(`/api/song/${song.id}/update_tag`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ tag_name: 'rating', tag_value: newRating })
                });
                const data = await res.json();
                if (res.ok && data.success) {
                    this.showNotification(data.message || "Rating updated.", "success", null, -4000);
                } else {
                    // Revert on failure
                    originalSong.rating = oldRating;
                    song.rating = oldRating;
                    this.allSongs = [...this.allSongs];
                    this.showNotification(data.message || "Failed to update rating.", "error");
                }
            } catch (e) {
                // Revert on error
                originalSong.rating = oldRating;
                song.rating = oldRating;
                this.allSongs = [...this.allSongs];
                console.error("Error saving rating:", e);
                this.showNotification("An error occurred while saving the rating.", "error");
            }
        },
        cancelEditingTag() {
            this.editingTag = { songId: null, field: null, value: '' };
        },
        startResizing(event) {
            this.isResizingColumn = true;
            const th = event.target.parentElement;
            const startX = event.pageX;
            const startWidth = th.offsetWidth;

            const onMouseMove = (e) => {
                const newWidth = Math.max(20, startWidth + (e.pageX - startX));
                th.style.width = `${newWidth}px`;
                th.style.minWidth = `${newWidth}px`;
            };

            const onMouseUp = () => {
                this.isResizingColumn = false;
                document.removeEventListener('mousemove', onMouseMove);
                document.removeEventListener('mouseup', onMouseUp);
            };

            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        },
        startSidebarResizing(event) {
            const sidebar = this.$refs.sidebarContainer;
            const startX = event.pageX;
            const startWidth = sidebar.offsetWidth;

            const resizer = event.target;
            resizer.classList.add('resizing');

            const onMouseMove = (e) => {
                if (this.isMobileMode) return;
                const deltaX = e.pageX - startX;
                const newWidth = Math.max(150, startWidth + deltaX);

                sidebar.style.width = `${newWidth}px`;
                sidebar.style.flex = 'none';
            };

            const onMouseUp = () => {
                resizer.classList.remove('resizing');
                document.removeEventListener('mousemove', onMouseMove);
                document.removeEventListener('mouseup', onMouseUp);
            };

            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        },
        handleSongClick(index, event) {
            // If we are currently editing a tag, ignore clicks to prevent song re-initialization
            if (this.editingTag.songId !== null) return;

            const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
            const clickedSong = list[index];
            const isSameSong = this.currentSong && clickedSong && this.currentSong.id === clickedSong.id;

            // If a timer exists, this is a double-click.
            if (this.clickTimer) {
                clearTimeout(this.clickTimer);
                this.clickTimer = null;

                // If the user can edit tags, we ignore the double-click action here
                // so that the native 'dblclick' event on the table cell can trigger the inline editor
                // without restarting or pausing the song.
                if (this.canEditTags) {
                    return;
                }

                // For users without edit permissions, double-click restarts the song
                if (!isSameSong) {
                    this.playerA.pause();
                    this.playerA.src = '';
                    this.playerB.pause();
                    this.playerB.src = '';
                }
                this.userPausedDisc = false;
                this.playSong(index, true, false, event);
                return;
            }

            // Single click: wait to see if another click comes (to distinguish from double click)
            this.clickTimer = setTimeout(() => {
                this.clickTimer = null;

                // If it's the same song already playing, a single click does nothing (prevents restart)
                if (isSameSong) return;

                // For a different song, we initialize the players and start playback
                this.playerA.pause();
                this.playerA.src = '';
                this.playerB.pause();
                this.playerB.src = '';
                this.userPausedDisc = false;
                this.playSong(index, true, false, event);
            }, 250);
        },
        getContextMenuItems(type, data) {
            const items = [];
            if (type === 'song') {
                const isFullscreenVisible = (this.fullscreenCoverVisible || this.fullscreenDesktopCoverVisible) && this.fullscreenCoverSong && this.fullscreenCoverSong.id === data.id;
                if (isFullscreenVisible) {
                    items.push({ actionId: 'hide-cover', label: 'Hide Cover', icon: this.shareIcons.cover, action: () => {
                        this.fullscreenCoverVisible = false;
                        this.fullscreenDesktopCoverVisible = false;
                    }});
                } else {
                    items.push({ actionId: 'show-cover', label: 'Show Cover', icon: this.shareIcons.cover, action: () => this.showFullscreenCoverForSong(data) });
                }
                items.push({ type: 'separator' });
                items.push({ actionId: 'share-song', label: 'Share Song URL', icon: this.shareIcons.share, action: () => this.shareLink('song', data.id) });
                const isCurrentSong = this.currentSong && this.currentSong.id === data.id;
                if (isCurrentSong && this.currentTime > 0 && !data.is_radio) {
                    items.push({ actionId: 'share-song-time', label: `Share Song at this Position (${this.formatTime(this.currentTime)})`, icon: this.shareIcons.clock, action: () => this.shareLink('song', data.id, true) });
                }
                items.push({ type: 'separator' });
                items.push({ actionId: 'download', label: 'Download Song', icon: this.shareIcons.download, action: () => this.downloadSong(data), disabled: data.is_radio });
                items.push({ type: 'separator' });
                items.push({ actionId: 'metadata', label: this.canEditTags ? 'Edit Metatags' : 'Show Metatags', icon: this.shareIcons.info, action: () => this.showSongMetadata(data) });
                items.push({ type: 'separator' });
                items.push(...this.getSocialShareItems(data));
            } else if (type === 'playlist' || type === 'genre' || type === 'library') {
                items.push({ actionId: 'share-list', label: 'Share this list', icon: this.shareIcons.share, action: (event) => this.pointToShareButton(event) });
                items.push({ actionId: 'open-tab', label: 'Open in new Tab', icon: this.shareIcons.open, action: () => this.openInNewTab(type === 'library' ? 'library' : (type === 'playlist' ? 'playlists' : 'genres'), data) });
            }
            return items;
        },
        notifications: [],
        notificationTimestamps: {},
        clickTimer: null,
        showShareHint: false,
        preloadingSongId: null,
        viewLoading: false,
        hideCoverForGenreInteraction: false,
        sidebarStates: [
            { collapsed: false, expanded: false, collapseTimer: null, search: '', searchVisible: false },
            { collapsed: false, expanded: false, collapseTimer: null, search: '', searchVisible: false }
        ],
        showAutoplayModal: false,
        audioUnlocked: false,
        autoplayStartTime: 0,
        coverArtSong: null,
        fullscreenCoverSong: null,
        discVisible: false,
        discGlowInterval: null,
        discGlows: [
            '0 0 25px 3px rgba(0, 0, 0, 0.0)',
            '0 0 25px 3px rgba(0, 217, 255, 0.6)',
            '0 0 25px 3px rgba(255, 0, 222, 0.5)',
            '0 0 25px 3px rgba(255, 255, 0, 0.5)',
            '0 0 25px 3px rgba(255, 25, 25, 0.6)',
            '0 0 25px 3px rgba(50, 205, 50, 0.6)',
            '0 0 25px 3px rgba(255, 165, 0, 0.6)',
        ],
        discGlowIndex: 0,
        showCoverImage: false,
        fullscreenCoverVisible: false,
        fullscreenDesktopCoverVisible: false,
        allSongs: [],
        playlists: {},
        playlistInfo: {},
        genres: [],
        artists: [],
        albums: [],
        currentSong: null,
        currentPlaylist: [],
        currentSongIndex: -1,
        selectedIndex: -1,
        isPlaying: false,
        currentTime: 0,
        duration: 0,
        volume: 1.0,
        showVolumeTooltip: false,
        muted: false,
        previousVolume: 0.75,
        progressPercent: 0,
        loading: true,
        loadingMessage: '',
        loadingProgress: 0,
        search: '',
        ratingFilter: [],
        sortCol: window.SWP_CONFIG.default_sort_by,
        sortDir: window.SWP_CONFIG.default_sort_order,
        selectedPlaylists: [],
        selectedGenres: [],
        selectedArtists: [],
        selectedAlbums: [],
        sidebar1: localStorage.getItem('sidebar1') || 'genre',
        sidebar2: localStorage.getItem('sidebar2') || 'playlist',
        shuffle: localStorage.getItem('shuffle') || 'off', // 'off', 'list', 'random'
        shuffleSeed: null,
        repeat: localStorage.getItem('repeat') || 'off',
        displayLimit: window.innerWidth < 1024 ? window.SWP_CONFIG.initial_songs_to_load_mobile : window.SWP_CONFIG.initial_songs_to_load_desktop,
        displayIncrement: this.isMobileMode ? window.SWP_CONFIG.songs_to_load_on_scroll_mobile : window.SWP_CONFIG.songs_to_load_on_scroll_desktop,
        sidebarsHiddenOnMobileSearch: false,
        isWindowFocused: true,
        blurTimeoutId: null,
        songsWithNoCover: new Set(),
        viralBannerVisible: false,
        hideViralBanner: localStorage.getItem('hideViralBanner') === 'true',
        playHistory: [],
        stopTimeout: null,
        isInitializing: true,
        isAttemptingAutoplay: false,
        isMobileDevice: false,
        isStandalone: window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone || false,
        mobilePlayerExpanded: localStorage.getItem('mobilePlayerExpanded') === 'true',
        _hasAutoExpandedHero: false,
        touchStartY: 0,
        holdTimer: null,
        holdInterval: null,
        _lastHoldEnd: 0,
        appVersion: window.SWP_CONFIG.app_version.replace(/^v/, ''),
        startupTime: Date.now(),
        userHidMobileCover: false,
        lastSongRequestTime: null,
        streamLoadTimeout: null,
        networkSpeed: localStorage.getItem('networkSpeed') ? parseFloat(localStorage.getItem('networkSpeed')) : 5, // Default to a reasonable speed
        _speedMeasureStart: null,
        lyricsAbortController: null,
        searchAbortController: null,
        lyricsCache: {},
        lyricsFetching: {},
        lyricsAnimationId: null,
        ws: null,
        wsPingInterval: null,
        currentArtworkBlobUrl: null,
        lastToggleTime: 0,
        toggleDebounceMs: 200,
        urlLoadedSongId: null,
        lyricsLines: [],
        lyricsLineElements: [],
        totalLyricsWords: 0,
        lyricsLineWordData: [],
        _lastQuantizedScrollTop: null,
        _scrollAnimationTarget: null,
        _scrollAnimationSource: null,
        _scrollAnimationStartTime: 0,
        // On-demand loading properties
        displayedSongCount: 0,
        libraryPageToLoad: 1,
        isLoadingMoreSongs: false,
        activePlayerRef: 'A',
        playerA: null,
        playerB: null,
        playbackRate: 1.0,
        playbackRates: [1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 0.8],
        playbackSpeedControl: 'auto',
        playbackSpeedMinDuration: window.SWP_CONFIG.show_playback_speed_min_minutes * 60,
        enableCoverArt: window.SWP_CONFIG.enable_cover_art,
        enableVisualEffects: true,
        enableLyrics: true,
        enableTrackNumber: false,
        enableBitrate: false,
        enableRatingColumn: true,
        sidebarOrLogic: localStorage.getItem('sidebarOrLogic') === 'true',
        uiScale: parseFloat(localStorage.getItem('uiScale')) || 1.0,
        lyricsScale: parseFloat(localStorage.getItem('lyricsScale')) || 1.0,
        browserNeedsAudioFix: false,
        // --- END MERGED DATA ---

        _naturalSort(a, b) {
            // Push radio items to the bottom
            if (a.is_radio && !b.is_radio) return 1;
            if (!a.is_radio && b.is_radio) return -1;

            const ax = [], bx = [];

            const normalize = (s) => {
                return String(s)
                    .normalize("NFD")
                    .replace(/[\u0300-\u036f]/g, "")
                    .replace(/^[^a-zA-Z0-9]+/, '')
                    .replace(/[^a-zA-Z0-9\s]/g, ' ')
                    .trim();
            };

            const strA = normalize(a.title || a);
            const strB = normalize(b.title || b);

            strA.replace(/(\d+)|(\D+)/g, (_, $1, $2) => { ax.push([$1 || Infinity, $2 || ""]) });
            strB.replace(/(\d+)|(\D+)/g, (_, $1, $2) => { bx.push([$1 || Infinity, $2 || ""]) });

            while(ax.length && bx.length) {
                const an = ax.shift();
                const bn = bx.shift();
                const nn = (an[0] - bn[0]) || an[1].localeCompare(bn[1], undefined, { sensitivity: 'base' });
                if(nn) return nn;
            }

            return ax.length - bx.length;
        },

        getPrettyUrl(urlObj) {
            return urlObj.toString().replace(/%7C/g, '|');
        },

        _loadJSONFromStorage(key, property = key) {
            const savedValue = localStorage.getItem(key);
            if (savedValue !== null) {
                try {
                    this[property] = JSON.parse(savedValue);
                } catch (e) {
                    console.error(`Could not parse saved ${property} from localStorage`, e);
                }
            }
        },

        getColumnLabel(colId) {
            const labels = {
                track_number: '#',
                title: 'Title',
                artist: 'Artist',
                album: 'Album',
                genre: 'Genre',
                rating: 'Rating',
                bitrate: 'kbps',
                duration: ''
            };
            return labels[colId];
        },

        handleColumnDragStart(event, colId) {
            this.draggedColumn = colId;
            event.dataTransfer.effectAllowed = 'move';
            event.dataTransfer.setData('text/plain', colId);
            setTimeout(() => {
                if (event.target && event.target.classList) {
                    event.target.classList.add('column-dragging');
                }
            }, 0);
        },

        handleColumnDragOver(event, colId) {
            event.preventDefault();
            event.dataTransfer.dropEffect = 'move';
            if (this.draggedColumn && this.draggedColumn !== colId) {
                this.dragOverColumn = colId;
            }
        },

        handleColumnDragLeave(event, colId) {
            if (this.dragOverColumn === colId) {
                this.dragOverColumn = null;
            }
        },

        handleColumnDragEnd(event) {
            if (event.target && event.target.classList) {
                event.target.classList.remove('column-dragging');
            }
            this.draggedColumn = null;
            this.dragOverColumn = null;
        },

        handleColumnDrop(event, targetColId) {
            event.preventDefault();
            this.dragOverColumn = null;
            if (!this.draggedColumn || this.draggedColumn === targetColId) return;

            const fromIndex = this.columnOrder.indexOf(this.draggedColumn);
            const toIndex = this.columnOrder.indexOf(targetColId);

            const newOrder = [...this.columnOrder];
            newOrder.splice(fromIndex, 1);
            newOrder.splice(toIndex, 0, this.draggedColumn);

            this.columnOrder = newOrder;
            localStorage.setItem('columnOrder', JSON.stringify(this.columnOrder));
            this.draggedColumn = null;
        },

        isColumnVisible(colId) {
            if (colId === 'track_number') return this.enableTrackNumber;
            if (colId === 'rating') return this.enableRatingColumn;
            if (colId === 'bitrate') return this.enableBitrate;
            return true;
        },

        isSettingVisible(varName) {
            if (!this.userSettings || !this.userSettings.values) return true; // Default to visible if settings not loaded
            if (varName === 'SERVER_PORT' || varName === 'UPNP_CHECK_INTERVAL_HOURS') {
                return !!this.userSettings.values.ENABLE_UPNP;
            }
            return true;
        },

        _getSettingInputType(varName) {
            const setting = this.userSettings.settings[varName];
            if (setting && setting.type === 'boolean') return 'boolean';
            if (setting && setting.type === 'list_name_value') return 'listNameValue';
            if (setting && setting.type === 'list_name_password') return 'listNamePassword';
            if (varName === 'DEFAULT_SORT_BY') return 'sortBy';
            if (varName === 'DEFAULT_SORT_ORDER') return 'sortOrder';
            if (varName === 'ADMIN_PASSWORD') return 'password';
            if (this.userSettings.values[varName] !== null && typeof this.userSettings.values[varName] === 'number') return 'number';
            if (typeof this.userSettings.values[varName] === 'string') return 'text';
            return 'unknown';
        },

        getSocialShareItems(song, context = 'song') {
            const platforms = [
                { id: 'x', name: 'X' },
                { id: 'facebook', name: 'Facebook' },
                { id: 'whatsapp', name: 'WhatsApp' },
                { id: 'telegram', name: 'Telegram' },
            ];
            const labelPrefix = context === 'playing song' ? 'Share playing song on' : 'Share song on';
            return platforms.map(p => ({
                actionId: `social-${p.id}-${context}`,
                label: `${labelPrefix} ${p.name}`,
                icon: this.shareIcons[p.id],
                action: () => this.shareOn(p.id, song),
                disabled: !song
            }));
        },

        getActivePlayer() {
            return this.activePlayerRef === 'A' ? this.playerA : this.playerB;
        },
        formatBalance(value) {
            if (value == 0) return 'Center';
            if (value > 0) return `R ${Math.abs(value)}`;
            return `L ${Math.abs(value)}`;
        },
        updateMarquees(reset = false) {
            const containers = document.querySelectorAll('.marquee-container');
            containers.forEach(container => {
                const content = container.querySelector('.marquee-content');
                if (!content) return;
                
                // Reset state
                container.classList.remove('animate-marquee');
                container.style.justifyContent = 'center';
                
                if (reset || !this.isWindowFocused) {
                    // Force a reflow to reset the animation position
                    void container.offsetWidth;
                    return;
                }

                // Check if content overflows container
                if (content.offsetWidth > container.offsetWidth) {
                    container.style.justifyContent = 'flex-start';
                    container.classList.add('animate-marquee');
                }
            });
        },
        sliderGlowTimers: new WeakMap(),
        handleSliderGlow(event, color) {
            const slider = event.target;
            if (!slider) return;

            if (this.sliderGlowTimers.has(slider)) {
                clearTimeout(this.sliderGlowTimers.get(slider));
            }

            slider.classList.add(`glowing-${color}`);

            const timer = setTimeout(() => {
                slider.classList.remove(`glowing-${color}`);
                this.sliderGlowTimers.delete(slider);
            }, 500); // Duration before fade-out starts
            this.sliderGlowTimers.set(slider, timer);
        },
        getInactivePlayer() {
            return this.activePlayerRef === 'A' ? this.playerB : this.playerA;
        },

        _cancelPendingFetches() {
            if (this.streamLoadTimeout) {
                clearTimeout(this.streamLoadTimeout);
                this.streamLoadTimeout = null;
            }
            if (this.lyricsAbortController) {
                this.lyricsAbortController.abort();
                this.lyricsAbortController = null;
            }
        },

        // Computed Properties
        get songsToDisplay() {
            // Always use filteredSongs which properly creates highlighted properties
            // and handles all shuffle modes correctly
            return this.filteredSongs.filter(song => song).slice(0, this.displayLimit);
        },
        get sortedPlaylists() {
            const playlistNames = Object.keys(this.playlists);
            playlistNames.sort((a, b) => {
                const aSelected = this.selectedPlaylists.includes(a);
                const bSelected = this.selectedPlaylists.includes(b);
                if (aSelected !== bSelected) {
                    return aSelected ? -1 : 1;
                }
                return this._naturalSort(a, b);
            });
            const sortedObject = {};
            playlistNames.forEach(name => {
                sortedObject[name] = this.playlists[name];
            });
            return sortedObject;
        },
        get sortedGenres() {
            return [...this.genres].sort((a, b) => {
                const aSelected = this.selectedGenres.includes(a);
                const bSelected = this.selectedGenres.includes(b);
                if (aSelected !== bSelected) {
                    return aSelected ? -1 : 1;
                }
                return this._naturalSort(a, b);
            });
        },
        get sortedArtists() {
            return [...this.artists].sort((a, b) => {
                const aSelected = this.selectedArtists.includes(a);
                const bSelected = this.selectedArtists.includes(b);
                if (aSelected !== bSelected) {
                    return aSelected ? -1 : 1;
                }
                return this._naturalSort(a, b);
            });
        },
        get sortedAlbums() {
            return [...this.albums].sort((a, b) => {
                const aSelected = this.selectedAlbums.includes(a);
                const bSelected = this.selectedAlbums.includes(b);
                if (aSelected !== bSelected) {
                    return aSelected ? -1 : 1;
                }
                return this._naturalSort(a, b);
            });
        },
        get viewTitle() {
            let parts = [];
            if (this.selectedPlaylists.length > 0) {
                parts.push('Playlists: <span class="text-gray-300">' + this.selectedPlaylists.join(', ') + '</span>');
            }
            if (this.selectedGenres.length > 0) {
                parts.push('Genres: <span class="text-gray-300">' + this.selectedGenres.join(', ') + '</span>');
            }
            if (this.selectedArtists.length > 0) {
                parts.push('Artists: <span class="text-gray-300">' + this.selectedArtists.join(', ') + '</span>');
            }
            if (this.selectedAlbums.length > 0) {
                parts.push('Albums: <span class="text-gray-300">' + this.selectedAlbums.join(', ') + '</span>');
            }
            if (parts.length === 0) {
                return 'All Tracks';
            }
            const separator = this.sidebarOrLogic ? ' <span class="text-fuchsia-500/50 italic">or</span> ' : ' &amp; ';
            return parts.join(separator);
        },
        get viewTitleClasses() {
            const plainText = this.viewTitle.replace(/<[^>]*>?/gm, '');
            if (plainText.length > 200) {
                return 'text-[0.7rem] md:text-[0.9rem]';
            }
            return 'text-sm md:text-2xl';
        },
        get filteredSongs() {
            const songsToList = this.allSongs;
            return songsToList.map(song => {
                if (!song) return null;
                const newSong = { ...song };
                newSong.highlighted_title = song.title_html || this.highlight(newSong, 'title');
                newSong.highlighted_artist = song.artist_html || this.highlight(newSong, 'artist');
                newSong.highlighted_album = song.album_html || this.highlight(newSong, 'album');
                if (newSong.year && typeof newSong.year === 'string') {
                    newSong.year = newSong.year.substring(0, 4);
                }
                return newSong;
            });
        },

        // Methods
        logAction(message) {
            fetch('/api/log', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message })
            }).catch(() => {});
        },
        updateSongStats(id, type) {
            fetch(`/api/song/${id}/stats`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ type })
            }).catch(() => {});
        },
        showNotification(message, type = 'info', url = null, extraTime = 0, originalMessage = null) {
            // Prevent duplicates if a notification with the exact same message is already visible.
            if (this.notifications.some(n => n.message === message && n.visible)) {
                return;
            }

            const now = Date.now();
            const cooldownMs = 1000; // 1 second cooldown to prevent spam

            // Clean up old timestamps to prevent memory leak.
            for (const msg in this.notificationTimestamps) {
                // Clean up timestamps older than a minute to prevent the object from growing indefinitely.
                if (now - this.notificationTimestamps[msg] > 60000) {
                    delete this.notificationTimestamps[msg];
                }
            }

            // If a timestamp for this message still exists and is within the cooldown period, ignore it.
            if (this.notificationTimestamps[message] && (now - this.notificationTimestamps[message] < cooldownMs)) {
                return;
            }

            this.notificationTimestamps[message] = now;

            const id = Date.now() + Math.random();
            this.notifications.push({ id, message, type, url, visible: true, originalMessage: originalMessage || message });

            const wordCount = message.split(/\s+/).length;
            const minDuration = window.SWP_CONFIG.notification_visible_ms;

            // Average reading speed is ~200-250 wpm.
            // 200 wpm = 3.33 wps -> 300ms/word.
            // Let's use 250ms/word + a base time.
            let duration = 2000 + (wordCount * 250); // Base 2s + 250ms/word

            // Ensure it's not shorter than the configured minimum.
            duration = Math.max(duration, minDuration);

            if (url) {
                duration += 3000; // Add 3 seconds to decide and click the link.
            }

            if (type === 'warning') {
                duration += 3000;
            } else if (type === 'error') {
                duration += 12000;
            }

            // Add extra time if provided
            duration += extraTime;

            setTimeout(() => { this.removeNotification(id); }, duration);
        },
        async _hashPassword(password) {
            const msgUint8 = new TextEncoder().encode(password);
            const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
            const hashArray = Array.from(new Uint8Array(hashBuffer));
            return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        },
        removeNotification(id) {
            const index = this.notifications.findIndex(n => n.id === id);
            if (index > -1) {
                const notification = this.notifications[index];
                notification.visible = false;

                // Also remove from client-side deduplication cache to allow it to be shown again sooner.
                delete this.notificationTimestamps[notification.message];

                setTimeout(() => {
                    this.notifications = this.notifications.filter(n => n.id !== id);
                }, 300);
            }
        },
        async setInitialAdminPassword() {
            this.initialPasswordError = '';
            if (this.initialAdminPassword !== this.initialAdminPasswordConfirm) {
                this.initialPasswordError = 'Passwords do not match.';
                return;
            }
            if (this.initialAdminPassword.length < 4) {
                this.initialPasswordError = 'Password must be at least 4 characters.';
                return;
            }
            this.initialPasswordLoading = true;
            try {
                const hashedPassword = await this._hashPassword(this.initialAdminPassword);
                const res = await fetch('/api/admin/set-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password: hashedPassword })
                });
                const data = await res.json();
                if (res.ok && data.success) {
                    this.showNotification(data.message || 'Password set successfully.', 'success');
                    this.showSetInitialPasswordModal = false;
                    // Update local config to reflect that a password is now set
                    window.SWP_CONFIG.admin_password_is_set = 1;
                    this.adminMode = false; // Ensure they have to login now
                    // Keep loading state briefly to allow server-side suppression to settle
                    setTimeout(() => { this.initialPasswordLoading = false; }, 3000);
                } else {
                    this.initialPasswordError = data.message || 'Failed to set password.';
                    this.initialPasswordLoading = false;
                }
            } catch (e) {
                if (e instanceof TypeError && e.message.includes('digest')) {
                    this.initialPasswordError = 'Security Error: Browser blocked encryption. Use HTTPS, or login via http://127.0.0.1 (localhost).';
                } else {
                    this.initialPasswordError = 'An error occurred.';
                }
                console.error('Set password error:', e);
                this.initialPasswordLoading = false;
            }
        },
        async loginAdmin() {
            this.adminLoginError = '';
            this.adminLoginLoading = true;
            try {
                const hashedPassword = await this._hashPassword(this.adminPassword);
                const res = await fetch('/api/admin/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password: hashedPassword })
                });
                const data = await res.json();
                if (res.ok && data.success) {
                    this.adminMode = true;
                    window.SWP_CONFIG.is_admin = true;
                    this.showAdminLoginModal = false;
                    this.adminPassword = '';
                    this.adminLockoutUntil = 0;
                    localStorage.removeItem('adminLockoutUntil');
                    this.showNotification('Admin mode enabled.', 'success', null, -4000);
                    this.openUserSettingsModal();
                } else {
                    this.adminLoginError = data.message || 'Login failed.';
                    if (data.lockout_until) {
                        this.adminLockoutUntil = data.lockout_until;
                        localStorage.setItem('adminLockoutUntil', data.lockout_until);
                        this.showAdminLoginModal = false;
                    }
                }
            } catch (e) {
                if (e instanceof TypeError && e.message.includes('digest')) {
                    this.adminLoginError = 'Security Error: Browser blocked encryption. Use HTTPS, or login via http://127.0.0.1 (localhost).';
                } else {
                    this.adminLoginError = 'An error occurred during login.';
                }
                console.error('Login error:', e);
            } finally {
                this.adminLoginLoading = false;
            }
        },
        async logoutAdmin() {
            try {
                const res = await fetch('/api/admin/logout', { method: 'POST' });
                if (res.ok) {
                    this.adminMode = false;
                    if (window.SWP_CONFIG) {
                        window.SWP_CONFIG.is_admin = false;
                    }
                    // Clear any potential local storage flags if they existed
                    localStorage.removeItem('adminMode');

                    this.showNotification('Exited Admin Mode.', 'info', null, -4000);
                    this.closeMenu('config');
                    // Reload is essential to clear the server-side session state from the browser's perspective
                    window.location.reload();
                }
            } catch (e) {
                console.error('Logout error:', e);
            }
        },
        pointToShareButton(event) {
            const shareButton = this.$refs.shareButtonContainer;
            if (!shareButton || !event) return;

            const startX = event.clientX;
            const startY = event.clientY;

            const comet = document.createElement('div');
            comet.style.position = 'fixed';
            comet.style.left = `${startX}px`;
            comet.style.top = `${startY}px`;
            comet.style.width = '24px';
            comet.style.height = '24px';
            comet.style.borderRadius = '50%';
            comet.style.background = 'radial-gradient(circle, #ff00de 30%, rgba(255, 0, 222, 0.4) 60%, rgba(255, 0, 222, 0) 80%)';
            comet.style.zIndex = '10001'; // above context menu
            comet.style.transition = 'all 0.7s cubic-bezier(0.5, 0, 0.75, 0)';
            comet.style.transform = 'translate(-50%, -50%)'; // Center on cursor
            document.body.appendChild(comet);

            const targetRect = shareButton.getBoundingClientRect();
            const endX = targetRect.left + targetRect.width / 2;
            const endY = targetRect.top + targetRect.height / 2;

            requestAnimationFrame(() => {
                comet.style.left = `${endX}px`;
                comet.style.top = `${endY}px`;
                comet.style.transform = 'translate(-50%, -50%) scale(0.5)';
                comet.style.opacity = '0';
            });

            setTimeout(() => {
                if (document.body.contains(comet)) {
                    document.body.removeChild(comet);
                }

                shareButton.scrollIntoView({ behavior: 'auto', block: 'center' });

                shareButton.classList.add('temporary-glow');
                this.showShareHint = true;

                setTimeout(() => {
                    shareButton.classList.remove('temporary-glow');
                    this.showShareHint = false;
                }, 5000);
            }, 700);
        },
        toggleRatingFilter(rating) {
            const index = this.ratingFilter.indexOf(rating);
            if (index > -1) {
                this.ratingFilter.splice(index, 1);
            } else {
                this.ratingFilter.push(rating);
            }
            // Ensure we trigger reactivity and URL update
            this.ratingFilter = [...this.ratingFilter];
        },
        async clearSelectionsForSidebar(sidebarType) {
            if (sidebarType === 'playlist' && this.selectedPlaylists.length > 0) {
                await this.clearPlaylists();
            } else if (sidebarType === 'genre' && this.selectedGenres.length > 0) {
                await this.clearGenres();
            } else if (sidebarType === 'artist' && this.selectedArtists.length > 0) {
                await this.clearArtists();
            } else if (sidebarType === 'album' && this.selectedAlbums.length > 0) {
                await this.clearAlbums();
            }
        },
        async _fetchSidebarOnDemand(value) {
            // Fetch artists/albums on demand
            if (value === 'artist' && this.artists.length === 0) {
                try { this.artists = Alpine.raw(await(await fetch('/api/artists')).json()); } catch(e) { console.error('Failed to load artists', e); }
            }
            if (value === 'album' && this.albums.length === 0) {
                try { this.albums = Alpine.raw(await(await fetch('/api/albums')).json()); } catch(e) { console.error('Failed to load albums', e); }
            }
        },
        initServerMonitoring() {
            let isOffline = false;
            if (this._serverMonitorTimeout) clearTimeout(this._serverMonitorTimeout);

            const checkServer = () => {
                fetch(window.location.origin + '/api/version', { cache: 'no-store' })
                    .then(r => r.json())
                    .then(data => {
                        const localHash = window.SWP_CONFIG.source_hash;
                        if (data.source_hash && localHash && data.source_hash !== localHash) {
                            if (!this._isReloading) {
                                this._isReloading = true;
                                console.log(`Version mismatch (polling)! Server: ${data.source_hash}, Local: ${localHash}`);
                                this.showNotification("A new server version is available. Reloading to update...", "warning", null, 10000);
                                setTimeout(() => {
                                    window.location.reload(true);
                                }, 3000);
                            }
                            return;
                        }

                        if (isOffline) {
                            isOffline = false;
                            this.showNotification("Server connection restored.", "success");
                        }
                        this._serverMonitorTimeout = setTimeout(checkServer, 30000);
                    })
                    .catch(() => {
                        if (!isOffline) {
                            isOffline = true;
                        }
                        this.showNotification("Server is offline. Attempting to reconnect...", "error", null, 5000);
                        this._serverMonitorTimeout = setTimeout(checkServer, 5000);
                    });
            };

            this._serverMonitorTimeout = setTimeout(checkServer, 10000);
        },
        init() {
            // If no admin password is set, prioritize showing that modal immediately
            if (window.SWP_CONFIG.showSetInitialPasswordModal) {
                this.showSetInitialPasswordModal = true;
            }

            this.initServerMonitoring();

            // Detect browsers that need the EQ enabled to avoid glitchy audio (surf/elsurf < 2.3)
            const ua = navigator.userAgent;
            const isSurf = ua.includes('Surf/');
            const isElsurf = ua.includes('Elsurf/');
            let isOldElsurf = false;
            if (isElsurf) {
                const match = ua.match(/Elsurf\/(\d+\.\d+)/);
                if (match && parseFloat(match[1]) < 2.3) {
                    isOldElsurf = true;
                }
            }
            const isUnknown = !ua || ua.length < 10;
            this.browserNeedsAudioFix = isSurf || isOldElsurf || isUnknown;
            this.menuPopup = new SWPMenu();
            this.menuPopup.setVisualEffects(this.enableVisualEffects);
            this.$watch('enableVisualEffects', val => this.menuPopup.setVisualEffects(val));

            // Ensure friends data is available for the menu template
            window.SWP_FRIENDS = window.SWP_FRIENDS || [];

            const isTouch = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0);
            this.isMobileDevice = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || (isTouch && this.isMobileModeTiny);

            // Update sidebar collapse state based on mobile detection
            if (this.isMobileDevice) {
                this.sidebarStates[0].collapsed = false;
                this.sidebarStates[1].collapsed = false;
            }

            // Prevent pull-to-refresh gesture on mobile devices.
            document.body.style.overscrollBehaviorY = 'contain';

            this.showSetInitialPasswordModal = window.SWP_CONFIG.showSetInitialPasswordModal;
            this.playerA = this.$refs.playerA;
            this.playerB = this.$refs.playerB;
            
            // Small delay to ensure session cookies are processed by the browser
            setTimeout(() => this.initWebSocket(), 500);

            // Ensure displayLimit matches the detected mode on startup
            this.displayLimit = this.isMobileMode ? window.SWP_CONFIG.initial_songs_to_load_mobile : window.SWP_CONFIG.initial_songs_to_load_desktop;

            this.$watch('sidebar1', async (value, oldValue) => {
                localStorage.setItem('sidebar1', value);
                if (oldValue && oldValue !== 'none' && oldValue !== value && oldValue !== this.sidebar2) {
                    await this.clearSelectionsForSidebar(oldValue);
                }
                // Fetch artists/albums on demand
                await this._fetchSidebarOnDemand(value);
                if (value !== 'none' && value === this.sidebar2) this.sidebar2 = 'none';
                this.closeMenu('config');
            });
            this.$watch('sidebar2', async (value, oldValue) => {
                localStorage.setItem('sidebar2', value);
                if (oldValue && oldValue !== 'none' && oldValue !== value && oldValue !== this.sidebar1) {
                    await this.clearSelectionsForSidebar(oldValue);
                }
                // Fetch artists/albums on demand
                await this._fetchSidebarOnDemand(value);
                if (value !== 'none' && value === this.sidebar1) this.sidebar1 = 'none';
                this.closeMenu('config');
            });

            // Load settings from localStorage
            this._loadJSONFromStorage('uiScale');
            this._loadJSONFromStorage('lyricsScale');
            this._loadJSONFromStorage('enableTrackNumber');
            this._loadJSONFromStorage('enableBitrate');
            this._loadJSONFromStorage('enableRatingColumn');
            this._loadJSONFromStorage('sidebarOrLogic');
            this._loadJSONFromStorage('enableVisualEffects');
            this._loadJSONFromStorage('columnOrder');
            this._loadJSONFromStorage('enableLyrics');

            const savedEnableVisualEffects = localStorage.getItem('enableVisualEffects');
            if (savedEnableVisualEffects !== null) {
                this.enableVisualEffects = JSON.parse(savedEnableVisualEffects);
            } else {
                const supportsBlur = CSS.supports('backdrop-filter', 'blur(1px)') || CSS.supports('-webkit-backdrop-filter', 'blur(1px)');
                this.enableVisualEffects = supportsBlur;
                if (!supportsBlur) {
                    this.showNotification("Your browser appears to not support blur effects, so they have been disabled for better performance.", 'info', null, 10000);
                }
            }

            const savedPlaybackSpeedControl = localStorage.getItem('playbackSpeedControl');
            if (savedPlaybackSpeedControl !== null) this.playbackSpeedControl = savedPlaybackSpeedControl;

            this.showUpnpErrorModal = window.SWP_CONFIG.showUpnpErrorModal;

            if ('mediaSession' in navigator) {
                const actions = {
                    'play': () => {
                        if (this.currentSong) {
                            this.togglePlay();
                        }
                    },
                    'pause': () => {
                        if (this.currentSong) {
                            this.togglePlay();
                        }
                    },
                    'previoustrack': () => {
                        this.playPrev();
                    },
                    'nexttrack': () => {
                        this.playNext();
                    },
                    'stop': () => {
                        this.stopSong();
                    },
                    'seekbackward': (details) => {
                        const audio = this.getActivePlayer();
                        if (!audio) {
                            return;
                        }
                        const skipTime = details.seekOffset || 10;
                        audio.currentTime = Math.max(audio.currentTime - skipTime, 0);
                        this.updateProgress();
                    },
                    'seekforward': (details) => {
                        const audio = this.getActivePlayer();
                        if (!audio) {
                            return;
                        }
                        const skipTime = details.seekOffset || 10;
                        audio.currentTime = Math.min(audio.currentTime + skipTime, this.duration);
                        this.updateProgress();
                    },
                    'seekto': (details) => {
                        if (details.seekTime !== null && details.seekTime !== undefined) {
                            const audio = this.getActivePlayer();
                            if (!audio) {
                                return;
                            }
                            audio.currentTime = details.seekTime;
                            this.updateProgress();
                        }
                    }
                };

                for (const [action, handler] of Object.entries(actions)) {
                    try {
                        navigator.mediaSession.setActionHandler(action, handler);
                    } catch (error) {
                        console.error(`MediaSession: Error setting handler for "${action}":`, error);
                    }
                }
            }

            if (!this.hideViralBanner) {
                setTimeout(() => { this.viralBannerVisible = true; }, 15000);
            }

            if (window.SWP_CONFIG.is_private_network) {
                this.runPeriodicUpdateCheck();
            }

            window.addEventListener('beforeunload', () => {
                if (this._serverMonitorTimeout) clearTimeout(this._serverMonitorTimeout);
                if (this._wsReconnectTimeout) clearTimeout(this._wsReconnectTimeout);
                if (this.wsPingInterval) clearInterval(this.wsPingInterval);
                if (this.discGlowInterval) clearInterval(this.discGlowInterval);
                if (this.ws) this.ws.close();
            });

            const handleKeyDown = (e) => {
                if (e.code === 'Escape' && (this.fullscreenCoverVisible || this.fullscreenDesktopCoverVisible)) {
                    this.hideFullscreenCover();
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    return;
                }
                if (e.ctrlKey && e.code === 'KeyS') e.preventDefault();
                if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

                if (e.code === 'Space') {
                    e.preventDefault();
                    this.togglePlay();
                } else if (e.code === 'Escape') {
                    if (this.isModalOpen) return; // Let Alpine handle modal closing
                    if (this.menuPopup && this.menuPopup.isOpen) {
                        this.menuPopup.hide();
                    } else if (this.showLyricsModal) {
                        this.showLyricsModal = false;
                        this.userClosedLyricsModal = true;
                    } else if (this.mobilePlayerExpanded) {
                        this.mobilePlayerExpanded = false;
                    }
                } else if (e.code === 'ArrowUp' || e.code === 'ArrowDown') {
                    e.preventDefault();
                    const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
                    if (list.length === 0) return;

                    if (this.selectedIndex === -1) this.selectedIndex = this.currentSongIndex !== -1 ? this.currentSongIndex : 0;

                    if (e.code === 'ArrowUp') {
                        this.selectedIndex = Math.max(0, this.selectedIndex - 1);
                    } else {
                        this.selectedIndex = Math.min(list.length - 1, this.selectedIndex + 1);
                    }
                    this.scrollSongIntoView(list[this.selectedIndex].id, 'auto');
                } else if (e.code === 'PageUp' || e.code === 'PageDown') {
                    e.preventDefault();
                    const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
                    if (list.length === 0) return;

                    if (this.selectedIndex === -1) this.selectedIndex = this.currentSongIndex !== -1 ? this.currentSongIndex : 0;

                    const pageSize = Math.floor(this.$refs.songListContainer.clientHeight / 35) || 10;
                    if (e.code === 'PageUp') {
                        this.selectedIndex = Math.max(0, this.selectedIndex - pageSize);
                    } else {
                        this.selectedIndex = Math.min(list.length - 1, this.selectedIndex + pageSize);
                    }
                    this.scrollSongIntoView(list[this.selectedIndex].id, 'auto');
                } else if (e.code === 'ArrowLeft' || e.code === 'ArrowRight') {
                    e.preventDefault();
                    if (e.ctrlKey) {
                        if (e.code === 'ArrowLeft') {
                            this.playPrev();
                        } else {
                            this.playNext(true);
                        }
                    } else {
                        const audio = this.getActivePlayer();
                        if (!audio || !this.currentSong || this.currentSong.is_radio) return;

                        // Clear pending autoplay sync to prevent "jump back" on first manual seek
                        this.autoplayStartTime = 0;

                        const multiplier = (e.shiftKey || e.altKey) ? 12 : 1;
                        const skipTime = 5 * multiplier; // seconds
                        if (e.code === 'ArrowLeft') {
                            audio.currentTime = Math.max(0, audio.currentTime - skipTime);
                        } else {
                            audio.currentTime = Math.min(this.duration, audio.currentTime + skipTime);
                        }
                        this.updateProgress();
                    }
                } else if (e.code === 'Home') {
                    e.preventDefault();
                    const audio = this.getActivePlayer();
                    // Clear any pending autoplay/sync seek logic to prevent it from overriding this manual action
                    this.autoplayStartTime = 0;
                    if (audio && this._currentSyncSeek) {
                        audio.removeEventListener('playing', this._currentSyncSeek);
                    }

                    if (audio && this.currentTime > 2) {
                        audio.currentTime = 0;
                        this.updateProgress();
                    } else {
                        const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
                        if (list.length > 0) {
                            this.selectedIndex = 0;
                            this.scrollSongIntoView(list[this.selectedIndex].id, 'auto');
                        }
                    }
                } else if (e.code === 'End') {
                    e.preventDefault();
                    const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
                    if (list.length > 0) {
                        this.selectedIndex = list.length - 1;
                        this.scrollSongIntoView(list[this.selectedIndex].id, 'auto');
                    }
                } else if ((e.ctrlKey || e.altKey) && e.key >= '1' && e.key <= '5') {
                    e.preventDefault();
                    if (this.currentSong) {
                        this.setSongRating(this.currentSong, parseInt(e.key));
                    }
                } else if (e.code === 'Enter') {
                    e.preventDefault();
                    const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
                    const idx = this.selectedIndex !== -1 ? this.selectedIndex : this.currentSongIndex;
                    const selected = list[idx];

                    if (selected) {
                        const playingSongId = this.currentSong ? this.currentSong.id : null;
                        if (selected.id === playingSongId) {
                            if (this.isPlaying) {
                                this.getActivePlayer().currentTime = 0;
                            } else {
                                this.togglePlay();
                            }
                        } else {
                            this.playSong(idx, true);
                        }
                    }
                }
            };
            window.removeEventListener('keydown', window._swpKeyDownHandler);
            window._swpKeyDownHandler = (e) => {
                // Focus Trapping Logic
                if (e.key === 'Tab' && this.isModalOpen) {
                    const modal = document.querySelector('.modal-content-host[style*="display: block"], .modal-content-host:not([style*="display: none"])');
                    if (modal) {
                        const focusables = modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
                        const first = focusables[0];
                        const last = focusables[focusables.length - 1];

                        if (e.shiftKey) {
                            if (document.activeElement === first) {
                                last.focus();
                                e.preventDefault();
                            }
                        } else {
                            if (document.activeElement === last) {
                                first.focus();
                                e.preventDefault();
                            }
                        }
                    }
                }
                handleKeyDown(e);
            };
            window.addEventListener('keydown', window._swpKeyDownHandler);

            // Ensure Alpine detects window resize for the isMobileMode getter
            window.addEventListener('resize', () => {
                this.resizeCounter++;
                this.updateMarquees();

                // Auto-expand Hero player on first resize to mobile if no preference is saved
                if (this.isMobileMode && !this.isMobileDevice && !this._hasAutoExpandedHero) {
                    if (localStorage.getItem('mobilePlayerExpanded') === null) {
                        this.mobilePlayerExpanded = true;
                        this._hasAutoExpandedHero = true;
                    }
                }
                
                // If a template-based menu is open, we need to re-trigger show() 
                // to ensure the DOM is correctly placed and Alpine re-evaluates x-if
                if (this.menuPopup && this.menuPopup.isOpen && !this.menuPopup._currentItems) {
                    this.menuPopup.show({
                        menuId: this.menuPopup.activeMenuId,
                        anchorEl: this.menuPopup._lastPos.anchorEl,
                        x: this.menuPopup._lastPos.x,
                        y: this.menuPopup._lastPos.y,
                        contentEl: this.menuPopup._currentContent
                    });
                }
            });

            const handleResize = () => {
                const isSmall = this.isMobileModeTiny;
                this.isMobileDevice = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || (('ontouchstart' in window || navigator.maxTouchPoints > 0) && isSmall);

                // If we are in desktop mode (>= 800px)
                if (!this.isMobileModeTiny) {
                    const shouldCollapse = this.isMobileMode;
                    if (this.sidebarStates[0].collapsed !== shouldCollapse) {
                        this.sidebarStates[0].collapsed = shouldCollapse;
                        this.sidebarStates[1].collapsed = shouldCollapse;
                    }
                } else {
                    // Default to expanded on mobile for better discoverability
                    this.sidebarStates[0].collapsed = false;
                    this.sidebarStates[1].collapsed = false;
                }

                // Reposition open menus to keep them within viewport
                if (this.menuPopup) {
                    this.menuPopup.reposition();
                }
            };
            window.addEventListener('resize', handleResize);

            window.addEventListener('focus', () => {
                if (this.blurTimeoutId) { clearTimeout(this.blurTimeoutId); this.blurTimeoutId = null; }
                this.isWindowFocused = true;
                if (this.isPlaying) { this.discVisible = true; }
            });
            window.addEventListener('visibilitychange', () => {
                if (document.visibilityState === 'hidden' && this.currentSong && this.isPlaying) {
                    const playbackData = {
                        songId: this.currentSong.id,
                        currentTime: this.currentTime,
                        timestamp: Date.now()
                    };
                    localStorage.setItem('playbackPosition', JSON.stringify(playbackData));
                }
            });
            window.addEventListener('blur', () => {
                if (this.editingTag.songId) {
                    this.saveTag();
                }
                this.isWindowFocused = false;
                if (this.blurTimeoutId) clearTimeout(this.blurTimeoutId);
                this.blurTimeoutId = setTimeout(() => {
                    if (!this.isWindowFocused && this.isPlaying && this.discVisible) {
                        setTimeout(() => {
                            this.discVisible = false;
                            this.updateMarquees(true);
                        }, 1000);
                    }
                }, 1000);
            });
            this.volume = 1.0;
            this.muted = false;
            this.playerA.volume = this.volume;
            this.playerB.volume = this.volume;

            // Add event listener for direct input of crossfade duration
            this.$nextTick(() => {
                document.addEventListener('click', (e) => {
                    if (this.crossfadeInputActive) {
                        const configMenu = document.querySelector('[aria-labelledby="config-menu"]');
                        if (configMenu && !configMenu.contains(e.target)) {
                            this.crossfadeInputActive = false;
                        }
                    }
                });
            });

            const scheduleHeaderFlicker = () => {
                const headerTitle = document.querySelector('.header-title');
                if (!headerTitle) return;

                const flickerLoop = () => {
                    // Random between 60s and 180s (1-3 minutes)
                    const delay = Math.random() * 120000 + 60000;
                    setTimeout(() => {
                        if (this.enableVisualEffects && this.isWindowFocused) {
                            headerTitle.classList.add('flickering');
                            headerTitle.addEventListener('animationend', () => {
                                headerTitle.classList.remove('flickering');
                            }, { once: true });
                        }
                        flickerLoop(); // Re-schedule
                    }, delay);
                };

                flickerLoop();
            };
            scheduleHeaderFlicker();

            // Apply initial scales
            document.documentElement.style.setProperty('--ui-scale', this.uiScale);
            document.documentElement.style.setProperty('--lyrics-scale', this.lyricsScale);

            this.checkLoadingStatus(); // Will now primarily rely on WebSocket for continuous updates

            // Watch for URL changes (like back/forward buttons) and ensure it stays pretty
            window.addEventListener('popstate', () => {
                const currentUrl = window.location.href;
                if (currentUrl.includes('%7C')) {
                    history.replaceState({}, '', currentUrl.replace(/%7C/g, '|'));
                }
            });

            // Periodically check if the browser has encoded the URL and prettify it again
            // This handles cases where the browser might re-encode it automatically
            setInterval(() => {
                if (!this.isWindowFocused) return;
                const currentUrl = window.location.href;
                if (currentUrl.includes('%7C')) {
                    history.replaceState({}, '', currentUrl.replace(/%7C/g, '|'));
                }
            }, 2000);

            this.$watch('volume', (newVolume) => {
                if (this.playerA) this.playerA.volume = newVolume;
                if (this.playerB) this.playerB.volume = newVolume;
                localStorage.setItem('volume', newVolume);
            });

            this.$watch('playbackSpeedControl', (value) => {
                localStorage.setItem('playbackSpeedControl', value);
                if (value === 'disabled') {
                    this.playbackRate = 1.0;
                }
            });

            this.$watch('enableTrackNumber', (value) => {
                localStorage.setItem('enableTrackNumber', JSON.stringify(value));
            });

            this.$watch('enableBitrate', (value) => {
                localStorage.setItem('enableBitrate', JSON.stringify(value));
            });

            this.$watch('enableRatingColumn', (value) => {
                localStorage.setItem('enableRatingColumn', JSON.stringify(value));
            });

            this.$watch('sidebarOrLogic', (value) => {
                localStorage.setItem('sidebarOrLogic', JSON.stringify(value));
                if (this.isInitializing) return;
                this.fetchSongs(1, false);
                this.fetchSidebarData();
            });

            this.$watch('uiScale', (value) => {
                document.documentElement.style.setProperty('--ui-scale', value);
                localStorage.setItem('uiScale', value);
            });

            this.$watch('lyricsScale', (value) => {
                document.documentElement.style.setProperty('--lyrics-scale', value);
                localStorage.setItem('lyricsScale', value);
            });

            this.$watch('enableVisualEffects', (value) => {
                localStorage.setItem('enableVisualEffects', JSON.stringify(value));
            });

            this.$watch('enableLyrics', (value) => {
                localStorage.setItem('enableLyrics', JSON.stringify(value));
                if (!value) {
                    this.showLyricsModal = false;
                } else if (this.currentSong && this.currentSong.lyrics === undefined) {
                    // Only fetch if lyrics have never been fetched (are undefined).
                    // If they are null, it means we already determined there are no lyrics.
                    this.fetchLyrics(this.currentSong);
                }
            });

            this.$watch('showLyricsModal', (value) => {
                localStorage.setItem('showLyricsModal', value);
                if (value) {
                    this._lastQuantizedScrollTop = null;
                    this._scrollAnimationStartTime = 0;
                    this.startLyricsAnimation();
                    // When the modal is shown, query for the lyric line elements.
                    this.$nextTick(() => {
                        this.lyricsLineElements = this.lyricsLines.map((_, index) => document.getElementById(`lyric-line-${index}`)).filter(Boolean);
                        const container = this.$refs.lyricsContainer;
                        if (container && !container.dataset.scrollListenerAdded) {
                            // Using a named function stored on the element allows us to remove the specific listener later.
                            container._handleManualScroll = (event) => {
                                // For pointerdown, use a heuristic to only trigger on the scrollbar.
                                if (event.type === 'pointerdown' && event.offsetX < container.clientWidth) return;
                                // For keydown, only react to scroll-related keys.
                                if (event.type === 'keydown' && !['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End'].includes(event.key)) return;

                                this.userScrolledLyrics = true;
                            };

                            container.setAttribute('tabindex', '-1'); // Make focusable for keyboard events.
                            container.addEventListener('wheel', container._handleManualScroll, { passive: true });
                            container.addEventListener('pointerdown', container._handleManualScroll, { passive: true });
                            container.addEventListener('keydown', container._handleManualScroll, { passive: true });
                            container.dataset.scrollListenerAdded = 'true';
                        }
                    });
                } else {
                    this.stopLyricsAnimation();
                    // When hidden, clear elements and remove listeners to prevent memory leaks and ensure they are re-added if modal re-opens.
                    this.lyricsLineElements = [];
                    const container = this.$refs.lyricsContainer;
                    if (container && container.dataset.scrollListenerAdded) {
                        if (container._handleManualScroll) {
                            container.removeEventListener('wheel', container._handleManualScroll);
                            container.removeEventListener('pointerdown', container._handleManualScroll);
                            container.removeEventListener('keydown', container._handleManualScroll);
                        }
                        delete container.dataset.scrollListenerAdded;
                        delete container._handleManualScroll;
                    }
                }
            });

            this.$watch('isMobileMode', (isMobile) => {
                // Reposition the menu if it's open to account for layout changes
                if (this.menuPopup && this.menuPopup.isOpen) {
                    this.$nextTick(() => this.menuPopup.reposition());
                }
            });

            this.$watch('mobilePlayerExpanded', (value) => {
                localStorage.setItem('mobilePlayerExpanded', value);
                if (value) {
                    this.$nextTick(() => {
                        setTimeout(() => this.updateMarquees(), 450);
                    });
                }
            });

            this.$watch('uiScale', (newScale) => {
                this.uiScale = parseFloat(newScale.toFixed(2));
            });

            this.$watch('lyricsScale', (newScale) => {
                this.lyricsScale = parseFloat(newScale.toFixed(2));
            });

            this.$watch('playbackRate', (newRate) => {
                if (this.playerA) {
                    this.playerA.playbackRate = newRate;
                    this.playerA.preservesPitch = true;
                }
                if (this.playerB) {
                    this.playerB.playbackRate = newRate;
                    this.playerB.preservesPitch = true;
                }
            });

            this.$watch('search', (value) => {
                if (this.isInitializing) return;

                if (this.searchAbortController) {
                    this.searchAbortController.abort();
                }
                this.searchAbortController = new AbortController();

                if (value) { this.logAction(`Search triggered: "${value}"`); }
                this.updateUrl();

                // A new search (or clearing search) re-fetches from page 1
                this.fetchSongs(1, false, this.searchAbortController.signal);
            });

            this.$watch('selectedPlaylists', async () => {
                if (this.isInitializing) return;
                await this.fetchSongs(1, false);
            });

            this.$watch('selectedGenres', async () => {
                if (this.isInitializing) return;
                await this.fetchSongs(1, false);
            });

            this.$watch('selectedArtists', async () => {
                if (this.isInitializing) return;
                await this.fetchSongs(1, false);
            });

            this.$watch('selectedAlbums', async () => {
                if (this.isInitializing) return;
                await this.fetchSongs(1, false);
            });

            this.$watch('ratingFilter', async () => {
                if (this.isInitializing) return;
                this.updateUrl();
                await this.fetchSongs(1, false); // Refetch from page 1 with new filters
                await this.fetchSidebarData();   // Update sidebars based on new rating filter
            });

            this.$watch('shuffle', (value) => {
                localStorage.setItem('shuffle', value);
                if (this.isInitializing) return;
                this.updateUrl();
                this.fetchSongs(1, false);
            });

            this.$watch('repeat', (value) => {
                localStorage.setItem('repeat', value);
            });

            this.$watch('isPlaying', (value) => {
                sessionStorage.setItem('playbackState', value ? 'playing' : 'paused');
                if ('mediaSession' in navigator) {
                    navigator.mediaSession.playbackState = value ? 'playing' : 'paused';
                }
                if (value) {
                    if (this.discGlowInterval) clearInterval(this.discGlowInterval);
                    this.discGlowInterval = setInterval(() => { this.toggleDiscGlow(); }, 30000);
                    this.startLyricsAnimation();
                } else {
                    if (this.discGlowInterval) { clearInterval(this.discGlowInterval); this.discGlowInterval = null; }
                    this.stopLyricsAnimation();
                }
            });

            this.$watch('coverArtSong', (newSong) => {
                if (this.fullscreenCoverVisible || this.fullscreenDesktopCoverVisible) {
                    if (this.showCoverImage) {
                        this.fullscreenCoverSong = newSong;
                    } else {
                        // If the new song has no cover, we must close the fullscreen view
                        this.fullscreenCoverVisible = false;
                        this.fullscreenDesktopCoverVisible = false;
                        setTimeout(() => { this.fullscreenCoverSong = null; }, 350);
                    }
                }
            });

            this.$watch('showShareHint', (value) => {
                if (value) {
                    // We need to wait for Alpine to make the element visible (nextTick)
                    // and then for the browser to be ready to paint it (requestAnimationFrame)
                    // to reliably get its dimensions for positioning.
                    this.$nextTick(() => {
                        requestAnimationFrame(() => {
                            this.positionTooltip({ currentTarget: this.$refs.shareButtonContainer }, '.tooltip-hint');
                        });
                    });
                }
            });
        },
        initWebSocket() {
            if (this._wsReconnectTimeout) clearTimeout(this._wsReconnectTimeout);
            if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
                return; // Connection is already open or being established
            }
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = `${protocol}//${window.location.host}/api/ws`;
            const ws = new WebSocket(wsUrl);

            ws.onopen = () => {
                console.log('WebSocket connection established.');
                // Send a ping every 30 seconds to keep the connection alive
                if (this.wsPingInterval) clearInterval(this.wsPingInterval);
                this.wsPingInterval = setInterval(() => {
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({ event: 'ping' }));
                    }
                }, 30000);
            };

            ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.event === 'ping') {
                        // This is a keep-alive message from the server
                        return;
                    }
                    if (data.event === 'lyrics_update') {
                        this._updateLyricsState(data.id, data.lyrics);
                        return;
                    }
                    if (data.event === 'library_updated') {
                        this.loadInitialData();
                    }
                    if (data.event === 'library_purged') {
                        this.showNotification('Library synchronized: removed entries no longer in configuration.', 'info', null, 3000);
                        this.allSongs = [];
                        this.currentPlaylist = [];
                        this.displayedSongCount = 0;
                        this.libraryPageToLoad = 1;
                        // Re-fetch everything to ensure UI is clean
                        this.fetchSongs(1, false);
                        this.fetchSidebarData();
                    }
                    if (data.event === 'config_updated') {
                        // Do not trigger reload if we are in the middle of setting up the initial password
                        // or if the user is actively editing settings, to avoid interrupting the flow.
                        if (this.showSetInitialPasswordModal || this.showUserSettingsModal || this.initialPasswordLoading) {
                            console.log("Config update received but suppressed to avoid interrupting initial setup.");
                            return;
                        }
                        this.showNotification('Server configuration has been updated. The page will now reload.', 'info', null, 5000);
                        setTimeout(() => {
                            window.location.reload();
                        }, 3000);
                    }
                    if (data.event === 'version') {
                        const serverHash = data.source_hash;
                        const localHash = window.SWP_CONFIG.source_hash;
                        if (serverHash && localHash && serverHash !== localHash) {
                            if (!this._isReloading) {
                                this._isReloading = true;
                                console.log(`Version mismatch! Server: ${serverHash}, Local: ${localHash}`);
                                this.showNotification("A new server version is available. Reloading to update...", "warning", null, 10000);
                                setTimeout(() => {
                                    window.location.reload(true);
                                }, 3000);
                            }
                        }
                    }
                    if (data.event === 'status_update') {
                        this.loading = !data.status.done;
                        this.loadingMessage = data.status.message;
                        this.loadingProgress = data.status.progress;
                        if (data.status.done) {
                           // If library is done loading and we haven't loaded data yet, trigger it.
                           // We check allSongs length to avoid redundant loads if already initialized.
                           if (this.allSongs.length === 0) {
                               this.loadInitialData();
                           }
                        }
                    }
                } catch (e) {
                    console.error('Error parsing WebSocket message:', e);
                }
            };

            ws.onclose = () => {
                console.warn('WebSocket connection closed. Attempting to reconnect in 5 seconds...');
                if (this.wsPingInterval) clearInterval(this.wsPingInterval);
                this._wsReconnectTimeout = setTimeout(() => this.initWebSocket(), 5000);
            };

            ws.onerror = (err) => {
                console.error('WebSocket error:', err);
                // onclose will be called automatically after an error, which will trigger reconnection logic.
            };

            this.ws = ws;
        },
        _fuseIndex: null,
        async fetchSongs(page = 1, append = false, signal = null) {
            if (this.isLoadingMoreSongs && !signal) return;
            this.isLoadingMoreSongs = true;
            if (!append) {
                this.cancelEditingTag();
                this.viewLoading = true;
                this.urlLoadedSongId = null;
            }

            const isSearch = (this.search || '').length > 0;
            let wasAborted = false;

            try {
                const baseUrl = isSearch ? `${window.location.origin}/api/search` : `${window.location.origin}/api/library`;
                const url = new URL(baseUrl);
                url.searchParams.set('page', page);
                
                const limit = this.shuffle === 'random' ? 0 : (window.SWP_CONFIG.songs_per_page || 5000);
                url.searchParams.set('limit', limit);

                if (isSearch) {
                    url.searchParams.set('q', this.search);
                }
                if (this.selectedPlaylists.length > 0) {
                    url.searchParams.set('playlists', this.selectedPlaylists.join('|'));
                }
                if (this.selectedGenres.length > 0) { url.searchParams.set('genres', this.selectedGenres.join('|')); }
                if (this.sidebarOrLogic) { url.searchParams.set('logic', 'or'); }
                if (this.selectedArtists.length > 0) { url.searchParams.set('artists', this.selectedArtists.join('|')); }
                if (this.selectedAlbums.length > 0) { url.searchParams.set('albums', this.selectedAlbums.join('|')); }

                if (!isSearch && this.shuffle === 'list' && this.shuffleSeed) {
                    url.searchParams.set('shuffle', this.shuffleSeed);
                } else if (!isSearch && this.shuffle === 'random') {
                    url.searchParams.set('shuffle', 'yes');
                } else if (this.sortCol) {
                    let sortValue = this.sortCol;
                    if (this.sortDir && this.sortDir !== 'asc') {
                        sortValue += `|${this.sortDir}`;
                    }
                    url.searchParams.set('sort', sortValue);
                }
                if (this.ratingFilter.length > 0) { url.searchParams.set('ratings', this.ratingFilter.join('|')); }

                const res = await fetch(url, { signal });
                if (!res.ok) {
                    const errorMsgHeader = res.headers.get('X-Error-Notification');
                    if (errorMsgHeader) {
                        this.showNotification(decodeURIComponent(errorMsgHeader), 'error');
                    }
                    throw new Error('Failed to fetch song data');
                }
                const data = await res.json();
                const newSongs = (data.songs || []).map(s => {
                    s.is_radio = s.duration === 999999999;
                    return s;
                });

                if (append) {
                    this.allSongs = [...this.allSongs, ...newSongs];
                } else {
                    this.allSongs = [...newSongs];
                    this.resetView();
                }

                if (this.shuffle !== 'off') {
                    this.$nextTick(() => {
                        this.currentPlaylist = [...this.filteredSongs];
                    });
                }

                // Update Fuse index for v7.1.0
                if (this.allSongs.length > 0) {
                    const options = {
                        keys: ['title', 'artist', 'album', 'genre'],
                        threshold: 0.3
                    };
                    this._fuseIndex = Fuse.createIndex(options.keys, this.allSongs);
                    this.fuse = new Fuse(this.allSongs, options, this._fuseIndex);
                }

                this.displayedSongCount = data.total || 0;
                this.libraryPageToLoad = page + 1;

                // Reset loading state if we've reached the end
                if (newSongs.length === 0 || (data.total && this.allSongs.length >= data.total)) {
                    this.isLoadingMoreSongs = false;
                }
            } catch(e) {
                if (e.name === 'AbortError') {
                    // This is expected when a new search is typed.
                    // We'll set a flag so the finally block doesn't hide the spinner.
                    wasAborted = true;
                    return;
                }
                console.error("Failed to fetch songs:", e);
                this.showNotification("Error loading songs.", 'error');
            } finally {
                this.isLoadingMoreSongs = false;
                // Only hide spinner if not appending and request was not aborted.
                if (!append && !wasAborted) {
                    this.viewLoading = false;
                }
            }
        },
        async finishLoading() {
            const urlParams = new URLSearchParams(window.location.search);
            const playlists = urlParams.get('playlists');
            const genres = urlParams.get('genres');
            const artists = urlParams.get('artists');
            const albums = urlParams.get('albums');
            let songId = urlParams.get('song');
            const search = urlParams.get('search');
            const ratings = urlParams.get('ratings');
            const sort = urlParams.get('sort');
            let time = urlParams.get('t');
            const shuffleParam = urlParams.get('shuffle');
            const autoplay = urlParams.get('autoplay');

            const savedPosition = localStorage.getItem('playbackPosition');
            let savedPositionData = null;
            if (savedPosition) {
                try {
                    savedPositionData = JSON.parse(savedPosition);
                    const isExpired = (Date.now() - savedPositionData.timestamp) > 24 * 60 * 60 * 1000;
                    if (isExpired) {
                        localStorage.removeItem('playbackPosition');
                        savedPositionData = null;
                    }
                } catch (e) {
                    localStorage.removeItem('playbackPosition');
                    savedPositionData = null;
                }
            }

            if (savedPositionData) {
                const hasUrlContext = playlists || genres || artists || albums || search;
                if (!songId && !hasUrlContext) { // No song in URL and no new context, use saved one
                    songId = savedPositionData.songId;
                    if (!time) {
                        time = savedPositionData.currentTime;
                    }
                } else if (songId === savedPositionData.songId && !time) { // Song in URL is same as saved, no time in URL
                    time = savedPositionData.currentTime;
                }
            }

            if (time) { this.autoplayStartTime = parseFloat(time) || 0; }
            if (search) { this.search = search; }
            if (ratings) { this.ratingFilter = ratings.split('|').map(Number).filter(n => n >= 0 && n <= 5); }

            if (shuffleParam) {
                if (shuffleParam === 'yes') {
                    this.shuffle = 'random';
                    this.shuffleSeed = null;
                } else {
                    this.shuffle = 'list';
                    this.shuffleSeed = parseInt(shuffleParam, 10);
                }
                this.sortCol = '';
                this.sortDir = 'asc';
            } else if (sort) {
                const [col, dir] = sort.split('|');
                if (['title', 'artist', 'album', 'genre', 'rating', 'duration', 'track_number'].includes(col) && (!dir || ['asc', 'desc'].includes(dir))) {
                    this.sortCol = col;
                    this.sortDir = dir || 'asc';
                }
            } else if (!songId && !playlists && !genres) {
                this.sortCol = window.SWP_CONFIG.default_sort_by;
                this.sortDir = window.SWP_CONFIG.default_sort_order;
            }
            if (playlists) {
                this.selectedPlaylists = playlists.split('|').filter(p => this.playlists.hasOwnProperty(p));
            }
            if (genres) {
                this.selectedGenres = genres.split('|').filter(g => this.genres.includes(g));
            }

            if (playlists || genres) {
                await this.fetchSidebarData();
            } else if (artists || albums) {
                // If only artists/albums are selected from URL, we need to fetch their full lists first.
                if (artists) await this._fetchSidebarOnDemand('artist');
                if (albums) await this._fetchSidebarOnDemand('album');
            }

            if (artists) {
                this.selectedArtists = artists.split('|').filter(a => this.artists.includes(a));
            }
            if (albums) {
                this.selectedAlbums = albums.split('|').filter(a => this.albums.includes(a));
            }

            // This will handle search if `this.search` is set from URL params.
            await this.fetchSongs();
            this.loading = false;
            this.isInitializing = false;

            await this._fetchSidebarOnDemand(this.sidebar1);
            await this._fetchSidebarOnDemand(this.sidebar2);

            if (songId) {
                await this.$nextTick();
                let songToPlay;
                try {
                    const res = await fetch(`/api/song/${songId}`);
                    if (res.ok) {
                        songToPlay = await res.json();
                        songToPlay.is_radio = songToPlay.duration === 999999999;
                        const isSongInList = this.allSongs.some(s => s.id === songToPlay.id);
                        if (!isSongInList) {
                            this.urlLoadedSongId = songId;
                            this.allSongs = Alpine.raw([songToPlay, ...this.allSongs.filter(s => s.id !== songId)]);
                            if (this.shuffle !== 'off') { this.currentPlaylist = this.filteredSongs; }
                        } else {
                            // Song is in the list, update it in place to get fresh data but preserve order.
                            const songIndex = this.allSongs.findIndex(s => s.id === songToPlay.id);
                            if (songIndex !== -1) {
                                this.allSongs.splice(songIndex, 1, songToPlay);
                                this.allSongs = [...this.allSongs]; // Trigger reactivity for Alpine
                            }
                            this.$nextTick(() => { this.scrollSongIntoView(songToPlay.id); });
                        }
                    } else {
                        this.showNotification('The song is not found and that the first one of the list is selected instead.', 'warning');
                        songToPlay = null;
                    }
                } catch (e) { console.error("Failed to fetch song by ID:", e); }

                if (songToPlay) {
                    // Ensure the song is in the list for the player to function
                    const exists = this.allSongs.find(s => s.id === songToPlay.id);
                    if (!exists) {
                        this.allSongs = [songToPlay, ...this.allSongs];
                    }

                    if (!songToPlay.is_radio) {
                        // Before attempting to play, check if the song has cover art.
                        // This prevents the fullscreen cover from showing up empty on initial load.
                        await this.checkCoverArtExists(songToPlay.id);
                    }

                    await this.$nextTick();
                    const songIndex = this.filteredSongs.findIndex(s => s.id === songId);
                    if (songIndex !== -1) {
                        this.isAttemptingAutoplay = true;
                        await this.selectSong(songIndex, false);
                        this.attemptAutoplayAfterLoad();
                    }
                } else if (songId && this.filteredSongs.length > 0) {
                    this.isAttemptingAutoplay = true;
                    await this.selectSong(0, false);
                    this.attemptAutoplayAfterLoad();
                }
            } else if (autoplay === 'yes') {
                this.$nextTick(async () => {
                    if (this.filteredSongs.length > 0) {
                        this.isAttemptingAutoplay = true;
                        await this.selectSong(0, false);
                        this.attemptAutoplayAfterLoad();
                    }
                });
            }

            this.updateUrl();
        },
        updateUrl(push = true) {
            const url = new URL(window.location.origin + window.location.pathname);
            if (this.selectedPlaylists.length > 0) { url.searchParams.set('playlists', this.selectedPlaylists.join('|')); }
            if (this.selectedGenres.length > 0) { url.searchParams.set('genres', this.selectedGenres.join('|')); }
            if (this.selectedArtists.length > 0) { url.searchParams.set('artists', this.selectedArtists.join('|')); }
            if (this.selectedAlbums.length > 0) { url.searchParams.set('albums', this.selectedAlbums.join('|')); }
            if (this.search) { url.searchParams.set('search', this.search); }
            if (this.ratingFilter.length > 0) { url.searchParams.set('ratings', this.ratingFilter.join('|')); }

            if (this.shuffle === 'list' && this.shuffleSeed) {
                url.searchParams.set('shuffle', this.shuffleSeed);
            } else if (this.shuffle === 'random') {
                url.searchParams.set('shuffle', 'yes');
            } else if (this.sortCol) {
                const isDefaultSort = this.sortCol === window.SWP_CONFIG.default_sort_by && this.sortDir === window.SWP_CONFIG.default_sort_order;
                if (!isDefaultSort) {
                    let sortValue = this.sortCol;
                    if (this.sortDir && this.sortDir !== 'asc') {
                        sortValue += `|${this.sortDir}`;
                    }
                    url.searchParams.set('sort', sortValue);
                }
            }
            if (this.currentSong) { url.searchParams.set('song', this.currentSong.id); }
            const historyMethod = push ? 'pushState' : 'replaceState';
            const prettyUrl = this.getPrettyUrl(url);
            if (prettyUrl !== window.location.href) { history[historyMethod]({}, '', prettyUrl); }
        },
        async checkLoadingStatus() {
            try {
                const res = await fetch('/api/status');
                if (!res.ok) throw new Error(`Server status check failed: ${res.statusText}`);
                const status = await res.json();

                this.loading = !status.done;
                this.loadingMessage = status.message;
                this.loadingProgress = (status.total > 0 && status.progress) ? status.progress : 0;

                if (status.done) {
                    if (this.allSongs.length === 0) {
                        this.loadInitialData(); // Load actual data after library is done
                    }
                } else {
                    // If not done, poll again until WebSocket is connected and taking over, or if WebSocket fails.
                    setTimeout(() => this.checkLoadingStatus(), 250);
                }
            } catch(e) {
                console.error("Error during initialization (polling /api/status):", e);
                this.loadingMessage = "Connection lost. Retrying...";
                this.loadingProgress = 0;
                this.loading = true;
                setTimeout(() => this.checkLoadingStatus(), 2000);
            }
        },
        async loadInitialData() {
            this.cancelEditingTag();
            try {
                // Ensure the loading status is marked as complete here too, in case WebSocket missed the final update.
                this.loading = false;
                this.loadingMessage = 'Loaded!';
                this.loadingProgress = 100;

                // Defer loading of artists and albums to speed up initial load, especially on mobile.
                const [playlistsRes, genresRes] = await Promise.all([
                    fetch('/api/playlists'),
                    fetch('/api/genres')
                ]);
                if (!playlistsRes.ok || !genresRes.ok) throw new Error('Failed to fetch initial metadata.');
                const playlistsData = await playlistsRes.json();

                const playlistNames = playlistsData.names || [];
                const playlistsObj = {};
                for (const name of playlistNames) {
                    playlistsObj[name] = []; // The value is not used, but the key is needed.
                }
                this.playlists = playlistsObj;

                this.playlistInfo = playlistsData.info || {};
                this.genres = await genresRes.json();
                this.artists = [];
                this.albums = [];

                // Now that basic metadata is loaded, finish parsing URL parameters and fetch songs.
                if (this.isInitializing) {
                    this.finishLoading();
                } else {
                    await this.fetchSongs(1, false);
                    await this.fetchSidebarData();
                }
            } catch (e) {
                console.error("Error loading initial data:", e);
                this.showNotification("Failed to load initial library data.", 'error');
                this.loadingMessage = "Failed to load library.";
                this.loading = true; // Stay in loading state if initial data fetch fails
            }
        },
        async fetchSidebarData() {
            try {
                const params = new URLSearchParams();
                // Sidebars should only be filtered by ratings, not by other sidebar selections
                // to prevent the lists from collapsing while browsing.
                if (this.ratingFilter.length > 0) {
                    params.set('ratings', this.ratingFilter.join('|'));
                }
                const queryString = params.toString() ? `?${params.toString()}` : '';

                const [playlistsRes, genresRes, artistsRes, albumsRes] = await Promise.all([
                    fetch(`/api/playlists${queryString}`),
                    fetch(`/api/genres${queryString}`),
                    fetch(`/api/artists${queryString}`),
                    fetch(`/api/albums${queryString}`)
                ]);

                if (!playlistsRes.ok || !genresRes.ok || !artistsRes.ok || !albumsRes.ok) {
                    throw new Error('Failed to fetch sidebar data.');
                }

                const playlistsData = await playlistsRes.json();
                const newGenres = await genresRes.json();
                const newArtists = await artistsRes.json();
                const newAlbums = await albumsRes.json();

                // Update Playlists
                const playlistNames = playlistsData.names || [];
                const playlistsObj = {};
                for (const name of playlistNames) {
                    playlistsObj[name] = [];
                }
                this.playlists = playlistsObj;
                this.playlistInfo = playlistsData.info || {};

                // Deselect items that are no longer in the filtered list
                this.selectedPlaylists = this.selectedPlaylists.filter(p => this.playlists.hasOwnProperty(p));

                const genresToKeep = this.selectedGenres.filter(genre => newGenres.includes(genre));
                if (genresToKeep.length !== this.selectedGenres.length) {
                    this.selectedGenres = genresToKeep;
                }
                this.genres = newGenres;

                const artistsToKeep = this.selectedArtists.filter(artist => newArtists.includes(artist));
                if (artistsToKeep.length !== this.selectedArtists.length) {
                    this.selectedArtists = artistsToKeep;
                }
                this.artists = newArtists;

                const albumsToKeep = this.selectedAlbums.filter(album => newAlbums.includes(album));
                if (albumsToKeep.length !== this.selectedAlbums.length) {
                    this.selectedAlbums = albumsToKeep;
                }
                this.albums = newAlbums;

            } catch (e) {
                console.error("Error fetching sidebar data:", e);
                this.showNotification("Error loading artists and albums.", 'error');
            }
        },
        formatTime(seconds) {
            if (seconds === null || seconds === '' || seconds === 999999998) return '';
            if (seconds === 999999999 || seconds < 0 || !isFinite(seconds)) return '∞';
            if (isNaN(seconds) || seconds === 0) return '00:00';

            // Adjust time based on playback speed
            const adjustedSeconds = seconds / (this.playbackRate || 1.0);

            const hrs = Math.floor(adjustedSeconds / 3600);
            const mins = Math.floor((adjustedSeconds % 3600) / 60);
            const secs = Math.floor(adjustedSeconds % 60);

            if (hrs > 0) {
                return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
            }
            return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        },
        highlight(song, key) {
            const text = song[key] || '';
            const search = this.search.trim();
            if (!search || !text) { return text; }

            const searchTerms = search.split(/\s+/);

            const regexPatterns = searchTerms.map(term =>
                term.split('')
                    .map(char => char.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'))
                    .join('[^A-Za-z0-9]*')
            );

            const regex = new RegExp(`(${regexPatterns.join('|')})`, 'gi');

            return text.replace(regex, `<span class="text-cyan-400 neon-text-cyan inline-block px-1">$1</span>`);
        },
        toggleMobilePlayer() {
            if (this.isMobileMode) {
                this.mobilePlayerExpanded = !this.mobilePlayerExpanded;
                localStorage.setItem('mobilePlayerExpanded', this.mobilePlayerExpanded);
                if (this.mobilePlayerExpanded) {
                    this.logAction('Action: Expand mobile player');
                    this.$nextTick(() => {
                        setTimeout(() => this.updateMarquees(), 450); // Wait for transition
                    });
                } else {
                    this.logAction('Action: Collapse mobile player');
                }
            }
        },
        handleButtonPress(direction, event) {
            if (event && event.cancelable) event.preventDefault();
            this.clearHold();
            this._wasHolding = false;
            this.holdTimer = setTimeout(() => {
                this._wasHolding = true;
                this.holdInterval = setInterval(() => {
                    const audio = this.getActivePlayer();
                    if (!audio || this.currentSong?.is_radio) return;
                    const step = 5;
                    if (direction === 'next') {
                        audio.currentTime = Math.min(audio.duration, audio.currentTime + step);
                    } else {
                        audio.currentTime = Math.max(0, audio.currentTime - step);
                    }
                    this.updateProgress();
                }, 100);
            }, 400);
        },
        handleButtonRelease(direction, event) {
            if (event && event.cancelable) event.preventDefault();
            if (this._wasHolding) {
                this._lastHoldEnd = Date.now();
            }
            this.clearHold();
            this._wasHolding = false;
        },
        clearHold() {
            if (this.holdTimer) clearTimeout(this.holdTimer);
            if (this.holdInterval) clearInterval(this.holdInterval);
            this.holdTimer = null;
            this.holdInterval = null;
        },
        handleTouchStart(e) {
            this.touchStartY = e.touches[0].clientY;
        },
        handleTouchEnd(e) {
            if (e.target.tagName === 'INPUT' && e.target.type === 'range') return;
            const touchEndY = e.changedTouches[0].clientY;
            const deltaY = this.touchStartY - touchEndY;

            if (Math.abs(deltaY) > 50) { // Threshold for swipe
                if (deltaY > 0 && !this.mobilePlayerExpanded) {
                    this.mobilePlayerExpanded = true;
                    localStorage.setItem('mobilePlayerExpanded', 'true');
                } else if (deltaY < 0 && this.mobilePlayerExpanded) {
                    this.mobilePlayerExpanded = false;
                    localStorage.setItem('mobilePlayerExpanded', 'false');
                }
            }
        },
        togglePlay() {
            const now = Date.now();
            // Increased debounce for mobile touch reliability
            const debounceLimit = this.isMobileDevice ? 400 : this.toggleDebounceMs;
            if (now - this.lastToggleTime < debounceLimit) {
                return;
            }
            this.lastToggleTime = now;

            if (!this.currentSong) {
                this.playSong(0, true);
                return;
            }

            const audio = this.getActivePlayer();

            // If we are currently playing or in the process of starting, pause it
            if (this.isPlaying || this.preloadingSongId) {
                this.logAction('Action: Pause/Stop playback');

                // Cancel any pending network requests for lyrics/streams
                this._cancelPendingFetches();

                audio.pause();
                this.isPlaying = false;
                this.stopLyricsAnimation();
                this.preloadingSongId = null;

                if (this.currentSong) {
                    try {
                        const playbackData = {
                            songId: this.currentSong.id,
                            currentTime: this.currentTime,
                            timestamp: Date.now()
                        };
                        localStorage.setItem('playbackPosition', JSON.stringify(playbackData));
                    } catch (e) {
                        console.error('Failed to save playback position on pause:', e);
                    }
                }
                this.fullscreenDesktopCoverVisible = false;

                if (this.discVisible) {
                    setTimeout(() => {
                        if (!this.isPlaying) this.discVisible = false;
                    }, 1000);
                }
            }
            // Otherwise, start/resume playback
            else {
                this.logAction('Action: Resume playback');
                this.isAttemptingAutoplay = false;
                // Ensure UI state is updated immediately
                this.isPlaying = true;
                this.discVisible = true;
                this.playAudio({ manualSelection: true, isNewPlay: false });
            }
        },
        toggleFullscreenCover() {
            if (!this.currentSong || !this.showCoverImage) return;
            if (this.fullscreenCoverVisible) {
                this.hideFullscreenCover();
            } else {
                this.fullscreenCoverSong = this.currentSong;
                this.fullscreenCoverVisible = true;
                if (this.isMobileMode) {
                    this.logAction('Action: Show mobile fullscreen cover');
                }
            }
        },
        toggleDiscRotation() {
            this.userPausedDisc = !this.userPausedDisc;
            this.logAction('Action: Toggle disc rotation manually to ' + (this.userPausedDisc ? 'paused' : 'playing'));
        },
        toggleFullscreenDesktopCover() {
            if (this.fullscreenDesktopCoverVisible) {
                this.fullscreenDesktopCoverVisible = false;
                setTimeout(() => { this.fullscreenCoverSong = null; }, 350); // Clear after transition
            } else {
                if (!this.currentSong || !this.showCoverImage) return;
                this.fullscreenCoverSong = this.currentSong;
                this.fullscreenDesktopCoverVisible = true;
            }
        },
        toggleDiscGlow() {
            if (this.discGlows && this.discGlows.length > 0) {
                this.discGlowIndex = (this.discGlowIndex + 1) % this.discGlows.length;
            }
        },
        _updateLyricsState(songId, lyrics) {
            this.lyricsCache[songId] = lyrics;

            // Update the master list of songs
            const songInAllSongs = this.allSongs.find(s => s.id === songId);
            if (songInAllSongs) {
                songInAllSongs.lyrics = lyrics;
                // Force Alpine to notice the change in the array item and re-render.
                // This is needed because filteredSongs creates copies.
                this.allSongs = [...this.allSongs];
            }

            // If the updated song is the currently playing one, update its state too.
            if (this.currentSong && this.currentSong.id === songId) {
                this.currentSong.lyrics = lyrics;
                const hasLyrics = lyrics && lyrics.trim().length > 0;

                if (hasLyrics) {
                    this.processLyricsForKaraoke(lyrics);
                } else {
                    this.lyricsModalContent = "No lyrics found for this song.";
                    this.lyricsLines = [];
                    this.lyricsLineElements = [];
                }

                if (!this.userClosedLyricsModal || localStorage.getItem('showLyricsModal') === 'true') {
                    this.showLyricsModal = hasLyrics && localStorage.getItem('showLyricsModal') === 'true';
                }
            }
        },
        async fetchLyrics(song) {
            if (!song) return;

            // If a fetch is already in progress for this song, don't start another.
            if (this.lyricsFetching[song.id]) {
                return;
            }

            // If lyrics are already in our cache, use them. This is the primary check.
            if (this.lyricsCache.hasOwnProperty(song.id)) {
                this._updateLyricsState(song.id, this.lyricsCache[song.id]);
                return;
            }

            // Defensive check: if lyrics are on the object but not in cache, sync the cache.
            // This case shouldn't happen with current logic but provides robustness against race conditions.
            if (song.lyrics !== undefined) {
                this._updateLyricsState(song.id, song.lyrics); // This will update cache and UI.
                return;
            }

            if (this.lyricsAbortController) {
                this.lyricsAbortController.abort();
            }
            const abortController = new AbortController();
            this.lyricsAbortController = abortController;

            if (!this.enableLyrics || song.is_radio) {
                this._updateLyricsState(song.id, null);
                return;
            }

            try {
                this.lyricsFetching[song.id] = true;
                const res = await fetch(`/api/lyrics/${song.id}`, { signal: abortController.signal });
                if (res.ok) {
                    const data = await res.json();
                    this._updateLyricsState(song.id, data.lyrics);
                } else {
                    this._updateLyricsState(song.id, null);
                }
            } catch (e) {
                if (e.name !== 'AbortError') {
                    // Only log the error and update state if the failed request was for the currently playing song.
                    // This prevents errors from old, aborted requests from affecting the current view.
                    if (this.currentSong && this.currentSong.id === song.id) {
                        console.error('Failed to fetch lyrics for song:', song.title, e, { songObject: song, currentSongObject: this.currentSong });
                        this._updateLyricsState(song.id, null);
                    }
                }
            } finally {
                delete this.lyricsFetching[song.id];
                if (this.lyricsAbortController === abortController) {
                    this.lyricsAbortController = null;
                }
            }
        },
        selectSong(index, shouldScroll = true) {
            if (this.shuffle === 'off') {
                this.currentPlaylist = this.filteredSongs;
            } else if (this.shuffle === 'random') {
                this.currentPlaylist = this.allSongs;
            }
            this.currentSongIndex = index;
            this.selectedIndex = index;
            if (this.currentPlaylist && index >= 0 && index < this.currentPlaylist.length) {
                const song = this.currentPlaylist[index];
                this.currentSong = song;
                this.coverArtSong = song;

                // Fix: Don't reset duration to 0 if we already have it from the library data.
                // This prevents the "00:00" bug on mobile while metadata is loading.
                if (song.duration && song.duration > 0 && !song.is_radio) {
                    this.duration = song.duration;
                } else {
                    this.duration = song.is_radio ? Infinity : 0;
                }
                this.currentTime = 0;
                this.progressPercent = 0;

                // UI updates in next tick to avoid blocking audio start
                this.$nextTick(async () => {
                    if (this.isMobileMode) {
                        // On mobile, we only show the cover if it actually exists
                        this.showCoverImage = song && !this.songsWithNoCover.has(song.id);
                    } else {
                        this.showCoverImage = true;
                    }

                    this.updateUrl();
                    this.updateMediaSession();

                    this.$nextTick(() => {
                        this.updateMarquees();
                    });

                    if (shouldScroll) { this.scrollSongIntoView(song.id); }
                    this.fetchLyrics(song);
                });
            }
        },
        async playAudio(options = {}) {
            const manualSelection = options.manualSelection || false;
            const isNewPlay = options.isNewPlay || false;

            if (!this.currentSong) return;

            const audio = this.getActivePlayer();
            const songToPlayId = this.currentSong.id;

            if (!audio) {
                console.error("Audio element not found");
                this.showNotification('Audio player not available.', 'error');
                return;
            }
            if (this.currentSong && !this.currentSong.is_radio && !audio.src) {
                audio.src = '/audio/' + this.currentSong.id;
                audio.load();
            }

            const targetTime = this.autoplayStartTime;
            if (targetTime > 0 && !this.currentSong.is_radio) {
                audio.muted = true;
                try {
                    // Mute + Play + Pause + Seek
                    await audio.play();
                    audio.pause();
                    audio.currentTime = targetTime;
                } catch (e) {}
            }

            try {
                await audio.play();

                if (!this.currentSong || this.currentSong.id !== songToPlayId) { return; }

                if (targetTime > 0 && !this.currentSong.is_radio) {
                    this.autoplayStartTime = 0;
                    // Check position immediately after play()
                    if (audio.currentTime < targetTime - 1) {
                        audio.currentTime = targetTime;
                    }
                    this.updateProgress();
                    // Final check and unmute after a short delay
                    setTimeout(() => {
                        if (audio.currentTime < targetTime - 1) {
                            audio.currentTime = targetTime;
                        }
                        this.updateProgress();
                        audio.muted = this.muted;
                    }, 150);
                }

                if (isNewPlay && !this.currentSong.is_radio) {
                    this.updateSongStats(this.currentSong.id, 'play');
                    // Reset background speed measurement for the new song
                    this._speedMeasureStart = Date.now();
                }

                if (this.streamLoadTimeout) {
                    clearTimeout(this.streamLoadTimeout);
                    this.streamLoadTimeout = null;
                }
                this.isPlaying = true; this.discVisible = true; this.audioUnlocked = true; this.preloadingSongId = null;
                if (this.isMobileDevice) { this.userPausedDisc = false; }
                if (this.currentSong && !manualSelection) { this.scrollSongIntoView(this.currentSong.id); }

                // Preload next song in background after current one starts
                setTimeout(() => this.preloadNextSong(), 5000);
            } catch (e) {
                audio.muted = this.muted;
                if (e.name === 'AbortError') {
                    // This is a common and often benign error when a play() request is interrupted by another action (like loading a new song).
                    // We can safely ignore it to prevent console noise.
                    return;
                }
                if (!this.currentSong || this.currentSong.id !== songToPlayId) {
                    console.warn(`Playback for song ${songToPlayId} was aborted by a new request.`);
                    return;
                }

                this.isPlaying = false; this.preloadingSongId = null;
                const timeSinceLastRequest = this.lastSongRequestTime ? Date.now() - this.lastSongRequestTime : (window.SWP_CONFIG.ignore_playback_errors_ms + 1);
                if (timeSinceLastRequest < window.SWP_CONFIG.ignore_playback_errors_ms) {
                    // This is likely due to quickly changing songs. User interrupted the last play action.
                    // We can ignore this error and not show a notification.
                    console.warn("Playback error suppressed, likely due to rapid song switching.", e);
                } else {
                    console.error("Audio playback error:", e, {
                        currentSong: JSON.parse(JSON.stringify(this.currentSong || {})),
                        activePlayerSrc: audio.src,
                        audioError: audio.error
                    });
                    this.showNotification('An error occurred during playback.', 'error');
                }
            }
        },
        async updateMediaSession() {
            if (!('mediaSession' in navigator)) {
                return;
            }

            const oldBlobUrl = this.currentArtworkBlobUrl;
            this.currentArtworkBlobUrl = null;

            if (!this.currentSong) {
                navigator.mediaSession.metadata = null;
                navigator.mediaSession.playbackState = 'none';
                if (oldBlobUrl) {
                    // Use a timeout to ensure the system has released the blob before revoking.
                    setTimeout(() => URL.revokeObjectURL(oldBlobUrl), 1000);
                }
                return;
            }

            const artwork = [];
            let newBlobUrl = null;
            if (this.enableCoverArt && this.currentSong && !this.currentSong.is_radio && !this.songsWithNoCover.has(this.currentSong.id)) {
                const coverUrl = new URL(`/cover/${this.currentSong.id}`, window.location.origin).href;
                try {
                    const response = await fetch(coverUrl);
                    if (response.ok) {
                        const blob = await response.blob();
                        // Don't create a blob for the placeholder SVG
                        if (blob.type && !blob.type.includes('svg')) {
                            newBlobUrl = URL.createObjectURL(blob);
                            artwork.push({ src: newBlobUrl, sizes: '512x512', type: blob.type });
                        }
                    }
                } catch (e) {
                    console.error('Failed to fetch cover art for media session:', e);
                }
            }

            this.currentArtworkBlobUrl = newBlobUrl;

            navigator.mediaSession.metadata = new MediaMetadata({
                title: this.currentSong.title,
                artist: this.currentSong.artist,
                album: this.currentSong.album,
                artwork: artwork
            });

            if (oldBlobUrl) {
                // Use a timeout to ensure the system has released the blob before revoking.
                setTimeout(() => URL.revokeObjectURL(oldBlobUrl), 1000);
            }
        },
        async handleAudioError(playerRef) {
            const player = playerRef === 'A' ? this.playerA : this.playerB;
            if (!player || !player.error) return;

            // During crossfade, errors on the outgoing (now inactive) player can be ignored.
            if (playerRef !== this.activePlayerRef) {
                // When changing song manually, the src of inactive player is cleared, which can cause a benign error.
                // We can safely ignore all errors on the inactive player.
                return;
            }

            // Suppress errors if they happen within a short time of a song change,
            // as they are likely due to the user interrupting playback (e.g., aborted request).
            const timeSinceLastRequest = this.lastSongRequestTime ? Date.now() - this.lastSongRequestTime : (window.SWP_CONFIG.ignore_playback_errors_ms + 1);
            if (timeSinceLastRequest < window.SWP_CONFIG.ignore_playback_errors_ms) {
                return;
            }

            const audioSrc = player.currentSrc || player.src;
            if (audioSrc && !audioSrc.startsWith('blob:')) {
                try {
                    const response = await fetch(audioSrc, { method: 'HEAD' });
                    if (!response.ok) {
                        let errorMsgHeader = response.headers.get('X-Error-Notification');
                        if (errorMsgHeader) {
                            const originalErrorMsg = decodeURIComponent(errorMsgHeader);
                            let displayErrorMsg = originalErrorMsg;
                            // Make generic messages unique by appending song details, if available.
                            if (this.currentSong && this.currentSong.title && originalErrorMsg.includes('Song not found')) {
                                displayErrorMsg = `Playback error: Song "${this.currentSong.title}" not found`;
                            }
                            this.showNotification(displayErrorMsg, 'error', null, 0, originalErrorMsg);
                        } else {
                            this.showNotification(`Playback error: Could not load song (HTTP ${response.status})`, 'error');
                        }
                    } else {
                        // The audio element failed, but a HEAD request to the same URL was successful.
                        // This likely indicates a transient network error or a browser-cancelled request.
                        // We will log it but not show a user-facing error to avoid confusion.
                    }
                } catch (e) {
                    console.error("Error during handleAudioError's HEAD request:", e, { audioSrc: audioSrc });
                    this.showNotification('Playback error: Network issue prevented loading song.', 'error');
                } finally {
                    // No checkDbStatus() here
                }
            } else {
                 console.error("An error occurred during playback. audioSrc was empty or a blob.", { audioSrc: audioSrc, currentSong: JSON.parse(JSON.stringify(this.currentSong || {})) });
                 this.showNotification('An error occurred during playback.', 'error');
            }
            this.isPlaying = false;
            this.preloadingSongId = null;
        },
        onLoadedMetadata(event, playerRef) {
            if (!event || !event.target) return;
            // Fix: Allow duration update if it's the active player OR the song we are currently trying to play.
            // This ensures duration is captured even if the player isn't fully 'active' yet during autoplay attempts.
            if (playerRef !== this.activePlayerRef && !(this.currentSong && event.target.src.includes(this.currentSong.id))) return;

            const d = event.target.duration;
            if (!isNaN(d) && d > 0) {
                this.duration = (this.currentSong && this.currentSong.is_radio) ? Infinity : d;
                if (this.currentSong) {
                    this.currentSong.duration = this.currentSong.is_radio ? 999999999 : d;
                }
            }
            if (this.currentSong) {
                this.currentSong.duration = this.currentSong.is_radio ? 999999999 : this.duration;
            }
            // If we have a target start time, set it immediately on metadata load.
            // This is the earliest possible moment to seek.
            if (this.autoplayStartTime > 0 && !this.currentSong.is_radio) {
                event.target.currentTime = this.autoplayStartTime;
            }
        },
        async confirmAutoplay() {
            this.showAutoplayModal = false;
            this.audioUnlocked = true;

            if (this.currentSong) {
                const audio = this.getActivePlayer();

                const targetTime = this.autoplayStartTime;
                if (targetTime > 0 && !this.currentSong.is_radio) {
                    audio.muted = true;
                    try {
                        // Mute + Play + Pause + Seek
                        await audio.play();
                        audio.pause();
                        audio.currentTime = targetTime;
                    } catch (e) {}
                }

                try {
                    await audio.play();
                    if (targetTime > 0 && !this.currentSong.is_radio) {
                        this.autoplayStartTime = 0;
                        // Check position immediately after play()
                        if (audio.currentTime < targetTime - 1) {
                            audio.currentTime = targetTime;
                        }
                        this.updateProgress();
                        // Final check and unmute after a short delay
                        setTimeout(() => {
                            if (audio.currentTime < targetTime - 1) {
                                audio.currentTime = targetTime;
                            }
                            this.updateProgress();
                            audio.muted = this.muted;
                        }, 150);
                    }
                    this.isCrossfading = false;
                    this.isPlaying = true;
                    this.discVisible = true;
                    this.audioUnlocked = true;
                    this.preloadingSongId = null;
                    this.isAttemptingAutoplay = false;

                    if (!this.currentSong.is_radio) {
                        this.updateSongStats(this.currentSong.id, 'play');
                    }
                    if (this.currentSong) { this.scrollSongIntoView(this.currentSong.id); }

                    // Clean up URL params now that user has committed to playing
                    const url = new URL(window.location.href);
                    url.searchParams.delete('t');
                    history.replaceState({}, '', url.toString());
                } catch (error) {
                    console.error("Autoplay confirmation failed:", error);
                    this.showNotification('An error occurred during playback.', 'error');
                    this.isPlaying = false;
                    this.preloadingSongId = null;
                    this.isAttemptingAutoplay = false;
                }
            }
        },
        cancelAutoplay() {
            this.showAutoplayModal = false;
            this.currentSong = null;
            this.currentSongIndex = -1;
            this.isAttemptingAutoplay = false;
            this.updateUrl();
        },
        async checkCoverArtExists(songId) {
            if (this.songsWithNoCover.has(songId)) {
                return false;
            }
            try {
                const response = await fetch(`/api/cover_exists/${songId}`);
                if (!response.ok) {
                    // Server error, assume no cover to be safe
                    this.songsWithNoCover.add(songId);
                    return false;
                }
                const data = await response.json();
                if (data.exists) {
                    return true;
                } else {
                    this.songsWithNoCover.add(songId);
                    return false;
                }
            } catch (e) {
                console.error('Failed to check for cover art:', e);
                this.songsWithNoCover.add(songId); // Assume no cover on network error
                return false;
            }
        },
        async playSong(index, manualSelection = false, fromPrev = false, event = null) {
            // FIX: Cancel pending stopSong timeout to prevent state corruption
            if (this.stopTimeout) {
                clearTimeout(this.stopTimeout);
                this.stopTimeout = null;
                this.isStopping = false;
            }

            if (manualSelection) {
                this.autoplayStartTime = 0;
                this.isAttemptingAutoplay = false;
            }
            if (manualSelection && this.isPlaying && this.currentSong && !this.currentSong.is_radio) {
                const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
                const clickedSong = list[index];
                if (clickedSong && this.currentSong.id !== clickedSong.id) {
                    this.updateSongStats(this.currentSong.id, 'skip');
                }
            }

            if (manualSelection && event && event.currentTarget) {
                const row = event.currentTarget;
                row.classList.add('song-clicked-animation');
                // Use a 'animationend' listener for cleanup to respect animation duration,
                // including if it's disabled via CSS (animation-duration: 0s).
                row.addEventListener('animationend', () => {
                    row.classList.remove('song-clicked-animation');
                }, { once: true });
            }
            this._cancelPendingFetches();

            const list = this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs;
            const clickedSong = list[index];

            // Only clear lyrics if a new song is being played or if there was no current song
            if (!this.currentSong || (clickedSong && this.currentSong.id !== clickedSong.id)) {
                this.lyricsModalContent = '';
                this.lyricsLines = [];
                this.lyricsLineElements = [];
                this.userScrolledLyrics = false;
            }

            this.currentTime = 0;
            this.progressPercent = 0;

            // Only reset players if EQ is enabled to avoid breaking the audio graph,
            // otherwise keep them to preserve pre-cached buffers for instant swap.
            if (this.enableEqualizer) {
                this.playerA.pause();
                this.playerB.pause();
                this.playerA.removeAttribute('src');
                this.playerA.load();
                this.playerB.removeAttribute('src');
                this.playerB.load();
            }

            this.lastSongRequestTime = Date.now();
            if (this.currentSong && clickedSong && this.currentSong.id === clickedSong.id) {
                this.userPausedDisc = false;
                if (manualSelection) {
                    // If song is already playing, restart it.
                    if (this.currentSong.is_radio) {
                        const audio = this.getActivePlayer();
                        // Re-load the stream to start fresh
                        audio.src = 'about:blank';
                        audio.pause();
                        audio.src = this.currentSong.location + "?" + Math.floor((Math.random() * 10000) + 1);
                        audio.load();
                        this.playAudio({ manualSelection: true });
                    } else {
                        this.getActivePlayer().currentTime = 0;
                        this.playAudio({ manualSelection: true });
                    }
                }
                return;
            }
            if (!clickedSong) { return; }

            this.duration = clickedSong.is_radio ? Infinity : 0;


            this.preloadingSongId = clickedSong.id;

            // Start cover check in background, don't block audio
            if (!clickedSong.is_radio) {
                this.checkCoverArtExists(clickedSong.id).then(exists => {
                    if (this.currentSong && this.currentSong.id === clickedSong.id) {
                        if (this.isMobileMode) {
                            this.showCoverImage = exists;
                        }
                    }
                });
            }

            if (!fromPrev && this.currentSongIndex > -1) { this.playHistory.push(this.currentSongIndex); }

            this.sidebarsHiddenOnMobileSearch = false;

            // Update state asynchronously to keep UI responsive
            this.selectSong(index, false);

            if (clickedSong) {
                const targetSrc = '/audio/' + this.currentSong.id;
                const inactivePlayer = this.getInactivePlayer();
                let audio = this.getActivePlayer();

                // Instant swap if pre-cached in the other player
                // We check if the inactive player has the correct song ID in its source
                const isPrecached = !this.currentSong.is_radio &&
                                   inactivePlayer.src &&
                                   (inactivePlayer.src.includes(this.currentSong.id) ||
                                    (inactivePlayer._cachedSongId === this.currentSong.id));

                if (isPrecached) {
                    this.activePlayerRef = this.activePlayerRef === 'A' ? 'B' : 'A';
                    audio = this.getActivePlayer();
                    // If we swapped, the other player (now inactive) should be paused
                    this.getInactivePlayer().pause();
                } else {
                    audio.pause();
                    if (this.currentSong.is_radio) {
                        audio.src = this.currentSong.location + "?" + Math.floor((Math.random() * 10000) + 1);
                    } else {
                        audio.src = targetSrc;
                    }
                    audio.load();
                }

                audio.playbackRate = this.playbackRate;
                this.playAudio({ manualSelection: manualSelection, isNewPlay: true });
            } else {
                this.preloadingSongId = null;
            }
        },
        attemptAutoplayAfterLoad() {
            if (!this.currentSong) {
                this.isAttemptingAutoplay = false;
                return;
            }
            if (this.currentSong.is_radio) {
                this.duration = Infinity;
            }
            const audio = this.getActivePlayer();
            if (this.currentSong.is_radio) {
                audio.src = this.currentSong.location + "?" + Math.floor((Math.random() * 10000) + 1);
            } else {
                audio.src = '/audio/' + this.currentSong.id;
            }
            audio.load();

            const savedPlaybackState = sessionStorage.getItem('playbackState');
            if (savedPlaybackState === 'paused') {
                // Song is loaded, but we honor the paused state and don't play.
                this.isAttemptingAutoplay = false;
                this.preloadingSongId = null;
                this.isPlaying = false;
                audio.addEventListener('loadedmetadata', () => {
                    this.duration = audio.duration || 0;
                    if (isNaN(this.duration)) this.duration = 0;
                    if (this.autoplayStartTime > 0) {
                        audio.currentTime = this.autoplayStartTime;
                        this.updateProgress();
                        this.autoplayStartTime = 0;
                        const url = new URL(window.location.href);
                        url.searchParams.delete('t');
                        history.replaceState({}, '', url.toString());
                    }
                }, { once: true });
                return;
            }

            const autoplayHandler = async () => {
                this.duration = audio.duration || 0;
                if (isNaN(this.duration)) this.duration = 0;

                // On mobile, browsers strictly block autoplay with sound.
                // To avoid a "silent play" state, we force the manual confirmation modal.
                if (this.isMobileDevice) {
                    this.preloadingSongId = null;
                    this.showAutoplayModal = true;
                    return;
                }

                const targetTime = this.autoplayStartTime;
                if (targetTime > 0 && !this.currentSong.is_radio) {
                    audio.muted = true;
                    audio.currentTime = targetTime;
                }

                try {
                    await audio.play();
                    if (targetTime > 0 && !this.currentSong.is_radio) {
                        // Force seek immediately after play starts
                        audio.currentTime = targetTime;

                        // Add a one-time listener to ensure we seek again once playing starts
                        this._currentSyncSeek = () => {
                            if (this.autoplayStartTime > 0) {
                                audio.currentTime = targetTime;
                                audio.muted = this.muted;
                                this.autoplayStartTime = 0;
                                this.updateProgress();
                            }
                        };
                        audio.addEventListener('playing', this._currentSyncSeek, { once: true });

                        // Final check and unmute after a short delay
                        setTimeout(() => {
                            if (this.autoplayStartTime > 0) {
                                audio.currentTime = targetTime;
                                audio.muted = this.muted;
                                this.autoplayStartTime = 0;
                                this.updateProgress();
                            }
                        }, 150);
                    }
                    // Autoplay Succeeded
                    this.isPlaying = true;
                    this.discVisible = true;
                    this.audioUnlocked = true;
                    this.preloadingSongId = null;
                    this.isAttemptingAutoplay = false;

                    if (!this.currentSong.is_radio) {
                        this.updateSongStats(this.currentSong.id, 'play');
                    }

                    const url = new URL(window.location.href);
                    url.searchParams.delete('t');
                    history.replaceState({}, '', url.toString());

                } catch (err) {
                    if (err.name === 'NotAllowedError') {
                        // Keep isAttemptingAutoplay true and keep autoplayStartTime
                        // so the next user click triggers the seek logic
                        this.preloadingSongId = null;
                        this.showAutoplayModal = true;
                    } else {
                        this.isAttemptingAutoplay = false;
                        console.error("Autoplay failed with an unexpected error:", err, {
                            currentSong: JSON.parse(JSON.stringify(this.currentSong || {}))
                        });
                        this.handleAudioError(this.activePlayerRef);
                    }
                }
            };

            audio.addEventListener('loadedmetadata', autoplayHandler, { once: true });
            audio.addEventListener('error', () => {
                audio.removeEventListener('loadedmetadata', autoplayHandler);
                this.isAttemptingAutoplay = false;
                this.preloadingSongId = null;
                this.handleAudioError(this.activePlayerRef);
            }, { once: true });
        },
        playNext(isManual = false) {
            const list = this.shuffle === 'random' ? this.allSongs : (this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs);
            if (!this.currentSong || list.length === 0) return;

            const isLastSong = this.currentSongIndex >= list.length - 1;
            if (isLastSong && this.repeat === 'off') {
                if (!isManual) {
                    this.isPlaying = false;
                }
                return;
            }

            if (isManual && this.isPlaying && !this.currentSong.is_radio) {
                this.updateSongStats(this.currentSong.id, 'skip');
            }

            localStorage.removeItem('playbackPosition');
            if (this.repeat === 'one') {
                this.playSong(this.currentSongIndex);
                return;
            }

            const nextIndex = (this.currentSongIndex + 1) % list.length;
            this.playSong(nextIndex);
        },
        playPrev() {
            const list = this.shuffle === 'random' ? this.allSongs : (this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs);
            if (!this.currentSong || list.length === 0) return;

            if (this.isPlaying && !this.currentSong.is_radio && this.currentTime < window.SWP_CONFIG.previous_button_restart_seconds) {
                this.updateSongStats(this.currentSong.id, 'skip');
            }

            if (this.currentTime > window.SWP_CONFIG.previous_button_restart_seconds || this.playHistory.length === 0) {
                 this.logAction('Action: Restarting song');
                 const audio = this.getActivePlayer();
                 if (audio) audio.currentTime = 0;
                 this.updateProgress();
                 return;
            }
            const prevIndex = this.playHistory.pop();
            // Ensure the index is still valid for the current list
            if (prevIndex >= 0 && prevIndex < list.length) {
                this.playSong(prevIndex, false, true);
            } else {
                this.playSong(0, false, true);
            }
        },
        updateProgress() {
            const audio = this.getActivePlayer();
            if (!audio) return;

            // Background speed measurement: check if the whole song is buffered
            if (this._speedMeasureStart && this.currentSong && !this.currentSong.is_radio && audio.buffered.length > 0) {
                const bufferedEnd = audio.buffered.end(audio.buffered.length - 1);
                if (bufferedEnd >= audio.duration * 0.95) { // 95% buffered is enough to measure
                    const durationSecs = (Date.now() - this._speedMeasureStart) / 1000;
                    if (durationSecs > 1) {
                        // Heuristic: bitrate (kbps) * duration / time_to_download
                        const bitrate = parseInt(this.currentSong.bitrate) || 192;
                        const estimatedMbps = (bitrate * audio.duration) / (durationSecs * 1024);
                        this.networkSpeed = (this.networkSpeed * 0.8) + (estimatedMbps * 0.2);
                        localStorage.setItem('networkSpeed', this.networkSpeed.toFixed(2));
                        this._speedMeasureStart = null; // Done measuring for this song
                    }
                }
            }
            // Prevent UI jumping to 0 during initial autoplay seek
            if (this.autoplayStartTime > 0 && (audio.currentTime === 0 || audio.seeking)) return;

            this.currentTime = audio.currentTime || 0;
            this.progressPercent = (this.duration > 0) ? (this.currentTime / this.duration) * 100 : 0;

            // FIX: Throttle localStorage writes to avoid UI blocking (once every 5 seconds)
            const now = Date.now();
            if (this.currentSong && this.isPlaying && !this.isAttemptingAutoplay && (now - this._lastPlaybackSaveTime > 5000)) {
                this._lastPlaybackSaveTime = now;
                try {
                    const playbackData = {
                        songId: this.currentSong.id,
                        currentTime: this.currentTime,
                        timestamp: Date.now()
                    };
                    localStorage.setItem('playbackPosition', JSON.stringify(playbackData));
                } catch (e) {
                    console.error('Failed to save playback position:', e);
                }
            }

            if ('mediaSession' in navigator && navigator.mediaSession.metadata) {
                if (this.currentSong && !this.currentSong.is_radio) {
                    if (isFinite(this.duration) && this.duration > 0 && this.currentTime <= this.duration) {
                        navigator.mediaSession.setPositionState({
                            duration: this.duration,
                            playbackRate: this.playbackRate,
                            position: this.currentTime
                        });
                    }
                } else {
                    navigator.mediaSession.setPositionState(null);
                }
            }

            // Preload next song 10s before end
            if (this.duration > 0 && (this.duration - this.currentTime) <= 10) {
                this.preloadNextSong();
            }

            if (this.duration > 0 && (this.duration - this.currentTime < 0.25) && this.isPlaying) {
                this.playNext(false);
            }
        },
        seek(event) {
            const audio = this.getActivePlayer();
            if (!audio || !event || !event.target) return;
            audio.currentTime = parseFloat(event.target.value) || 0;
        },
        changeVolume(event) {
            if (!event || !event.target) return;
            const newVol = parseFloat(event.target.value) || 0;
            this.volume = newVol;
            this.muted = newVol === 0;
        },
        updateVolumeTooltip(event) {
            if (this.showVolumeTooltip) {
                if (!event || !event.target) return;
                const newVol = parseFloat(event.target.value) || 0;
                this.volume = newVol;
                this.muted = newVol === 0;
            }
        },
        adjustVolumeWithWheel(event) {
            if (!event) return;
            event.preventDefault();
            const delta = event.deltaY > 0 ? -0.05 : 0.05;
            this.volume = Math.min(1, Math.max(0, (this.volume || 0) + delta));
            this.muted = this.volume === 0;

            // Show tooltip while adjusting
            this.showVolumeTooltip = true;
            if (this.volumeTooltipTimer) clearTimeout(this.volumeTooltipTimer);
            this.volumeTooltipTimer = setTimeout(() => {
                this.showVolumeTooltip = false;
            }, 1000);
        },
        adjustProgressWithWheel(event) {
            if (!event) return;
            event.preventDefault();
            const audio = this.getActivePlayer();
            if (!audio) return;
            const delta = event.deltaY > 0 ? -5 : 5;
            audio.currentTime = Math.min(this.duration || 0, Math.max(0, (audio.currentTime || 0) + delta));
        },
        async sortBy(column) {
            this.shuffle = 'off';
            this.shuffleSeed = null;
            this.allSongs = [];
            this.libraryPageToLoad = 1;
            this.displayLimit = this.isMobileMode ? window.SWP_CONFIG.initial_songs_to_load_mobile : window.SWP_CONFIG.initial_songs_to_load_desktop;

            if (this.sortCol === column) {
                this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortCol = column;
                this.sortDir = 'asc';
            }

            // Always fetch sorted results from server
            await this.fetchSongs(1, false);
            this.updateUrl();
        },
        async clearPlaylists() {
            this.logAction('Action: View All Tracks (cleared playlist filters)');
            this.selectedPlaylists = [];
            await this.fetchSidebarData();
            await this.fetchSongs();
            this.updateUrl();
        },
        async togglePlaylist(name, event) {
            const isExclusive = event && event.altKey;
            if (isExclusive) {
                if (this.selectedPlaylists.length === 1 && this.selectedPlaylists[0] === name) {
                    this.selectedPlaylists = [];
                } else {
                    this.selectedPlaylists = [name];
                }
            } else {
                const index = this.selectedPlaylists.indexOf(name);
                if (index > -1) {
                    this.selectedPlaylists.splice(index, 1);
                } else {
                    this.selectedPlaylists.push(name);
                }
            }
            this.logAction(`Playlists updated: "${this.selectedPlaylists.join(', ')}"`);
            await this.fetchSidebarData();
            await this.fetchSongs();
            this.updateUrl();
        },
        async clearGenres() {
            this.logAction('Action: View All Genres (cleared genre filters)');
            this.selectedGenres = [];
            await this.fetchSidebarData();
            await this.fetchSongs();
            this.updateUrl();
        },
        async toggleGenre(name, event) {
            const isExclusive = event && event.altKey;
            if (isExclusive) {
                if (this.selectedGenres.length === 1 && this.selectedGenres[0] === name) {
                    this.selectedGenres = [];
                } else {
                    this.selectedGenres = [name];
                }
            } else {
                const index = this.selectedGenres.indexOf(name);
                if (index > -1) {
                    this.selectedGenres.splice(index, 1);
                } else {
                    this.selectedGenres.push(name);
                }
            }
            this.logAction(`Genres updated: "${this.selectedGenres.join(', ')}"`);
            await this.fetchSidebarData();
            await this.fetchSongs();
            this.updateUrl();
        },
        async clearArtists() {
            this.logAction('Action: View All Artists (cleared artist filters)');
            this.selectedArtists = [];
            await this.fetchSongs();
            this.updateUrl();
        },
        async toggleArtist(name, event) {
            const isExclusive = event && event.altKey;
            if (isExclusive) {
                if (this.selectedArtists.length === 1 && this.selectedArtists[0] === name) {
                    this.selectedArtists = [];
                } else {
                    this.selectedArtists = [name];
                }
            } else {
                const index = this.selectedArtists.indexOf(name);
                if (index > -1) {
                    this.selectedArtists.splice(index, 1);
                } else {
                    this.selectedArtists.push(name);
                }
            }
            this.logAction(`Artists updated: "${this.selectedArtists.join(', ')}"`);
            await this.fetchSongs();
            this.updateUrl();
        },
        async clearAlbums() {
            this.logAction('Action: View All Albums (cleared album filters)');
            this.selectedAlbums = [];
            await this.fetchSongs();
            this.updateUrl();
        },
        async toggleAlbum(name, event) {
            const isExclusive = event && event.altKey;
            if (isExclusive) {
                if (this.selectedAlbums.length === 1 && this.selectedAlbums[0] === name) {
                    this.selectedAlbums = [];
                } else {
                    this.selectedAlbums = [name];
                }
            } else {
                const index = this.selectedAlbums.indexOf(name);
                if (index > -1) {
                    this.selectedAlbums.splice(index, 1);
                } else {
                    this.selectedAlbums.push(name);
                }
            }
            this.logAction(`Albums updated: "${this.selectedAlbums.join(', ')}"`);
            await this.fetchSongs();
            this.updateUrl();
        },
        toggleShuffle() {
            this.playHistory = [];
            let shuffleState;

            if (this.shuffle === 'off') {
                this.shuffle = 'list';
                shuffleState = 'list';
                this.shuffleSeed = Math.floor(Math.random() * 1000000);
                this.sortCol = ''; // shuffling overrides sorting
                this.sortDir = 'asc';
            } else if (this.shuffle === 'list') {
                this.shuffle = 'random';
                shuffleState = 'random';
                this.shuffleSeed = null;
            } else { // 'random'
                this.shuffle = 'off';
                shuffleState = 'off';
                this.shuffleSeed = null;
                this.sortCol = window.SWP_CONFIG.default_sort_by; // revert to default sort
                this.sortDir = window.SWP_CONFIG.default_sort_order;
            }
            this.logAction(`Action: Toggle shuffle to ${shuffleState}`);

            this.allSongs = [];
            this.libraryPageToLoad = 1;
            this.displayLimit = this.isMobileMode ? window.SWP_CONFIG.initial_songs_to_load_mobile : window.SWP_CONFIG.initial_songs_to_load_desktop;
            this.updateUrl();
            this.fetchSongs(1, false);
        },

        toggleMute() {
            if (this.muted) {
                this.volume = this.previousVolume;
                this.muted = false;
            } else {
                this.previousVolume = this.volume;
                this.volume = 0;
                this.muted = true;
            }
        },
        cyclePlaybackRate() {
            let currentIndex = this.playbackRates.indexOf(this.playbackRate);
            if (currentIndex === -1) {
                const closest = this.playbackRates.reduce((prev, curr) => (Math.abs(curr - this.playbackRate) < Math.abs(prev - this.playbackRate) ? curr : prev));
                currentIndex = this.playbackRates.indexOf(closest);
            }
            const nextIndex = (currentIndex + 1) % this.playbackRates.length;
            this.playbackRate = this.playbackRates[nextIndex];
        },
        adjustUiScaleWithWheel(event) {
            event.preventDefault();
            const delta = event.deltaY > 0 ? -0.05 : 0.05;
            this.uiScale = Math.min(2.0, Math.max(0.5, this.uiScale + delta));
        },
        adjustPlaybackRateWithWheel(event) {
            event.preventDefault();
            const delta = event.deltaY > 0 ? -0.1 : 0.1;
            let newRate = this.playbackRate + delta;
            newRate = Math.max(0.5, Math.min(3.0, newRate));
            this.playbackRate = parseFloat(newRate.toFixed(1));
        },
        resetView(scrollTop = true) {
            if (this.menuPopup) this.menuPopup.hide();
            this.playHistory = []; this.displayLimit = this.isMobileMode ? window.SWP_CONFIG.initial_songs_to_load_mobile : window.SWP_CONFIG.initial_songs_to_load_desktop;
            if (this.shuffle !== 'off') {
                this.$nextTick(() => this.currentPlaylist = this.filteredSongs);
            }
            if (scrollTop) { this.$nextTick(() => { if (this.$refs.songListContainer) { this.$refs.songListContainer.scrollTop = 0; } }); }
        },
        handleScroll(e) {
            const el = e.target;
            // Trigger when user is within 1000px of the bottom
            if (el.scrollHeight - el.scrollTop - el.clientHeight < 1000) {
                if (this.displayLimit < this.filteredSongs.length) {
                    this.displayLimit += this.displayIncrement;
                } else if (!this.isLoadingMoreSongs && this.allSongs.length < this.displayedSongCount) {
                    // We've displayed everything we have locally, so fetch more from server.
                    this.loadMoreSongs();
                }
            }
        },
        async loadMoreSongs() {
            if (this.isLoadingMoreSongs || this.allSongs.length >= this.displayedSongCount) {
                this.isLoadingMoreSongs = false;
                return;
            }
            await this.fetchSongs(this.libraryPageToLoad, true);
        },
        toggleRepeat() {
            if (this.repeat === 'off') { this.repeat = 'all'; } else if (this.repeat === 'all') { this.repeat = 'one'; } else { this.repeat = 'off'; }
            localStorage.setItem('repeat', this.repeat);
            this.logAction(`Action: Toggle repeat to ${this.repeat}`);
        },
        scrollSongIntoView(songId, behavior = 'smooth') {
            // If song is not in DOM, increase displayLimit
            const list = this.shuffle === 'random' ? this.allSongs : (this.shuffle !== 'off' ? this.currentPlaylist : this.filteredSongs);
            const index = list.findIndex(s => s && s.id === songId);
            if (index !== -1 && index >= this.displayLimit) {
                this.displayLimit = index + this.displayIncrement;
            }

            const songRow = document.getElementById('song-row-' + songId);
            if (songRow && this.$refs.songListContainer) {
                const container = this.$refs.songListContainer;
                const containerRect = container.getBoundingClientRect();
                const songRowRect = songRow.getBoundingClientRect();
                // vertical alignement of the selected song row within the container
                const desiredTop = containerRect.top + (container.clientHeight * (this.isMobileMode ? window.SWP_CONFIG.scroll_to_song_align_mobile : window.SWP_CONFIG.scroll_to_song_align_desktop));
                const scrollAmount = songRowRect.top - desiredTop;
                container.scrollBy({ top: scrollAmount, behavior: behavior });
                return true;
            }
            return false;
        },
        async showFullscreenCoverForSong(song) {
            if (!song || !song.id || song.is_radio) return;

            if (this.songsWithNoCover.has(song.id)) {
                this.fullscreenCoverSong = song;
                if (this.isMobileMode) { this.fullscreenCoverVisible = true; }
                else { this.fullscreenDesktopCoverVisible = true; }
                return;
            }

            // If we are selecting the cover for the currently playing song,
            // we can take a shortcut if its cover is already loaded and visible.
            if (this.currentSong && this.currentSong.id === song.id && this.showCoverImage) {
                this.fullscreenCoverSong = song;
                if (this.isMobileMode) { this.fullscreenCoverVisible = true; }
                else { this.fullscreenDesktopCoverVisible = true; }
                return;
            }

            this.viewLoading = true;
            const coverExists = await this.checkCoverArtExists(song.id);
            this.viewLoading = false;

            if (coverExists) {
                // Cover exists. Set it for the fullscreen view.
                this.fullscreenCoverSong = song;

                // Show the fullscreen view.
                if (this.isMobileMode) {
                    this.fullscreenCoverVisible = true;
                } else {
                    this.fullscreenDesktopCoverVisible = true;
                }
            }
        },
        openInNewTab(type, value) {
            const url = new URL(window.location.origin + window.location.pathname);
            if (type === 'playlists') {
                url.searchParams.set('playlists', value);
            } else if (type === 'genres') {
                url.searchParams.set('genres', value);
            }
            window.open(url.toString(), '_blank');
        },
        downloadSong(song) {
            if (!song) return;
            if (song.is_radio) {
                this.showNotification('Cannot download a radio stream.', 'warning');
                return;
            }
            const link = document.createElement('a');
            link.href = `/audio/${song.id}?download=1`;
            let filename = `${song.title} - ${song.artist}`;
            if (song.album && song.album !== '') {
                filename += ` - ${song.album}`;
            }
            const match = song.location.match(/\.([^.]+)$/);
            const extension = match ? match[1] : 'mp3';
            link.download = `${filename}.${extension}`;
            document.body.appendChild(link); link.click(); document.body.removeChild(link);
        },
        async stopSong() {
            this._cancelPendingFetches();
            this.isStopping = true;
            this.playerA.pause();
            this.playerB.pause();
            this.isPlaying = false;
            localStorage.removeItem('playbackPosition');
            if (this.currentArtworkBlobUrl) {
                URL.revokeObjectURL(this.currentArtworkBlobUrl);
                this.currentArtworkBlobUrl = null;
            }
            if ('mediaSession' in navigator) {
                navigator.mediaSession.metadata = null;
                navigator.mediaSession.playbackState = 'none';
            }
            const resetState = async () => {
                this.preloadingSongId = null; this.currentSong = null; this.currentSongIndex = -1;
                this.currentTime = 0; this.duration = 0; this.progressPercent = 0;
                this.showCoverImage = false; this.coverArtSong = null; this.ratingFilter = [];
                this.search = ''; this.selectedPlaylists = []; this.selectedGenres = []; this.selectedArtists = []; this.selectedAlbums = [];
                this.shuffle = 'off'; this.sortCol = window.SWP_CONFIG.default_sort_by; this.sortDir = window.SWP_CONFIG.default_sort_order;
                history.pushState({}, '', window.location.pathname);
                await this.fetchSongs();
            };
            if (this.discVisible) {
                this.stopTimeout = setTimeout(() => {
                    this.discVisible = false;
                    setTimeout(() => {
                        resetState();
                        this.isStopping = false;
                    }, 550);
                }, 1000);
            } else {
                await resetState();
                this.isStopping = false;
            }
        },
        async preloadNextSong() {
            const list = this.shuffle === 'random' ? this.allSongs : this.currentPlaylist;
            if (!list || this.currentSongIndex === -1) return;

            const nextIndex = (this.currentSongIndex + 1) % list.length;
            const nextSong = list[nextIndex];

            if (!nextSong || nextSong.is_radio) return;

            const inactivePlayer = this.getInactivePlayer();
            const nextSrc = '/audio/' + nextSong.id;

            // Don't re-cache if already set
            if (inactivePlayer.src.includes(nextSong.id) || inactivePlayer._cachedSongId === nextSong.id) return;

            try {
                const response = await fetch(nextSrc);
                if (!response.ok) return;

                const size = parseInt(response.headers.get('Content-Length')) || 0;
                // Only blob-ify if it's a reasonable size (e.g., < 40MB) to avoid memory issues
                if (size > 0 && size <= 40 * 1024 * 1024) {
                    const blob = await response.blob();
                    if (inactivePlayer.src.startsWith('blob:')) URL.revokeObjectURL(inactivePlayer.src);
                    inactivePlayer.src = URL.createObjectURL(blob);
                    inactivePlayer._cachedSongId = nextSong.id;
                    inactivePlayer.load();
                }
            } catch (e) {
                console.warn("Background preload failed:", e);
            }
        },
        hideFullscreenCover() {
            this.fullscreenCoverVisible = false;
            this.fullscreenDesktopCoverVisible = false;
            setTimeout(() => { 
                if (!this.fullscreenCoverVisible && !this.fullscreenDesktopCoverVisible) {
                    this.fullscreenCoverSong = null; 
                }
            }, 350); // Clear after transition
        },
        showSongMetadata(song) {
            if (!song) return;
            this.metadataSong = song;
            // Initialize the form with a copy of the current song's editable metadata
            this.metadataEditForm = {
                title: song.title || '',
                artist: song.artist || '',
                album: song.album || '',
                genre: song.genre || '',
                year: song.year || '',
                track_number: song.track_number || '',
                rating: song.rating || 0, // Ensure rating is present for the form
                comment: song.comment || '',
                album_artist: song.album_artist || '',
                composer: song.composer || '',
                disc_number: song.disc_number || '',
                play_count: song.play_count || 0,
                skip_count: song.skip_count || 0,
            };
            this.showMetadataModal = true;
        },
        async saveMetadata() {
            if (!this.metadataSong || this.savingMetadata) return;

            const songId = this.metadataSong.id;
            const songToUpdateRef = this.allSongs.find(s => s.id === songId); // Reference to the actual song object in the main array

            const fieldsToUpdate = [];
            const editableFields = ['title', 'artist', 'album', 'genre', 'track_number', 'rating', 'year', 'comment', 'album_artist', 'composer', 'disc_number', 'play_count', 'skip_count'];

            for (const field of editableFields) {
                const newValue = this.metadataEditForm[field];
                const oldValue = this.metadataSong[field] || ''; // metadataSong holds the original values from when the modal opened

                // Only consider string comparison for now, handle numbers by converting to string
                if (String(newValue) !== String(oldValue)) {
                    fieldsToUpdate.push({ field, value: newValue });
                }
            }

            if (fieldsToUpdate.length === 0) {
                this.showMetadataModal = false; // No changes, just close the modal
                return;
            }

            this.savingMetadata = true;
            try {
                let successCount = 0;
                for (const item of fieldsToUpdate) {
                    const res = await fetch(`/api/song/${songId}/update_tag`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ tag_name: item.field, tag_value: item.value })
                    });
                    const data = await res.json();
                    if (res.ok && data.success) {
                        successCount++;
                        // Update local state in allSongs and in the modal's original song (for potential re-edits)
                        if (songToUpdateRef) {
                            songToUpdateRef[item.field] = item.value;
                            if (['title', 'artist', 'album'].includes(item.field)) {
                                delete songToUpdateRef[item.field + '_html'];
                                delete songToUpdateRef['highlighted_' + item.field];
                            }
                        }
                        this.metadataSong[item.field] = item.value; // Update the modal's internal 'original' reference
                    } else {
                        this.showNotification(data.message || `Failed to update ${item.field}.`, "error");
                    }
                }

                if (successCount > 0) {
                    this.showNotification(successCount === fieldsToUpdate.length ? "Metatags updated." : "Some metatags updated.", "success");
                    this.allSongs = [...this.allSongs]; // Trigger full reactivity for song list
                    if (successCount === fieldsToUpdate.length) {
                        this.showMetadataModal = false;
                    }
                }
            } catch (e) {
                console.error("Error saving metadata:", e);
                this.showNotification("An error occurred while saving metatags.", "error");
            } finally {
                this.savingMetadata = false;
            }
        },
        cancelMetadataEditing() {
            this.showMetadataModal = false;
            this.metadataEditForm = {}; // Clear form data on cancel
        },
        copyFilepath() {
            if (this.metadataSong && this.metadataSong.location) {
                this.copyToClipboard(this.metadataSong.location, 'Filepath copied to clipboard!');
            }
        },
        closeMenu(name) {
            if (this.menuPopup) this.menuPopup.hide();
        },
        toggleMenu(name, event) {
            if (this.menuPopup) {
                if (this.menuPopup.isOpen && this.menuPopup.activeMenuId === name) {
                    this.menuPopup.hide();
                } else {
                    const el = document.getElementById('menu-tpl-' + name);
                    if (el) {
                        this.menuPopup.show({
                            menuId: name,
                            anchorEl: event.currentTarget,
                            contentEl: el
                        });
                    }
                }
            }
        },
        openMenu(name, event, data) {
            if (name === 'context') {
                this.menuData = data;
                if (this.menuPopup) {
                    this.menuPopup.show({
                        menuId: 'context',
                        x: event.clientX,
                        y: event.clientY,
                        contentEl: document.getElementById('menu-tpl-context')
                    });
                }
            }
        },
        showSharingNetworkWarning() {
            if (!window.SWP_CONFIG.is_private_network) return;

            const hostname = window.location.hostname;
            const isLocalhost = hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1';

            if (isLocalhost) {
                this.showNotification("This link will only work on THIS computer. To share it with other devices in your local network, use the IP address of this machine instead.", 'warning', null, 10000);
            } else {
                this.showNotification("This link will only work within your local network. To share it with people outside your home, enable the 'Online Server' option in settings.", 'warning', null, 10000);
            }
        },
        async copyToClipboard(text, successMessage = 'Copied to clipboard!') {
            if (navigator.clipboard && window.isSecureContext) {
                try {
                    await navigator.clipboard.writeText(text);
                    this.showNotification(successMessage, 'info');
                } catch (err) {
                    console.error('Failed to copy: ', err);
                    this.showNotification('Clipboard mission aborted.', 'error');
                }
            } else {
                const textArea = document.createElement('textarea');
                textArea.value = text;
                textArea.style.position = 'fixed';
                textArea.style.top = '-9999px';
                textArea.style.left = '-9999px';
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                try {
                    document.execCommand('copy');
                    this.showNotification(successMessage, 'info');
                } catch (err) {
                    console.error('Fallback failed: ', err);
                    this.showNotification('Clipboard mission aborted.', 'error');
                }
                document.body.removeChild(textArea);
            }
        },
        async shareLink(type, value, withTime = false) {
            this.showSharingNetworkWarning();
            let url; let successMessage;
            if (type === 'autoplay') {
                if (!this.currentSong) { this.showNotification("No track is loaded to share.", 'info'); return; }
                url = new URL(window.location.href);
                url.searchParams.delete('song');
                url.searchParams.delete('t');
                if (withTime && this.currentTime > 0) {
                    successMessage = 'Song link with timestamp copied to clipboard!';
                } else {
                    successMessage = 'Song link copied to clipboard!';
                }
                url.searchParams.set('song', this.currentSong.id);
                if (withTime && this.currentTime > 0) {
                    url.searchParams.set('t', Math.floor(this.currentTime));
                }
            } else if (type === 'list') {
                url = new URL(window.location.href); url.searchParams.delete('song'); url.searchParams.delete('t'); successMessage = 'View link copied to clipboard!';
            } else if (type) {
                if (type === 'song') {
                    url = new URL(window.location.href);
                } else {
                    url = new URL(window.location.origin + window.location.pathname);
                }

                if (type === 'song') {
                    url.searchParams.delete('song');
                    url.searchParams.delete('t');
                    if (withTime && this.currentSong && this.currentSong.id === value && this.currentTime > 0) {
                        successMessage = 'Song link with timestamp copied to clipboard!';
                    } else {
                        successMessage = 'Song link copied to clipboard!';
                    }
                    url.searchParams.set('song', value);
                    if (withTime && this.currentSong && this.currentSong.id === value && this.currentTime > 0) {
                        url.searchParams.set('t', Math.floor(this.currentTime));
                    }
                } else if (type === 'playlists') {
                    url.searchParams.set('playlists', value);
                    successMessage = 'Playlist link copied to clipboard!';
                } else if (type === 'genres') {
                    url.searchParams.set('genres', value);
                    successMessage = 'Genre link copied to clipboard!';
                } else if (type === 'library') {
                    successMessage = 'Library link copied to clipboard!';
                }
            } else { url = new URL(window.location.href); url.searchParams.delete('song'); url.searchParams.delete('t'); successMessage = 'View link copied to clipboard!'; }
            await this.copyToClipboard(this.getPrettyUrl(url), successMessage || 'Link copied!');
        },
        positionTooltip(event, selector = '.tooltip', forceLeft = false) {
            const tooltip = event.currentTarget.querySelector(selector);
            // Do not try to position a tooltip that is not visible in the layout
            if (!tooltip || tooltip.offsetParent === null) return;

            // Reset styles to default so we can measure correctly
            tooltip.style.transform = 'translateX(-50%)';
            tooltip.style.top = 'auto';
            tooltip.style.bottom = '100%';
            tooltip.style.left = '50%';
            tooltip.style.marginTop = '0';
            tooltip.style.marginBottom = '0.5rem';

            this.$nextTick(() => {
                const rect = tooltip.getBoundingClientRect();
                const viewportWidth = window.innerWidth;
                const PADDING = 10; // 10px padding from edge of screen

                // Horizontal check
                if (rect.right > viewportWidth - PADDING) {
                    const overflow = rect.right - (viewportWidth - PADDING);
                    tooltip.style.transform = `translateX(calc(-50% - ${overflow + 15}px))`;
                } else if (rect.left < PADDING) {
                    const overflow = PADDING - rect.left;
                    tooltip.style.transform = `translateX(calc(-50% + ${overflow + 15}px))`;
                }

                // Vertical check
                if (rect.top < PADDING) {
                    tooltip.style.top = '100%';
                    tooltip.style.bottom = 'auto';
                    tooltip.style.marginTop = '0.5rem';
                    tooltip.style.marginBottom = '0';
                }
            });
        },
        shareOn(platform, song) {
            if (!song) return;
            this.showSharingNetworkWarning();
            const url = new URL(window.location.origin + window.location.pathname);
            if (this.selectedPlaylists.length > 0) { url.searchParams.set('playlists', this.selectedPlaylists.join('|')); }
            if (this.selectedGenres.length > 0) { url.searchParams.set('genres', this.selectedGenres.join('|')); }
            url.searchParams.set('song', song.id);
            const prettyUrl = this.getPrettyUrl(url);
            const encodedUrl = encodeURIComponent(prettyUrl);
            const shareText = `I really love this song: '${song.title}' by ${song.artist} from an amazing music player made by Elive Linux:`;
            const encodedText = encodeURIComponent(shareText);
            const encodedTextAndUrl = encodeURIComponent(shareText + ' ' + prettyUrl);
            let shareUrl, windowFeatures = 'width=600,height=400';
            switch (platform) {
                case 'x': shareUrl = `https://x.com/intent/tweet?url=${encodedUrl}&text=${encodedText}`; break;
                case 'facebook': shareUrl = `https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}&quote=${encodedText}`; break;
                case 'whatsapp': shareUrl = `https://api.whatsapp.com/send?text=${encodedTextAndUrl}`; windowFeatures = 'width=800,height=600'; break;
                case 'telegram': shareUrl = `https://t.me/share/url?url=${encodedUrl}&text=${encodedText}`; windowFeatures = 'width=600,height=500'; break;
                default: return;
            }
            window.open(shareUrl, '_blank', windowFeatures);
        },
        openBugReportModal() {
            this.showReportBugPremiumModal = true;
        },
        showInstallInstructions() {
            this.showInstallModal = true;
            this.logAction('Action: Show PWA install instructions');
        },
        async checkForUpdates() {
            this.closeMenu('config');
            localStorage.removeItem('dismissedUpdateVersion');
            localStorage.removeItem('lastUpdateCheck');
            await this._doUpdateCheck(true);
        },
        async openUserSettingsModal() {
            this.showUserSettingsModal = true;
            this.configLoading = true;
            try {
                const res = await fetch('/api/config');
                if (res.status === 403) {
                    this.adminMode = false;
                    window.SWP_CONFIG.is_admin = false;
                    this.showUserSettingsModal = false;
                    this.showAdminLoginModal = true;
                    this.adminLoginError = 'Session expired or access denied. Please login again.';
                    return;
                }
                if (!res.ok) throw new Error('Failed to load config');
                const data = await res.json();
                // Ensure boolean values are actual booleans for Alpine checkboxes
                for (const key in data.values) {
                    if (data.settings[key] && data.settings[key].type === 'boolean') {
                        data.values[key] = !!data.values[key];
                    }
                }
                this.userSettings = data;
                this.initialMusicDirectories = [...(data.values.MUSIC_DIRECTORIES || [])];
                if (this.userSettings.values.hasOwnProperty('SERVER_PORT')) {
                    this.originalServerPort = this.userSettings.values.SERVER_PORT;
                }
            } catch(e) {
                console.error(e);
                this.showNotification('Could not load server settings.', 'error');
                this.showUserSettingsModal = false;
            } finally {
                this.configLoading = false;
            }
        },
        async saveUserSettings(event) {
            // If triggered by Enter key, only save if we are not in an input field
            // to allow natural tabbing and editing within the form.
            if (event && event.type === 'keydown' && event.key === 'Enter') {
                if (['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName)) {
                    return;
                }
            }
            this.configLoading = true;
            try {
                const valuesToSave = { ...this.userSettings.values };
                for (const key in valuesToSave) {
                    // Ensure array-based settings are properly formatted
                    if (this.userSettings.settings[key] && this.userSettings.settings[key].type === 'array') {
                        // Filter out empty entries, ensure item is a string before calling trim
                        valuesToSave[key] = valuesToSave[key].filter(item => item && String(item).trim() !== '');
                    }
                    // Ensure list_name_value and list_name_password settings are properly formatted
                    if (this.userSettings.settings[key]?.type === 'list_name_value' || this.userSettings.settings[key]?.type === 'list_name_password') {
                        // Filter out entries with empty keys or values
                        valuesToSave[key] = valuesToSave[key].filter(item => item && item.name && item.name.trim() !== '' && item.value && item.value.trim() !== '');
                    }
                }

                const directoriesChanged = JSON.stringify(valuesToSave.MUSIC_DIRECTORIES) !== JSON.stringify(this.initialMusicDirectories);
                const portChanged = this.originalServerPort !== null && valuesToSave.SERVER_PORT !== this.originalServerPort;
                const upnpToggledOn = valuesToSave.ENABLE_UPNP && !this.userSettings.values.ENABLE_UPNP;

                // If UPnP is being enabled, we first try to set it up
                if (upnpToggledOn) {
                    this.showNotification('Attempting to configure UPnP port forwarding...', 'info');
                    try {
                        const upnpRes = await fetch('/api/admin/setup_upnp', { method: 'POST' });
                        const upnpData = await upnpRes.json();
                        if (!upnpRes.ok || !upnpData.success) {
                            // Revert the setting in the UI and the object to be saved
                            this.userSettings.values.ENABLE_UPNP = false;
                            valuesToSave.ENABLE_UPNP = false;
                            window.SWP_CONFIG.upnp_error_message = upnpData.message || 'UPnP setup failed.';
                            this.showUpnpErrorModal = true;
                            this.configLoading = false;
                            return;
                        }
                    } catch (e) {
                        // Revert the setting in the UI and the object to be saved
                        this.userSettings.values.ENABLE_UPNP = false;
                        valuesToSave.ENABLE_UPNP = false;
                        window.SWP_CONFIG.upnp_error_message = 'Network error during UPnP setup.';
                        this.showUpnpErrorModal = true;
                        this.configLoading = false;
                        return;
                    }
                }

                const res = await fetch('/api/config', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(valuesToSave)
                });
                const data = await res.json();
                if (res.ok && data.success) {
                    if (directoriesChanged) {
                        fetch('/api/library/update', { method: 'POST' }).catch(e => console.error("Library update trigger failed", e));
                    }

                    if (portChanged) {
                        this.showNotification('Settings saved. Please restart the server for the port change to take effect.', 'warning', null, 10000);
                    } else {
                        this.showNotification(data.message || 'Settings saved.', 'success');
                    }
                    
                    // Update the global config object with new values
                    Object.assign(window.SWP_CONFIG, valuesToSave);
                    this.showUserSettingsModal = false;
                    this.configLoading = false;
                } else {
                    throw new Error(data.message || 'Failed to save settings.');
                }
            } catch (e) {
                console.error(e);
                this.showNotification(`Error: ${e.message}`, 'error');
            } finally {
                this.configLoading = false;
            }
        },
        getArrayInputPlaceholder(varName, part = 'value') {
            if (part === 'key') {
                return varName.startsWith('USERS_') ? 'Username' : (varName === 'FRIENDS_MUSIC' ? 'Name' : 'Key');
            }
            switch(varName) {
                case 'MUSIC_DIRECTORIES': return '/home/user/Music';
                case 'PLAYLISTS_DIRECTORIES': return '/home/user/Music/playlists';
                case 'IGNORE_PLAYLISTS_MATCHING': return 'playlist_name_regex/i';
                case 'IGNORE_GENRES_MATCHING': return 'genre_name_regex/i';
                case 'BLACKLIST_PLAYLISTS_MATCHING': return 'playlist_name_regex/i';
                case 'BLACKLIST_GENRES_MATCHING': return 'genre_name_regex/i';
                case 'BLACKLIST_ARTISTS_MATCHING': return 'artist_name_regex/i';
                case 'PRIVATE_NETWORKS': return 'IP range regex, e.g. ^192\\.168\\.';
                default:
                    if (varName.startsWith('USERS_')) return 'Password';
                    return 'Enter value';
            }
        },
        addArrayItem(varName) {
            let newItem = '';
            if (varName === 'MUSIC_DIRECTORIES') {
                newItem = this.userSettings.default_music_dir || '';
            } else if (this.userSettings.settings[varName] && (this.userSettings.settings[varName].type === 'list_name_value' || this.userSettings.settings[varName].type === 'list_name_password')) {
                if (!this.userSettings.values[varName]) this.userSettings.values[varName] = [];
                this.userSettings.values[varName].push({ name: '', value: '' });
                return;
            }
            if (!this.userSettings.values[varName]) this.userSettings.values[varName] = [];
            this.userSettings.values[varName].push(newItem);
        },
        getArrayAddButtonText(varName) {
            if (varName.startsWith('USERS_')) return '+ Add User';
            if (varName === 'FRIENDS_MUSIC') return '+ Add Friend';
            if (varName === 'PRIVATE_NETWORKS') return '+ Add Network Pattern';
            if (varName.includes('DIRECTORIES')) return '+ Add Directory';
            if (this.userSettings.settings[varName]?.type === 'list_name_value' || this.userSettings.settings[varName]?.type === 'list_name_password') return '+ Add Item';
            return '+ Add Pattern';
        },
        dismissUpdate() {
            if (this.updateInfo) {
                localStorage.setItem('dismissedUpdateVersion', this.updateInfo.latest_version);
            }
            this.showUpdateModal = false;
        },
        async runPeriodicUpdateCheck() {
            if (!this.adminMode) return;

            const now = Date.now();
            const startupDelayMs = 20 * 60 * 1000; // 20 minutes delay
            if (now - this.startupTime < startupDelayMs) {
                const remainingDelay = Math.ceil((startupDelayMs - (now - this.startupTime)) / 60000);
                console.log(`Update check deferred. Waiting ${remainingDelay} more minutes since startup.`);
                setTimeout(() => this.runPeriodicUpdateCheck(), 60000);
                return;
            }

            const lastCheck = localStorage.getItem('lastUpdateCheck');
            const checkIntervalMs = window.SWP_CONFIG.periodic_update_check_hours * 60 * 60 * 1000;

            if (!lastCheck || (now - lastCheck > checkIntervalMs)) {
                await this._doUpdateCheck(false);
            } else {
                const timeLeft = checkIntervalMs - (now - lastCheck);
                const daysLeft = (timeLeft / (1000 * 60 * 60 * 24)).toFixed(1);
                console.log(`Skipping periodic update check. Next check in ${daysLeft} days.`);
            }
        },
        async _doUpdateCheck(isManual) {
            if (isManual) {
                this.showNotification('Checking for updates...', 'info');
            }
            console.log(`Performing update check (manual: ${isManual})...`);
            try {
                const res = await fetch('/api/check_update');
                localStorage.setItem('lastUpdateCheck', Date.now().toString());
                if (!res.ok) {
                    const errorMsg = 'Update check failed: Server responded with status ' + res.status;
                    console.error(errorMsg);
                    if (isManual) this.showNotification(errorMsg, 'error');
                    return;
                }
                const data = await res.json();
                if (data.update_available) {
                    console.log(`Update available: ${data.latest_version}. Current version: ${this.appVersion}`);
                    this.updateInfo = data;
                    const dismissedVersion = localStorage.getItem('dismissedUpdateVersion');
                    
                    if (dismissedVersion !== this.updateInfo.latest_version) {
                        this.showUpdateModal = true;
                        // If on Elive Lite, mark as dismissed immediately so it only shows once
                        if (this.is_elive && !this.is_pro) {
                            localStorage.setItem('dismissedUpdateVersion', this.updateInfo.latest_version);
                        }
                    } else {
                        console.log(`Update ${data.latest_version} has been dismissed previously.`);
                    }
                } else if (data.error) {
                     const errorMsg = `Update check resulted in an error: ${data.error}`;
                     console.error(errorMsg);
                     if (isManual) this.showNotification(errorMsg, 'error');
                } else {
                    console.log(`Update check complete. You are on the latest version (${this.appVersion}).`);
                    if (isManual) {
                        if (data.latest_version === '0.0.0') { // 'v' is removed server-side
                            this.showNotification(`Could not find any release version to compare with.`, 'warning');
                        } else if (data.current_version.replace(/^v/, '') === data.latest_version) {
                            this.showNotification(`You are up to date! (${this.appVersion})`, 'info');
                        } else {
                            this.showNotification('Wow! You seem to have a newer version than what is released.', 'info');
                        }
                    }
                }
            } catch (e) {
                const errorMsg = 'Update check failed due to a network error: ' + e.message;
                console.error(errorMsg, e);
                if (isManual) this.showNotification(errorMsg, 'error');
            }
        },
        escapeHtml(text) {
            const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
            return text.replace(/[&<>"']/g, m => map[m]);
        },
        startLyricsAnimation() {
            if (this.lyricsAnimationId || !this.isPlaying || !this.showLyricsModal) return;
            const animate = () => {
                this.updateKaraokeScroll();
                this.lyricsAnimationId = requestAnimationFrame(animate);
            };
            this.lyricsAnimationId = requestAnimationFrame(animate);
        },
        stopLyricsAnimation() {
            if (this.lyricsAnimationId) {
                cancelAnimationFrame(this.lyricsAnimationId);
                this.lyricsAnimationId = null;
            }
        },
        processLyricsForKaraoke(lyricsText) {
            if (!lyricsText) {
                this.lyricsLines = [];
                this.lyricsLineElements = [];
                this.lyricsModalContent = "No lyrics found for this song.";
                this.totalLyricsWords = 0;
                this.lyricsLineWordData = [];
                return;
            }
            const lines = lyricsText.split('\n');
            this.lyricsLines = lines;
            this.lyricsLineElements = []; // Will be populated by showLyricsModal watcher.

            let cumulativeWords = 0;
            this.lyricsLineWordData = lines.map(line => {
                const wordCount = line.trim().split(/\s+/).filter(Boolean).length;
                cumulativeWords += wordCount;
                return { wordCount, cumulativeWords };
            });
            this.totalLyricsWords = cumulativeWords;
            this._lastQuantizedScrollTop = null;
            this._scrollAnimationStartTime = 0;

            this.lyricsModalContent = lines.map((line, index) => {
                // Return a non-breaking space for empty lines to preserve height
                const text = line.trim() === '' ? '&nbsp;' : this.escapeHtml(line);
                return `<span id="lyric-line-${index}" class="lyric-line">${text}</span>`;
            }).join('\n');

            // If the modal is already open, we need to re-query the DOM for the new lyric lines
            // after Alpine has had a chance to render them.
            if (this.showLyricsModal) {
                this.$nextTick(() => {
                    this.lyricsLineElements = this.lyricsLines.map((_, index) => document.getElementById(`lyric-line-${index}`)).filter(Boolean);
                });
            }

            // Note: The watcher for 'showLyricsModal' will now handle populating lyricsLineElements
            // to ensure the DOM is ready before querying elements.
        },
        updateKaraokeScroll() {
            if (!this.showLyricsModal || !this.karaokePossible || !this.isWindowFocused) {
                return;
            }

            const container = this.$refs.lyricsContainer;
            if (!container || this.totalLyricsWords === 0) {
                return;
            }

            const audio = this.getActivePlayer();
            if (!audio) return;

            // Use audio.currentTime directly for higher precision in the animation loop
            const currentTime = audio.currentTime;
            let timeProgress = currentTime / this.duration;

            // Add a delay at the start (4%) and padding at the end (6%) for karaoke timing,
            // with a maximum of 30 seconds each. This maps the time range to a progress of [0 to 1].
            const startOffsetSeconds = Math.min(this.duration * 0.04, 30);
            const endOffsetSeconds = Math.min(this.duration * 0.06, 30);
            const startOffsetPercent = this.duration > 0 ? startOffsetSeconds / this.duration : 0;
            const endOffsetPercent = this.duration > 0 ? endOffsetSeconds / this.duration : 0;
            timeProgress = (timeProgress - startOffsetPercent) / (1.0 - startOffsetPercent - endOffsetPercent);
            timeProgress = Math.max(0, Math.min(1, timeProgress));

            const targetWordIndex = timeProgress * this.totalLyricsWords;

            // Find which line contains the target word
            let currentLineIndex = -1;
            let wordsInLine = 0;
            let wordsBeforeLine = 0;

            for (let i = 0; i < this.lyricsLineWordData.length; i++) {
                if (targetWordIndex <= this.lyricsLineWordData[i].cumulativeWords) {
                    currentLineIndex = i;
                    wordsInLine = this.lyricsLineWordData[i].wordCount;
                    wordsBeforeLine = i > 0 ? this.lyricsLineWordData[i - 1].cumulativeWords : 0;
                    break;
                }
            }

            if (currentLineIndex === -1 && this.lyricsLineElements.length > 0) {
                currentLineIndex = this.lyricsLineElements.length - 1;
            }
            if (currentLineIndex === -1) return;

            const lineEl = this.lyricsLineElements[currentLineIndex];
            if (!lineEl) return;

            const lineTop = lineEl.offsetTop;
            const lineHeight = lineEl.offsetHeight;

            // Calculate progress within the current line
            let intraLineProgress = 0;
            if (wordsInLine > 0) {
                intraLineProgress = (targetWordIndex - wordsBeforeLine) / wordsInLine;
            }
            // Clamp to avoid over/undershooting
            intraLineProgress = Math.max(0, Math.min(1, intraLineProgress));

            const scrollTargetTop = lineTop + (intraLineProgress * lineHeight);

            const containerHeight = container.clientHeight;
            if (containerHeight === 0) return;

            // Center the current position in the viewport by scrolling the container
            const desiredScrollTop = scrollTargetTop - (containerHeight / 2);

            if (!this.userScrolledLyrics) {
                // Scroll in smooth chunks of 20% of the page height
                const stepSize = containerHeight * 0.2;
                const targetScrollTop = Math.max(0, Math.round(desiredScrollTop / stepSize) * stepSize);

                if (this._lastQuantizedScrollTop === null) {
                    this._lastQuantizedScrollTop = container.scrollTop;
                    this._scrollAnimationTarget = targetScrollTop;
                    this._scrollAnimationSource = container.scrollTop;
                    this._scrollAnimationStartTime = 0;
                }

                // Detect when the quantized target changes to start a new transition
                if (targetScrollTop !== this._scrollAnimationTarget) {
                    this._scrollAnimationSource = this._lastQuantizedScrollTop;
                    this._scrollAnimationTarget = targetScrollTop;
                    this._scrollAnimationStartTime = performance.now();
                }

                if (this._scrollAnimationStartTime > 0) {
                    // Duration of the scroll animation in milliseconds.
                    // 1000ms provides a smooth, moderately fast transition.
                    const duration = 1000;
                    const elapsed = performance.now() - this._scrollAnimationStartTime;
                    const progress = Math.min(1, elapsed / duration);

                    // Sinusoidal ease-in-out (slow + fast + slow)
                    const easedProgress = 0.5 * (1 - Math.cos(Math.PI * progress));

                    this._lastQuantizedScrollTop = this._scrollAnimationSource + (this._scrollAnimationTarget - this._scrollAnimationSource) * easedProgress;
                    container.scrollTop = this._lastQuantizedScrollTop;

                    if (progress === 1) {
                        this._scrollAnimationStartTime = 0;
                    }
                } else if (this._lastQuantizedScrollTop !== targetScrollTop) {
                    // Fallback for when not animating but target is different (e.g. initial load)
                    this._lastQuantizedScrollTop = targetScrollTop;
                    container.scrollTop = targetScrollTop;
                }
            }
        }
    }));
});
