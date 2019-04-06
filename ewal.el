;;; ewal.el --- A wal-based <https://github.com/dylanaraps/pywal>, automatic,
;;; terminal-aware Emacs theme generator.

;; Copyright (C) 2019 Uros Perisic
;; Copyright (C) 2019 Grant Shangreaux
;; Copyright (C) 2016-2018 Henrik Lissner

;; Author: Uros Perisic
;; URL: <https://gitlab.com/jjzmajic/ewal.el>
;;
;; Version: 0.1
;; Keywords: color, theme, generator, wal, pywal
;; Package-Requires: ((emacs "24") (cl-lib) (json))

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of Emacs.

;;; Commentary:

;; This is a color theme generator for Emacs with an eye towards Spacemacs
;; <https://github.com/syl20bnr/spacemacs>, and `spacemacs-theme'
;; <https://github.com/nashamri/spacemacs-theme>, but no dependencies on either,
;; so you can use it to colorize your vanilla Emacs as well.

;; My hope is that `ewal' will remain theme agnostic, with people
;; contributing functions like `ewal-get-spacemacs-theme-colors' for other
;; popular themes such as `solarized-emacs'
;; <https://github.com/bbatsov/solarized-emacs>, making it easy to keep the
;; style of different themes, while adapting them to the rest of your theming
;; setup. No problem should ever have to be solved twice!

;;; Code:

;; deps
(require 'json)
(require 'cl-lib)
(require 'term/tty-colors)

(defgroup ewal nil
  "ewal options."
  :group 'faces)

(defcustom ewal-wal-cache-dir
  (file-name-as-directory (expand-file-name "~/.cache/wal"))
  "Location of wal cache directory."
  :type 'string
  :group 'ewal)

(defvar ewal--wal-cache-json-file
  (concat ewal-wal-cache-dir "colors.json")
  "Location of cached wal theme in json format.")

(defcustom ewal-ansi-color-name-symbols
  (mapcar 'intern
          (cl-loop for (key . value)
                   in tty-defined-color-alist
                   collect key))
  "The 8 most universaly supported TTY color names.
They will be extracted from `ewal--cache-json-file', and
with the right escape sequences applied using

source ${HOME}/.cache/wal/colors-tty.sh

should be viewable even in the Linux console (See
https://github.com/dylanaraps/pywal/wiki/Getting-Started#applying-the-theme-to-new-terminals
for more details). NOTE: Order matters."
  :type 'list
  :group 'ewal)


