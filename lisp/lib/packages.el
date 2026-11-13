;;; lisp/lib/packages.el -*- lexical-binding: t; -*-

;;;###autoload
(defun doom/reload-packages ()
  "Reload `doom-packages' and the build dirs on the `load-path'."
  (interactive)
  (message "Reloading packages")
  (doom-initialize-packages t)
  (message "Reloading packages...DONE"))

(provide 'doom-lib '(packages))
;;; packages.el ends here
