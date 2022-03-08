;;; flymake-luacheck.el --- Flymake backend for luacheck  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Augusto Stoffel

;; Author: Augusto Stoffel <arstoffel@gmail.com>
;; Keywords: languages, tools
;; Package-Requires: ((emacs "27.1") (flymake "1.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A Flymake backend for Lua using the luacheck program [1].
;;
;; To use it, add
;;
;;     (add-hook 'lua-mode-hook 'flymake-luacheck-setup)
;;
;; to your init file.  Make sure to also activate `flymake-mode' in
;; Lua buffers.
;;
;; [1] https://github.com/mpeterv/luacheck

;;; Code:

(defgroup flymake-luacheck nil
  "Flymake support for Lua via luacheck."
  :group 'flymake)

(defcustom flymake-luacheck-program "luacheck"
  "Name of the luacheck executable."
  :type 'string)

(defvar-local flymake-luacheck--proc nil)

(defun flymake-luacheck (report-fn &rest _args)
  "Flymake backend using the luacheck program.
Takes a Flymake callback REPORT-FN as argument, as expected of a
member of `flymake-diagnostic-functions'."
  (when (process-live-p flymake-luacheck--proc)
    (kill-process flymake-luacheck--proc))
  (let ((source (current-buffer)))
    (save-restriction
      (widen)
      (setq flymake-luacheck--proc
            (make-process
             :name "luacheck" :noquery t :connection-type 'pipe
             :buffer (generate-new-buffer " *flymake-luacheck*")
             :command `(,flymake-luacheck-program
                        "--codes" "--formatter" "plain" "-")
             :sentinel
             (lambda (proc _event)
               (when (eq 'exit (process-status proc))
                 (unwind-protect
                     (if (with-current-buffer source
                           (eq proc flymake-luacheck--proc))
                         (with-current-buffer (process-buffer proc)
                           (goto-char (point-min))
                           (cl-loop
                            while (search-forward-regexp
                                   "^\\([^:]*\\):\\([0-9]+\\):\\([0-9]+\\): \\(.*\\)$"
                                   nil t)
                            for msg = (match-string 4)
                            for (beg . end) = (flymake-diag-region
                                               source
                                               (string-to-number (match-string 2))
                                               (string-to-number (match-string 3)))
                            for type = (if (string-match "\\`(E" msg) :error :warning)
                            collect (flymake-make-diagnostic source beg end type msg)
                            into diags
                            finally (funcall report-fn diags)))
                       (flymake-log :warning "Canceling obsolete check %s" proc))
                   (kill-buffer (process-buffer proc)))))))
      (process-send-region flymake-luacheck--proc (point-min) (point-max))
      (process-send-eof flymake-luacheck--proc))))

;;;###autoload
(defun flymake-luacheck-setup ()
  "Add `flymake-luacheck' as a Flymake backend to the current buffer."
  (add-hook 'flymake-diagnostic-functions 'flymake-luacheck nil t))

(provide 'flymake-luacheck)
;;; flymake-luacheck.el ends here
