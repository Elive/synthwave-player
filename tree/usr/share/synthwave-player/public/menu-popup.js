class SWPMenu {
    constructor(options = {}) {
        this.options = options;
        this.container = null;
        this.isOpen = false;
        this.activeMenuId = null;
        this._lastPos = null;
        this._targetScrollY = 0;
        this._currentScrollY = 0;
        this._animFrame = null;
        this._init();
    }

    _init() {
        this.$nextTick = (cb) => setTimeout(cb, 0);
        window.addEventListener('resize', () => this.reposition());
        this.container = document.createElement('div');
        this.container.id = 'swp-dynamic-menu';
        this.setVisualEffects(true);
        
        // We don't append to body here anymore, we wait for Alpine's container
        // but for safety if it's not found in index, we'll append to body in show()
        
        // Close on click outside or escape
        this._onMouseDown = (e) => {
            if (this.isOpen && !this.container.contains(e.target)) {
                // Check if we clicked an anchor element that might be trying to toggle this menu
                const anchor = e.target.closest('[data-menu-anchor]');
                // If we clicked the SAME anchor that is currently active, let the anchor's click handler toggle it off
                if (anchor && this._lastPos && anchor === this._lastPos.anchorEl) return;
                
                this.hide();
            }
        };
        document.addEventListener('mousedown', this._onMouseDown);

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.hide();
            }
        });

        // Proximity scrolling (macOS style)
        this.container.addEventListener('mousemove', (e) => {
            const wrapper = this.container.querySelector('.menu-content-wrapper');
            if (!wrapper) return;

            const rect = this.container.getBoundingClientRect();
            const contentHeight = wrapper.scrollHeight;
            const viewHeight = rect.height;
            const overflow = contentHeight - viewHeight;

            if (overflow <= 0) {
                this._targetScrollY = 0;
                this._currentScrollY = 0;
                wrapper.style.transform = 'translateY(0)';
                return;
            }

            // Calculate percentage based on mouse position relative to container height
            const relativeY = e.clientY - rect.top;
            const percentage = Math.max(0, Math.min(1, relativeY / viewHeight));

            this._targetScrollY = percentage * overflow;
            this._startAnimation();
        });

        // Unified Event Delegation
        this.container.addEventListener('click', (e) => {
            // Prevent closing when clicking inside a select, label, checkbox, input or button
            if (e.target.closest('select') || e.target.closest('label') || e.target.closest('input') || e.target.closest('button')) {
                if (e.target.tagName === 'INPUT' && e.target.type === 'number') {
                    e.target.focus();
                    e.target.select();
                }
                return;
            }

            const itemEl = e.target.closest('[data-action-id]');
            if (!itemEl) return;

            const actionId = itemEl.getAttribute('data-action-id');
            const item = this._currentItems.find(i => i.actionId === actionId);

            if (item && !item.disabled) {
                if (item.type === 'checkbox') {
                    const cb = itemEl.querySelector('input[type="checkbox"]');
                    if (cb) {
                        cb.checked = !cb.checked;
                        cb.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                } else if (item.type === 'select') {
                    // Do nothing, let the change event handle it
                } else {
                    item.action(e);
                    this.hide();
                }
            }
        });

        this.container.addEventListener('wheel', (e) => {
            if (e.target.closest('input[type="number"]') || e.target.closest('select')) {
                e.stopPropagation();
            }
        }, { passive: false });

        this.container.addEventListener('change', (e) => {
            const itemEl = e.target.closest('[data-action-id]');
            if (!itemEl || !this._currentItems) return;
            const actionId = itemEl.getAttribute('data-action-id');
            const item = this._currentItems.find(i => i.actionId === actionId);
            if (item && item.type === 'select') {
                item.action(e.target.value);
            }
        });
    }

    setVisualEffects(enabled) {
        const baseClass = 'fixed z-[20000] dropdown-menu rounded-md overflow-hidden menu-hidden';
        if (enabled) {
            this.container.className = `${baseClass} glassmorphism border border-[var(--color-cyan-glow)] shadow-[0_0_8px_var(--color-cyan-glow)]`;
        } else {
            this.container.className = `${baseClass} bg-gray-900 border border-fuchsia-500/50 shadow-lg`;
        }
    }

    show(options) {
        const { x, y, menuId, anchorEl, contentEl, items } = options;

        this.container.style.maxHeight = 'none';

        // Ensure previous content is returned to its original parent before showing new content
        // We do this immediately if a new menu is requested to avoid DOM conflicts
        if (this._currentContent && this._originalParent && this._currentContent !== contentEl) {
            this._returnContentToParent();
        }

        this.activeMenuId = menuId;
        this.isOpen = true;
        this._lastPos = { x, y, anchorEl };

        if (items) {
            this.renderItems(items);
        } else if (contentEl) {
            const menuHost = document.getElementById('menu-host');
            if (menuHost) {
                if (!menuHost.contains(this.container)) {
                    menuHost.appendChild(this.container);
                }
            } else if (!document.body.contains(this.container)) {
                document.body.appendChild(this.container);
            }

            this.container.innerHTML = '';
            const wrapper = document.createElement('div');
            wrapper.className = 'py-1 menu-content-wrapper transition-transform duration-150 ease-out will-change-transform';
            this.container.appendChild(wrapper);

            if (this._currentContent !== contentEl) {
                this._currentContent = contentEl;
                this._originalParent = contentEl.parentElement;
            }
            
            // Clear wrapper but don't use innerHTML = '' to avoid destroying references
            while (wrapper.firstChild) {
                wrapper.removeChild(wrapper.firstChild);
            }
            
            wrapper.appendChild(contentEl);
            contentEl.classList.remove('hidden');
            
            // If Alpine is present, ensure it re-initializes the moved content
            if (window.Alpine && contentEl.__x) {
                window.Alpine.initTree(contentEl);
            }
        }

        this.container.classList.remove('menu-hidden');

        requestAnimationFrame(() => {
            this.position(x, y, anchorEl);
        });
    }

    reposition() {
        if (this.isOpen && this._lastPos) {
            this.position(this._lastPos.x, this._lastPos.y, this._lastPos.anchorEl);
        }
    }

    hide() {
        if (!this.isOpen) return;
        if (this._animFrame) {
            cancelAnimationFrame(this._animFrame);
            this._animFrame = null;
        }
        this._targetScrollY = 0;
        this._currentScrollY = 0;

        this.container.classList.add('menu-hidden');
        this.isOpen = false;
        this.activeMenuId = null;
        
        // Delay returning content to parent to allow for transition
        setTimeout(() => {
            if (!this.isOpen) {
                this._returnContentToParent();
            }
        }, 150);
    }

    _returnContentToParent() {
        if (this._currentContent && this._originalParent) {
            this._currentContent.classList.add('hidden');
            this._originalParent.appendChild(this._currentContent);
            this._currentContent = null;
            this._originalParent = null;
        }
    }

    _startAnimation() {
        if (!this._animFrame) {
            this._animateScroll();
        }
    }

    _animateScroll() {
        const wrapper = this.container.querySelector('.menu-content-wrapper');
        if (!wrapper || !this.isOpen) {
            this._animFrame = null;
            return;
        }

        const diff = this._targetScrollY - this._currentScrollY;
        if (Math.abs(diff) < 0.1) {
            this._currentScrollY = this._targetScrollY;
            wrapper.style.transform = `translateY(-${this._currentScrollY}px)`;
            this._animFrame = null;
            return;
        }

        this._currentScrollY += diff * 0.15;
        wrapper.style.transform = `translateY(-${this._currentScrollY}px)`;
        this._animFrame = requestAnimationFrame(() => this._animateScroll());
    }

    position(x, y, anchorEl) {
        const padding = 10;
        this.container.style.maxHeight = 'none'; // Reset for measurement
        const rect = this.container.getBoundingClientRect();
        let finalX = x;
        let finalY = y;

        // If anchor element provided (top bar menus), position relative to it
        if (anchorEl) {
            const anchorRect = anchorEl.getBoundingClientRect();
            finalX = anchorRect.right - rect.width;
            finalY = anchorRect.bottom + 8;
        }

        // Viewport collision detection
        if (window.Alpine && window.Alpine.raw(window.Alpine.store('musicPlayer'))?.isMobileMode) {
            finalX = (window.innerWidth - rect.width) / 2;
        } else {
            if (finalX + rect.width > window.innerWidth - padding) {
                finalX = window.innerWidth - rect.width - padding;
            }
            if (finalX < padding) finalX = padding;
        }

        if (finalY + rect.height > window.innerHeight - padding) {
            // Open upwards if no space below
            if (anchorEl) {
                const anchorRect = anchorEl.getBoundingClientRect();
                const spaceAbove = anchorRect.top - padding;
                const spaceBelow = window.innerHeight - anchorRect.bottom - padding;

                if (spaceAbove > spaceBelow) {
                    finalY = anchorRect.top - rect.height - 8;
                } else {
                    finalY = anchorRect.bottom + 8;
                }
            } else {
                finalY = window.innerHeight - rect.height - padding;
            }
        }

        // Final safety check for top boundary
        if (finalY < padding) finalY = padding;

        this.container.style.left = `${finalX}px`;
        this.container.style.top = `${finalY}px`;

        // Recalculate maxHeight based on final position to prevent screen overflow
        const availableHeight = window.innerHeight - finalY - padding;
        this.container.style.maxHeight = `${availableHeight}px`;

        // Reset proximity scroll transform on reposition
        const wrapper = this.container.querySelector('.menu-content-wrapper');
        if (wrapper) {
            this._targetScrollY = 0;
            this._currentScrollY = 0;
            wrapper.style.transform = 'translateY(0)';
        }
    }

    renderItems(items) {
        this._currentItems = items;
        let html = '<div class="py-1 menu-content-wrapper transition-transform duration-150 ease-out will-change-transform" style="font-family: var(--ui-font-family), sans-serif !important;">';
        items.forEach(item => {
            if (item.type === 'separator') {
                html += '<div class="border-t border-fuchsia-500/20 mx-2 my-1"></div>';
            } else if (item.type === 'checkbox') {
                html += `
                    <div class="w-full px-4 py-2 flex items-center justify-between text-sm text-gray-200 hover:bg-cyan-400/20 cursor-pointer" data-action-id="${item.actionId}">
                        <label class="flex items-center cursor-pointer">
                            <input type="checkbox" ${item.checked ? 'checked' : ''} class="mr-2 h-4 w-4 accent-cyan-500 rounded border-cyan-500 bg-transparent">
                            ${item.label}
                        </label>
                    </div>`;
            } else if (item.type === 'select') {
                let optionsHtml = (item.options || []).map(opt =>
                    `<option value="${opt.value}" ${opt.value === item.value ? 'selected' : ''}>${opt.label}</option>`
                ).join('');
                html += `
                    <div class="w-full px-4 py-2 flex items-center justify-between text-sm text-gray-200 hover:bg-cyan-400/20" data-action-id="${item.actionId}">
                        <span>${item.label}</span>
                        <select class="synth-select ml-2 bg-gray-800 border border-gray-600 rounded-md text-white text-xs p-1">
                            ${optionsHtml}
                        </select>
                    </div>`;
            } else {
                const disabledAttr = item.disabled ? 'opacity-50 cursor-not-allowed' : 'hover:bg-cyan-400/20 cursor-pointer';
                const iconHtml = item.icon ? `<span class="w-5 h-5 inline-block text-cyan-400">${item.icon}</span>` : '';
                const labelClass = item.class || 'text-gray-200';

                html += `
                    <div class="w-full px-4 py-2 flex items-center gap-3 text-sm ${labelClass} ${disabledAttr}"
                         data-action-id="${item.actionId}">
                        ${iconHtml}
                        <span>${item.label}</span>
                    </div>`;
            }
        });
        html += '</div>';
        this.container.innerHTML = html;
    }
}
