;;; lisp/lib/process.el -*- lexical-binding: t; -*-

(defun doom--strip-final-newline ()
  (unless (= (point-min) (point-max))
    (save-excursion
      (goto-char (point-max))
      (when (looking-at-p "^$")
        (delete-char -1)))))

;;;###autoload
(defun doom-call-process (command &rest args)
  "Execute COMMAND with ARGS synchronously.

Returns (STATUS . OUTPUT) when it is done, where STATUS is the returned error
code of the process and OUTPUT is its stdout output."
  (with-temp-buffer
    (cons (or (apply #'call-process command nil t nil (remq nil args))
              -1)
          (progn
            (doom--strip-final-newline)
            (buffer-string)))))

(provide 'doom-lib '(process))
;;; process.el ends here