(defcustom ewal-force-tty-colors nil
  "Whether to use TTY version of `ewal' colors.
Meant for setting TTY theme regardless of GUI support."
  :type 'boolean
  :group 'ewal)

(defcustom ewal-primary-accent-color 'magenta
  "Predominant `ewal' color.
Must be one of `ewal-ansi-color-name-symbols'"
  :type 'symbol
  :group 'ewal)

(defvar ewal-secondary-accent-color 'blue
  "Second most predominant `ewal' color.
Must be one of `ewal-ansi-color-name-symbols'")

(defvar ewal-base-palette nil
  "Current base palette extracted from `ewal--wal-cache-json-file'.")

(defvar ewal-extended-palette nil
  "Extended palette based on `ewal-base-palette'.")

(defvar ewal-spacemacs-theme-gui-colors nil
  "`spacemacs-theme' compatible GUI colors.
Extracted from current `ewal' theme.")

(defvar ewal-spacemacs-theme-tty-colors nil
  "`spacemacs-theme' compatible TTY colors.
Extracted from current `ewal' theme.")

(defvar ewal-spacemacs-evil-cursors-gui-colors nil
  "`spacemacs-evil-cursors' compatible GUI colors.
Extracted from current `ewal' palette.")

(defvar ewal-spacemacs-evil-cursors-tty-colors nil
  "`spacemacs-evil-cursors' compatible TTY colors.
Extracted from current `ewal' palette.")

(defun ewal--use-tty-colors-p (tty)
  "Utility function to check if TTY colors should be used."
  (if (boundp tty) tty
    (or ewal-force-tty-colors
        (display-graphic-p))))

(defun ewal--load-wal-theme (&optional json color-names)
  "Read JSON as the most complete of the cached wal files.
COLOR-NAMES will be associated with the first 8 colors of the
cached wal colors. COLOR-NAMES are meant to be used in
conjunction with `ewal-ansi-color-name-symbols'.
\"Special\" wal colors such as \"background\", \"foreground\",
and \"cursor\", tend to \(but do not always\) correspond to the
remaining colors generated by wal. Add those special colors to
the returned alist."
  (let ((json (or json ewal--wal-cache-json-file))
        (json-object-type 'alist)
        (json-array-type 'list)
        (color-names (or color-names ewal-ansi-color-name-symbols)))
    (let ((colors (json-read-file json)))
      (let ((special-colors (alist-get 'special colors))
            (regular-colors (alist-get 'colors colors)))
        (let ((regular-color-values (cl-loop for
                                             (key . value)
                                             in
                                             regular-colors
                                             collect
                                             value)))
          (let ((cannonical-colors
                 (cl-pairlis color-names regular-color-values)))
            (append special-colors cannonical-colors)))))))

;; Color helper functions, shamelessly *borrowed* from solarized
(defun ewal--color-name-to-rgb (color)
  "Retrieves the hex string represented the named COLOR (e.g. \"red\")."
  (cl-loop with div = (float (car (tty-color-standard-values "#ffffff")))
           for x in (tty-color-standard-values (downcase color))
           collect (/ x div)))

(defun ewal--color-blend (color1 color2 alpha)
  "Blend COLOR1 and COLOR2 (hex strings) together by a coefficient ALPHA.
\(a float between 0 and 1\)"
  (when (and color1 color2)
    (cond ((and color1 color2 (symbolp color1) (symbolp color2))
           (ewal--color-blend (ewal-get-color color1 0)
                              (ewal-get-color color2 0) alpha))

          ((or (listp color1) (listp color2))
           (cl-loop for x in color1
                    when (if (listp color2) (pop color2) color2)
                    collect (ewal--color-blend x it alpha)))

          ((and (string-prefix-p "#" color1) (string-prefix-p "#" color2))
           (apply (lambda (r g b) (format "#%02x%02x%02x" (* r 255) (* g 255) (* b 255)))
                  (cl-loop for it    in (ewal--color-name-to-rgb color1)
                           for other in (ewal--color-name-to-rgb color2)
                           collect (+ (* alpha it) (* other (- 1 alpha))))))

          (t color1))))

(defun ewal--color-darken (color alpha)
  "Darken a COLOR \(a hexidecimal string\) by a coefficient ALPHA.
\(a float between 0 and 1\)."
  (cond ((and color (symbolp color))
         (ewal--color-darken (ewal-get-color color 0) alpha))

        ((listp color)
         (cl-loop for c in color collect (ewal--color-darken c alpha)))

        (t
         (ewal--color-blend color "#000000" (- 1 alpha)))))

(defun ewal--color-lighten (color alpha)
  "Brighten a COLOR (a hexidecimal string) by a coefficient ALPHA.
\(a float between 0 and 1\)."
  (cond ((and color (symbolp color))
         (ewal--color-lighten (ewal-get-color color 0) alpha))

        ((listp color)
         (cl-loop for c in color collect (ewal--color-lighten c alpha)))

        (t
         (ewal--color-blend color "#FFFFFF" (- 1 alpha)))))

(defun ewal--extend-base-color (color num-shades shade-percent-difference)
  "Extend \(darken \(-\) or lighten \(+\)\) COLOR.
Do so by 2 * NUM-SHADES \(NUM-SHADES lighter, and NUM-SHADES
darker\), in increments of SHADE-PERCENT-DIFFERENCE percentage
points. Return list of extended colors"
  (let ((extended-color-list ()))
    (dotimes (i (+ 1 num-shades) extended-color-list)
      (add-to-list 'extended-color-list
                   (ewal--color-darken
                    color (/ (* i shade-percent-difference) (float 100)))))
    (add-to-list 'extended-color-list color t)
    (dotimes (i (+ 1 num-shades) extended-color-list)
      (add-to-list 'extended-color-list
                   (ewal--color-lighten
                    color (/ (* i shade-percent-difference) (float 100)))
                   t))))

(defun ewal--extend-base-palette (num-shades shade-percent-difference &optional palette)
  "Use `ewal--extend-base-color' to extend entire base PALETTE.
which defaults to `ewal-base-palette' and returns an extended
palette alist intended to be stored in `ewal-extended-palette'.
Like `ewal--extend-base-color', extend \(darken \(-\) or lighten
\(+\)\) COLOR. Do so by 2 * NUM-SHADES \(NUM-SHADES lighter, and
NUM-SHADES darker\), in increments of SHADE-PERCENT-DIFFERENCE
percentage points. Return list of extended colors"
  (let ((palette (or palette ewal-base-palette)))
    (cl-loop for (key . value)
             in palette
             collect `(,key . ,(ewal--extend-base-color
                                value num-shades
                                shade-percent-difference)))))

(defun ewal--tty-color-approximate-hex (color)
  "Use `tty-color-approximate' to approximate COLOR.
Find closest color to COLOR in `tty-defined-color-alist', and
return it."
  (apply 'color-rgb-to-hex
         (cddr (tty-color-approximate
                (tty-color-standard-values color)))))

(defun ewal-get-color (color &optional shade tty approximate palette)
  "Return SHADE of COLOR from current `ewal' PALETTE.
Choose color that is darker (-) or lightener (+) than COLOR
\(must be one of `ewal-ansi-color-name-symbols'\) by SHADE. SHADE
defaults to 0, returning original wal COLOR. If SHADE exceeds
number of available shades, the darkest/lightest shade is
returned. If TTY is t, return original, TTY compatible `wal'
color regardless od SHADE. If APPROXIMATE is set, approximate
color using `ewal--tty-color-approximate-hex', otherwise return
default (non-extended) wal color."
  (let ((palette (or palette ewal-extended-palette))
        (tty (or tty nil))
        (middle (/ (- (length (car ewal-extended-palette)) 1) 2))
        (shade (or shade 0)))
    (let ((return-color (nth (+ middle shade) (alist-get color palette))))
      (let ((bound-return-color (if return-color
                                    return-color
                                  (car (last (alist-get color palette))))))
        ;; TTY compatible color
        (if tty
            (if approximate
                ;; closest of `tty-defined-color-alist'
                (ewal--tty-color-approximate-hex bound-return-color)
              ;; unmodified color that should be supported in a TTY by wal.
              (nth middle (alist-get color palette)))
          bound-return-color)))))

(defun ewal--generate-spacemacs-theme-colors (&optional tty
                                                        primary-accent-color
                                                        secondary-accent-color)
  "Make theme colorscheme from theme palettes.
If TTY is t, colorscheme is reduced to basic tty supported colors.
PRIMARY-ACCENT-COLOR sets the main theme color---defaults to
`ewal-primary-accent-color'. Ditto for
SECONDARY-ACCENT-COLOR"
  (let ((primary-accent-color
         (or primary-accent-color ewal-primary-accent-color))
        (secondary-accent-color
         (or secondary-accent-color ewal-secondary-accent-color)))
    (let ((theme-colors
          `((act1          . ,(ewal-get-color 'background -3 tty))
            (act2          . ,(ewal-get-color primary-accent-color 0 tty))
            (base          . ,(ewal-get-color 'foreground 0 tty))
            (base-dim      . ,(ewal-get-color 'foreground -4 tty))
            (bg1           . ,(ewal-get-color 'background 0 tty))
            (bg2           . ,(ewal-get-color 'background -2 tty))
            (bg3           . ,(ewal-get-color 'background -3 tty))
            (bg4           . ,(ewal-get-color 'background -4 tty))
            (border        . ,(ewal-get-color 'background 0 tty))
            (cblk          . ,(ewal-get-color 'foreground -3 tty))
            (cblk-bg       . ,(ewal-get-color 'background -3 tty))
            (cblk-ln       . ,(ewal-get-color primary-accent-color 4 tty))
            (cblk-ln-bg    . ,(ewal-get-color primary-accent-color -4 tty))
            (cursor        . ,(ewal-get-color 'cursor 0 tty))
            (const         . ,(ewal-get-color primary-accent-color 4 tty))
            (comment       . ,(ewal-get-color 'background 4 tty))
            (comment-bg    . ,(ewal-get-color 'background 0 tty))
            (comp          . ,(ewal-get-color secondary-accent-color 0 tty))
            (err           . ,(ewal-get-color 'red 0 tty))
            (func          . ,(ewal-get-color primary-accent-color 0 tty))
            (head1         . ,(ewal-get-color primary-accent-color 0 tty))
            (head1-bg      . ,(ewal-get-color 'background -3 tty))
            (head2         . ,(ewal-get-color secondary-accent-color 0 tty))
            (head2-bg      . ,(ewal-get-color 'background -3 tty))
            (head3         . ,(ewal-get-color 'cyan 0 tty))
            (head3-bg      . ,(ewal-get-color 'background -3 tty))
            (head4         . ,(ewal-get-color 'yellow 0 tty))
            (head4-bg      . ,(ewal-get-color 'background -3 tty))
            (highlight     . ,(ewal-get-color 'background 4 tty))
            (highlight-dim . ,(ewal-get-color 'background 2 tty))
            (keyword       . ,(ewal-get-color secondary-accent-color 0 tty))
            (lnum          . ,(ewal-get-color 'background 2 tty))
            (mat           . ,(ewal-get-color 'green 0 tty))
            (meta          . ,(ewal-get-color 'yellow 4 tty))
            (str           . ,(ewal-get-color 'cyan 0 tty))
            (suc           . ,(ewal-get-color 'green 4 tty))
            (ttip          . ,(ewal-get-color 'background 2 tty))
            (ttip-sl       . ,(ewal-get-color 'background 4 tty))
            (ttip-bg       . ,(ewal-get-color 'background 0 tty))
            (type          . ,(ewal-get-color 'red 2 tty))
            (var           . ,(ewal-get-color secondary-accent-color 4 tty))
            (war           . ,(ewal-get-color 'red 4 tty))

            ;; colors
            (aqua          . ,(ewal-get-color 'cyan 0 tty))
            (aqua-bg       . ,(ewal-get-color 'cyan -3 tty))
            (green         . ,(ewal-get-color 'green 0 tty))
            (green-bg      . ,(ewal-get-color 'green -3 tty))
            (green-bg-s    . ,(ewal-get-color 'green -4 tty))
            ;; literally the same as aqua in web development
            (cyan          . ,(ewal-get-color 'cyan 0 tty))
            (red           . ,(ewal-get-color 'red 0 tty))
            (red-bg        . ,(ewal-get-color 'red -3 tty))
            (red-bg-s      . ,(ewal-get-color 'red -4 tty))
            (blue          . ,(ewal-get-color 'blue 0 tty))
            (blue-bg       . ,(ewal-get-color 'blue -3 tty))
            (blue-bg-s     . ,(ewal-get-color 'blue -4 tty))
            (magenta       . ,(ewal-get-color 'magenta 0 tty))
            (yellow        . ,(ewal-get-color 'yellow 0 tty))
            (yellow-bg     . ,(ewal-get-color 'yellow -3 tty)))))
          theme-colors)))

(defun ewal--generate-spacemacs-evil-cursors-colors (&optional tty)
  "Use wal colors to customize `spacemacs-evil-cursors'.
TTY specifies whether to use TTY or GUI colors."
  (let ((tty (ewal--use-tty-colors-p tty)))
    `(("normal" ,(ewal-get-color 'cursor 0 tty) box)
      ("insert" ,(ewal-get-color 'green 0 tty) (bar . 2))
      ("emacs" ,(ewal-get-color 'blue 0 tty) box)
      ("hybrid" ,(ewal-get-color 'blue 0 tty) (bar . 2))
      ("evilified" ,(ewal-get-color 'red 0 tty) box)
      ("visual" ,(ewal-get-color 'white -4 tty) (hbar . 2))
      ("motion" ,(ewal-get-color 'magenta 0) box)
      ("replace" ,(ewal-get-color 'red -4 tty) (hbar . 2))
      ("lisp" ,(ewal-get-color 'magenta 4 tty) box)
      ("iedit" ,(ewal-get-color 'magenta -4 tty) box)
      ("iedit-insert" ,(ewal-get-color 'magenta -4 tty) (bar . 2)))))

(defun ewal-load-ewal-theme ()
  "Load all `ewal' palettes and colors.
If `ewal--load-from-cache-p' returns t, load from cache.
Otherwise regenerate palettes and colors."
    (setq ewal-base-palette (ewal--load-wal-theme))
    (setq ewal-extended-palette (ewal--extend-base-palette 4 5))
    (setq ewal-spacemacs-theme-gui-colors
          (ewal--generate-spacemacs-theme-colors nil))
    (setq ewal-spacemacs-theme-tty-colors
          (ewal--generate-spacemacs-theme-colors t))
    (setq ewal-spacemacs-evil-cursors-gui-colors
          (ewal--generate-spacemacs-evil-cursors-colors nil))
    (setq ewal-spacemacs-evil-cursors-tty-colors
          (ewal--generate-spacemacs-evil-cursors-colors t)))

(defun ewal--vars-loaded-p ()
  "Check if all `ewal' variables have been set."
  (or
   (null 'ewal-base-palette)
   (null 'ewal-extended-palette)
   (null 'ewal-spacemacs-theme-gui-colors)
   (null 'ewal-spacemacs-theme-tty-colors)
   (null 'ewal-spacemacs-evil-cursors-gui-colors)
   (null 'ewal-spacemacs-evil-cursors-tty-colors)))

(defun ewal-get-spacemacs-theme-colors (&optional force-reload tty)
  "Get `spacemacs-theme' colors.
For usage see: <https://github.com/nashamri/spacemacs-theme>. To
reload `ewal' environment variables before returning colors even
if they have already been computed, set FORCE-RELOAD to t. TTY
defaults to return value of `ewal--use-tty-colors-p'."
  (when (or (not (ewal--vars-loaded-p)) force-reload)
    (ewal-load-ewal-theme))
  (let ((tty (ewal--use-tty-colors-p tty)))
    (if tty
        ewal-spacemacs-theme-tty-colors
      ewal-spacemacs-theme-gui-colors)))

(defun ewal-get-spacemacs-evil-cursors-colors (&optional force-reload tty)
  "Get `spacemacs-evil-cursors' colors.
To reload `ewal' environment variables before returning colors
even if they have already been computed, set FORCE-RELOAD to t.
TTY defaults to return value of `ewal--use-tty-colors-p'."
  (when (or (not (ewal--vars-loaded-p)) force-reload)
    (ewal-load-ewal-theme))
  (let ((tty (ewal--use-tty-colors-p tty)))
    (if tty
        ewal-spacemacs-evil-cursors-tty-colors
      ewal-spacemacs-evil-cursors-gui-colors)))

(provide 'ewal)
;;; ewal ends here
