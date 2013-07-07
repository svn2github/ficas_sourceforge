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


;;;  @(#)debug.lisp     2.5      90/02/15  10:27:33

; NAME:    Debugging Package
; PURPOSE: Debugging hooks for Boot code

(in-package "BOOT")

(DEFPARAMETER /TRACESIZE NIL "sets limit on size of object to be mathprinted")
(DEFPARAMETER /DEPTH 0)
(DEFVAR CURSTRM *standard-output*)
(DEFVAR /PRETTY () "controls pretty printing of trace output")
(DEFPARAMETER /ECHO NIL) ;;"prevents echo of SPAD or BOOT code with /c"

(defun enable-backtrace (&rest arg))

(defun |adjoin_equal|(x y) (ADJOIN x y :test #'equal))

(defun |remove_equal|(x y) (REMOVE x y :test #'equal))

(defun WHOCALLED(n) nil) ;; no way to look n frames up the stack

(defun heapelapsed () 0)

(defun |goGetTracerHelper| (dn f oname alias options modemap)
    (lambda(&rest l)
         (|goGetTracer| l dn f oname alias options modemap)))

(defun |setSf| (sym fn) (SETF (SYMBOL-FUNCTION sym) fn))

(DEFUN OPTIONS2UC (L)
  (COND ((NOT L) NIL)
        ((ATOM (CAR L))
         (|spadThrowBrightly|
           (format nil "~A has wrong format for an option" (car L))))
        ((CONS (CONS (UPCASE (CAAR L)) (CDAR L)) (OPTIONS2UC (CDR L))))))

(DEFUN MONITOR-PRINVALUE (VAL NAME)
  (let (u)
    (COND ((setq U (GET NAME '/TRANSFORM))
           (COND
             ((EQCAR U '&)
              (PRINC "//" CURSTRM) (PRIN1 VAL CURSTRM) (TERPRI CURSTRM))
             (T (PRINC "! " CURSTRM)
                (PRIN1 (EVAL (SUBST (MKQ VAL) '* (CAR U))) CURSTRM)
                (TERPRI CURSTRM)) ))
          (T
           (PRINC ": " CURSTRM)
           (COND ((NOT (SMALL-ENOUGH VAL)) (|F,PRINT-ONE| VAL CURSTRM))
                 (/PRETTY (PRETTYPRINT VAL CURSTRM))
                 (T (COND (|$mathTrace| (TERPRI)))
                    (PRINMATHOR0 VAL CURSTRM)))))))

(DEFUN MONITOR-BLANKS (N) (PRINC (|make_full_CVEC| N " ") CURSTRM))

(DEFUN MONITOR-EVALBEFORE (X) (EVAL (MONITOR-EVALTRAN X NIL)) X)

(DEFUN MONITOR-EVALAFTER (X) (EVAL (MONITOR-EVALTRAN X 'T)))

(DEFUN MONITOR-EVALTRAN (X FG)
  (if (HAS_SHARP_VAR X) (MONITOR-EVALTRAN1 X FG) X))

(DEFUN MONITOR-EVALTRAN1 (X FG)
  (let (n)
    (COND
      ((SETQ N (|isSharpVarWithNum| X)) (MONITOR-GETVALUE N FG))
      ((ATOM X) X)
      ((CONS (MONITOR-EVALTRAN1 (CAR X) FG)
             (MONITOR-EVALTRAN1 (CDR X) FG))))))

(DEFUN HAS_SHARP_VAR (X)
  (COND ((AND (ATOM X) (IS_SHARP_VAR X)) 'T)
        ((ATOM X) NIL)
        ((OR (HAS_SHARP_VAR (CAR X)) (HAS_SHARP_VAR (CDR X))))))

(DEFUN IS_SHARP_VAR (X)
  (AND (IDENTP X)
       (EQL (ELT (PNAME X) 0) #\#)
       (INTEGERP (parse-integer (symbol-name X) :start 1))))

(DEFUN MONITOR-GETVALUE (N FG)
  (COND ((= N 0)
         (if FG
             (MKQ /VALUE)
             (|spadThrowBrightly| "cannot ask for value before execution")))
        ((= N 9) (MKQ /CALLER))
        ((<= N (SIZE /ARGS)) (MKQ (ELT /ARGS (1- N))))
        ((|spadThrowBrightly| (LIST 'function '|%b| /NAME '|%d|
                              "does not have" '|%b| N '|%d| "arguments")))))

(DEFUN MONITOR-PRINARGS (L CODE /TRANSFORM)
  (let (N)
    (cond
      ((= (digit-char-p (elt CODE 2)) 0) NIL)
      ((= (digit-char-p (elt CODE 2)) 9)
       (cond
         (/TRANSFORM
           (mapcar
             #'(lambda (x y)
                 (COND ((EQ Y '*)
                        (PRINC "\\ " CURSTRM)
                        (MONITOR-PRINT X CURSTRM))
                       ((EQ Y '&)
                        (PRINC "\\\\" CURSTRM)
                        (TERPRI CURSTRM)
                        (PRINT X CURSTRM))
                       ((NOT Y) (PRINC "! " CURSTRM))
                       (T
                        (PRINC "! " CURSTRM)
                        (MONITOR-PRINT
                          (EVAL (SUBST (MKQ X) '* Y)) CURSTRM))))
            L (cdr /transform)))
         (T (PRINC ": " CURSTRM)
            (COND ((NOT (ATOM L))
                   (if |$mathTrace| (TERPRI CURSTRM))
                   (MONITOR-PRINT (CAR L) CURSTRM) (SETQ L (CDR L))))
            (mapcar #'monitor-printrest L))))
      ((do ((istep 2 (+ istep 1))
            (k (maxindex code)))
           ((> istep k) nil)
        (when (not (= 0 (SETQ N (digit-char-p (elt CODE ISTEP)))))
         (PRINC "\\" CURSTRM)
         (PRINMATHOR0 N CURSTRM)
         (PRINC ": " CURSTRM)
         (MONITOR-PRINARGS-1 L N)))))))

(DEFUN MONITOR-PRINTREST (X)
  (COND ((NOT (SMALL-ENOUGH X))
         (PROGN (TERPRI)
                (MONITOR-BLANKS (1+ /DEPTH))
                (PRINC "\\" CURSTRM)
                (PRINT X CURSTRM)))
        ((PROGN (if (NOT |$mathTrace|) (PRINC "\\" CURSTRM))
                (COND (/PRETTY (PRETTYPRINT X CURSTRM))
                      ((PRINMATHOR0 X CURSTRM)))))))

(DEFUN MONITOR-PRINARGS-1 (L N)
  (COND ((OR (ATOM L) (< N 1)) NIL)
        ((EQ N 1) (MONITOR-PRINT (CAR L) CURSTRM))
        ((MONITOR-PRINARGS-1 (CDR L) (1- N)))))

(DEFUN MONITOR-PRINT (X CURSTRM)
  (COND ((NOT (SMALL-ENOUGH X)) (|F,PRINT-ONE| X CURSTRM))
        (/PRETTY (PRETTYPRINT X CURSTRM))
        ((PRINMATHOR0 X CURSTRM))))

(DEFUN PRINMATHOR0 (X CURSTRM)
  (if |$mathTrace| (|maprinSpecial| (|outputTran| X) /DEPTH 80)
      (PRIN0 X CURSTRM)))

(DEFUN SMALL-ENOUGH (X) (if /TRACESIZE (SMALL-ENOUGH-COUNT X 0 /TRACESIZE) t))

(DEFUN SMALL-ENOUGH-COUNT (X N M)
  "Returns number if number of nodes < M otherwise nil."
  (COND ((< M N) NIL)
        ((VECP X)
         (do ((i 0 (1+ i)) (k (maxindex x)))
             ((> i k) n)
           (if (NOT (SETQ N (SMALL-ENOUGH-COUNT (ELT X I) (1+ N) M)))
               (RETURN NIL))))
        ((ATOM X) N)
        ((AND (SETQ N (SMALL-ENOUGH-COUNT (CAR X) (1+ N) M))
              (SMALL-ENOUGH-COUNT (CDR X) N M)))))

(defun /TRACELET-PRINT (X Y &AUX (/PRETTY 'T))
  (PRINC (STRCONC (PNAME X) ": ") *standard-output*)
  (MONITOR-PRINT Y *standard-output*))

(DEFPARAMETER |$TraceFlag| t)

(defun /MONITORX (/ARGS FUNCT OPTS &AUX NAME TYPE TRACECODE COUNTNAM TIMERNAM
                        BEFORE AFTER CONDITION BREAK TRACEDMODEMAP
                        BREAKCONDITION)
            (declare (special /ARGS))
  (let ((x opts))
       (setf NAME (ifcar x)              x (ifcdr x))
       (setf TYPE (ifcar x)              x (ifcdr x))
       (setf TRACECODE (ifcar x)         x (ifcdr x))
       (setf COUNTNAM (ifcar x)          x (ifcdr x))
       (setf TIMERNAM (ifcar x)          x (ifcdr x))
       (setf BEFORE (ifcar x)            x (ifcdr x))
       (setf AFTER (ifcar x)             x (ifcdr x))
       (setf CONDITION (ifcar x)         x (ifcdr x))
       (setf BREAK (ifcar x)             x (ifcdr x))
       (setf TRACEDMODEMAP (ifcar x)     x (ifcdr x))
       (setf BREAKCONDITION (ifcar x)    x (ifcdr x)))

  (|stopTimer|)
  (PROG (C V A NAME1 CURSTRM EVAL_TIME INIT_TIME NOT_TOP_LEVEL
         (/DEPTH (if (and (BOUNDP '/DEPTH) (numberp /depth)) (1+ /DEPTH) 1))
         (|depthAlist| (if (BOUNDP '|depthAlist|) (COPY-TREE |depthAlist|) NIL))
         FUNDEPTH NAMEID YES (|$tracedSpadModemap| TRACEDMODEMAP) (|$mathTrace| NIL)
         /caller /name /value /breakcondition curdepth)
    (declare (special curstrm /depth fundepth |$tracedSpadModemap| |$mathTrace|
                      /caller /name /value /breakcondition |depthAlist|))
        (SETQ /NAME NAME)
        (SETQ NAME1 (PNAME (|rassocSub| (INTERN NAME) |$mapSubNameAlist|)))
        (SETQ /BREAKCONDITION BREAKCONDITION)
        (SETQ /CALLER (|rassocSub| (WHOCALLED 6) |$mapSubNameAlist|))
        (if (NOT (STRINGP TRACECODE))
            (MOAN "set TRACECODE to \'1911\' and restart"))
        (SETQ C (digit-char-p (elt TRACECODE 0))
              V (digit-char-p (elt TRACECODE 1))
              A (digit-char-p (elt TRACECODE 2)))
        (if COUNTNAM (SET COUNTNAM (1+ (EVAL COUNTNAM))))
        (SETQ NAMEID (INTERN NAME))
        (SETQ NOT_TOP_LEVEL (ASSOC NAMEID |depthAlist| :test #'eq))
        (if (NOT NOT_TOP_LEVEL)
            (SETQ |depthAlist| (CONS (CONS NAMEID 1) |depthAlist|))
            (RPLACD NOT_TOP_LEVEL (1+ (CDR NOT_TOP_LEVEL))))
        (SETQ FUNDEPTH (CDR (ASSOC NAMEID |depthAlist| :test #'eq)))
        (SETQ CONDITION (MONITOR-EVALTRAN CONDITION NIL))
        (SETQ YES (EVAL CONDITION))
        (if (member NAMEID |$mathTraceList| :test #'eq)
            (SETQ |$mathTrace| T))
        (if (AND YES |$TraceFlag|)
            (PROG (|$TraceFlag|)
                  (declare (special |$TraceFlag|))
                  (SETQ CURSTRM *standard-output*)
                  (if (EQUAL TRACECODE "000") (RETURN NIL))
                  (TAB 0 CURSTRM)
                  (MONITOR-BLANKS (1- /DEPTH))
                  (PRIN0 FUNDEPTH CURSTRM)
                  (|sayBrightlyNT2| (LIST "<enter" '|%b|
                                         NAME1 '|%d|) CURSTRM)
                  (COND ((EQ 0 C) NIL)
                        ((EQ TYPE 'MACRO)
                         (PRINT " expanded" CURSTRM))
                        (T (PRINT " from " CURSTRM)
                           (PRIN0 /CALLER CURSTRM)))
                  (MONITOR-PRINARGS
                    (if (SPADSYSNAMEP NAME)
                        (NREVERSE (REVERSE  (|coerceTraceArgs2E|
                                              (INTERN NAME1)
                                              (INTERN NAME)
                                              /ARGS)))
                        (|coerceTraceArgs2E| (INTERN NAME1)
                                             (INTERN NAME) /ARGS))
                    TRACECODE
                    (GET (INTERN NAME) '/TRANSFORM))
                  (if (NOT |$mathTrace|) (TERPRI CURSTRM))))
        (if before (MONITOR-EVALBEFORE BEFORE))
        (if (member '|before| BREAK :test #'eq)
            (|break| (LIST "Break on entering" '|%b| NAME1 '|%d| ":")))
        (if TIMERNAM (SETQ INIT_TIME (|startTimer|)))
        (SETQ /VALUE (if (EQ TYPE 'MACRO) (macroexpand FUNCT /ARGS)
                         (APPLY FUNCT /ARGS)))
        (|stopTimer|)
        (if TIMERNAM (SETQ EVAL_TIME (- (|clock|) INIT_TIME)) )
        (if (AND TIMERNAM (NOT NOT_TOP_LEVEL))
            (SET TIMERNAM (+ (EVAL TIMERNAM) EVAL_TIME)))
        (if AFTER (MONITOR-EVALAFTER AFTER))
        (if (AND YES |$TraceFlag|)
            (PROG (|$TraceFlag|)
                  (declare (special |$TraceFlag|))
                  (if (EQUAL TRACECODE "000") (GO SKIP))
                  (TAB 0 CURSTRM)
                  (MONITOR-BLANKS (1- /DEPTH))
                  (PRIN0 FUNDEPTH CURSTRM)
                  (|sayBrightlyNT2| (LIST ">exit " '|%b| NAME1 '|%d|) CURSTRM)
                  (COND (TIMERNAM
                         (|sayBrightlyNT2| '\( CURSTRM)
                         (|sayBrightlyNT2| (/ EVAL_TIME 60.0) CURSTRM)
                         (|sayBrightlyNT2| '\ sec\) CURSTRM) ))
                  (if (EQ 1 V)
                      (MONITOR-PRINVALUE
                        (|coerceTraceFunValue2E|
                          (INTERN NAME1) (INTERN NAME) /VALUE)
                        (INTERN NAME1)))
                  (if (NOT |$mathTrace|) (TERPRI CURSTRM))
               SKIP))
        (if (member '|after| BREAK :test #'eq)
            (|break| (LIST "Break on exiting" '|%b| NAME1 '|%d| ":")))
        (|startTimer|)
        (RETURN /VALUE)))

; Functions to run a timer for tracing
; It avoids timing the tracing function itself by turning the timer
; on and off

(defparameter $delay 0)

(defun |startTimer| ()
    (SETQ $delay (+ $delay (- (TEMPUS-FUGIT) |$oldTime|)))
    (SETQ |$timerOn| 'T)
    (|clock|))

(defun |stopTimer| () (SETQ |$oldTime| (TEMPUS-FUGIT) |$timerOn| NIL) (|clock|))

(defun |clock| ()
  (if |$timerOn| (- (TEMPUS-FUGIT) $delay) (- |$oldTime| $delay)))

(defun SPADSYSNAMEP (STR)
  (let (n i j)
    (AND (SETQ N (MAXINDEX STR))
         (SETQ I (position #\. STR :start 1))
         (SETQ J (position #\, STR :start (1+ I)))
         (do ((k (1+ j) (1+ k)))
             ((> k n) t)
           (if (not (digitp (elt str k))) (return nil))))))

; **********************************************************************
;            Utility functions for Tracing Package
; **********************************************************************

(MAKEPROP '|coerce| '/TRANSFORM '(& & *))
(MAKEPROP '|comp| '/TRANSFORM '(& * * &))
(MAKEPROP '|compIf| '/TRANSFORM '(& * * &))

;  by having no transform for the 3rd argument, it is simply not printed

(MAKEPROP '|compFormWithModemap| '/TRANSFORM '(& * * & *))

(defun UNVEC (X)
  (COND ((REFVECP X) (CONS '$ (VEC_TO_TREE X)))
        ((ATOM X) X)
        ((CONS (UNVEC (CAR X)) (UNVEC (CDR X))))))

(defun DROPENV (X) (AND X (LIST (CAR X) (CADR X))))

(defun SHOWBIND (E)
  (do ((v e (cdr v))
       (llev 1 (1+ llev)))
      ((not v))
    (PRINT (LIST "LAMBDA LEVEL" LLEV))
    (do ((w (car v) (cdr w))
         (clev 1 (1+ clev)))
        ((not w))
      (PRINT (LIST "CONTOUR LEVEL" CLEV))
      (PRINT (mapcar #'car (car W))))))


;;; A "resumable" break loop for use in trace etc. Unfortunately this
;;; only worked for CCL. We need to define a Common Lisp version. For
;;; now the function is defined but does nothing.
(defun interrupt (&rest ignore))
