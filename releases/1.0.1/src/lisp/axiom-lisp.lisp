;;; This file contains portablity and support routines which abstract away
;;; differences between Lisp dialects.

(in-package "AXIOM-LISP")
#+:sbcl
(progn
     (defvar *saved-terminal-io* *terminal-io*)
     (setf *terminal-io* (make-two-way-stream *standard-input*
                                             *standard-output*))
     (setf sb-ext:*evaluator-mode* :interpret)
 )

(defun set-initial-parameters()
    (setf *read-default-float-format* 'double-float))

#-:sbcl
(eval-when (:execute :load-toplevel)
    (set-initial-parameters))

#+:clisp
(eval-when (:execute :compile-toplevel :load-toplevel)
    ;;; clisp wants to search whole "~/lisp" subtree to find a source
    ;;; file, which is insane.  Below we disable this behaviour.
    (setf custom:*load-paths* '(#P"./"))
    ;;; We want ANSI compliance
    (setf custom:*ansi* t))

;; Save current image on disk as executable and quit.
(defun save-core-restart (core-image restart)
#+:GCL
  (progn
     (if restart
          (setq system::*top-level-hook* restart))
     (system::save-system core-image))
#+:allegro
  (if restart
   (excl::dumplisp :name core-image :restart-function restart)
   (excl::dumplisp :name core-image))
#+Lucid
  (if restart
   (sys::disksave core-image :restart-function restart)
   (sys::disksave core-image))
#+:CCL
  (preserve)
#+:sbcl
  (let* ((restart-fun 
               (if restart
                   restart
                   #'(lambda () nil)))
         (top-fun #'(lambda ()
                       (set-initial-parameters)
                       (funcall restart-fun)
                       (sb-impl::toplevel-repl nil))))
        (sb-ext::save-lisp-and-die core-image :toplevel top-fun
            :executable t))
#+:clisp
  (if restart
     (ext::saveinitmem core-image :INIT-FUNCTION restart :QUIET t
         :executable t)
     (ext::saveinitmem core-image :executable t :QUIET t))
#+:openmcl
  (let ((ccl-dir (|getEnv| "CCL_DEFAULT_DIRECTORY"))
        (core-fname (concatenate 'string core-image ".image"))
        (eval-arg (if restart 
                      (format nil " --eval '(~A)'" restart)
                      ""))
        core-path exe-path)
        ;;; truename works only on existing files, so we
        ;;; create one just to get absolute path
        (with-open-file (ims core-fname 
                          :direction :output :if-exists :supersede)
            (declare (ignore ims))
            (setf core-path (namestring (truename core-fname))))
        (delete-file core-path)
        (with-open-file (ims core-image 
                        :direction :output :if-exists :supersede)
                (setf exe-path (namestring (truename core-image)))
                (format ims "#!/bin/sh~2%")
                (format ims "CCL_DEFAULT_DIRECTORY=~A~%" ccl-dir)
                (format ims "export CCL_DEFAULT_DIRECTORY~%")
                (format ims "exec ~A/~A -I ~A~A~%"
                            ccl-dir (ccl::standard-kernel-name)
                            core-path eval-arg))
        (ccl::run-program "chmod" (list "a+x" exe-path))
        #|
        ;;; We would prefer this version, but due to openmcl bug
        ;;; it does not work
        (if restart
          (ccl::save-application core-path :toplevel-function restart)
          (ccl::save-application core-path))
        |#
        (ccl::save-application core-path)
        )
  )
     

(defun save-core (core-image)
     (save-core-restart core-image nil))

;; Load Lisp files (any LOADable file), given as a list of file names.
;; The file names are strings, as approrpriate for LOAD.
(defun load-lisp-files (files)
  (mapcar #'(lambda (f) (load f)) files))

(defun make-program (core-image lisp-files)
  (load-lisp-files lisp-files)
  (save-core core-image))

;;; How to exit Lisp process
#+(and :gcl :common-lisp)
(defun quit() (lisp::quit))

#+:sbcl
(defun quit()
    (setf *terminal-io* *saved-terminal-io*)
    (sb-ext::quit))

#+:clisp
(defun quit() (ext::quit))

#+:openmcl
(defun quit() (ccl::quit))

#+:ecl
(defun quit ()
    (SI:quit))

#+:poplog
(defun quit() (poplog::bye))

;;; -----------------------------------------------------------------

;;; Chdir function

#+:gcl
(defun chdir (dir)
 (system::chdir dir))

#+:sbcl
(eval-when (:execute :compile-toplevel :load-toplevel)
    (require :sb-posix))
#+:sbcl
(defun chdir (dir)
 (let ((tdir (probe-file dir)))
  (cond
    (tdir
       #-:win32 (sb-posix::chdir tdir) 
       (setq *default-pathname-defaults* tdir))
     (t nil))))

#+(and :clisp (or :unix :win32))
(defun chdir (dir)
 (ext::cd dir))

#+:openmcl
(defun chdir (dir)
  (ccl::%chdir dir))

#+:ecl
(defun chdir (dir)
   (SI:CHDIR dir t))

;;; Environment access

(defun |getEnv| (var-name)
  #+:GCL (system::getenv var-name)
  #+:sbcl (sb-ext::posix-getenv var-name)
  #+:clisp (ext::getenv var-name)
  #+:openmcl (ccl::getenv var-name)
  #+:ecl (si::getenv var-name)
  )

;;; Silent loading of files

(defun |load_quietly| (f)
    ;;; (format *error-output* "entred load_quietly ~&") 
    #-(or :GCL :CCL)
    (handler-bind ((warning #'muffle-warning))
                  (load f))
    #+(or :GCL :CCL)
    (load f)
    ;;; (format *error-output* "finished load_quietly ~&") 
)

;;; File and directory support
;;; First version contributed by Juergen Weiss.

#+:GCL
(progn
  (LISP::defentry file_kind (LISP::string)      (LISP::int "directoryp"))
  (LISP::defentry |makedir| (LISP::string)         (LISP::int "makedir")))

#+:ecl
(uffi:def-function ("directoryp" raw_file_kind)
                   ((arg :cstring))
                   :returning :int)
#+:ecl
(defun file_kind (name)
      (FFI:WITH-CSTRING (cname name)
           (raw_file_kind cname)))

#+:ecl
(uffi:def-function ("makedir" raw_makedir)
                   ((arg :cstring))
                   :returning :int)

#+:ecl
(defun |makedir| (name)
      (FFI:WITH-CSTRING (cname name)
          (raw_makedir cname)))

(defun trim-directory-name (name)
    #+(or :unix :win32)
    (if (char= (char name (1- (length name))) #\/)
        (setf name (subseq name 0 (1- (length name)))))
    name)

(defun pad-directory-name (name)
   #+(or :unix :win32)
   (if (char= (char name (1- (length name))) #\/)
       name
       (concatenate 'string name "/")))

;;; Make directory

#+(or :GCL :ecl)
(defun makedir (fname) (|makedir| fname))

#+:sbcl
(defun makedir (fname)
    (sb-ext::run-program "mkdir" (list fname) :search t))

#+:openmcl
(defun makedir (fname)
    (ccl::run-program "mkdir" (list fname)))

#+:clisp
(defun makedir (fname)
    (ext:make-dir (pad-directory-name (namestring fname))))

;;;

(defun file-kind (filename)
   #+(or :GCL :ecl) (file_kind filename)
   #+:sbcl (case (sb-unix::unix-file-kind filename)
                 (:directory 1)
                 ((nil) -1)
               (t 0))
   #+:openmcl (if (ccl::directoryp filename)
                  1
                  (if (probe-file filename)
                      0
                     -1))
   #+:clisp (let* ((fname (trim-directory-name (namestring filename)))
                   (dname (pad-directory-name fname)))
             (if (ignore-errors (truename dname))
                 1
                 (if (ignore-errors (truename fname))
                     0
                     -1)))
   )
 
#+:cmu
(defun get-current-directory ()
  (namestring (extensions::default-directory)))

#+(or :ecl :gcl :sbcl :clisp :openmcl)
(defun get-current-directory ()
    (trim-directory-name (namestring (truename ""))))

#+:poplog
(defun get-current-directory ()
   (let ((name (namestring (truename "."))))
        (trim-directory-name (subseq name 0 (1- (length name))))))



(defun axiom-probe-file (file)
#|
#+:GCL (if (fboundp 'system::stat)
           ;;; gcl-2.6.8
           (and (system::stat file) (truename file))
           ;;; gcl-2.6.7
           (probe-file file))
|#
#+:GCL (let* ((fk (file-kind (namestring file)))
              (fname (trim-directory-name (namestring file)))
              (dname (pad-directory-name fname)))
           (cond
             ((equal fk 1)
                (truename dname))
             ((equal fk 0)
               (truename fname))
             (t nil)))
#+:sbcl (if (sb-unix::unix-file-kind file) (truename file))
#+(or :openmcl :ecl) (probe-file file)
#+:clisp(let* ((fname (trim-directory-name (namestring file)))
               (dname (pad-directory-name fname)))
                 (or (ignore-errors (truename dname))
                     (ignore-errors (truename fname))))
         )



