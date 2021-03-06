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
 
(DEFPARAMETER /COUNTLIST NIL)
(DEFPARAMETER /TIMERLIST NIL)
(DEFPARAMETER /TRACESIZE NIL "sets limit on size of object to be mathprinted")
(DEFVAR CURSTRM *TERMINAL-IO*)
(DEFVAR /TRACELETNAMES ())
(DEFVAR /PRETTY () "controls pretty printing of trace output")
(SETANDFILEQ /ECHO NIL) ;;"prevents echo of SPAD or BOOT code with /c"
(MAKEPROP 'LISP '/TERMCHR '(#\  #\())
(MAKEPROP 'LSP '/TERMCHR '(#\  #\())
(MAKEPROP 'META '/TERMCHR '(#\:  #\())
(MAKEPROP 'INPUT '/TERMCHR '(#\:  #\<  #\  #\())
(MAKEPROP 'SPAD '/TERMCHR '(#\:  #\<  #\  #\())
(MAKEPROP 'BOOT '/TERMCHR '(#\:  #\<  #\  #\())
(MAKEPROP 'INPUT '/XCAPE #\_)
(MAKEPROP 'BOOT '/XCAPE '#\_)
(MAKEPROP 'SPAD '/XCAPE '#\_)
(MAKEPROP 'META '/READFUN 'META\,RULE)
(MAKEPROP 'META '/TRAN '/TRANSMETA)
(MAKEPROP 'INPUT '/READFUN '|New,LEXPR,Interactive|)
(MAKEPROP 'INPUT '/TRAN '/TRANSPAD)
(MAKEPROP 'BOOT '/READFUN '|New,LEXPR1|)
(MAKEPROP 'BOOT '/TRAN '/TRANSNBOOT)
(MAKEPROP 'SPAD '/READFUN '|New,LEXPR|)
(MAKEPROP 'SPAD '/TRAN '/TRANSPAD)
 
(defmacro |/C,LIB| (&rest L &aux optionlist /editfile
                          ($prettyprint 't) ($reportCompilation 't))
  (declare (special optionlist /editfile $prettyprint $reportComilation))
  `',(|compileConstructorLib| L (/COMP) NIL NIL))
 
(defmacro /C (&rest L) `',(/D-1 L (/COMP) NIL NIL))
 
(defmacro /CT (&rest L) `',(/D-1 L (/COMP) NIL 'T))
 
(defmacro /CTL (&rest L) `',(/D-1 L (/COMP) NIL 'TRACELET))
 
(defmacro /D (&rest L) `',(/D-1 L 'DEFINE NIL NIL))
 
(defmacro /EC (&rest L) `', (/D-1 L (/COMP) 'T NIL))
 
(defmacro /ECT (&rest L) `',(/D-1 L (/COMP) 'T 'T))
 
(defmacro /ECTL (&rest L) `',(/D-1 L (/COMP) 'T 'TRACELET))
 
(defmacro /E (&rest L) `',(/D-1 L NIL 'T NIL))
 
(defmacro /ED (&rest L) `',(/D-1 L 'DEFINE 'T NIL))
 
(defun heapelapsed () 0)
 
(defun /COMP () (if (fboundp 'COMP) 'COMP 'COMP370))
 
(DEFUN /D-1 (L OP EFLG TFLG)
  (CATCH 'FILENAM
    (PROG (TO OPTIONL OPTIONS FNL INFILE OUTSTREAM FN )
          (declare (special fn infile outstream ))
          (if (member '? L :test #'eq)
              (RETURN (OBEY "EXEC SPADEDIT /C TELL")))
          (SETQ OPTIONL (/OPTIONS L))
          (SETQ FNL (TRUNCLIST L OPTIONL))
          (SETQ OPTIONS (OPTIONS2UC OPTIONL))
          (SETQ INFILE (/MKINFILENAM (/GETOPTION OPTIONS 'FROM)))
          (SETQ TO (/GETOPTION OPTIONS 'TO))
          (if TO (SETQ TO (/MKOUTFILENAM (/GETOPTION OPTIONS 'TO) INFILE)))
          (SETQ OUTSTREAM (if TO (DEFSTREAM TO 'OUTPUT) CUROUTSTREAM))
          (RETURN (mapcar #'(lambda (fn)
                              (/D-2 FN INFILE OUTSTREAM OP EFLG TFLG))
                          (or fnl (list /fn)))))))
 
(DEFUN |/D,2,LIB| (FN INFILE CUROUTSTREAM OP EDITFLAG TRACEFLAG)
       (declare (special CUROUTSTREAM))
  "Called from compConLib1 (see LISPLIB BOOT) to bind CUROUTSTREAM."
  (/D-2 FN INFILE CUROUTSTREAM OP EDITFLAG TRACEFLAG))
 
(DEFUN /D-2 (FN INFILE OUTPUTSTREAM OP EDITFLAG TRACEFLAG)
       (declare (special OUTPUTSTREAM))
  (PROG (FT oft SFN X EDINFILE FILE DEF KEY RECNO U W SOURCEFILES
         ECHOMETA SINGLINEMODE XCAPE XTOKENREADER INPUTSTREAM SPADERRORSTREAM
         ISID NBLNK COMMENTCHR (/SOURCEFILES |$sourceFiles|)
         METAKEYLST DEFINITION_NAME (|$sourceFileTypes| '(|spad| |boot| |lisp| |lsp| |meta|))
         ($FUNCTION FN) $BOOT $LINESTACK $LINENUMBER STACK STACKX BACK OK
         TRAPFLAG |$InteractiveMode| TOK COUNT ERRCOL COLUMN *QUERY CHR LINE
         (*COMP370-APPLY* (if (eq op 'define) #'eval-defun #'compile-defun)))
        (declare (special ECHOMETA SINGLINEMODE XCAPE XTOKENREADER INPUTSTREAM
                     SPADERRORSTREAM ISID NBLNK COMMENTCHR /SOURCEFILES
                     METAKEYLST DEFINITION_NAME |$sourceFileTypes|
                     $FUNCTION $BOOT $LINESTACK $LINENUMBER STACK STACKX BACK OK
                     TRAPFLAG |$InteractiveMode| TOK COUNT ERRCOL COLUMN *QUERY CHR LINE))
        (if (PAIRP FN) (SETQ FN (QCAR FN)))
        (SETQ INFILE (OR INFILE (|getFunctionSourceFile| FN)))
          ;; $FUNCTION is freely set in getFunctionSourceFile
        (IF (PAIRP $FUNCTION) (SETQ $FUNCTION (QCAR $FUNCTION)))
        (SETQ FN $FUNCTION)
        (SETQ /FN $FUNCTION)
   LOOP (SETQ SOURCEFILES
              (cond ( INFILE
                      (SETQ /SOURCEFILES (CONS INFILE (REMOVE INFILE /SOURCEFILES)))
                      (LIST INFILE))
                    ( /EDITFILE
                      (|insert| (|pathname| /EDITFILE) /SOURCEFILES))
                    ( 't /SOURCEFILES)))
        (SETQ RECNO
              (dolist (file sourcefiles)
                    (SETQ INPUTSTREAM (DEFSTREAM FILE 'INPUT))
 
                    ;;?(REMFLAG S-SPADKEY 'KEY)    ;  hack !!
                    (SETQ  FT (|pathnameType| FILE))
                    (SETQ  oft (|object2Identifier| (UPCASE FT)))
                    (SETQ XCAPE (OR (GET oft '/XCAPE) #\|))
                    (SETQ COMMENTCHR (GET oft '/COMMENTCHR))
                    (SETQ XTOKENREADER (OR (GET oft '/NXTTOK) 'METATOK))
                    (SETQ DEFINITION_NAME FN)
                    (SETQ KEY
                          (STRCONC
                            (OR (AND (EQ oFT 'SPAD) "")
                                (AND (EQ oFT 'BOOT) "")
                                (GET oFT '/PREFIX)
                                "")
                            (PNAME FN)))
                    (SETQ SFN (GET oFT '/READFUN))
                    (SETQ RECNO (/LOCATE FN KEY FILE 0))
                    (SHUT INPUTSTREAM)
                    (cond ((NUMBERP RECNO)
                           (SETQ /SOURCEFILES (CONS FILE (REMOVE FILE /SOURCEFILES)))
                           (SETQ INFILE FILE)
                           (RETURN RECNO)))) )
        (if (NOT RECNO)
            (if (SETQ INFILE (/MKINFILENAM '(NIL))) (GO LOOP) (UNWIND)))
        (TERPRI)
        (TERPRI)
        (SETQ INFILE (|pathname| INFILE))
        (COND
         ( EDITFLAG
          ;;%% next form is used because $FINDFILE seems to screw up
          ;;%% sometimes. The stream is opened and closed several times
          ;;%% in case the filemode has changed during editing.
          (SETQ EDINFILE (make-input-filename INFILE))
          (SETQ INPUTSTREAM (DEFSTREAM EDINFILE 'INPUT))
          (|sayBrightly|
            (LIST  "   editing file" '|%b| (|namestring| EDINFILE) '|%d|))
          (OBEY
            (STRCONC
              (make-absolute-filename "/lib/SPADEDFN ")
              (|namestring| EDINFILE)
              " "
              (STRINGIMAGE $LINENUMBER)))
          (SHUT INPUTSTREAM)
          ;(COND
          ;  ( (EQ (READ ERRORINSTREAM) 'ABORTPROCESS)
          ;    (RETURN 'ABORT) ) )
          ;;%% next is done in case the diskmode changed
          ;;(SETQ INFILE (|pathname| (IFCAR
          ;; (QSORT ($LISTFILE INFILE)))))
          (SETQ INPUTSTREAM (DEFSTREAM INFILE 'INPUT))
          (SETQ RECNO (/LOCATE FN KEY INFILE RECNO))
        
          (COND ((NOT RECNO)
                 (|sayBrightly| (LIST "   Warning: function" "%b" /FN "%d"
                                      "was not found in the file" "%l" "  " "%b"
                                      (|namestring| INFILE) "%d" "after editing."))
                 (RETURN NIL)))
          ;; next is done in case the diskmode changed
          (SHUT INPUTSTREAM) ))
        ;;(SETQ INFILE (|pathname| (IFCAR ($LISTFILE INFILE))))
        (SETQ INFILE (vmlisp::make-input-filename INFILE))
        (MAKEPROP /FN 'DEFLOC
                  (CONS RECNO INFILE))
        (SETQ oft (|object2Identifier| (UPCASE (|pathnameType| INFILE))))
        (COND
         ( (NULL OP)
           (RETURN /FN) ) )
        (COND
         ( (EQ TRACEFLAG 'TRACELET)
           (RETURN (/TRACELET-1 (LIST FN) NIL)) ) )
        (SETQ INPUTSTREAM (DEFSTREAM INFILE 'INPUT))
        (|sayBrightly|
         (LIST  "   Reading file" '|%b| (|namestring| INFILE) '|%d|))
        (TERPRI)
        (SETQ $BOOT (EQ oft 'BOOT))
        (SETQ DEF
              (COND
               ( SFN
                 ;(+VOL 'METABASE)
                 (POINT RECNO INPUTSTREAM)
                 ;(SETQ CHR (CAR INPUTSTREAM))
                 ;(SETQ ERRCOL 0)
                 ;(SETQ COUNT 0)
                 ;(SETQ COLUMN 0)
                 ;(SETQ TRAPFLAG NIL)
                 (SETQ OK 'T)
                 ;(NXTTOK)
                 ;(SETQ LINE (CURINPUTLINE))
                 ;(SETQ SPADERRORSTREAM CUROUTSTREAM)
                 ;(AND /ECHO (SETQ ECHOMETA 'T) (PRINTEXP LINE) (TERPRI))
                 ;(SFN)
                 (SETQ DEF (BOOT-PARSE-1 INPUTSTREAM))
                 (SETQ DEBUGMODE 'YES)
                 (COND
                  ( (NULL OK)
                    (FUNCALL (GET oft 'SYNTAX_ERROR))
                    NIL )
                  ( 'T
                    DEF ) ) )
               ( 'T
                 (let* ((mode-line (read-line inputstream))
                        (pacpos (search "package:" mode-line :test #'equalp))
                        (endpos (search "-*-" mode-line :from-end t))
                        (*package* *package*)
                        (newpac nil))
                   (when pacpos
                         (setq newpac (read-from-string mode-line nil nil
                                                        :start (+ pacpos 8)
                                                        :end endpos))
                         (setq *package*
                               (cond ((find-package newpac))
                                     (t *package*))))
                   (POINT RECNO INPUTSTREAM)
                   (READ INPUTSTREAM)))))
      #+Lucid(system::compiler-options :messages t :warnings t)
        (COND
         ( (SETQ U (GET oft '/TRAN))
           (SETQ DEF (FUNCALL U DEF)) ) )
      (/WRITEUPDATE
        /FN
        (|pathnameName| INFILE)
        (|pathnameType| INFILE)
        (OR (|pathnameDirectory| INFILE) '*)
        (OR (KAR (KAR (KDR DEF))) NIL)
        OP)
      (COND
        ( (OR /ECHO $PRETTYPRINT)
          (PRETTYPRINT DEF OUTPUTSTREAM) ) )
      (COND
        ( (EQ oft 'LISP)
          (if (EQ OP 'DEFINE) (EVAL DEF)
            (compile (EVAL DEF))))
        ( DEF
          (FUNCALL OP (LIST DEF)) ) )
      #+Lucid(system::compiler-options :messages nil :warnings nil)
      #+Lucid(TERPRI)
      (COND
        ( TRACEFLAG
          (/TRACE-2 /FN NIL) ) )
      (SHUT INPUTSTREAM)
      (RETURN (LIST /FN)) ) )
 
(DEFUN FUNLOC (func &aux file)
  (if (PAIRP func) (SETQ func (CAR func)))
  (setq file (ifcar (findtag func)))
  (if file (list (pathname-name file) (pathname-type file) func)
    nil))
 
(DEFUN /LOCATE (FN KEY INFILE INITRECNO)
       (PROG (FT RECNO KEYLENGTH LN)
        (if (AND (NOT (eq 'FROMWRITEUPDATE (|pathnameName| INFILE)))
                    (NOT (make-input-filename INFILE)))
            (RETURN NIL))
        (SETQ FT (UPCASE (|object2Identifier| (|pathnameType| INFILE))))
        (SETQ KEYLENGTH (STRINGLENGTH KEY))
        (WHEN (> INITRECNO 1)  ;; we think we know where it is
              (POINT INITRECNO INPUTSTREAM)
              (SETQ LN (READ-LINE INPUTSTREAM NIL NIL))
              (IF (AND LN (MATCH-FUNCTION-DEF FN KEY KEYLENGTH LN FT))
                  (RETURN INITRECNO)))
        (SETQ $LINENUMBER 0)
        (POINT 0 INPUTSTREAM)
EXAMINE (SETQ RECNO (NOTE INPUTSTREAM))
        (SETQ LN (READ-LINE INPUTSTREAM NIL NIL))
        (INCF $LINENUMBER)
        (if (NULL LN) (RETURN NIL))
        (IF (MATCH-FUNCTION-DEF FN KEY KEYLENGTH LN FT)
            (RETURN RECNO))
        (GO EXAMINE)))
 
(DEFUN MATCH-FUNCTION-DEF (fn key keylength line type)
       (if (eq type 'LISP) (match-lisp-tag fn line "(def")
         (let ((n (mismatch key line)))
           (and (= n keylength)
                (or (= n (length line))
                    (member (elt line n)
                            (or (get type '/termchr) '(#\space ))))))))
 
(define-function '|/D,1| #'/D-1)
 
(DEFUN /INITUPDATES (/VERSION)
   (SETQ FILENAME (STRINGIMAGE /VERSION))
   (SETQ /UPDATESTREAM (open (strconc "/tmp/update." FILENAME) :direction :output
                             :if-exists :append :if-does-not-exist :create))
   (PRINTEXP
 "       Function Name                    Filename             Date   Time"
      /UPDATESTREAM)
   (TERPRI /UPDATESTREAM)
   (PRINTEXP
 " ---------------------------      -----------------------  -------- -----"
      /UPDATESTREAM)
   (TERPRI /UPDATESTREAM) )
 
(defun /UPDATE (&rest ARGS)
  (LET (( FILENAME (OR (KAR ARGS)
                       (strconc "/tmp/update." (STRINGIMAGE /VERSION))))
        (|$createUpdateFiles| NIL))
       (DECLARE (SPECIAL |$createUpdateFiles|))
       (CATCH 'FILENAM (/UPDATE-1 FILENAME '(/COMP)))
       (SAY "Update is finished")))

(defun /DUPDATE (&rest ARGS)
  (LET (( FILENAME (OR (KAR ARGS)
                       (strconc "/tmp/update." (STRINGIMAGE /VERSION))))
        (|$createUpdateFiles| NIL))
       (DECLARE (SPECIAL |$createUpdateFiles|))
       (CATCH 'FILENAM (/UPDATE-1 FILENAME 'DEFINE))
       (SAY "Update is finished")))
 
(DEFUN /UPDATE-1 (UPFILE OP)
   ;;if /VERSION=0 then no new update files will be written.
  (prog (STREAM RECORD FUN FILE FUNFILES)
   (SETQ STREAM (DEFSTREAM (/MKINFILENAM UPFILE) 'INPUT))
 LOOP
   (if (STREAM-EOF STREAM) (RETURN NIL))
   (SETQ RECORD (read-line STREAM))
   (if (NOT (STRINGP RECORD)) (RETURN NIL))
   (if (< (LENGTH RECORD) 36) (GO LOOP))
   (SETQ FUN (STRING2ID-N (SUBSTRING RECORD 0 36) 1))
   (if (AND (NOT (EQUAL FUN 'QUAD)) (EQUAL (SUBSTRING RECORD 0 1) " "))
       (GO LOOP))
   (SETQ FILE (STRING2ID-N RECORD 2))
   (if (member (cons fun file) funfiles :test #'equal) (go loop))
   (push (cons fun file) funfiles)
   (COND ((EQUAL FUN 'QUAD) (/RF-1 FILE))
         ((/D-2 FUN FILE CUROUTSTREAM OP NIL NIL)))
   (GO LOOP)))
 
(DEFUN /WRITEUPDATE (FUN FN FT FM FTYPE OP)
 
;;;If /VERSION=0 then no save has yet been done.
;;;If A disk is not read-write, then issue msg and return.
;;;If /UPDATESTREAM not set or current /UPDATES file doesnt exist, initialize.
 
   (PROG (IFT KEY RECNO ORECNO COUNT DATE TIME)
;         (if (EQ 0 /VERSION) (RETURN NIL))
         (if (EQ 'INPUT FT) (RETURN NIL))
         (if (NOT |$createUpdateFiles|) (RETURN NIL))
;         (COND ((/= 0 (directory "A")))
;               ((SAY "A disk is not read-write. Update file not modified")
;                (RETURN NIL)))
         (if (OR (NOT (BOUNDP '/UPDATESTREAM))
                 (NOT (STREAMP /UPDATESTREAM)))
             (/INITUPDATES /VERSION))
;         (SETQ IFT (INTERN (STRINGIMAGE /VERSION)))
;         (SETQ INPUTSTREAM (open (strconc IFT /WSNAME) :direction :input))
;         (NEXT INPUTSTREAM)
;         (SETQ KEY (if (NOT FUN)
;                       (STRCONC "                                QUAD "
;                                (PNAME FN))
;                       (PNAME FUN)))
;         (SETQ RECNO (/LOCATE KEY (LIST 'FROMWRITEUPDATE /WSNAME) 1))
;         (SETQ COUNT (COND
;                       ((NOT (NUMBERP RECNO)) 1)
;                       ((POINT RECNO INPUTSTREAM)
;                        (do ((i 1 (1+ i))) ((> i 4)) (read inputstream))
;                        (1+ (READ INPUTSTREAM)) )))
;         (COND ((NUMBERP RECNO)
;                (SETQ ORECNO (NOTE /UPDATESTREAM))
;                (POINTW RECNO /UPDATESTREAM) ))
         (SETQ DATETIME (|getDateAndTime|))
         (SETQ DATE (CAR DATETIME))
         (SETQ TIME (CDR DATETIME))
         (PRINTEXP (STRCONC
                  (COND ((NOT FUN) "                                QUAD ")
                        ((STRINGPAD (PNAME FUN) 28))) " "
                  (STRINGIMAGE FM)
                  (STRINGIMAGE FN) "." (STRINGIMAGE FT)
                  " "
                  DATE " " TIME) /UPDATESTREAM)
         (TERPRI /UPDATESTREAM)
;         (if (NUMBERP RECNO) (POINTW ORECNO /UPDATESTREAM))
         ))
 
(defun |getDateAndTime| ()
   (MULTIPLE-VALUE-BIND (sec min hour day mon year) (get-decoded-time)
   (CONS (STRCONC (LENGTH2STR mon) "/"
                  (LENGTH2STR day) "/"
                  (LENGTH2STR year) )
         (STRCONC (LENGTH2STR hour) ":"
                  (LENGTH2STR min)))))
 
(DEFUN LENGTH2STR (X &aux XLEN)
       (cond ( (= 1 (SETQ XLEN (LENGTH (SETQ X (STRINGIMAGE X))))) (STRCONC "0" X))
             ( (= 2 XLEN) X)
             ( (subseq x (- XLEN 2)))))
 
(defmacro /T (&rest L) (CONS '/TRACE (OR L (LIST /FN))))
 
(defmacro /TRACE (&rest L) `',(/TRACE-0 L))
 
(DEFUN /TRACE-0 (L)
  (if (member '? L :test #'eq)
      (OBEY "EXEC NORMEDIT TRACE TELL")
      (let* ((options (/OPTIONS L)) (FNL (TRUNCLIST L OPTIONS)))
        (/TRACE-1 FNL OPTIONS))))
 
(define-function '|/TRACE,0| #'/TRACE-0)
 
(defmacro /TRACEANDCOUNT (&rest L) `',
  (let* ((OPTIONS (/OPTIONS L))
         (FNL (TRUNCLIST L OPTIONS)))
    (/TRACE-1 FNL (CONS '(DEPTH) OPTIONS))))
 
(DEFUN /TRACE-1 (FNLIST OPTIONS)
   (mapcar #'(lambda (X) (/TRACE-2 X OPTIONS)) FNLIST)
   (/TRACEREPLY))
 
(DEFUN /TRACE-2 (FN OPTIONS)
  (PROG (U FNVAL COUNTNAM TRACECODE BEFORE AFTER CONDITION
         TRACENAME CALLER VARS BREAK FROM_CONDITION VARBREAK TIMERNAM
         ONLYS G WITHIN_CONDITION  DEPTH_CONDITION COUNT_CONDITION
         LETFUNCODE MATHTRACE )
        (if (member FN /TRACENAMES :test #'eq) (/UNTRACE-2 FN NIL))
        (SETQ OPTIONS (OPTIONS2UC OPTIONS))
        (if (AND |$traceDomains| (|isFunctor| FN) (ATOM FN))
            (RETURN (|traceDomainConstructor| FN OPTIONS)))
        (SETQ MATHTRACE (/GETTRACEOPTIONS OPTIONS 'MATHPRINT))
        (if (AND MATHTRACE (NOT (EQL (ELT (PNAME FN) 0) #\$)) (NOT (GENSYMP FN)))
            (if (RASSOC FN |$mapSubNameAlist|)
                (SETQ |$mathTraceList| (CONS FN |$mathTraceList|))
                (|spadThrowBrightly|
                  (format nil "mathprint not available for ~A" FN))))
        (SETQ VARS (/GETTRACEOPTIONS OPTIONS 'VARS))
        (if VARS
            (progn (if (NOT (CDR VARS)) (SETQ VARS 'all) (SETQ VARS (CDR VARS)))
                   (|tracelet| FN VARS)))
        (SETQ BREAK (/GETTRACEOPTIONS OPTIONS 'BREAK))
        (SETQ VARBREAK (/GETTRACEOPTIONS OPTIONS 'VARBREAK))
        (if VARBREAK
            (progn   (if (NOT (CDR VARBREAK)) (SETQ VARS 'all)
                         (SETQ VARS (CDR VARBREAK)))
                     (|breaklet| FN VARS)))
        (if (and (symbolp fn) (not (boundp FN)) (not (fboundp FN)))
            (progn
              (COND ((|isUncompiledMap| FN)
                     (|sayBrightly|
                       (format nil
           "~A must be compiled before it may be traced -- invoke ~A to compile"
                                            FN FN)))
                    ((|isInterpOnlyMap| FN)
                     (|sayBrightly| (format nil
            "~A cannot be traced because it is an interpret-only function" FN)))
                    (T (|sayBrightly| (format nil "~A is not a function" FN))))
              (RETURN NIL)))
        (if (and (symbolp fn) (boundp FN)
                 (|isDomainOrPackage| (SETQ FNVAL (EVAL FN))))
            (RETURN (|spadTrace| FNVAL OPTIONS)))
        (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'MASK=))
            (MAKEPROP FN '/TRANSFORM (CADR U)))
        (SETQ /TRACENAMES
              (COND ((/GETTRACEOPTIONS OPTIONS 'ALIAS) /TRACENAMES)
                    ((ATOM /TRACENAMES) (LIST FN))
                    ((CONS FN /TRACENAMES))))
        (SETQ TRACENAME
              (COND ((SETQ U (/GETTRACEOPTIONS OPTIONS 'ALIAS))
                     (STRINGIMAGE (CADR U)))
                    (T
                     (COND ((AND |$traceNoisely| (NOT VARS)
                                 (NOT (|isSubForRedundantMapName| FN)))
                            (|sayBrightly|
                             (LIST '|%b| (|rassocSub| FN |$mapSubNameAlist|)
                                   '|%d| "traced"))))
                     (STRINGIMAGE FN))))
        (COND (|$fromSpadTrace|
               (if MATHTRACE (push (INTERN TRACENAME) |$mathTraceList|))
               (SETQ LETFUNCODE `(SETQ |$currentFunction| ,(MKQ FN)))
               (SETQ BEFORE
                     (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'BEFORE))
                         `(progn ,(CADR U) ,LETFUNCODE)
                         LETFUNCODE)))
              (T (SETQ BEFORE
                       (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'BEFORE))
                           (CADR U)))))
        (SETQ AFTER (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'AFTER)) (CADR U)))
        (SETQ CALLER (/GETTRACEOPTIONS OPTIONS 'CALLER))
        (SETQ FROM_CONDITION
              (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'FROM))
                  (LIST 'EQ '|#9| (LIST 'QUOTE (CADR U)))
                  T))
        (SETQ CONDITION
              (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'WHEN)) (CADR U) T))
        (SETQ WITHIN_CONDITION T)
        (COND ((SETQ U (/GETTRACEOPTIONS OPTIONS 'WITHIN))
               (SETQ G (INTERN (STRCONC (PNAME FN) "/" (PNAME (CADR U)))))
               (SET G 0)
               (/TRACE-1
                 (LIST (CADR U))
                 `((WHEN NIL)
                   (BEFORE (SETQ ,G (1+ ,G)))
                   (AFTER (SETQ ,G (1- ,G)))))
               (SETQ WITHIN_CONDITION `(> ,G 0))))
        (SETQ COUNTNAM
              (AND (/GETTRACEOPTIONS OPTIONS 'COUNT)
                   (INTERN (STRCONC TRACENAME ",COUNT"))) )
        (SETQ COUNT_CONDITION
              (COND ((SETQ U (/GETTRACEOPTIONS OPTIONS 'COUNT))
                     (SETQ /COUNTLIST (adjoin TRACENAME /COUNTLIST
                                              :test 'equal))
                     (if (AND (CDR U) (integerp (CADR U)))
                         `(cond ((<= ,COUNTNAM ,(CADR U)) t)
                                (t (/UNTRACE-2 ,(MKQ FN) NIL) NIL))
                         t))
                    (T T)))
        (AND (/GETTRACEOPTIONS OPTIONS 'TIMER)
             (SETQ TIMERNAM (INTERN (STRCONC TRACENAME ",TIMER")))
             (SETQ /TIMERLIST (adjoin TRACENAME /TIMERLIST :test 'equal)))
        (SETQ DEPTH_CONDITION
              (if (SETQ U (/GETTRACEOPTIONS OPTIONS 'DEPTH))
                  (if (AND (CDR U) (integerp (CADR U)))
                      (LIST 'LE 'FUNDEPTH (CADR U))
                    (TRACE_OPTION_ERROR 'DEPTH))
                  T))
        (SETQ CONDITION
              (MKPF
                (LIST CONDITION WITHIN_CONDITION FROM_CONDITION COUNT_CONDITION
                      DEPTH_CONDITION )
                'AND))
        (SETQ ONLYS (/GETTRACEOPTIONS OPTIONS 'ONLY))
 
        ;TRACECODE meaning:
        ; 0:        Caller (0,1)           print caller if 1
        ; 1:        Value (0,1)            print value if 1
        ; 2...:     Arguments (0,...,9)    stop if 0; print ith if i; all if 9
        (SETQ TRACECODE
              (if (/GETTRACEOPTIONS OPTIONS 'NT) "000"
                  (PROG (F A V C NL BUF)
                        (SETQ ONLYS (MAPCAR #'COND-UCASE ONLYS))
                        (SETQ F (OR (member 'F ONLYS :test #'eq)
                                    (member 'FULL ONLYS :test #'eq)))
                        (SETQ A (OR F (member 'A ONLYS :test #'eq)
                                    (member 'ARGS ONLYS :test #'eq)))
                        (SETQ V (OR F (member 'V ONLYS :test #'eq)
                                    (member 'VALUE ONLYS :test #'eq)))
                        (SETQ C (OR F (member 'C ONLYS :test #'eq)
                                    (member 'CALLER ONLYS :test #'eq)))
                        (SETQ NL
                              (if A '(#\9)
                                  (mapcan #'(lambda (X)
                                              (if (AND (INTEGERP X)
                                                       (> X 0)
                                                       (< X 9))
                                                  (LIST (FETCHCHAR (STRINGIMAGE X) 0))))
                                          onlys)))
                        (if (NOT (OR A V C NL))
                            (if Caller (return "119") (return "019")))
                        (SETQ NL (APPEND NL '(\0)))
                        (SETQ BUF (GETSTR 12))
                        (SUFFIX (if (or C Caller) #\1 #\0) BUF)
                        (SUFFIX (if V #\1 #\0) BUF)
                        (if A (suffix #\9 BUF)
                            (mapcar #'(lambda (x) (suffix x BUF)) NL))
                        (RETURN BUF))))
        (/MONITOR FN TRACECODE BEFORE AFTER CONDITION TIMERNAM
                  COUNTNAM TRACENAME BREAK )))
 
(DEFUN OPTIONS2UC (L)
  (COND ((NOT L) NIL)
        ((ATOM (CAR L))
         (|spadThrowBrightly|
           (format nil "~A has wrong format for an option" (car L))))
        ((CONS (CONS (LC2UC (CAAR L)) (CDAR L)) (OPTIONS2UC (CDR L))))))
 
(DEFUN COND-UCASE (X) (COND ((INTEGERP X) X) ((UPCASE X))))
 
(DEFUN TRACEOPTIONS (X)
  (COND ((NOT X) NIL)
        ((EQ (CAR X) '/) X)
        ((TRACEOPTIONS (CDR X)))))
 
(defmacro |/untrace| (&rest L) `', (/UNTRACE-0 L))
 
(defmacro /UNTRACE (&rest L) `', (/UNTRACE-0 L))
 
(defmacro /U (&rest L) `', (/UNTRACE-0 L))
 
(DEFUN /UNTRACE-0 (L)
    (PROG (OPTIONL OPTIONS FNL)
      (if (member '? L :test #'eq) (RETURN (OBEY "EXEC NORMEDIT TRACE TELL")))
      (SETQ OPTIONL (/OPTIONS L))
      (SETQ FNL (TRUNCLIST L OPTIONL))
      (SETQ OPTIONS (if OPTIONL (CAR OPTIONL)))
      (RETURN (/UNTRACE-1 FNL OPTIONS))))
 
(define-function '|/UNTRACE,0| #'/UNTRACE-0)
 
(defun /UNTRACE-1 (L OPTIONS)
  (cond
    ((NOT L)
     (if (ATOM /TRACENAMES)
         NIL
         (mapcar #'(lambda (u) (/UNTRACE-2 (/UNTRACE-REDUCE U) OPTIONS))
                 (APPEND /TRACENAMES NIL))))
    ((mapcar #'(lambda (x) (/UNTRACE-2 X OPTIONS)) L)))
  (/TRACEREPLY))
 
(DEFUN /UNTRACE-REDUCE (X) (if (ATOM X) X (first X))) ; (CAR X) is now a domain
 
(DEFUN /UNTRACE-2 (X OPTIONS)
 (let (u y)
  (COND ((AND (|isFunctor| X) (ATOM X))
         (|untraceDomainConstructor| X))
        ((OR (|isDomainOrPackage| (SETQ U X))
             (and (symbolp X) (boundp X)
                  (|isDomain| (SETQ U (EVAL X)))))
         (|spadUntrace| U OPTIONS))
        ((EQCAR OPTIONS 'ALIAS)
           (if |$traceNoisely|
               (|sayBrightly| (LIST '|%b| (CADR OPTIONS) '|%d| '**untraced)))
           (SETQ /TIMERLIST
                 (REMOVE (STRINGIMAGE (CADR OPTIONS)) /TIMERLIST :test 'equal))
           (SETQ /COUNTLIST
                 (REMOVE (STRINGIMAGE (CADR OPTIONS)) /COUNTLIST :test 'equal))
           (SETQ |$mathTraceList|
                 (REMOVE (CADR OPTIONS) |$mathTraceList| :test 'equal))
           (UNEMBED X))
        ((AND (NOT (MEMBER X /TRACENAMES))
              (NOT (|isSubForRedundantMapName| X)))
         (|sayBrightly|
           (LIST
             '|%b|
             (|rassocSub| X |$mapSubNameAlist|)
             '|%d|
             "not traced")))
        (T (SETQ /TRACENAMES (REMOVE X /TRACENAMES :test 'equal))
           (SETQ |$mathTraceList|
                 (REMOVE (if (STRINGP X) (INTERN X) X) |$mathTraceList|))
           (SETQ |$letAssoc| (DELASC X |$letAssoc|))
           (setq Y (if (IS_GENVAR X) (|devaluate| (EVAL X)) X))
           (SETQ /TIMERLIST (REMOVE (STRINGIMAGE Y) /TIMERLIST :test 'equal))
           (SET (INTERN (STRCONC Y ",TIMER")) 0)
           (SETQ /COUNTLIST (REMOVE (STRINGIMAGE Y) /COUNTLIST :test 'equal))
           (SET (INTERN (STRCONC Y ",COUNT")) 0)
           (COND ((AND |$traceNoisely| (NOT (|isSubForRedundantMapName| Y)))
                  (|sayBrightly|
                    (LIST '|%b| (|rassocSub| Y |$mapSubNameAlist|)
                  '|%d| "untraced"))))
           (UNEMBED X)))))
 
  ;; the following is called by |clearCache|
(define-function '/UNTRACE\,2 #'/UNTRACE-2)
 
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
 
(DEFUN MONITOR-BLANKS (N) (PRINC (MAKE-FULL-CVEC N " ") CURSTRM))
 
(DEFUN MONITOR-EVALBEFORE (X) (EVALFUN (MONITOR-EVALTRAN X NIL)) X)
 
(DEFUN MONITOR-EVALAFTER (X) (EVALFUN (MONITOR-EVALTRAN X 'T)))
 
(DEFUN MONITOR-EVALTRAN (X FG)
  (if (HAS_SHARP_VAR X) (MONITOR-EVALTRAN1 X FG) X))
 
(define-function 'MONITOR\,EVALTRAN #'MONITOR-EVALTRAN)
 
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
  (COND ((OR (ATOM L) (LESSP N 1)) NIL)
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
 
(DEFUN /OPTIONS (X)
  (COND ((ATOM X) NIL)
        ((OR (ATOM (CAR X)) (|isFunctor| (CAAR X))) (/OPTIONS (CDR X)))
        (X)))
 
(DEFUN /GETOPTION (L OPT) (KDR (/GETTRACEOPTIONS L OPT)))
 
(DEFUN /GETTRACEOPTIONS (L OPT)
  (COND ((ATOM L) NIL)
        ((EQ (KAR (CAR L)) OPT) (CAR L))
        ((/GETTRACEOPTIONS (CDR L) OPT))))
 
(DEFMACRO /TRACELET (&rest L) `',
  (PROG (OPTIONL FNL)
        (if (member '? L :test #'eq)
            (RETURN (OBEY (if (EQ (SYSID) 1)
                              "EXEC NORMEDIT TRACELET TELL"
                              "$COPY AZ8F:TRLET.TELL")) ))
        (SETQ OPTIONL (/OPTIONS L))
        (SETQ FNL (TRUNCLIST L OPTIONL))
        (RETURN (/TRACELET-1 FNL OPTIONL))))
 
(DEFUN /TRACELET-1 (FNLIST OPTIONL)
  (mapcar #'(lambda (x) (/tracelet-2 x optionl)) fnlist)
  (/TRACE-1 FNLIST OPTIONL)
  (TRACELETREPLY))
 
(DEFUN TRACELETREPLY ()
   (if (ATOM /TRACELETNAMES) '(none tracelet)
       (APPEND /TRACELETNAMES (LIST 'tracelet))))
 
(DEFUN /TRACELET-2 (FN OPTIONL &AUX ($TRACELETFLAG T))
  (/D-1 (CONS FN OPTIONL) 'COMP NIL NIL)
  (SETQ /TRACELETNAMES
        (if (ATOM /TRACELETNAMES) (LIST FN) (CONS FN /TRACELETNAMES)))
  FN)
 
(defmacro /TRACE-LET (A B)
  `(PROG1 (SPADLET ,A ,B)
          . ,(mapcar #'(lambda (x) `(/tracelet-print ',x ,x))
                     (if (ATOM A) (LIST A) A))))
 
(defun /TRACELET-PRINT (X Y &AUX (/PRETTY 'T))
  (PRINC (STRCONC (PNAME X) ": ") *terminal-io*)
  (MONITOR-PRINT Y *terminal-io*))
 
(defmacro /UNTRACELET (&rest L) `',
  (COND
    ((NOT L)
     (if (ATOM /TRACELETNAMES) NIL (EVAL (CONS '/UNTRACELET /TRACELETNAMES))))
    ((mapcar #'/untracelet-1 L))
    ((TRACELETREPLY))))
 
(DEFUN /UNTRACELET-1 (X)
  (COND
    ((NOT (MEMBER X /TRACELETNAMES))
     (PROGN (PRINT (STRCONC (PNAME X) " not tracelet")) (TERPRI)))
    ((PROGN
       (/UNTRACELET-2 X)
       (/D-1 (LIST X) 'COMP NIL NIL)))))
 
(DEFUN /UNTRACELET-2 (X)
  (SETQ /TRACELETNAMES (REMOVE X /TRACELETNAMES))
  (PRINT (STRCONC (PNAME X) " untracelet")) (TERPRI))
 
(defmacro /EMBED (&rest L) `',
 (COND ((NOT L) (/EMBEDREPLY))
       ((member '? L :test #'eq) (OBEY "EXEC NORMEDIT EMBED TELL"))
       ((EQ 2 (LENGTH L)) (/EMBED-1 (CAR L) (CADR L)))
       ((MOAN "IMPROPER USE OF /EMBED"))))
 
(defmacro /UNEMBED (&rest L) `',
  (COND ((NOT L)
         (if (ATOM (EMBEDDED)) NIL
             (mapcar #'unembed (embedded)))
         (SETQ /TRACENAMES NIL)
         (SETQ /EMBEDNAMES NIL))
        ((mapcar #'/unembed-1 L)
         (SETQ /TRACENAMES (S- /TRACENAMES L)) ))
  (/EMBEDREPLY))
 
(defun /UNEMBED-Q (X)
  (COND
    ((NOT (MEMBER X /EMBEDNAMES))
     (ERROR (STRCONC (PNAME X) " not embeded")))
    ((PROGN
       (SETQ /EMBEDNAMES (REMOVE X /EMBEDNAMES))
       (UNEMBED X)))))
 
(defun /UNEMBED-1 (X)
  (COND
    ((NOT (MEMBER X /EMBEDNAMES))
     (|sayBrightly| (LIST '|%b| (PNAME X) '|%d| "not embeded" '|%l|)))
    ((PROGN
       (SETQ /EMBEDNAMES (REMOVE X /EMBEDNAMES))
       (|sayBrightly| (LIST '|%b| (PNAME X) '|%d| "unembeded" '|%l|))
       (UNEMBED X)))  ))
 
 
 
(defun /MONITOR (&rest G5)
  (PROG (G1 G4 TRACECODE BEFORE AFTER CONDITION
         TIMERNAM COUNTNAM TRACENAME BREAK)
        (dcq (G1 TRACECODE BEFORE AFTER CONDITION TIMERNAM COUNTNAM TRACENAME BREAK) G5)
        (SETQ G4 (macro-function G1))
        (SETQ TRACECODE (OR TRACECODE "119"))
        (if COUNTNAM (SET COUNTNAM 0))
        (if TIMERNAM (SET TIMERNAM 0))
        (EMBED
          G1
          (LIST
            (if G4 'MLAMBDA 'LAMBDA)
            '(&rest G6)
            (LIST
              '/MONITORX
              (QUOTE G6)
              G1
              (LIST
                'QUOTE
                (LIST
                  TRACENAME (if G4 'MACRO) TRACECODE
                  COUNTNAM TIMERNAM BEFORE AFTER
                  CONDITION BREAK |$tracedModemap| ''T)))))
        (RETURN G1)))
 
(defun /MONITORX (/ARGS FUNCT OPTS &AUX NAME TYPE TRACECODE COUNTNAM TIMERNAM
                        BEFORE AFTER CONDITION BREAK TRACEDMODEMAP
                        BREAKCONDITION)
            (declare (special /ARGS))
  (DCQ (NAME TYPE TRACECODE COUNTNAM TIMERNAM BEFORE AFTER CONDITION BREAK TRACEDMODEMAP BREAKCONDITION) OPTS)
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
        (SETQ YES (EVALFUN CONDITION))
        (if (member NAMEID |$mathTraceList| :test #'eq)
            (SETQ |$mathTrace| T))
        (if (AND YES |$TraceFlag|)
            (PROG (|$TraceFlag|)
                  (SETQ CURSTRM *TERMINAL-IO*)
                  (if (EQUAL TRACECODE "000") (RETURN NIL))
                  (TAB 0 CURSTRM)
                  (MONITOR-BLANKS (1- /DEPTH))
                  (PRIN0 FUNDEPTH CURSTRM)
                  (|sayBrightlyNT| (LIST "<enter" '|%b|
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
        (SETQ /VALUE (if (EQ TYPE 'MACRO) (MDEFX FUNCT /ARGS)
                         (APPLY FUNCT /ARGS)))
        (|stopTimer|)
        (if TIMERNAM (SETQ EVAL_TIME (- (|clock|) INIT_TIME)) )
        (if (AND TIMERNAM (NOT NOT_TOP_LEVEL))
            (SET TIMERNAM (+ (EVAL TIMERNAM) EVAL_TIME)))
        (if AFTER (MONITOR-EVALAFTER AFTER))
        (if (AND YES |$TraceFlag|)
            (PROG (|$TraceFlag|)
                  (if (EQUAL TRACECODE "000") (GO SKIP))
                  (TAB 0 CURSTRM)
                  (MONITOR-BLANKS (1- /DEPTH))
                  (PRIN0 FUNDEPTH CURSTRM)
                  (|sayBrightlyNT| (LIST ">exit " '|%b| NAME1 '|%d|) CURSTRM)
                  (COND (TIMERNAM
                         (|sayBrightlyNT| '\( CURSTRM)
                         (|sayBrightlyNT| (/ EVAL_TIME 60.0) CURSTRM)
                         (|sayBrightlyNT| '\ sec\) CURSTRM) ))
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
 
(defun |startTimer| ()
    (SETQ $delay (PLUS $delay (DIFFERENCE (TEMPUS-FUGIT) |$oldTime|)))
    (SETQ |$timerOn| 'T)
    (|clock|))
 
(defun |stopTimer| () (SETQ |$oldTime| (TEMPUS-FUGIT) |$timerOn| NIL) (|clock|))
 
(defun |clock| ()
  (if |$timerOn| (- (TEMPUS-FUGIT) $delay) (- |$oldTime| $delay)))
 
; Functions to trace/untrace a BPI; use as follows:
; To trace a BPI-value <bpi>, evaluate (SETQ <name> (BPITRACE <bpi>))
; To later untrace <bpi>, evaluate (BPITRACE <name>)
 
(defun PAIRTRACE (PAIR ALIAS)
   (RPLACA PAIR (BPITRACE (CAR PAIR) ALIAS )) NIL)
 
(defun BPITRACE (BPI ALIAS &optional OPTIONS)
  (SETQ NEWNAME (GENSYM))
  (IF (identp bpi) (setq bpi (symbol-function bpi)))
  (SET NEWNAME BPI)
  (SETF (symbol-function NEWNAME) BPI)
  (/TRACE-0 (APPEND (LIST NEWNAME (LIST 'ALIAS ALIAS)) OPTIONS))
  NEWNAME)
 
(defun BPIUNTRACE (X ALIAS) (/UNTRACE-0 (LIST X (LIST 'ALIAS ALIAS))))
 
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
 
#+:CCL
(defun break (&rest ignore) (lisp-break ignore) (lisp::unwind))


#+:CCL
(defun lisp-break (&rest ignore)
  (prog (prompt ifile ofile u v)
    (setq ifile (rds *debug-io*))
    (setq ofile (wrs *debug-io*))
    (setq prompt (setpchar "Break loop (:? for help)> "))
top (setq u (read))
    (cond
      ((equal u ':x) (go exit))
      ((equal u ':q)
        (progn (lisp::enable-backtrace nil) 
               (princ "Backtrace now disabled")
               (terpri)))
      ((equal u ':v)
        (progn (lisp::enable-backtrace t)
               (princ "Backtrace now enabled")
               (terpri)))
      ((equal u ':?)
        (progn
           (princ ":Q   disables backtrace")
           (terpri)
           (princ ":V   enables backtrace")
           (terpri)
           (princ ":X   exits from break loop")
           (terpri)
           (princ "else enter LISP expressions for evaluation")
           (terpri)))
      ((equal u #\eof)
       (go exit))
     (t (progn
           (setq v (errorset u nil nil))
           (if (listp v) (progn (princ "=> ") (prinl (car v)) (terpri))))) )
     (go top)
exit (rds ifile)
     (wrs ofile)
     (setpchar prompt)
     (return nil)))

(defun lisp-break-from-axiom (&rest ignore) 
    (boot::|handleLispBreakLoop| boot::|$BreakMode|))
#+:CCL (setq lisp:*break-loop* 'boot::lisp-break-from-axiom)

;;; A "resumable" break loop for use in trace etc. Unfortunately this
;;; only works for CCL. We need to define a Common Lisp version. For
;;; now the function is defined but does nothing.
#-:CCL
(defun interrupt (&rest ignore))

#+:CCL
(defun interrupt (&rest ignore)
  (prog (prompt ifile ofile u v)
    (setq ifile (rds *debug-io*))
    (setq ofile (wrs *debug-io*))
    (setq prompt (setpchar "Break loop (:? for help)> "))
top (setq u (read))
    (cond
      ((equal u ':x) (go exit))
      ((equal u ':r) (go resume))
      ((equal u ':q)
        (progn (lisp::enable-backtrace nil) 
               (princ "Backtrace now disabled")
               (terpri)))
      ((equal u ':v)
        (progn (lisp::enable-backtrace t)
               (princ "Backtrace now enabled")
               (terpri)))
      ((equal u ':?)
        (progn
           (princ ":Q   disables backtrace")
           (terpri)
           (princ ":V   enables backtrace")
           (terpri)
           (princ ":R   resumes from break")
           (terpri)
           (princ ":X   exits from break loop")
           (terpri)
           (princ "else enter LISP expressions for evaluation")
           (terpri)))
      ((equal u #\eof)
       (go exit))
     (t (progn
           (setq v (errorset u nil nil))
           (if (listp v) (progn (princ "=> ") (prinl (car v)) (terpri))))) )
     (go top)
resume (rds ifile)
     (wrs ofile)
     (setpchar prompt)
     (return nil)
exit (rds ifile)
     (wrs ofile)
     (setpchar prompt)
     (lisp::unwind)))


