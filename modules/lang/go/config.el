;;; lang/go/config.el -*- lexical-binding: t; -*-

;;
;;; Packages

(defun +go-common-config (mode)
  (add-hook (intern (format "%s-local-vars-hook" mode)) #'lsp! 'append)

  (map! :map ,(intern (format "%s-map" mode))
        :localleader
        (:prefix ("b" . "build")
          :desc "go run ." "r" (cmd! (compile "go run ."))
          :desc "go build" "b" (cmd! (compile "go build"))
          :desc "go clean" "c" (cmd! (compile "go clean")))
        (:prefix ("g" . "generate")
          "f" #'+go/generate-file
          "d" #'+go/generate-dir
          "a" #'+go/generate-all)
        (:prefix ("t" . "test")
          "t" #'+go/test-rerun
          "a" #'+go/test-all
          "s" #'+go/test-single
          "n" #'+go/test-nested
          "f" #'+go/test-file
          "g" #'go-gen-test-dwim
          "G" #'go-gen-test-all
          "e" #'go-gen-test-exported
          (:prefix ("b" . "bench")
            "s" #'+go/bench-single
            "a" #'+go/bench-all))))


(use-package! go-ts-mode
  :mode ("\\.go\\'" . go-ts-mode)
  :mode ("/go\\.mod\\'" . go-mod-ts-mode)
  :mode ("/go\\.work\\'" . go-work-ts-mode)
  :config
  (+go-common-config 'go-ts-mode))
