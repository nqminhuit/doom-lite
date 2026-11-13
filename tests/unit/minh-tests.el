;;; minh-tests.el --- ERT tests for the minh Doom modules -*- lexical-binding: t; -*-

;; Run with: tests/run.sh (or emacs --batch -Q -l tests/unit/minh-tests.el -f ert-run-tests-batch-and-exit)

(require 'ert)
(require 'cl-lib)
(require 'crm)
(require 'transient)

(defconst minh-tests--modules
  (expand-file-name "../../config/modules/minh/"
                    (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "utils/autoload.el" minh-tests--modules) nil t)
(load (expand-file-name "gis/autoload.el" minh-tests--modules) nil t)

;;; mm--get-file-names

(ert-deftest minh-file-names/keeps-paths-in-order ()
  (should (equal (mapcar #'cdr (mm--get-file-names '("/p/src/a.el" "/p/b.el" "/q/c.el") "/p"))
                 '("/p/src/a.el" "/p/b.el" "/q/c.el"))))

(ert-deftest minh-file-names/shows-the-directory-relative-to-the-project ()
  (let ((display (mapcar #'car (mm--get-file-names '("/p/src/a.el" "/p/b.el" "/q/c.el") "/p"))))
    (should (string-prefix-p "a.el " (nth 0 display)))
    (should (string-suffix-p " src/" (nth 0 display)))
    (should (string-suffix-p " ./" (nth 1 display)))
    (should (string-suffix-p " ../q/" (nth 2 display)))))

(ert-deftest minh-file-names/bare-names-have-no-directory-column ()
  (should (equal (mm--get-file-names '("README.md") "/p") '(("README.md" . "README.md")))))

;;; prot-common-crm-exclude-selected-p

(ert-deftest minh-crm/keeps-a-fresh-entry ()
  (let ((crm-separator "[ \t]*,[ \t]*"))
    (should (prot-common-crm-exclude-selected-p "svc"))
    (should (prot-common-crm-exclude-selected-p "api,svc"))))

(ert-deftest minh-crm/hides-an-entry-already-selected ()
  (let ((crm-separator "[ \t]*,[ \t]*"))
    (should-not (prot-common-crm-exclude-selected-p "svc,api,svc"))
    (should-not (prot-common-crm-exclude-selected-p "a,b,c,b"))))

;;; gis--parse-status

(ert-deftest minh-gis/parse-status-rejects-non-json ()
  (should-not (gis--parse-status "gis: unknown option --format"))
  (should-not (gis--parse-status "")))

(ert-deftest minh-gis/parse-status-reads-false-and-null-as-nil ()
  (let* ((data (gis--parse-status
                (concat "{\"fetchedAt\":\"2026-09-23T10:00:00\",\"modules\":["
                        "{\"module\":\"api\",\"root\":true,"
                        "\"branch\":{\"name\":\"main\",\"detached\":false,\"gone\":false,"
                        "\"upstream\":null,\"ahead\":0,\"behind\":2},"
                        "\"files\":[{\"indexStatus\":\"M\",\"worktreeStatus\":\" \"}]}]}")))
         (module (car (plist-get data :modules)))
         (branch (plist-get module :branch)))
    (should (equal (plist-get module :module) "api"))
    (should (eq (plist-get module :root) t))
    ;; json.el's default `:false' would be truthy and mark every module detached.
    (should-not (plist-get branch :detached))
    (should-not (plist-get branch :upstream))
    (should (equal (plist-get branch :behind) 2))
    (should (equal (length (plist-get module :files)) 1))))

;;; gis--status-buffer auto-fetch timer

(ert-deftest minh-gis/status-buffer-starts-and-cancels-fetch-timer ()
  (let* ((gis-auto-fetch-interval 300)
         (buffer (gis--status-buffer "/tmp/minh-gis-test-timer/" t))
         (timer (buffer-local-value 'gis--fetch-timer buffer)))
    (unwind-protect
        (progn
          (should (timerp timer))
          (should (memq timer timer-list))
          (kill-buffer buffer)
          ;; kill-buffer-hook must have cancelled it, not merely left it behind.
          (should-not (memq timer timer-list)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest minh-gis/status-buffer-skips-fetch-timer-when-disabled ()
  (let* ((gis-auto-fetch-interval nil)
         (buffer (gis--status-buffer "/tmp/minh-gis-test-no-timer/" t)))
    (unwind-protect
        (should-not (buffer-local-value 'gis--fetch-timer buffer))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

;;; gis/status display

(defmacro minh-tests--with-gis-status (root &rest body)
  "Run BODY with `gis/status' stubbed to ROOT, restoring windows and buffers."
  (declare (indent 1))
  `(save-window-excursion
     (delete-other-windows)
     (cl-letf (((symbol-function 'gis--get-gis-marker) (lambda () ,root))
               ((symbol-function 'gis--status-reload) #'ignore))
       (unwind-protect (progn ,@body)
         (when-let* ((buffer (gis--status-buffer ,root)))
           (kill-buffer buffer))))))

(ert-deftest minh-gis/status-obeys-display-buffer-alist ()
  (minh-tests--with-gis-status "/tmp/minh-gis-test-popup/"
    (let ((display-buffer-alist
           '(("^\\*gis: " display-buffer-in-side-window (side . right))))
          (code (window-buffer)))
      (gis/status)
      (should (eq (window-parameter (selected-window) 'window-side) 'right))
      (should (derived-mode-p 'gis-status-mode))
      (should (get-buffer-window code)))))

(ert-deftest minh-gis/status-replaces-the-window-without-a-rule ()
  (minh-tests--with-gis-status "/tmp/minh-gis-test-no-rule/"
    (let ((display-buffer-alist nil))
      (gis/status)
      (should (one-window-p))
      (should (derived-mode-p 'gis-status-mode)))))

;;; gis--beside-panel-a

(defun minh-tests--side-window (buffer side)
  (display-buffer-in-side-window buffer `((side . ,side))))

(defun minh-tests--full-height-p (window)
  (and (window-at-side-p window 'top) (window-at-side-p window 'bottom)))

(ert-deftest minh-gis/panel-keeps-its-full-height-under-a-bottom-window ()
  (let ((gis-auto-fetch-interval nil)
        (other (get-buffer-create " *minh-tests-bottom*")))
    (minh-tests--with-gis-status "/tmp/minh-gis-test-anchor/"
      (unwind-protect
          (let ((panel (minh-tests--side-window
                        (gis--status-buffer "/tmp/minh-gis-test-anchor/" t) 'left)))
            (should (minh-tests--full-height-p panel))
            (should-not (window-at-side-p (minh-tests--side-window other 'bottom) 'left))
            (should (minh-tests--full-height-p panel)))
        (kill-buffer other)))))

(ert-deftest minh-gis/bottom-window-spans-the-frame-without-a-panel ()
  (save-window-excursion
    (delete-other-windows)
    (let ((other (get-buffer-create " *minh-tests-bottom*")))
      (unwind-protect
          (let ((window (minh-tests--side-window other 'bottom)))
            (should (window-at-side-p window 'left))
            (should (window-at-side-p window 'right)))
        (kill-buffer other)))))

;;; gis--call-outside-panel

(ert-deftest minh-gis/outside-panel-uses-the-code-window ()
  (save-window-excursion
    (delete-other-windows)
    (let ((code (selected-window))
          (panel (split-window-right)))
      (set-window-dedicated-p panel 'popup)
      (select-window panel)
      (let ((default-directory "/tmp/minh-gis-root/"))
        (should (equal (gis--call-outside-panel
                        (lambda () (list (selected-window) default-directory)))
                       (list code "/tmp/minh-gis-root/")))))))

(ert-deftest minh-gis/outside-panel-stays-in-an-ordinary-window ()
  (save-window-excursion
    (delete-other-windows)
    (let ((window (selected-window)))
      (split-window-right)
      (should (eq (gis--call-outside-panel #'selected-window) window)))))

(ert-deftest minh-gis/magit-at-point-replaces-the-code-window ()
  (save-window-excursion
    (delete-other-windows)
    (let ((code (selected-window))
          (panel (split-window-right))
          (magit (get-buffer-create " *minh-tests-magit*")))
      (set-window-dedicated-p panel 'popup)
      (select-window panel)
      (cl-letf (((symbol-function 'vtable-current-object) (lambda () '(:dir "svc")))
                ((symbol-function 'gis--get-gis-marker) (lambda () "/tmp/minh-gis-root/"))
                ;; Stands in for Doom's display function, which splits when the
                ;; code window already shows another module's magit.
                ((symbol-function 'magit-status-setup-buffer)
                 (lambda (_dir) (display-buffer magit '(display-buffer-pop-up-window)))))
        (unwind-protect
            (progn
              (gis/magit-status-at-point)
              (should (= (length (window-list)) 2))
              (should (eq (window-buffer code) magit)))
          (kill-buffer magit))))))

;;; m--project-file-candidates

(ert-deftest minh-project-files/expands-abbreviated-root-for-fd ()
  (let (args)
    (cl-letf (((symbol-function 'm--call)
               (lambda (&rest a) (setq args a) "/home/u/p/src/a.el\n")))
      (let ((res (m--project-file-candidates "~/p")))
        (should (equal (car (last args)) (expand-file-name "~/p/")))
        (should-not (string-prefix-p "~" (car (last args))))
        (should (equal (mapcar #'cdr res) '("/home/u/p/src/a.el")))))))

(ert-deftest minh-project-files/finds-files-under-tilde-root ()
  (skip-unless (executable-find "fd"))
  (let* ((home (file-name-as-directory (make-temp-file "minh-home" t)))
         (process-environment (cons (concat "HOME=" home) process-environment)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "p" home))
          (write-region "" nil (expand-file-name "p/a.el" home))
          (let ((res (m--project-file-candidates "~/p/")))
            (should (equal (mapcar #'cdr res) (list (expand-file-name "p/a.el" home))))))
      (delete-directory home t))))

;;; minh-tests.el ends here
