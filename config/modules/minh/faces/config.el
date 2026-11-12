;;; minh/faces/config.el -*- lexical-binding: t; -*-

;; `doom-theme' rather than a direct `load-theme': Doom applies it once at
;; the right point in startup (and on `server-after-make-frame-hook'), so
;; a daemon's first frame comes up themed.  `custom-set-faces!' below is
;; applied from `doom-load-theme-hook', so it composes either way.
(setq doom-theme 'modus-operandi)

(custom-set-faces!
  '(font-lock-comment-face :foreground "DarkGray" :slant italic))

(setq doom-font
      ;; `find-font' needs a graphical display.  In a daemon started before
      ;; the first frame it returns nil even for fonts that *are* installed
      ;; -- verified with Hack present in fc-list -- so the old check
      ;; silently downgraded to Monospace and printed a misleading warning
      ;; on every daemon start.  Treat "cannot tell yet" as "use Hack" and
      ;; let Emacs fall back on its own if it really is missing.
      (if (or (not (display-graphic-p))
              (find-font (font-spec :family "Hack")))
          (font-spec :family "Hack" :size 14)
        (message "Warning: Hack font not found, falling back to Monospace")
        (font-spec :family "Monospace" :size 14)))

;; this is to fix an early loading issue on doom:
;; Invalid face reference: marginalia-file-priv-dir [819 times]
(defface marginalia-file-priv-dir
  '((t :inherit font-lock-keyword-face))
  "Face used to highlight the dir file privilege attribute.")

(with-eval-after-load 'diff-hl
  (set-face-foreground 'diff-hl-insert "green")
  (set-face-foreground 'diff-hl-delete "red")
  (set-face-foreground 'diff-hl-change "blue"))
