;; Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;;     - Redistributions of source code must retain the above copyright
;;       notice, this list of conditions and the following disclaimer.
;;
;;     - Redistributions in binary form must reproduce the above copyright
;;       notice, this list of conditions and the following disclaimer in
;;       the documentation and/or other materials provided with the
;;       distribution.
;;
;;     - Neither the name of The Numerical ALgorithms Group Ltd. nor the
;;       names of its contributors may be used to endorse or promote products
;;       derived from this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
;; IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
;; TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
;; PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
;; OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


; NAME:         BootLex.lisp
; PURPOSE:      Parsing support routines for Boot and Spad code
; CONTENTS:
;
;               0. Global parameters
;               1. BOOT File Handling
;               2. BOOT Line Handling
;               3. BOOT Token Handling
;               4. BOOT Token Parsing Actions
;               5. BOOT Error Handling

(in-package "BOOT")

; *** 0. Global parameters

(defparameter Boot-Line-Stack nil       "List of lines returned from PREPARSE.")

(defun Next-Lines-Clear () (setq Boot-Line-Stack nil))

(defun Next-Lines-Show ()
  (and Boot-Line-Stack (format t "Currently preparsed lines are:~%~%"))
  (mapcar #'(lambda (line)
              (format t "~&~5D> ~A~%" (car line) (cdr Line)))
          Boot-Line-Stack))

; *** 1. BOOT file handling

(defvar SPADERRORSTREAM)

