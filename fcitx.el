;;; fcitx.el --- Make fcitx better in Emacs

;; Copyright (C) 2015  Junpeng Qiu

;; Author: Junpeng Qiu <qjpchmail@gmail.com>
;; Keywords: extensions

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Chinese version of README: https://github.com/cute-jumper/fcitx.el/blob/master/README-zh.org

;; #+TITLE: fcitx.el
;; Make [[https://github.com/fcitx/fcitx/][fcitx]] better in Emacs.

;; This package provides a set of functions to make fcitx work better in Emacs.

;; * Setup
;;   : (add-to-list 'load-path "/path/to/fcitx.el")
;;   : (require 'fcitx)

;;   Recommended though optional:
;;   : M-x fcitx-default-setup

;;   Calling =fcitx-default-setup= will enable all the features that this
;;   package provides and use default settings. See the following sections for
;;   details.

;;   Note that for every feature, there are both =*-turn-on= and =*-turn-off=
;;   functions defined, which can enable and disable the corresponding feature,
;;   respectively.

;; * Disable Fcitx by Prefix Keys
;;   If you've enabled fcitx, then you can't easily change your buffer by "C-x b"
;;   because the second key "b" will be blocked by fcitx(and you need to press
;;   "enter" in order to send "b" to emacs). This package provides a way
;;   to define the prefix keys after which you can temporarily disable fcitx.

;;   For example, you want to temporarily disable fcitx after you press "C-x" so
;;   that you can directly type "b" after "C-x" and after you press "b", fcitx will
;;   be activated again so you can still type Chinese buffer name. To define "C-x"
;;   to be the prefix key that can temporarily disable fcitx:
;;   : (fcitx-prefix-keys-add "C-x")

;;   Usually, defining "C-x" and "C-c" to be such prefix keys is enough for most
;;   users. You can simply use following command:
;;   : (fcitx-prefix-keys-setup)
;;   to add "C-x" and "C-c".

;;   After defining prefix keys, you need to call
;;   : (fcitx-prefix-keys-turn-on)
;;   to enable this feature.

;;   Of course, you can use
;;   : (fcitx-prefix-keys-turn-off)
;;   to disable this feature.

;;   Note if you use =M-x fcitx-default-setup=, then it already does all the
;;   above things, i.e. adding "C-x" and "C-c" to be prefix keys and enabling this
;;   feature, for you.

;; * Evil Support
;;   To disable fcitx when you exiting "insert mode" and enable fcitx after
;;   entering "insert mode" if originally you enable it in "insert mode":
;;   : (fcitx-evil-turn-on)

;;   It currently should work well for "entering" and "exiting" the insert state.
;;   It will also disable fcitx if you use =switch-to-buffer= or =other-window= to
;;   switch to a buffer which is not in insert state or Emacs state. For example,
;;   if you're currently in insert mode in buffer =A= and you've enabled fcitx,
;;   then you call =switch-to-buffer= to switch to another buffer =B=, which is
;;   currently, say, in normal mode, then fcitx will be disabled in buffer =B=.

;;   Note that currently the Evil support is not perfect. If you come across any
;;   bugs, consider file an issue or creating a pull request.

;;   Similarly, =M-x fcitx-default-setup= enables this feature.

;; * =M-x=, =M-!=, =M-&= and =M-:= Support
;;   Usually you don't want to type Chinese when you use =M-x=, =M-!=
;;   (=shell-command=), =M-&= (=async-shell-command=) or =M-:= (=eval-expression=).
;;   You can use:
;;   : (fcitx-M-x-turn-on)
;;   : (fcitx-shell-command-turn-on)
;;   : (fcitx-eval-expression-turn-on)
;;   to disable fcitx temporarily in these commands.

;;   =M-x= should work with the original =M-x= (=execute-extended-command=), =smex=
;;   and =helm-M-x=.

;;   Again, =M-x fcitx-default-setup= enables all these three features.

;;   Note: If you rebind =M-x= to =smex= or =helm-M-x=, then you should call
;;   =fcitx-default-setup= or =fcitx-M-x-turn-on= *after* the rebinding.

;; * TODO TODO
;;   - Better Evil support
;;   - Add =key-chord= support

;;   For more features, pull requests are always welcome!

;;; Code:

(defvar fcitx-prefix-keys-polling-time 0.1
  "Time interval to execute prefix keys polling function.")

(defvar fcitx--prefix-keys-sequence nil
  "Prefix keys that can trigger disabling fcitx.")

(defvar fcitx--prefix-keys-timer nil
  "Timer for prefix keys polling function.")

(defun fcitx--check-status ()
  (unless (executable-find "fcitx-remote")
    (error "`fcitx-remote' is not avaiable. Please check your
 fcitx installtion.")))

(defun fcitx--activate ()
  (call-process-shell-command "fcitx-remote -o"))

(defun fcitx--deactivate ()
  (call-process-shell-command "fcitx-remote -c"))

(defun fcitx--active-p ()
  (char-equal
   (aref (shell-command-to-string "fcitx-remote") 0) ?2))

(defmacro fcitx--defun-maybe (prefix)
  (let ((var-symbol (intern
                     (concat "fcitx--"
                             prefix
                             "-disabled-by-elisp")))
        (deactivate-symbol (intern
                            (concat "fcitx--"
                                    prefix
                                    "-maybe-deactivate")))
        (activate-symbol (intern
                          (concat "fcitx--"
                                  prefix
                                  "-maybe-activate"))))
    `(progn
       (defvar ,var-symbol nil)
       (defun ,deactivate-symbol ()
         (when (fcitx--active-p)
           (fcitx--deactivate)
           (setq ,var-symbol t)))
       (defun ,activate-symbol ()
         (when ,var-symbol
           (fcitx--activate)
           (setq ,var-symbol))))))

;; ------------------- ;;
;; prefix keys support ;;
;; ------------------- ;;
(fcitx--defun-maybe "prefix-keys")


(defun fcitx--prefix-keys-polling-function ()
  "Polling function executed every `fcitx-prefix-keys-polling-time'."
  (let ((key-seq (this-single-command-keys)))
    (cond
     ((member key-seq fcitx--prefix-keys-sequence)
      (fcitx--prefix-keys-maybe-deactivate))
     ((and (equal (this-command-keys-vector) [])
           (not (equal last-command 'switch-to-buffer))
           (not (equal last-command 'other-window)))
      (fcitx--prefix-keys-maybe-activate)))))

;;;###autoload
(defun fcitx-prefix-keys-add (prefix-key)
  (interactive)
  (push (vconcat (read-kbd-macro prefix-key))
        fcitx--prefix-keys-sequence))

;;;###autoload
(defun fcitx-prefix-keys-turn-on ()
  "Turn on `fcixt-disable-prefix-keys'."
  (interactive)
  (unless fcitx--prefix-keys-timer
    (setq fcitx--prefix-keys-timer
          (run-at-time t fcitx-prefix-keys-polling-time
                       #'fcitx--prefix-keys-polling-function))))

;;;###autoload
(defun fcitx-prefix-keys-turn-off ()
  "Turn off `fcixt-disable-prefix-keys'."
  (interactive)
  (when fcitx--prefix-keys-timer
    (cancel-timer fcitx--prefix-keys-timer)
    (setq fcitx--prefix-keys-timer)))

;;;###autoload
(defun fcitx-prefix-keys-setup ()
  (interactive)
  (fcitx-prefix-keys-add "C-x")
  (fcitx-prefix-keys-add "C-c"))

;; ------------ ;;
;; evil support ;;
;; ------------ ;;
(fcitx--defun-maybe "evil-insert")
(make-variable-buffer-local 'fcitx--evil-insert-disabled-by-elisp)

(defvar fcitx--evil-saved-active-p nil
  "Remember the fcitx state for each buffer")
(make-variable-buffer-local 'fcitx--evil-saved-active-p)

(defun fcitx--evil-should-disable-fcitx-p ()
  (not (or (evil-emacs-state-p)
           (evil-insert-state-p))))

;;FIX: cooperate with prefix keys and remove redundant code
(if (fboundp 'advice-add)
    (defun fcitx--evil-switch-buffer (orig-func &rest args)
      ;; before switch
      (when (and evil-mode
                 (not (window-minibuffer-p)))
        ;; save state. Should we set `fcitx--prefix-keys-disabled-by-elisp' too?
        (setq fcitx--evil-saved-active-p
              (or (fcitx--active-p)
                  fcitx--prefix-keys-disabled-by-elisp))
        (setq fcitx--prefix-keys-disabled-by-elisp))

      ;; switch buffer
      (apply orig-func args)
      ;; after switch
      (when (and evil-mode
                 (not (window-minibuffer-p)))
        (cond
         ((fcitx--evil-should-disable-fcitx-p)
          (fcitx--deactivate))
         (fcitx--evil-saved-active-p
          (fcitx--activate)))
        (setq fcitx--evil-saved-active-p)))
  (defadvice switch-to-buffer (around fcitx--evil-switch-buffer-1)
    (when (and evil-mode
               (not (window-minibuffer-p)))
      ;; save state. Should we set `fcitx--prefix-keys-disabled-by-elisp' too?
      (setq fcitx--evil-saved-active-p
            (or (fcitx--active-p)
                fcitx--prefix-keys-disabled-by-elisp))
      (setq fcitx--prefix-keys-disabled-by-elisp))

    ;; switch buffer
    ad-do-it
    ;; after switch
    (when (and evil-mode
               (not (window-minibuffer-p)))
      (cond
       ((fcitx--evil-should-disable-fcitx-p)
        (fcitx--deactivate))
       (fcitx--evil-saved-active-p
        (fcitx--activate)))
      (setq fcitx--evil-saved-active-p)))
  (defadvice other-window (around fcitx--evil-switch-buffer-2)
    (when (and evil-mode
               (not (window-minibuffer-p)))
      ;; save state. Should we set `fcitx--prefix-keys-disabled-by-elisp' too?
      (setq fcitx--evil-saved-active-p
            (or (fcitx--active-p)
                fcitx--prefix-keys-disabled-by-elisp))
      (setq fcitx--prefix-keys-disabled-by-elisp))
    ;; switch buffer
    ad-do-it
    ;; after switch
    (when (and evil-mode
               (not (window-minibuffer-p)))
      (cond
       ((fcitx--evil-should-disable-fcitx-p)
        (fcitx--deactivate))
       (fcitx--evil-saved-active-p
        (fcitx--activate)))
      (setq fcitx--evil-saved-active-p))))

;;;###autoload
(defun fcitx-evil-turn-on ()
  (interactive)
  (eval-after-load "evil"
    '(progn
       (add-hook 'evil-insert-state-exit-hook
                 #'fcitx--evil-insert-maybe-deactivate)
       (add-hook 'evil-insert-state-entry-hook
                 #'fcitx--evil-insert-maybe-activate)
       (if (fboundp 'advice-add)
           (progn
             (advice-add 'switch-to-buffer :around
                         #'fcitx--evil-switch-buffer)
             (advice-add 'other-window :around
                         #'fcitx--evil-switch-buffer))
         (ad-enable-advice 'switch-to-buffer 'around 'fcitx--evil-switch-buffer-1)
         (ad-activate 'switch-to-buffer)
         (ad-enable-advice 'other-window 'around 'fcitx--evil-switch-buffer-2)
         (ad-activate 'other-window)))))

;;;###autoload
(defun fcitx-evil-turn-off ()
  (interactive)
  (eval-after-load "evil"
    '(progn
       (remove-hook 'evil-insert-state-exit-hook
                    #'fcitx--evil-insert-maybe-deactivate)
       (remove-hook 'evil-insert-state-entry-hook
                    #'fcitx--evil-insert-maybe-activate)
       (if (fboundp 'advice-add)
           (progn
             (advice-remove 'switch-to-buffer
                            #'fcitx--evil-switch-buffer)
             (advice-remove 'other-window
                            #'fcitx--evil-switch-buffer))
         (ad-disable-advice 'switch-to-buffer 'around 'fcitx--evil-switch-buffer-1)
         (ad-activate 'switch-to-buffer)
         (ad-disable-advice 'other-window 'around 'fcitx--evil-switch-buffer-2)
         (ad-activate 'other-window)))))

;; ----------------------------- ;;
;; M-x, M-!, M-& and M-: support ;;
;; ----------------------------- ;;
(fcitx--defun-maybe "minibuffer")

(defun fcitx--minibuffer (orig-fun &rest args)
  (fcitx--minibuffer-maybe-deactivate)
  (unwind-protect
      (apply orig-fun args)
    (fcitx--minibuffer-maybe-activate)))

(defmacro fcitx-defun-minibuffer-on-off (func-name command)
  (let ((turn-on-func-name (intern
                            (concat "fcitx-"
                                    func-name
                                    "-turn-on")))
        (turn-off-func-name (intern
                             (concat "fcitx-"
                                     func-name
                                     "-turn-off"))))
    `(progn
       (if (fboundp 'advice-add)
           (progn
             (defun ,turn-on-func-name ()
               (interactive)
               (advice-add ,command :around #'fcitx--minibuffer))
             (defun ,turn-off-func-name ()
               (interactive)
               (advice-remove ,command #'fcitx--minibuffer)))
         (defadvice ,(cadr command) (around ,turn-on-func-name)
           (fcitx--minibuffer-maybe-deactivate)
           (unwind-protect
               ad-do-it
             (fcitx--minibuffer-maybe-activate)))
         (defun ,turn-on-func-name ()
           (interactive)
           (ad-activate ,command))
         (defun ,turn-off-func-name ()
           (interactive)
           (ad-deactivate ,command))))))

(defvar fcitx--M-x-binding-command nil
  "The command that `M-x' binds to")

(fcitx-defun-minibuffer-on-off "-original-M-x" 'read-extended-command)
(fcitx-defun-minibuffer-on-off "-smex-M-x" 'smex)
(fcitx-defun-minibuffer-on-off "-helm-M-x" 'helm-M-x-read-extended-command)

;;;###autoload
(defun fcitx-M-x-turn-on ()
  (interactive)
  (setq fcitx--M-x-binding-command (key-binding (kbd "M-x")))
  (let ((M-x-cmd fcitx--M-x-binding-command))
    (cond
     ((eq M-x-cmd 'execute-extended-command)
      (fcitx--original-M-x-turn-on))
     ((eq M-x-cmd 'smex)
      (fcitx--smex-M-x-turn-on))
     ((eq M-x-cmd 'helm-M-x)
      (fcitx--helm-M-x-turn-on))
     (t
      (error "I don't know your `M-x' binding command.
 Only support original M-x, `smex' and `helm-M-x'")))))

;;;###autoload
(defun fcitx-M-x-turn-off ()
  (interactive)
  (let ((M-x-cmd fcitx--M-x-binding-command))
    (cond
     ((eq M-x-cmd 'execute-extended-command)
      (fcitx--original-M-x-turn-off))
     ((eq M-x-cmd 'smex)
      (fcitx--smex-M-x-turn-off))
     ((eq M-x-cmd 'helm-M-x)
      (fcitx--helm-M-x-turn-off))
     (t
      (error "I don't know your `M-x' binding command.
 Only support original M-x, `smex' and `helm-M-x'")))))

;;;###autoload (autoload 'fcitx-shell-command-turn-on "fcitx" "Enable `shell-command' support" t)
;;;###autoload (autoload 'fcitx-shell-command-turn-off "fcitx" "Disable `shell-command' support" t)
(fcitx-defun-minibuffer-on-off "shell-command" 'read-shell-command)

;;;###autoload (autoload 'fcitx-eval-expression-turn-on "fcitx" "Enable `shell-command' support" t)
;;;###autoload (autoload 'fcitx-eval-expression-turn-off "fcitx" "Disable `eval-expression' support" t)
(fcitx-defun-minibuffer-on-off "eval-expression" 'read--expression)

;;;###autoload
(defun fcitx-default-setup ()
  "Default setup for `fcitx'."
  (interactive)
  (fcitx--check-status)
  ;; enable prefix keys related
  (fcitx-prefix-keys-setup)
  (fcitx-prefix-keys-turn-on)
  ;; enable minibuffer related
  (fcitx-M-x-turn-on)
  (fcitx-shell-command-turn-on)
  (fcitx-eval-expression-turn-on)
  ;; enable evil related
  (fcitx-evil-turn-on))

(provide 'fcitx)
;;; fcitx.el ends here
