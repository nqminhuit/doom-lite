;;; minh/pulsar/config.el --- Description -*- lexical-binding: t; -*-

(with-eval-after-load 'pulsar

  (setq pulsar-pulse t
        pulsar-delay 0.03
        pulsar-iterations 10
        pulsar-face 'ansi-color-blue
        pulsar-highlight-face 'pulsar-blue)

  (dolist (func '(+lookup/definition
                  +lookup/implementations
                  +workspace/switch-to-0
                  +workspace/switch-to-1
                  +workspace/switch-to-2
                  +workspace/switch-to-3
                  +workspace/switch-to-4
                  +workspace/switch-to-5
                  +workspace/switch-to-6
                  +workspace/switch-to-7
                  +workspace/switch-to-8
                  kill-current-buffer
                  evil-jump-backward
                  evil-jump-forward
                  evil-jump-item
                  evil-window-down
                  evil-window-up
                  evil-window-left
                  evil-window-right
                  evil-window-top
                  evil-window-middle
                  evil-window-bottom
                  find-file
                  consult-bookmark
                  keyboard-quit
                  evil-switch-to-windows-last-buffer))
    (add-to-list 'pulsar-pulse-functions func)))
