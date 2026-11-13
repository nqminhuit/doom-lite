;;; comment-tests.el --- the `gc' comment operator -*- lexical-binding: t; -*-

(require 'ert)

(defconst cmt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/packages-paths.el" cmt--root) nil t)

(dolist (pkg '("evil" "goto-chg" "evil-nerd-commenter"))
  (let ((dir (tpp-build-dir cmt--root pkg)))
    (when (file-directory-p dir) (add-to-list 'load-path dir))))

(defconst cmt--evil-p (require 'evil nil t))

(defun cmt--operator ()
  "The operator under test: ours when present, else evil-nerd-commenter's."
  (load (expand-file-name "modules/editor/evil/autoload/comment.el" cmt--root) t t)
  (if (fboundp '+evil:comment)
      '+evil:comment
    (require 'evil-nerd-commenter)
    'evilnc-comment-operator))

(defun cmt--run (text point keys)
  "Run KEYS on TEXT with point at POINT; return (TEXT . POINT)."
  (unless cmt--evil-p (ert-skip "evil not found"))
  (let ((op (cmt--operator)))
    ;; The command loop acts on the selected window's buffer, so the buffer must be displayed.
    (save-window-excursion
     (let ((buf (generate-new-buffer " *cmt*")))
      (unwind-protect
       (progn
      (switch-to-buffer buf)
      (emacs-lisp-mode)
      (insert text)
      (goto-char point)
      (evil-local-mode 1)
      (evil-normal-state)
      (dolist (map (list evil-normal-state-local-map evil-visual-state-local-map))
        (define-key map (kbd "gc") op))
      (execute-kbd-macro (kbd keys))
      (cons (buffer-string) (point)))
       (kill-buffer buf))))))

(ert-deftest cmt-gcc-toggles-line ()
  (let ((text "(foo)\n  (bar baz)\n(qux)\n"))
    (let ((r (cmt--run text 12 "gcc")))
      (should (equal (car r) "(foo)\n  ;; (bar baz)\n(qux)\n"))
      (should (= (cdr r) 9)))
    (let ((r (cmt--run "(foo)\n  ;; (bar baz)\n(qux)\n" 12 "gcc")))
      (should (equal (car r) text))
      (should (= (cdr r) 9)))))

(ert-deftest cmt-gcap-first-paragraph-only ()
  (let ((r (cmt--run "(a)\n(b)\n(c)\n\n(d)\n(e)\n" 6 "gcap")))
    (should (equal (car r) ";; (a)\n;; (b)\n;; (c)\n\n(d)\n(e)\n"))
    (should (= (cdr r) 1))))

(ert-deftest cmt-count-comments-two-lines ()
  (let ((r (cmt--run "(a)\n(b)\n(c)\n" 2 "2gcc")))
    (should (equal (car r) ";; (a)\n;; (b)\n(c)\n"))
    (should (= (cdr r) 1)))
  (let ((r (cmt--run "(a)\n(b)\n(c)\n" 2 "gcj")))
    (should (equal (car r) ";; (a)\n;; (b)\n(c)\n"))
    (should (= (cdr r) 1))))

(ert-deftest cmt-linewise-visual-toggles ()
  (let ((r (cmt--run "(a)\n(b)\n(c)\n" 2 "Vjgc")))
    (should (equal (car r) ";; (a)\n;; (b)\n(c)\n"))
    (should (= (cdr r) 1))
    (let ((r2 (cmt--run (car r) 2 "Vjgc")))
      (should (equal (car r2) "(a)\n(b)\n(c)\n"))
      (should (= (cdr r2) 1)))))

(ert-deftest cmt-charwise-visual-comments-exact-region ()
  ;; evil-nerd-commenter does not widen a characterwise selection to whole lines.
  (let ((r (cmt--run "(a b c d)\n(e)\n" 3 "vegc")))
    (should (equal (car r) "(a ;; b\n   c d)\n(e)\n"))
    (should (= (cdr r) 3))))

(ert-deftest cmt-last-line-without-newline ()
  (let ((r (cmt--run "(a)\n(b)" 6 "gcc")))
    (should (equal (car r) "(a)\n;; (b)"))
    (should (= (cdr r) 5))))

;;; comment-tests.el ends here
