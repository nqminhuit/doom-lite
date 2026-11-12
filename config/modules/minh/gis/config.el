;;; minh/gis/config.el -*- lexical-binding: t; -*-

;; Its name starts with `*', which Doom's `doom-special-buffer-p' treats as
;; "unreal" and so never registers with the current workspace -- making the
;; buffer invisible to `+vertico/switch-workspace-buffer' (`SPC b b').
(add-hook! 'gis-status-mode-hook
  #'(lambda ()
      (setq-local hl-line-face 'highlight)
      (setq-local doom-real-buffer-p t)))

;; A full-height panel at the left edge (`gis--beside-panel-a'); its own vslot
;; keeps other left popups out of its column.  `:quit nil' so ESC never closes it;
;; `:ttl nil' keeps the buffer and its fetch timer if it is closed anyway.
(set-popup-rule! "^\\*gis: " :side 'left :vslot -100 :size 0.33 :select t :quit nil :ttl nil :modeline t)

;; Defined here rather than in autoload.el, which Doom loads lazily: the
;; keybindings module fills this map in and is loaded right after this one.
(defvar gis-status-vtable-map (make-sparse-keymap)
  "Bindings for the rows of the gis status table.

vtable installs this map -- with `vtable-map' as its parent, which it sets
itself, so do not give it one -- as a `keymap' TEXT PROPERTY on every row.
A property keymap is consulted before the evil emulation maps and before
the major mode map, which has two consequences: whatever `vtable-map'
binds (`g', `S', `{', `}') has to be rebound here to survive on a row, and
the bindings here must be stateless, since evil's `:n' auxiliary keymaps
inside a property map are not reliably picked up.

The column header line carries vtable's own map instead of this one, so
`gis-status-mode-map' still needs the keys that must work everywhere.")