(defun init-boot/spad-reader ()
  (setq $SPAD_ERRORS (VECTOR 0 0 0))
  (setq SPADERRORSTREAM *standard-output*)
  (setq XTokenReader 'get-BOOT-token)
  (setq Line-Handler 'next-BOOT-line)
  (setq Meta_Error_Handler 'spad_syntax_error)
  (setq File-Closed nil)
  (Next-Lines-Clear)
  (setq Boot-Line-Stack nil)
  (ioclear))

(defun |oldParserAutoloadOnceTrigger| () nil)

(defun print-defun (name body)
   (let* ((sp (assoc 'vmlisp::compiler-output-stream vmlisp::optionlist))
          (st (if sp (cdr sp) *standard-output*)))
     (if (and (is-console st) (symbolp name) (fboundp name)
              (not (compiled-function-p (symbol-function name))))
         (compile name))
     (when (or |$PrettyPrint| (not (is-console st)))
           (print-full body st) (force-output st))))

(defun boot (&optional
              (boot-input-file nil)
              (boot-output-file nil)
             &aux
             (Echo-Meta t)
             ($BOOT T)
             (|$InteractiveMode| NIL)
             (XCape #\_)
             (File-Closed NIL)
             (*EOF* NIL)
             (OPTIONLIST NIL)
             (*fileactq-apply* (function print-defun))
             (*comp370-apply* (function print-defun)))
  (declare (special echo-meta *comp370-apply* *EOF* File-Closed XCape))
  (init-boot/spad-reader)
  (with-open-stream
    (in-stream (if boot-input-file (open boot-input-file :direction :input)
                    *standard-input*))
    (initialize-preparse in-stream)
    (with-open-stream
      (out-stream (if boot-output-file
                      (open boot-output-file :direction :output
                         :if-exists :supersede)
                      #-(or :cmu :sbcl) (make-broadcast-stream *standard-output*)
                      #+(or :cmu :sbcl) *standard-output*
                      ))
      (when boot-output-file
         (format out-stream "~&;;; -*- Mode:Lisp; Package:Boot  -*-~%~%")
         (print-package "BOOT"))
      (loop (if (and (not File-Closed)
                     (setq Boot-Line-Stack (PREPARSE in-stream)))
                (progn
                       (|PARSE-Expression|)
                       (let ((parseout (pop-stack-1)) )
                         (setq parseout (|new2OldLisp| parseout))
                         (setq parseout (DEF-RENAME parseout))
                         (let ((*standard-output* out-stream))
                           (DEF-PROCESS parseout))
                         (format out-stream "~&")
                         (if (null parseout) (ioclear)) ))
                (return nil)))
      (if boot-input-file
          (format out-stream ";;;Boot translation finished for ~a~%"
                  (namestring boot-input-file)))
      (IOClear in-stream out-stream)))
  T)

(defun spad (&optional
              (spad-input-file nil)
              (spad-output-file nil)
             &aux
           (*comp370-apply* (function print-defun))
           (*fileactq-apply* (function print-defun))
         ;;  (|$InteractiveMode| nil)
           ($SPAD T)
           ($BOOT nil)
           (XCape #\_)
           (OPTIONLIST nil)
           (*EOF* NIL)
           (File-Closed NIL)
           (/editfile spad-input-file)
           in-stream out-stream)
  (declare (special echo-meta /editfile *comp370-apply* *EOF*
                    File-Closed Xcape))
  ;; only rebind |$InteractiveFrame| if compiling
  (progv (if (not |$InteractiveMode|) '(|$InteractiveFrame|))
         (if (not |$InteractiveMode|)
             (list (|addBinding|
                    '|$DomainsInScope|
                    `((FLUID . |true|)
                      (|special| . ,(COPY-TREE |$InitialDomainsInScope|)))
                    (|addBinding| '|$Information| NIL (|makeInitialModemapFrame|)))))
  (init-boot/spad-reader)
  (unwind-protect
    (progn
      (setq in-stream (if spad-input-file
                         (open spad-input-file :direction :input)
                         *standard-input*))
      (initialize-preparse in-stream)
      (setq out-stream (if spad-output-file
                           (open spad-output-file :direction :output)
                         *standard-output*))
      (when spad-output-file
         (format out-stream "~&;;; -*- Mode:Lisp; Package:Boot  -*-~%~%")
         (print-package "BOOT"))
      (setq curoutstream out-stream)
      (loop
       (if (or *eof* file-closed) (return nil))
       (catch 'SPAD_READER
         (if (setq Boot-Line-Stack (PREPARSE in-stream))
             (let ((LINE (cdar Boot-Line-Stack)))
               (declare (special LINE))
               (|PARSE-NewExpr|)
               (let ((parseout (pop-stack-1)) )
                 (when parseout
                       (let ((*standard-output* out-stream))
                         (S-PROCESS parseout))
                       (format out-stream "~&")))
               ;(IOClear in-stream out-stream)
               )))
      (IOClear in-stream out-stream)))
    (if spad-input-file (shut in-stream))
    (if spad-output-file (shut out-stream)))
  T))

;  *** 2. BOOT Line Handling ***

; See the file PREPARSE.LISP for the hard parts of BOOT line processing.

(defun next-BOOT-line (&optional (in-stream t))

  "Get next line, trimming trailing blanks and trailing comments.
One trailing blank is added to a non-blank line to ease between-line
processing for Next Token (i.e., blank takes place of return).  Returns T
if it gets a non-blank line, and NIL at end of stream."

  (if Boot-Line-Stack
      (let ((Line-Number (caar Boot-Line-Stack))
            (Line-Buffer (suffix #\Space (cdar Boot-Line-Stack))))
        (pop Boot-Line-Stack)
        (Line-New-Line Line-Buffer Current-Line Line-Number)
        (setq |$currentLine| (setq LINE Line-Buffer))
        Line-Buffer)))

;  *** 3. BOOT Token Handling ***

(defparameter xcape #\_ "Escape character for Boot code.")

(defun get-BOOT-token (token)

  "If you have an _, go to the next line.
If you have a . followed by an integer, get a floating point number.
Otherwise, get a .. identifier."

  (if (not (boot-skip-blanks))
      nil
      (let ((token-type (boot-token-lookahead-type (current-char))))
        (case token-type
          (eof                  (token-install nil '*eof token nonblank))
          (escape               (advance-char)
                                (get-boot-identifier-token token t))
          (argument-designator  (get-argument-designator-token token))
          (id                   (get-boot-identifier-token token))
          (num                  (get-number-token token))
          (string               (get-SPADSTRING-token token))
          (special-char         (get-special-token token))
          (t                    (get-gliph-token token token-type))))))

(defun boot-skip-blanks ()
  (setq nonblank t)
  (loop (let ((cc (current-char)))
          (if (not cc) (return nil))
          (if (eq (boot-token-lookahead-type cc) 'white)
              (progn (setq nonblank nil) (if (not (advance-char)) (return nil)))
              (return t)))))

(defun boot-token-lookahead-type (char)
  "Predicts the kind of token to follow, based on the given initial character."
  (cond ((not char)                                        'eof)
        ((char= char #\_)                                  'escape)
        ((and (char= char #\#) (digitp (next-char)))       'argument-designator)
        ((digitp char)                                     'num)
        ((and (char= char #\$) $boot
              (alpha-char-p (next-char)))                  'id)
        ((or (char= char #\%) (char= char #\?)
             (char= char #\!) (alpha-char-p char))         'id)
        ((char= char #\")                                  'string)
        ((member char
                 '(#\Space #\Tab #\Return)
                 :test #'char=)                            'white)
        ((get (intern (string char)) 'Gliph))
        (t                                                 'special-char)))

(defun get-argument-designator-token (token)
  (advance-char)
  (get-number-token token)
  (token-install (intern (strconc "#" (format nil "~D" (token-symbol token))))
                 'argument-designator token nonblank))

(defvar Keywords '(|or| |and| |isnt| |is| |otherwise| |when| |where|
                  |has| |with| |add| |case| |in| |by| |pretend| |mod|
                  |exquo| |div| |quo| |else| |rem| |then| |suchthat|
                  |if| |yield| |iterate| |from| |exit| |leave| |return|
                  |not| |unless| |repeat| |until| |while| |for| |import|)



"Alphabetic literal strings occurring in the New Meta code constitute
keywords.   These are recognized specifically by the AnyId production,
GET-BOOT-IDENTIFIER will recognize keywords but flag them
as keywords.")

(defun get-boot-identifier-token (token &optional (escaped? nil))
  "An identifier consists of an escape followed by any character, a %, ?,
or an alphabetic, followed by any number of escaped characters, digits,
or the chracters ?, !, ' or %"
  (prog ((buf (make-adjustable-string 0))
         (default-package NIL))
      (suffix (current-char) buf)
      (advance-char)
   id (let ((cur-char (current-char)))
         (cond ((char= cur-char XCape)
                (if (not (advance-char)) (go bye))
                (suffix (current-char) buf)
                (setq escaped? t)
                (if (not (advance-char)) (go bye))
                (go id))
               ((and (null default-package)
                     (char= cur-char #\'))
                (setq default-package buf)
                (setq buf (make-adjustable-string 0))
                (if (not (advance-char)) (go bye))
                (go id))
               ((or (alpha-char-p cur-char)
                    (digitp cur-char)
                    (member cur-char '(#\% #\' #\? #\!) :test #'char=))
                (suffix (current-char) buf)
                (if (not (advance-char)) (go bye))
                (go id))))
  bye (if (and (stringp default-package)
               (or (not (find-package default-package))  ;; not a package name
                   (every #'(lambda (x) (eql x #\')) buf))) ;;token ends with ''
          (setq buf (concatenate 'string default-package "'" buf)
                default-package nil))
      (setq buf (intern buf (or default-package "BOOT")))
      (return (token-install
                buf
                (if (and (not escaped?)
                         (member buf Keywords :test #'eq))
                    'keyword 'identifier)
                token
                nonblank))))

(defun get-gliph-token (token gliph-list)
  (prog ((buf (make-adjustable-string 0)))
        (suffix (current-char) buf)
        (advance-char)
   loop (setq gliph-list (assoc (intern (string (current-char))) gliph-list))
        (if gliph-list
            (progn (suffix (current-char) buf)
                   (pop gliph-list)
                   (advance-char)
                   (go loop))
            (let ((new-token (intern buf)))
              (return (token-install new-token
                                     'gliph token nonblank))))))

(defun get-SPADSTRING-token (token)
   "With TOK=\" and ABC\" on IN-STREAM, extracts and stacks string ABC"
  (PROG ((BUF (make-adjustable-string 0)))
        (if (char/= (current-char) #\") (RETURN NIL) (advance-char))
        (loop
         (if (char= (current-char) #\") (return nil))
         (SUFFIX (if (char= (current-char) XCape)
                     (advance-char)
                   (current-char))
                 BUF)
         (if (null  (advance-char)) ;;end of line
             (PROGN (|sayBrightly| "Close quote inserted") (RETURN nil)))
         )
        (advance-char)
        (return (token-install (copy-seq buf) ;should make a simple string
                               'spadstring token))))

; **** 4. BOOT token parsing actions

; Parsing of operator tokens depends on tables initialized by BOTTOMUP.LISP

(defun-parse-token SPADSTRING)
(defun-parse-token KEYWORD)
(defun-parse-token ARGUMENT-DESIGNATOR)

(defun TRANSLABEL (X AL) (TRANSLABEL1 X AL) X)

(defun TRANSLABEL1 (X AL)
 "Transforms X according to AL = ((<label> . Sexpr) ..)."
  (COND ((REFVECP X)
         (do ((i 0 (1+ i))
              (k (maxindex x)))
             ((> i k))
           (if (LET ((Y (LASSOC (ELT X I) AL))) (SETELT X I Y))
               (TRANSLABEL1 (ELT X I) AL))))
        ((ATOM X) NIL)
        ((LET ((Y (LASSOC (FIRST X) AL)))
           (if Y (setf (FIRST X) Y) (TRANSLABEL1 (CDR X) AL))))
        ((TRANSLABEL1 (FIRST X) AL) (TRANSLABEL1 (CDR X) AL))))

; **** 5. BOOT Error Handling

(defparameter DEBUGMODE 'YES "Can be either YES or NO")

(defun SPAD_SYNTAX_ERROR (&rest byebye)
  "Print syntax error indication, underline character, scrub line."
  (BUMPERRORCOUNT '|syntax|)
  (COND ((AND (EQ DEBUGMODE 'YES) (NOT(CONSOLEINPUTP IN-STREAM)))
         (SPAD_LONG_ERROR))
        ((SPAD_SHORT_ERROR)))
  (IOClear)
  (throw 'spad_reader nil))

(defun SPAD_LONG_ERROR ()
  (SPAD_ERROR_LOC SPADERRORSTREAM)
  (iostat)
  (unless (EQUAL OUT-STREAM SPADERRORSTREAM)
    (SPAD_ERROR_LOC OUT-STREAM)
    (TERPRI OUT-STREAM)))

(defun SPAD_SHORT_ERROR () (current-line-show))

(defun SPAD_ERROR_LOC (STR)
  (format str "******** Boot Syntax Error detected ********"))

(defun BUMPERRORCOUNT (KIND)
  (unless |$InteractiveMode|
          (LET ((INDEX (case KIND
                         (|syntax| 0)
                         (|precompilation| 1)
                         (|semantic| 2)
                         (T (ERROR "BUMPERRORCOUNT")))))
            (SETELT $SPAD_ERRORS INDEX (1+ (ELT $SPAD_ERRORS INDEX))))))



