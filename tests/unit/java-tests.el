;;; java-tests.el --- ERT tests for the minh java module -*- lexical-binding: t; -*-

;; Run with: tests/run.sh (or emacs --batch -Q -l tests/unit/java-tests.el -f ert-run-tests-batch-and-exit)

(require 'ert)
(require 'cl-lib)
(require 'eglot)

(load (expand-file-name "../../config/modules/minh/java/config.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(defun java-tests--data-dir (contact)
  (cadr (member "-data" contact)))

(defun java-tests--expected (cache-root dir)
  (expand-file-name (file-name-concat cache-root "lsp-cache" (md5 (directory-file-name dir)))))

(defmacro java-tests--with-dirs (&rest body)
  "Run BODY with `dir', `other' and `cache' temp dirs, outside any VCS."
  `(let* ((dir (file-name-as-directory (make-temp-file "java-tests-dir" t)))
          (other (file-name-as-directory (make-temp-file "java-tests-other" t)))
          (cache (file-name-as-directory (make-temp-file "java-tests-cache" t)))
          (default-directory dir)
          (user-emacs-directory cache)
          (project-find-functions (list #'project-try-vc)))
     (unwind-protect (progn ,@body)
       (dolist (d (list dir other cache)) (delete-directory d t)))))

(ert-deftest java-contact/lombok-agent-added-when-jar-exists ()
  (java-tests--with-dirs
   (let ((jar (expand-file-name "lombok.jar" dir)))
     (write-region "" nil jar)
     (cl-letf (((symbol-function '+java--lombok-jar) (lambda () jar)))
       (should (member (concat "--jvm-arg=-javaagent:" jar) (jdtls-command-contact nil)))))))

(ert-deftest java-contact/missing-lombok-jar-warns-once-and-omits-agent ()
  (java-tests--with-dirs
   (let ((jar (expand-file-name "missing.jar" dir))
         (+java--lombok-warned nil)
         warnings)
     (cl-letf (((symbol-function '+java--lombok-jar) (lambda () jar))
               ((symbol-function 'display-warning)
                (lambda (_type msg &rest _) (push msg warnings))))
       (dotimes (_ 2)
         (should-not (cl-some (lambda (a) (string-prefix-p "--jvm-arg=-javaagent" a))
                              (jdtls-command-contact nil))))
       (should (= (length warnings) 1))
       (should (string-search jar (car warnings)))))))

(ert-deftest java-contact/no-project-uses-the-file-directory ()
  (java-tests--with-dirs
   (should-not (project-current))
   (should (equal (java-tests--data-dir (jdtls-command-contact nil))
                  (java-tests--expected cache dir)))))

(ert-deftest java-contact/explicit-project-wins ()
  (java-tests--with-dirs
   (should (equal (java-tests--data-dir (jdtls-command-contact nil (cons 'transient other)))
                  (java-tests--expected cache other)))))
