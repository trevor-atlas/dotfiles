(setq custom-file (locate-user-emacs-file "custom-vars.el"))
(load custom-file 'noerror 'nomessage)

(setq inhibit-startup-message t
      visible-bell nil)

;; always show line-numbers
(global-display-line-numbers-mode 1)
(column-number-mode)

;; set font
(set-face-attribute 'default nil :font "Comic Code Ligatures" :height 160)

;; highlight the current line
(hl-line-mode t)

;; remember mini-buffer history
(setq history-length 100)
(savehist-mode 1)

;; remember last cursor position in a file
(save-place-mode 1)

;; prevent using UI dialogs for prompts
(setq use-dialog-box nil)

(global-auto-revert-mode 1)

(setq global-auto-revert-non-file-buffers t)

;; Make ESC quit prompts
;;(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

;; Runtime optimizations
;; PERF: A second, case-insensitive pass over `auto-mode-alist' is time wasted.
(setq auto-mode-case-fold nil)

;; PERF: Disable bidirectional text scanning for a modest performance boost.
;;   I've set this to `nil' in the past, but the `bidi-display-reordering's docs
;;   say that is an undefined state and suggest this to be just as good:
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

;; PERF: Disabling BPA makes redisplay faster, but might produce incorrect
;;   reordering of bidirectional text with embedded parentheses (and other
;;   bracket characters whose 'paired-bracket' Unicode property is non-nil).
(setq bidi-inhibit-bpa t)  ; Emacs 27+ only

;; Reduce rendering/line scan work for Emacs by not rendering cursors or regions
;; in non-focused windows.
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

;; More performant rapid scrolling over unfontified regions. May cause brief
;; spells of inaccurate syntax highlighting right after scrolling, which should
;; quickly self-correct.
(setq fast-but-imprecise-scrolling t)

;; Don't ping things that look like domain names.
(setq ffap-machine-p-known 'reject)

;; Emacs "updates" its ui more often than it needs to, so slow it down slightly
(setq idle-update-delay 1.0)  ; default is 0.5

;; Font compacting can be terribly expensive, especially for rendering icon
;; fonts on Windows. Whether disabling it has a notable affect on Linux and Mac
;; hasn't been determined, but do it anyway, just in case. This increases memory
;; usage, however!
(setq inhibit-compacting-font-caches t)

;; PGTK builds only: this timeout adds latency to frame operations, like
;; `make-frame-invisible', which are frequently called without a guard because
;; it's inexpensive in non-PGTK builds. Lowering the timeout from the default
;; 0.1 should make childframes and packages that manipulate them (like `lsp-ui',
;; `company-box', and `posframe') feel much snappier. See emacs-lsp/lsp-ui#613.

;; Increase how much is read from processes in a single chunk (default is 4kb).
;; This is further increased elsewhere, where needed (like our LSP module).
(setq read-process-output-max (* 64 1024))  ; 64kb

;; Introduced in Emacs HEAD (b2f8c9f), this inhibits fontification while
;; receiving input, which should help a little with scrolling performance.
(setq redisplay-skip-fontification-on-input t)

;; The GC introduces annoying pauses and stuttering into our Emacs experience,
;; so we use `gcmh' to stave off the GC while we're using Emacs, and provoke it
;; when it's idle. However, if the idle delay is too long, we run the risk of
;; runaway memory usage in busy sessions. If it's too low, then we may as well
;; not be using gcmh at all.
(setq gcmh-idle-delay 'auto  ; default is 15s
      gcmh-auto-idle-delay-factor 10
      gcmh-high-cons-threshold (* 16 1024 1024))  ; 16mb


;;; Disable UI elements early
;; PERF,UI: Doom strives to be keyboard-centric, so I consider these UI elements
;;   clutter. Initializing them also costs a morsel of startup time. Whats more,
;;   the menu bar exposes functionality that Doom doesn't endorse. Perhaps one
;;   day Doom will support these, but today is not that day.
;;
;; HACK: I intentionally avoid calling `menu-bar-mode', `tool-bar-mode', and
;;   `scroll-bar-mode' because they do extra work to manipulate frame variables
;;   that isn't necessary this early in the startup process.
(push '(menu-bar-lines . 0)   default-frame-alist)
(push '(tool-bar-lines . 0)   default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
;; And set these to nil so users don't have to toggle the modes twice to
;; reactivate them.
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil)

;; Plugins

;; Initialize package sources
(require 'package)

(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("org" . "https://orgmode.org/elpa/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

  ;; Initialize use-package on non-Linux platforms
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(use-package auto-package-update
  :custom
  (auto-package-update-interval 7)
  (auto-package-update-prompt-before-update t)
  (auto-package-update-hide-results t)
  :config
  (auto-package-update-maybe)
  (auto-package-update-at-time "09:00"))

(use-package command-log-mode)
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 0.3))

(use-package markdown-mode
  :ensure t)

(use-package ivy
  :diminish
  :bind (("C-s" . swiper)
         :map ivy-minibuffer-map
         ("TAB" . ivy-alt-done)
         ("C-l" . ivy-alt-done)
         ("C-j" . ivy-next-line)
         ("C-k" . ivy-previous-line)
         :map ivy-switch-buffer-map
         ("C-k" . ivy-previous-line)
         ("C-l" . ivy-done)
         ("C-d" . ivy-switch-buffer-kill)
         :map ivy-reverse-i-search-map
         ("C-k" . ivy-previous-line)
         ("C-d" . ivy-reverse-i-search-kill))
  :config
  (ivy-mode 1))


(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :custom ((doom-modeline-height 15)))

(use-package doom-themes
  :ensure t
  :config
  ;; Global settings (defaults)
  (setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
        doom-themes-enable-italic t) ; if nil, italics is universally disabled
  (load-theme 'doom-one t)

  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (all-the-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (setq doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

;; Make ESC quit prompts
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

(use-package general
  :after evil
  :config
  (general-create-definer efs/leader-keys
    :keymaps '(normal insert visual emacs)
    :prefix "SPC"
    :global-prefix "C-SPC")

  (efs/leader-keys
    "t"  '(:ignore t :which-key "toggles")
    "tt" '(counsel-load-theme :which-key "choose theme")
    "fde" '(lambda () (interactive) (find-file (expand-file-name "~/.emacs.d/Emacs.org")))))

(use-package evil
    :init
    (setq evil-want-integration t)
    (setq evil-want-keybinding nil)
    (setq evil-want-C-u-scroll t)
    (setq evil-want-C-i-jump nil)
    (setq evil-leader/leader "SPC")
    :config
    (evil-mode 1)

    (define-prefix-command 'my-evil-leader-map)
    (define-key evil-normal-state-map (kbd "SPC") 'my-evil-leader-map)

    ;; Use visual line motions even outside of visual-line-mode buffers
    (evil-global-set-key 'motion "j" 'evil-next-visual-line)
    (evil-global-set-key 'motion "k" 'evil-previous-visual-line)

    (keymap-set evil-normal-state-map (kbd "H") 'evil-first-non-blank)
    (keymap-set evil-normal-state-map (kbd "L") 'evil-end-of-line)
    (keymap-set evil-visual-state-map (kbd "H") 'evil-first-non-blank)
    (keymap-set evil-visual-state-map (kbd "L") 'evil-end-of-line)

    (define-key my-evil-leader-map (kbd "j") 'previous-buffer)
    (define-key my-evil-leader-map (kbd "k") 'next-buffer)

    (defun evil-join-and-keep-position ()
	"Join lines and keep cursor position."
	(interactive)
	(let ((current-column (current-column)))
	(evil-join (line-beginning-position) (line-beginning-position 2))
	(move-to-column current-column)))

    (define-key evil-normal-state-map (kbd "J") 'evil-join-and-keep-position)

    (defun evil-source-current-buffer ()
	"Reload the current buffer."
	(interactive)
	(load-file (buffer-file-name)))

    (define-key my-evil-leader-map (kbd "rr") 'evil-source-current-buffer)


    (defun my/evil-shift-right ()
	(interactive)
	(evil-shift-right evil-visual-beginning evil-visual-end)
	(evil-normal-state)
	(evil-visual-restore))

    (defun my/evil-shift-left ()
	(interactive)
	(evil-shift-left evil-visual-beginning evil-visual-end)
	(evil-normal-state)
	(evil-visual-restore))

    (evil-define-key 'visual global-map (kbd ">") 'my/evil-shift-right)
    (evil-define-key 'visual global-map (kbd "<") 'my/evil-shift-left)
    ;; Define the key mappings
    (evil-define-key 'visual global-map (kbd "S-<tab>") 'my/evil-shift-left)
    (evil-define-key 'visual global-map (kbd "TAB") 'my/evil-shift-right)

    (evil-set-initial-state 'messages-buffer-mode 'normal)
    (evil-set-initial-state 'dashboard-mode 'normal))


(use-package evil-collection
:after evil
:config
(evil-collection-init))

(use-package magit
:commands (magit-status magit-get-current-branch)
:custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;; plug magit into github - requires some config that I've yet to do
(use-package forge)

(use-package ivy-rich
  :after ivy
  :init
  (ivy-rich-mode 1))

;;(use-package counsel
  ;;:bind (("C-M-j" . 'counsel-switch-buffer)
         ;;:map minibuffer-local-map
         ;;("C-r" . 'counsel-minibuffer-history))
  ;;:custom
  ;;;;(counsel-linux-app-format-function #'counsel-linux-app-format-function-name-only)
  ;;:config
  ;;(counsel-mode 1))

