;;; lang/java/config.el -*- lexical-binding: t; -*-

(defvar +java-project-package-roots (list "java/" "test/" "main/" "src/" 1)
  "A list of relative directories (strings) or depths (integer) used by
`+java-current-package' to delimit the namespace from the current buffer's full
file path. Each root is tried in sequence until one is found.

If a directory is encountered in the file path, everything before it (including
it) will be ignored when converting the path into a namespace.

An integer depth is how many directories to pop off the start of the relative
file path (relative to the project root). e.g.

Say the absolute path is ~/some/project/src/java/net/lissner/game/MyClass.java
The project root is ~/some/project
If the depth is 1, the first directory in src/java/net/lissner/game/MyClass.java
  is removed: java.net.lissner.game.
If the depth is 2, the first two directories are removed: net.lissner.game.")


;;
;;; Common packages

(use-package! cc-mode  ; where `java-mode' lives
  :defer t
  :config
  (set-indent-vars! 'java-mode 'c-basic-offset))


(use-package! java-ts-mode  ; 29.1+ only
  :defer t
  :init
  (set-tree-sitter! 'java-mode 'java-ts-mode '(java doxygen)))

