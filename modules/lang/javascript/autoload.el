;;; lang/javascript/autoload.el -*- lexical-binding: t; -*-

(defvar +javascript-npm-conf (make-hash-table :test 'equal))

;;;###autoload
(defun +javascript-npm-conf (&optional project-root refresh-p)
  "Retrieve an alist of this project's package.json.

If REFRESH-P is non-nil ignore the cache. PROJECT-ROOT determines where to look
for the package.json file, and defaults to the current buffer's project root."
  (let ((project-root (or project-root (doom-project-root))))
    (or (and (not refresh-p)
             (gethash project-root +javascript-npm-conf))
        (let ((package-file (expand-file-name "package.json" project-root)))
          (when-let* ((json (and (file-exists-p package-file)
                                 (require 'json)
                                 (json-read-file package-file))))
            (puthash project-root json +javascript-npm-conf))))))

;;;###autoload
(defun +javascript-add-npm-path-h ()
  "Add node_modules/.bin to `exec-path'."
  (when-let* ((search-directory (or (doom-project-root) default-directory))
              (node-modules-parent (locate-dominating-file search-directory "node_modules/"))
              (node-modules-dir (expand-file-name "node_modules/.bin/" node-modules-parent)))
    (make-local-variable 'exec-path)
    (add-to-list 'exec-path node-modules-dir)
    (doom-log ":lang:javascript: add %s to $PATH" (expand-file-name "node_modules/" node-modules-parent))))

