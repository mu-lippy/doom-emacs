;;; core.el --- The heart of the beast

;;; Naming conventions:
;;
;;   doom-...   A public variable or function (non-interactive use)
;;   doom--...  A private variable, function (non-interactive use) or macro
;;   doom/...   An interactive function
;;   doom:...   An evil operator, motion or command
;;   doom|...   A hook
;;   doom*...   An advising function
;;   ...!       Macro, shortcut alias or defsubst
;;   @...       lambda macro for keybinds
;;   +...       Any of the above, but part of a module, e.g. +emacs-lisp|init-hook
;;
;;; Autoloaded functions are in {core,modules}/defuns/defuns-*.el

(when (version< emacs-version "25.1")
  (error "DOOM Emacs no longer supports Emacs <25.1! Time to upgrade!"))

;;;
(defvar doom-version "2.0.0"
  "Current version of DOOM emacs")

(defvar doom-emacs-dir user-emacs-directory
  "The path to this emacs.d directory")

(defvar doom-core-dir (concat doom-emacs-dir "core/")
  "Where essential files are stored")

(defvar doom-modules-dir (concat doom-emacs-dir "modules/")
  "Where configuration modules are stored")

(defvar doom-private-dir (concat doom-emacs-dir "private/")
  "Where private configuration filse and assets are stored (like snippets)")

(defvar doom-scripts-dir (concat doom-emacs-dir "scripts/")
  "Where external dependencies are stored (like libraries or binaries)")

(defvar doom-packages-dir (concat doom-private-dir "packages/")
  "Where package.el and quelpa plugins (and their caches) are kept.")

(defvar doom-themes-dir (concat doom-private-dir "themes/")
  "Where theme files and subfolders go")

(defvar doom-temp-dir
  (concat doom-private-dir "cache/" (system-name) "/")
  "Hostname-based elisp temp directories")

(defvar doom-org-dir "~/org/"
  "Where to find org notes")


;;;
;; UTF-8 as the default coding system, please
(set-charset-priority 'unicode)        ; pretty
(prefer-coding-system        'utf-8)   ; pretty
(set-terminal-coding-system  'utf-8)   ; pretty
(set-keyboard-coding-system  'utf-8)   ; perdy
(set-selection-coding-system 'utf-8)   ; please
(setq locale-coding-system   'utf-8)   ; with sugar on top
(setq-default buffer-file-coding-system 'utf-8)

;; Configuration
(setq ad-redefinition-accept 'accept   ; silence advised function warnings
      apropos-do-all t                 ; make `apropos' more useful
      byte-compile-warnings nil
      compilation-always-kill t
      compilation-ask-about-save nil
      compilation-scroll-output t
      confirm-nonexistent-file-or-buffer t
      enable-recursive-minibuffers nil
      idle-update-delay 5
      minibuffer-prompt-properties '(read-only t point-entered minibuffer-avoid-prompt face minibuffer-prompt)
      save-interprogram-paste-before-kill nil)

;; History & backup settings
(setq auto-save-default nil
      auto-save-list-file-name (concat doom-temp-dir "/autosave")
      backup-directory-alist (list (cons ".*" (concat doom-temp-dir "/backup/")))
      create-lockfiles nil
      history-length 1000
      make-backup-files nil
      vc-make-backup-files nil)


;;;
;; Automatic minor modes
(defvar doom-auto-minor-mode-alist '()
  "Alist mapping filename patterns to corresponding minor mode functions, like
`auto-mode-alist'. All elements of this alist are checked, meaning you can
enable multiple minor modes for the same regexp.")

(defun doom|enable-minor-mode-maybe ()
  "Check file name against `doom-auto-minor-mode-alist'."
  (when buffer-file-name
    (let ((name buffer-file-name)
          (remote-id (file-remote-p buffer-file-name))
          (alist doom-auto-minor-mode-alist))
      ;; Remove backup-suffixes from file name.
      (setq name (file-name-sans-versions name))
      ;; Remove remote file name identification.
      (when (and (stringp remote-id)
                 (string-match-p (regexp-quote remote-id) name))
        (setq name (substring name (match-end 0))))
      (while (and alist (caar alist) (cdar alist))
        (if (string-match (caar alist) name)
            (funcall (cdar alist) 1))
        (setq alist (cdr alist))))))

(add-hook 'find-file-hook 'doom|enable-minor-mode-maybe)


;;;
;; Bootstrap
(setq gc-cons-threshold 339430400
      gc-cons-percentage 0.6)

(let (file-name-handler-list)
  (eval-and-compile
    (load (concat doom-core-dir "core-packages") nil t))
  (eval-when-compile
    ;; Ensure cache folder exists
    (unless (file-exists-p doom-temp-dir)
      (make-directory doom-temp-dir t))
    (doom-package-init))

  (setq load-path (eval-when-compile load-path)
        custom-theme-load-path (append (list doom-themes-dir) custom-theme-load-path))

  ;;; Essential packages
  (require 'core-lib)
  (package! dash :demand t)
  (package! s    :demand t)
  (package! f    :demand t)

  ;;; Helper packages (autoloaded)
  (package! async
    :commands (async-start
               async-start-process
               async-byte-recompile-directory))

  (package! persistent-soft
    :commands (persistent-soft-exists-p
               persistent-soft-fetch
               persistent-soft-flush
               persistent-soft-store)
    :init (defvar pcache-directory (concat doom-temp-dir "/pcache/")))

  (package! smex :commands smex)

  ;;; Let 'er rip! (order matters!)
  ;; (require 'core-set)           ; configuration management system
  ;; (require 'core-popups)        ; taming sudden yet inevitable windows
  (require 'core-evil)             ; come to the dark side, we have cookies
  ;; (require 'core-project)
  ;; (require 'core-os)
  ;; (require 'core-ui)
  ;; (require 'core-modeline)
  ;; (require 'core-editor)
  ;; (require 'core-completion)
  ;; (require 'core-jump)
  ;; (require 'core-repl)
  ;; (require 'core-snippets)
  ;; (require 'core-syntax-checking)
  ;; (require 'core-vcs)
  ;; (require 'core-workspaces)

  (unless (require 'autoloads nil t)
    (doom/refresh-autoloads t)))


;;;
;;
(defmacro doom! (&rest packages)
  (let (paths)
    (dolist (p packages)
      (if (memq p '(:apps :emacs :lang :lib :private :ui))
          (setq mode p)
        (unless mode
          (error "No namespace specified on `doom!' for %s" p))
        (pushnew (format "%s%s/%s/" doom-modules-dir (substring (symbol-name mode) 1) (symbol-name p))
                 paths)))

    `(let (file-name-handler-alist)
       (unless noninteractive
         (load "~/.emacs.local.el" t t))

       (with-demoted-errors "ERROR: %s"
         ,@(mapcar
            (lambda (path)
              (macroexp-progn
               (mapcar (lambda (file)
                         (when noninteractive (setq file (file-name-sans-extension file)))
                         `(load ,(expand-file-name file path) t t (not noninteractive)))
                       (append (list "packages.el")
                               (unless noninteractive (list "config.el"))))))
            paths))

       (unless noninteractive
         (require 'my-bindings)
         (require 'my-commands)

         (when (display-graphic-p)
           (require 'server)
           (unless (server-running-p)
             (server-start)))

         ;; Prevent any auto-displayed text + benchmarking
         (advice-add 'display-startup-echo-area-message :override 'ignore)
         (message "")))))

(provide 'core)
;;; core.el ends here
