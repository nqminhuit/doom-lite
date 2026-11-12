;;; minh/majormodes/config.el -*- lexical-binding: t; -*-

(defvar powershell-minimal-font-lock-keywords
  `(
    ;; Comments
    ("#.*$" . font-lock-comment-face)

    ;; Keywords
    (,(regexp-opt
       '("if" "else" "elseif" "for" "foreach" "while" "switch" "break"
         "continue" "return" "function" "param" "begin" "process" "end"
         "try" "catch" "finally" "throw" "trap")
       'words)
     . font-lock-keyword-face)

    ;; Cmdlets (start with verb-noun)
    ("\\b\\([A-Z][a-z]+-[A-Z][A-Za-z]+\\)\\b" . font-lock-function-name-face)

    ;; Variables
    ("\\$[A-Za-z0-9:_-]+" . font-lock-variable-name-face)

    ;; Strings
    ("\"[^\"]*\"" . font-lock-string-face)
    ("'[^']*'"   . font-lock-string-face)))

(define-derived-mode m-powershell-mode prog-mode "PowerShell"
  "A minimal major mode for PowerShell syntax highlighting."
  (setq-local font-lock-defaults '((powershell-minimal-font-lock-keywords))))

;;;

(defvar m-proto-mode-font-lock-keywords
  '(("\\<\\(message\\|enum\\|service\\|rpc\\|returns\\|import\\|syntax\\|package\\)\\>" . font-lock-keyword-face)
    ("\\<\\(optional\\|repeated\\|required\\)\\>" . font-lock-type-face)
    ("\\<\\(int32\\|int64\\|string\\|bool\\|float\\|double\\|bytes\\)\\>" . font-lock-builtin-face)
    ("//.*" . font-lock-comment-face))
  "Keyword patterns for `m-proto-mode'.")

(define-derived-mode m-proto-mode prog-mode "Proto"
  "Minimal mode for editing Protocol Buffer files."
  (setq-local font-lock-defaults '((m-proto-mode-font-lock-keywords))))

;; Single-line `//' comments.  Modify the table `define-derived-mode'
;; generated -- which inherits from `prog-mode-syntax-table' -- instead of
;; a fresh `make-syntax-table', which inherits only from the standard
;; table and was rebuilt for every buffer.
(modify-syntax-entry ?/ ". 12b" m-proto-mode-syntax-table)
(modify-syntax-entry ?\n "> b" m-proto-mode-syntax-table)


;;;

(defvar containerfile-instructions
  '("FROM" "RUN" "CMD" "LABEL" "MAINTAINER" "EXPOSE" "ENV" "ADD" "COPY"
    "ENTRYPOINT" "VOLUME" "USER" "WORKDIR" "ARG" "ONBUILD" "STOPSIGNAL"
    "HEALTHCHECK" "SHELL" "STAGE" "STAGES")
  "List of Dockerfile/Containerfile instructions to highlight.
This list is canonicalized manually; duplicates are removed here.")

(defvar containerfile-font-lock-keywords
  (let* ((instr-re (concat "^\\s-*\\(" (regexp-opt containerfile-instructions 'words) "\\)\\b")))
    (list
     ;; BuildKit syntax directive (must be at top; highlight specially)
     '("^\\s-*#\\s-*syntax=\\([^ \t\n]+\\)" 1 font-lock-preprocessor-face)

     ;; Instructions at beginning of line (highlight as keywords)
     (cons instr-re 'font-lock-keyword-face)

     ;; AS in "FROM ... AS <stage>" -- highlight the stage name
     '("^[ \t]*FROM[ \t].*\\bAS\\b[ \t]+\\([A-Za-z0-9_\\-]+\\)" 1 font-lock-constant-face)

     ;; Common flags used in instructions (--mount, --from, --chown, --platform, --target)
     '("\\(--mount=\\|--from=\\|--chown=\\|--platform=\\|--target=\\)" . font-lock-builtin-face)

     ;; RUN --mount types (cache/secret/bind/tmpfs)
     '("\\btype=\\(cache\\|secret\\|bind\\|tmpfs\\)\\b" 1 font-lock-builtin-face)

     ;; Variable references $VAR and ${VAR}
     '("\\$\\({\\)?[A-Za-z_][A-Za-z0-9_]*\\(}\\)?" . font-lock-variable-name-face)

     ;; JSON/exec-form punctuation (very small touch)
     '("[][{},]" . font-lock-punctuation-face)

     ;; Heredoc starter: <<EOF or <<-'EOF' etc.  highlight the marker token
     ;; The quote group always matches, possibly empty: a \1 back-reference to a group
     ;; that did not take part never matches, which hid every unquoted <<EOF.
     '("<<-?\\(['\"]?\\)\\([A-Za-z0-9_/-]+\\)\\1" 2 font-lock-string-face)

     ;; Comments fallback
     '("#.*$" . font-lock-comment-face)))
  "Font-lock keywords for `containerfile-mode'.")

(define-derived-mode containerfile-mode prog-mode "Containerfile"
  "A minimal major mode for Dockerfile / Containerfile syntax highlighting."
  ;; Localize comment handling
  (setq-local comment-start "#")
  (setq-local comment-start-skip "#+\\s-*")
  ;; Dockerfile instructions are case-insensitive.  The case-fold flag
  ;; font-lock honours is the *third* element of `font-lock-defaults'
  ;; (it sets `font-lock-keywords-case-fold-search'); a buffer-local
  ;; `case-fold-search' has no effect on fontification, so lowercase
  ;; `from'/`run' went unhighlighted.
  (setq-local font-lock-defaults '(containerfile-font-lock-keywords nil t)))

;; `#' starts a comment to end of line.  As above: modify the generated
;; table rather than replacing it with a fresh one.
(modify-syntax-entry ?# "<" containerfile-mode-syntax-table)
(modify-syntax-entry ?\n ">" containerfile-mode-syntax-table)
