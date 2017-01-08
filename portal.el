;; portal.el - Reversed copy-paste.
;;
;; Placing a "portal" using Ctrl-v at current point enters portal minor
;; mode. All subsequent yank/copy operations that add text to the kill-ring will
;; also insert that text at the portal. Ctrl-v again exits portal minor mode and
;; brings the point back to its original position.
;;
;; (require 'portal)
;; (global-set-key "\C-v" 'portal/toggle)

(defface portal/face-before
  '((((class grayscale) 
      (background light)) (:background "DarkGray"))
    (((class grayscale) 
      (background dark))  (:background "LightGray"))
    (((class color) 
      (background light)) (:foreground "ivory1" :background "MediumBlue"))
    (((class color) 
      (background dark))  (:foreground "Black" :background "LightSkyBlue")))
  "Face used to highlight the end of portal line."
  :group 'portal)

(defface portal/face-after
  '((((class grayscale) 
      (background light)) (:background "DarkGray"))
    (((class grayscale) 
      (background dark))  (:background "LightGray"))
    (((class color) 
      (background light)) (:foreground "ivory1" :background "OrangeRed1"))
    (((class color) 
      (background dark))  (:foreground "Black" :background "DarkOrange2")))
  "Face used to highlight the beginning of portal line."
  :group 'portal)

(defcustom portal/face-before 'portal/face-before
  "*Specify face used to highlight the text before the portal."
  :type 'face
  :group 'portal)

(defcustom portal/face-after 'portal/face-after
  "*Specify face used to highlight the text after portal."
  :type 'face
  :group 'portal)

(defvar portal/image
  (create-image "/* XPM */
static char * arrow_left[] = {
\"8 9 2 1\",
\". c Black\",
\"  c White\",
\"        \",
\"   .    \",
\"  ...   \",
\" .....  \",
\"....... \",
\" .....  \",
\"  ...   \",
\"   .    \",
\"        \"};
" 'xpm t :ascent 'center))

(defvar portal/overlay nil
  "The list of 2 overlays that define the portal")

(defvar portal/kill-ring-before-command nil)

(defun portal/move-overlays ()
  (if portal/overlay
      (with-current-buffer (overlay-buffer (car portal/overlay))
        (save-excursion
          (goto-char (overlay-start (car portal/overlay)))
          (let ((start (point-at-bol))
                (end (min (point-max) (+ 1 (point-at-eol)))))
            (move-overlay (cadr portal/overlay) start (point))
            (move-overlay (car portal/overlay) (point) end))))))

(defun portal/update-overlays (overlay after begin end &optional len)
  (portal/move-overlays))

(defun portal/add ()
  "Add a portal at point. Deletes previous portal."
  (interactive)
  (if portal/overlay (portal/delete))
  (let ((start (point-at-bol))
        (end (min (point-max) (+ 1 (point-at-eol)))))
    (let ((overlay-before (make-overlay (point) end))
          (overlay-after (make-overlay start (point)))
          (marker-string "*"))
      (overlay-put overlay-before 'face portal/face-before)
      (overlay-put overlay-after 'face portal/face-after)
      (put-text-property 0 (length marker-string) 'display portal/image marker-string)
      (overlay-put overlay-before 'before-string marker-string)
      (overlay-put overlay-before 'modification-hooks '(portal/update-overlays))
      (overlay-put overlay-before 'insert-in-front-hooks '(portal/update-overlays))
      (overlay-put overlay-after 'modification-hooks '(portal/update-overlays))
      (overlay-put overlay-before 'insert-behind-hooks '(portal/update-overlays))
      (setq portal/overlay (list overlay-before overlay-after)))))

(defun portal/delete ()
  "Destroy current portal."
  (interactive)
  (if portal/overlay
      (progn
        (delete-overlay (car portal/overlay))
        (delete-overlay (cadr portal/overlay))
        (setq portal/overlay nil))))

(defun portal/swap-mark-and-portal ()
  "Swaps mark and portal."
  (interactive)
  (if portal/overlay
      (let ((new-buffer (overlay-buffer (car portal/overlay)))
            (new-pos (overlay-start (car portal/overlay))))
        (portal/add)
        (pop-to-buffer new-buffer)
        (goto-char new-pos))))

(defun portal/pre-command ()
  "Records kill-ring before a command is executed."
  (setq portal/kill-ring-before-command kill-ring))

(defun portal/post-command ()
  "Pushes anything that was added to kill-ring by command to the portal."
  (if (and portal-mode
           (not (equal portal/kill-ring-before-command kill-ring)))
      (let ((kill-ring-head (car kill-ring)))
        (with-current-buffer (overlay-buffer (car portal/overlay))
           (save-excursion
             (goto-char (overlay-start (car portal/overlay)))
             (insert-before-markers kill-ring-head)
             (portal/move-overlays)
             )))))

(defun portal/toggle (n)
  (interactive "^p")
  (if portal-mode
      (progn
        (portal-mode 0)
        (if (> n 0)
            ;; Unless called with a prefix 0, jump to original position.
            (portal/swap-mark-and-portal))
        ;; Destroy portal.
        (portal/delete))
    (portal/add)
    (portal-mode 1)))

(define-minor-mode portal-mode
  "Mode while next command copies to portal additionally to kill-ring."
  nil " P" nil :global t
  (if portal-mode
      (progn
        ;; Post-command-hook is invoked immediately after entering portal mode.
        ;; We need to start with a matching portal/pre-command.
        (portal/pre-command)
        (add-hook 'pre-command-hook 'portal/pre-command nil nil)
        (add-hook 'post-command-hook 'portal/post-command t nil))
    (remove-hook 'post-command-hook 'portal/post-command nil)
    (remove-hook 'pre-command-hook 'portal/pre-command nil)
    (setq portal/kill-ring-before-command nil)))

(provide 'portal)
