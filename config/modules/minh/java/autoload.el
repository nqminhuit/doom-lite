;;; minh/minh-java/autoload.el -*- lexical-binding: t; -*-

;; Constants
(defconst mvn-cmd "mvnd")
(defconst mvn-pom "pom.xml")
(defconst mm-classpath "mm.classpath")
(defconst junit-jar-path "/opt/minh/tools/junit-platform-console-standalone-1.12.1.jar")

(defconst all-modules "<all>")
(defconst cm--vers '("cmonp" "cmcloud"))
(defvar cm--ver (car cm--vers))

;; Placeholder vars for per-project `.dir-locals.el'
(defvar compileable-modules '())
(defvar mm--services '())
(defvar lib-modules '())

(defun m--compile (cmd bufname &optional directory)
  "Run `compile` with CMD under buffer BUFNAME in DIRECTORY."
  (let ((default-directory (or directory (project-root (project-current t)))))
    (save-some-buffers t)
    (compilation-start cmd nil (lambda (_mode) (format "*compilation*-%s" bufname)))))

;; Maven/Podman Integration
(defun m--choose-lib-module (lib-module)
  (if (string= all-modules lib-module)
      (mapconcat #'identity lib-modules ",")
    lib-module))

(defun m--choose-services (service)
  (if (string= all-modules service)
      (mapconcat #'identity mm--services ",")
    service))

(defun mvn--build-lib (lib-module &optional service)
  (let* ((dir (project-root (project-current t)))
         (build-buffer
          (m--compile
           (if service
               (format "%s -pl %s,%s clean install -DskipTests"
                       mvn-cmd (m--choose-lib-module lib-module) (m--choose-services service))
             (format "%s -pl %s install -DskipTests" mvn-cmd (m--choose-lib-module lib-module)))
           (format "buildlib-%s%s" lib-module (if service (concat "-" service) ""))
           dir)))
    (when service
      ;; A buffer-local finish hook rather than a new process sentinel: replacing
      ;; `compilation-sentinel' left the buffer unfinished and "Compiling" stuck.
      (with-current-buffer build-buffer
        (add-hook 'compilation-finish-functions
                  (lambda (_buffer status)
                    (when (string-prefix-p "finished" status)
                      (m--compile (cm--s-restart service) service dir)))
                  nil t)))))

(defun mvn--get-root-module ()
  (m--get-parent-dir-only (project-root (project-current t))))

(defun cm--s-restart (service &optional compile)
  (if (string= all-modules service)
      (format "n=\"%s\"; podman pod stop --ignore $n &; %s wait; podman kube play -q --configmap ../dockers/config/config-$n.yaml --replace dev-composes/$n.yaml"
              cm--ver
              (if compile (format "%s -DskipTests clean install || return 1;" mvn-cmd) ""))
    (format "p=\"%s\"; n=\"%s\"; podman stop -t 1 --ignore $p-$n &; %s wait; podman restart $p-$n"
            cm--ver service
            (if compile (format "%s -DskipTests clean -pl $n package || return 1;" mvn-cmd) ""))))

;;;###autoload
(defun java/build-lib (module)
  (interactive (list (completing-read "Build lib: " (cons all-modules lib-modules))))
  (mvn--build-lib module))

;;;###autoload
(defun cm/switch-cloud-or-onprem (ver)
  (interactive (list (completing-read "Choose version: " cm--vers)))
  (setq cm--ver ver))

;;;###autoload
(defun java/build-lib-and-restart (module service)
  (interactive
   (list (completing-read "Build lib: " (cons all-modules lib-modules))
         (completing-read (format "Deploy %s service: " cm--ver) (cons all-modules mm--services))))
  (mvn--build-lib module service))

;;;###autoload
(defun java/compile (module)
  (interactive (list (completing-read "Compile module: " compileable-modules)))
  (m--compile
   (if (string= (mvn--get-root-module) module)
       (format "%s test-compile" mvn-cmd)
     (format "%s -f %s test-compile" mvn-cmd module))
   module))

;;;###autoload
(defun java/test (module)
  (interactive (list (completing-read "Test module: " compileable-modules)))
  (let ((cmd (format "%s -DtrimStackTrace=false -Djacoco.skip=true verify" mvn-cmd))
        (dir (if (string= (mvn--get-root-module) module)
                 nil
               (file-name-concat (project-root (project-current t)) module))))
    (m--compile cmd (format "test:%s" module) dir)))

;;;###autoload
(defun java/generate-current-project-classpath ()
  (interactive)
  (m--compile
   (format "%s dependency:build-classpath -Dmdep.outputFile=%s" mvn-cmd mm-classpath)
   "genclasspath"))

;;;###autoload
(defun java/test-current-method ()
  "Run mvn test method inside method body, require `java-ts-mode'."
  (interactive)
  (let ((pom (locate-dominating-file buffer-file-name mvn-pom))
        (method (treesit-defun-name (treesit-defun-at-point)))
        (class (file-name-base buffer-file-name)))
    (m--compile
     (format "mvn -q -f %s test -DtrimStackTrace=false -Dtest=%s#%s" pom class method)
     (concat "test:" method))))

;;;###autoload
(defun java/test-current-class ()
  "Run mvn test current buffer."
  (interactive)
  (let ((pom (locate-dominating-file buffer-file-name mvn-pom))
        (class (file-name-base buffer-file-name)))
    (m--compile
     (format "mvn -q -T 1C -f %s test -DtrimStackTrace=false -Dtest=%s" pom class)
     (concat "test:" class))))

;;;###autoload
(defun java/rebuild-services (services)
  (interactive (list (completing-read-multiple
                      (format "Build and Deploy %s service: " cm--ver)
                      (cons all-modules mm--services)
                      #'prot-common-crm-exclude-selected-p)))
  (dolist (service services)
    (m--compile (cm--s-restart service t) service)))

;;;###autoload
(defun java/restart-services (services)
  (interactive (list (completing-read-multiple
                      (format "Restart %s service: " cm--ver)
                      (cons all-modules mm--services)
                      #'prot-common-crm-exclude-selected-p)))
  (dolist (service services)
    (m--compile (cm--s-restart service) service)))
