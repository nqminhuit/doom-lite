;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; completion/vertico/doctor.el

(when (require 'consult nil t)
  (if (executable-find "rg")
      (unless (consult--grep-lookahead-p "rg" "-P")
        (warn! "The installed ripgrep binary was not built with support for PCRE lookaheads.")
        (explain! "Some advanced consult filtering features will not work as a result."))
    (if (executable-find "grep")
        (unless (consult--grep-lookahead-p "grep" "-P")
          (warn! "The installed grep binary was not built with support for PCRE lookaheads")
          (explain! "Some advanced consult filtering features will not work as a result."))
      (error! "Neither grep nor ripgrep are available on this system")
      (explain! "Various file and project search features won't be available"))))
