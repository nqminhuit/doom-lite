;;; lisp/lib/system.el -*- lexical-binding: t; -*-

;;;###autoload
(defun doom-system-distro-version ()
  "Return a distro name and version string."
  (letf! (defun sh (&rest args) (cdr (apply #'doom-call-process args)))
    (cond
     ((executable-find "nixos-version")
      (format "NixOS %s" (sh "nixos-version")))
     ((executable-find "lsb_release")
      (sh "lsb_release" "-s" "-d"))
     ((ignore-errors
        (with-file-contents! "/etc/os-release"
          (when (re-search-forward "^PRETTY_NAME=\"?\\([^\"\n]+\\)\"?" nil t)
            (match-string 1)))))
     ((when-let* ((files (doom-glob "/etc/*-release")))
        (truncate-string-to-width
         (replace-regexp-in-string
          "\n" " " (doom-file-read (car files) :end 73) nil t)
         64 nil nil "...")))
     ((concat "Unknown " (sh "uname" "-v"))))))

;;;###autoload
(defun doom-system-cpus ()
  "Return the max number of processing units on this system."
  (with-memoization (get 'doom-system-cpus 'cached-value)
    (num-processors)))

(provide 'doom-lib '(system))
;;; system.el ends here
