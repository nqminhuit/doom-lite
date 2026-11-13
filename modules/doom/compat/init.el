;;; modules/doom/compat/init.el -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;;
;;; * Deprecated sub-modules

(load! "+use-package")
(if (modulep! +keybinds)    (load! "+keybinds"))  ; `map!'

;;; init.el ends here
