;;; term/ghostel/doctor.el -*- lexical-binding: t; -*-

;; The module is downloaded on first use (see config.el); compiling it from
;; source (zig) is unsupported, so there is no zig check.
(unless (fboundp 'module-load)
  (warn! "Your emacs wasn't built with dynamic modules support. The ghostel module won't load"))
