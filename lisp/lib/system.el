;;; lisp/lib/system.el -*- lexical-binding: t; -*-

;;;###autoload
(defun doom-system-distro ()
  "Return a symbol representing the installed distro."
  (with-memoization (get 'doom-system-distro 'cached-value)
    (cond ((ignore-errors
             (with-file-contents! "/etc/os-release"
               (when (re-search-forward "^ID=\"?\\([^\"\n]+\\)\"?" nil t)
                 (intern (downcase (match-string 1)))))))
          ;; A few redundancies in case os-release fails us
          ((file-exists-p "/etc/debian_version")
           'debian)
          ((executable-find "nixos-version")
           'nixos)
          ((and (or (file-exists-p "/etc/config.scm")
                    (file-directory-p "/run/current-system"))
                (executable-find "guix"))
           'guix)
          ('linux))))

;;;###autoload
(defun doom-system-distro-version ()
  "Return a distro name and version string."
  (letf! (defun sh (&rest args) (cdr (apply #'doom-call-process args)))
    (let ((distro (doom-system-distro)))
      (cond
       ((eq distro 'windows)
        (format "Windows %s" "Unknown")) ; TODO
       ((eq distro 'macos)
        (format "MacOS %s" (sh "sw_vers" "-productVersion")))
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
       ((concat "Unknown " (sh "uname" "-v")))))))

;;;###autoload
(defun doom-system-distro-icon ()
  "Display icon for the installed distro."
  (with-memoization (get 'doom-system-distro-icon 'cached-value)
    (propertize
     (pcase (doom-system-distro)
       (`windows (nerd-icons-faicon "nf-fa-windows"))
       (`macos (nerd-icons-faicon "nf-fa-apple"))
       (`arch "\uF303")
       (`debian "\uF306")
       (`raspbian "\uF315")
       (`ubuntu "\uF31b")
       (`elementary "\uF309")
       (`fedora "\uF30a")
       (`coreos "\uF305")
       (`gentoo "\uF30d")
       (`mageia "\uF310")
       (`centos "\uF304")
       ((or `opensuse `tumbleweed) "\uF314")
       (`sabayon "\uF317")
       (`slackware "\uF319")
       (`linuxmint "\uF30e")
       (`alpine "\uF300")
       (`aosc "\uF301")
       (`nixos "\uF313")
       (`devuan "\uF307")
       (`manjaro "\uF312")
       ((or `void `artix) "\uF17c")
       (_ (nerd-icons-faicon "nf-fa-linux")))
     'face '(:height 1)
     'display '(raise 0))))

;;;###autoload
(defun doom-system-cpus ()
  "Return the max number of processing units on this system."
  (with-memoization (get 'doom-system-cpus 'cached-value)
    (num-processors)))

;;;###autoload
(defun doom-system-supports-symlinks-p ()
  "Return non-nil if this system supports symlinks"
  (condition-case e
      (let ((filea (expand-file-name "__doom_testfile1" temporary-file-directory))
            (fileb (expand-file-name "__doom_testfile2" temporary-file-directory)))
        (unwind-protect
            (progn
              (with-temp-file fileb)
              (make-symbolic-link fileb filea)
              (and (file-symlink-p filea)
                   (file-equal-p filea fileb)))
          (delete-file filea)
          (delete-file fileb)))
    (file-error
     (if (equal (cons (nth 1 e) (nth 2 e))
                (cons "Making symbolic link" "Operation not permitted"))
         nil
       (signal (car e) (cdr e))))))

(provide 'doom-lib '(system))
;;; system.el ends here
