;;; tools/lsp/autoload/common.el -*- lexical-binding: t; -*-

;;;###autodef (fset 'lsp! #'ignore)
(defun lsp! ()
  "Start eglot for the current buffer if a client is defined for its major mode."
  (when (require 'eglot nil t)
    (if (eglot--lookup-mode major-mode)
        (eglot-ensure)
      (eglot--message "No client defined for %s" major-mode))))
