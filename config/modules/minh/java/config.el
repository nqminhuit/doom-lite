;;; minh/java/config.el -*- lexical-binding: t; -*-

;; To install eclipse jdtls:
;; mkdir /opt/minh/tools/lsp-java/1.48.0; cd /opt/minh/tools/lsp-java/1.48.0
;; wget -O jdt-language-server-1.48.0.tar.gz "https://www.eclipse.org/downloads/download.php?file=/jdtls/milestones/1.48.0/jdt-language-server-1.48.0-202506271502.tar.gz"
;; tar -xf *.gz
;; ln -sfn /opt/minh/tools/lsp-java/1.48.0/bin/jdtls ~/.local/bin

(defconst +java/lombok-version
  (string-trim
   (with-temp-buffer
     (insert-file-contents
      (expand-file-name "lombok-version"
                        (file-name-directory (or load-file-name buffer-file-name))))
     (buffer-string))))

(defun +java--project ()
  "The current project, or eglot's transient project for `default-directory' when there is none."
  (or (project-current) `(transient . ,(expand-file-name default-directory))))

(with-eval-after-load 'eglot
  ;; ref: https://github.com/zsxh/emacs.d/blob/master/lisp/init-lang-java.el
  (defun jdtls-command-contact (&optional interactive project)
    (let* ((jdtls-cache-dir (file-name-concat user-emacs-directory "lsp-cache"))
           ;; The full root, not its basename: two checkouts named alike must not share a workspace.
           (project-dir (directory-file-name (expand-file-name (project-root (or project (+java--project))))))
           (data-dir (expand-file-name (file-name-concat jdtls-cache-dir (md5 project-dir))))
           (java-agent-path
            (expand-file-name
             (format "~/.m2/repository/org/projectlombok/lombok/%s/lombok-%s.jar" +java/lombok-version +java/lombok-version)))
           (jvm-args `(,(concat "-javaagent:" java-agent-path)))
           (jvm-args (mapcar (lambda (arg) (concat "--jvm-arg=" arg)) jvm-args))
           ;; tell jdtls the data directory and jvm args
           (contact (append '("jdtls") jvm-args `("-data" ,data-dir))))
      contact))

  (push '((java-mode java-ts-mode) . jdtls-command-contact) eglot-server-programs)

  ;; ----------------------- Intialization/Configurations -----------------------
  ;; (jsonrpc--json-encode (jdtls-initialization-options))
  (defun jdtls-initialization-options ()
    `(:settings (:java (:autobuild (:enabled t)
                                   :import (:generatesMetadataFilesAtProjectRoot t)
                                   :format (:enabled t :settings (:url "file:///opt/minh/linux-config/tools/eclipse-java-google-style_customize.xml" :profile "GoogleStyleCustom"))
                                   :completion (:overwrite :json-false
                                                           :guessMethodArguments t
                                                           :lazyResolveTextEdit (:enabled t))
                                   :edit (:validateAllOpenBuffersOnChanges :json-false)
                                   ;; Javadoc generation, https://github.com/mfussenegger/nvim-jdtls/issues/76#issuecomment-831448277
                                   :codeGeneration (:generateComments t)
                                   :maven (:downloadSources t)))
                :extendedClientCapabilities (:classFileContentsSupport t :overrideMethodsPromptSupport t)

                ;; mvn org.apache.maven.plugins:maven-dependency-plugin:3.8.1:get -Dartifact=com.microsoft.java:com.microsoft.java.debug.plugin:0.53.1
                :bundles ["/home/minh/.m2/repository/com/microsoft/java/com.microsoft.java.debug.plugin/0.53.1/com.microsoft.java.debug.plugin-0.53.1.jar"]))

  (cl-defmethod eglot-initialization-options (server &context (major-mode java-mode))
    (jdtls-initialization-options))

  (cl-defmethod eglot-initialization-options (server &context (major-mode java-ts-mode))
    (jdtls-initialization-options))

  ;; ----------------------- Support URI jdt:// protocol -----------------------
  (defun +java/eglot-find-jdt-server ()
    (let ((filter-fn (lambda (server)
                       (cl-loop for (mode . languageid) in
                                (eglot--languages server)
                                when (string= languageid "java")
                                return languageid)))
          (servers (gethash (eglot--current-project) eglot--servers-by-project)))
      (cl-find-if filter-fn servers)))

  (defun +java--jdt-fallback (operation args)
    "Run OPERATION on ARGS through the file name handlers other than ours."
    (let ((inhibit-file-name-handlers
           (cons '+java/eglot-jdt-uri-handler
                 (and (eq inhibit-file-name-operation operation)
                      inhibit-file-name-handlers)))
          (inhibit-file-name-operation operation))
      (apply operation args)))

  (defun +java/eglot-jdt-uri-handler (operation &rest args)
    "Support Eclipse jdtls `jdt://' uri scheme."
    (let* ((uri (car args))
           (parts (and (stringp uri)
                       (string-match "jdt://contents/\\(.*?\\)/\\(.*\\)\\.class\\?" uri)
                       (list (match-string 1 uri) (match-string 2 uri)))))
      (if (null parts)
          ;; Not a class-contents uri; without this the stale match data of
          ;; some earlier search was used to build a path.
          (+java--jdt-fallback operation args)
        ;; Under Doom's cache rather than the shared /tmp, where anyone could
        ;; plant the "decompiled" source first.
        (let* ((cache-dir (expand-file-name "eglot-java" doom-cache-dir))
               (jar-dir (file-name-as-directory (expand-file-name (car parts) cache-dir)))
               (java-file (format "%s.java" (replace-regexp-in-string "/" "." (cadr parts) t t)))
               (source-file (expand-file-name java-file jar-dir)))
          (unless (file-readable-p source-file)
            (let ((content (jsonrpc-request
                            (or (eglot-current-server)
                                ;; NOTE: dape https://github.com/svaante/dape/issues/78#issuecomment-1966786597
                                (+java/eglot-find-jdt-server))
                            :java/classFileContents (list :uri uri))))
              (unless (file-directory-p jar-dir) (make-directory jar-dir t))
              (with-temp-file source-file (insert content))))
          (cond
           ((eq operation 'expand-file-name) source-file)
           ((eq operation 'file-truename) source-file)
           ((eq operation 'file-local-name) source-file)
           ((eq operation 'file-remote-p) nil)
           ;; Handle any operation we don’t know about.
           (t (+java--jdt-fallback operation args)))))))

  (add-to-list 'file-name-handler-alist '("\\`jdt://" . +java/eglot-jdt-uri-handler)))


(with-eval-after-load 'dape
  (add-to-list 'dape-configs
               `(jdtls
                 modes (java-mode java-ts-mode)
                 fn (lambda (config)
                      (let ((project (+java--project)))
                        (with-current-buffer
                            (find-file-noselect (expand-file-name (plist-get config :program)
                                                                  (project-root project)))
                          (thread-first
                            config
                            (plist-put 'hostname "localhost")
                            (plist-put 'port (eglot-execute-command (eglot-current-server)
                                                                    "vscode.java.startDebugSession" nil))
                            (plist-put :projectName (project-name project))))))
                 :program dape-buffer-default
                 :request "attach"
                 :hostname "localhost"
                 :port 12100)))


;; Skip import statements in xref results for Java buffers.  This has to
;; live in config.el: as a top-level `advice-add' in autoload.el it was
;; only installed once some other autoloaded function from that file ran,
;; so in a fresh session the filter did nothing.
(with-eval-after-load 'xref
  (defun m/xref-filter-imports (xrefs)
    "Filter out xref results that are in import statements, for Java files only."
    (if (derived-mode-p 'java-ts-mode)
        (seq-remove
         (lambda (xref)
           (let ((summary (xref-item-summary xref)))
             (and summary
                  (string-match-p "\\bimport\\b" summary))))
         xrefs)
      xrefs))

  (defun m/xref--show-xrefs-around (orig-fn fetcher alist)
    "Advice to filter xrefs only in Java files to skip import references."
    (let ((filtered (m/xref-filter-imports (funcall fetcher))))
      (funcall orig-fn (lambda () filtered) alist)))

  (advice-add 'xref--show-xrefs :around #'m/xref--show-xrefs-around))
