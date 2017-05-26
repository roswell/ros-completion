(defpackage ros-completion
  (:use :cl))
(ros:include "util-install-quicklisp")
(in-package :ros-completion)

(defvar *supported-shell* '(bash zsh))

(defun login-shell ()
  #+ros.init
  (or (ros:opt "SHELL")
      (pathname-name (ros:getenv "SHELL"))))

(defun completion-path (name)
  (make-pathname :defaults (asdf:system-source-file "ros-completion")
                 :type nil
                 :name name))

(defun read-file (file)
  (with-open-file (in file)
    (loop for l = (read-line in nil nil)
          while l
          collect l)))

(defun write-file (file lines)
  (with-open-file (out file
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (loop for l in lines
          do (format out "~A~%" l))))

(defvar *start* "#<roswell-completion>")
(defvar *end* "#</roswell-completion>")

(defun separate-file (file)
  (loop
    with bf = t
    with af = nil
    for l in (read-file file)
    when (equal *start* l)
      do (setf bf nil)
    if af collect l
      into after
    when (and (equal *end* l) (not bf))
      do (setf af t)
    if bf collect l
      into before
    finally (return-from nil (list before after))))

(defun zsh-conf ()
  (list
   *start*
   "fpath=(~/.zsh $fpath)"
   "autoload -Uz compinit"
   "compinit"
   *end*))

(defun zsh ()
  (let* ((path (merge-pathnames ".zshrc" (user-homedir-pathname)))
         (list (separate-file path))
         (to (merge-pathnames ".zsh/_ros" (user-homedir-pathname))))
    (uiop:copy-file
     (completion-path "zsh")
     (ensure-directories-exist to))
    #+sbcl(sb-posix:chmod to #o755)
    (write-file path
                (append
                 (first list)
                 (zsh-conf)
                 (second list)))))

(defun bash-conf ()
  (list
   *start*
   (format nil "source ~A" (namestring (completion-path "bash")))
   *end*))

(defun bash ()
  (let* ((path (merge-pathnames ".bashrc" (user-homedir-pathname)))
         (list (separate-file path)))
    (write-file path
                (append
                 (first list)
                 (bash-conf)
                 (second list)))))

(defun add-to-init-file (&optional (shell (login-shell)))
  (format t "install completion for ~A~%" shell)
  (find shell *supported-shell* :test 'string-equal))

(setf roswell.install:*build-hook* 'add-to-init-file)
