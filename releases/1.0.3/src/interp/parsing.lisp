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


; NAME:    META/LISP Parser Generator and Lexical Analysis Utilities (Parsing)
;
; PURPOSE: This package provides routines to support the Metalanguage
;          translator writing system.   Metalanguage is described
;          in META/LISP, R.D. Jenks, Tech Report, IBM T.J. Watson Research Center,
;          1969.  Familiarity with this document is assumed.
;
;          The parser generator itself is described in either the file
;          MetaBoot.lisp (hand-coded version) or the file MetaMeta.lisp (machine
;          generated from self-descriptive Meta code), both of which load themselves
;          into package Parsing.

; CONTENTS:
;
;       0. Current I/O Stream definition
;
;       1. Data structure declarations (defstructs) for parsing objects
;
;               A. Line Buffer
;               B. Stack
;               C. Token
;               D. Reduction
;
;       2. Recursive descent parsing support routines
;               A. Stacking and retrieving reductions of rules.
;               B. Applying metagrammatical elements of a production (e.g., Star).
;
;       3. Routines for handling lexical scanning
;
;               A. Manipulating the token stack and reading tokens
;               B. Error handling
;               C. Constructing parsing procedures
;               D. Managing rule sets
;
;       4. Tracing routines
;
;       5. Routines for inspecting and resetting total I/O system state
;
;       METALEX.LISP:  Meta file handling, auxiliary parsing actions and tokenizing
;       METAMETA.LISP: Meta parsing
;
;       BOOTLEX.LISP:  Boot file handling, auxiliary parsing actions and tokenizing
;       NEWMETA.LISP:  Boot parsing

(in-package "BOOT")

; 0. Current I/O Stream definition

(defparameter in-stream  t "Current input stream.")
(defparameter out-stream t "Current output stream.")
(defparameter File-Closed nil   "Way to stop EOF tests for console input.")

(defun IOStreams-Show ()
  (format t "~&Input is coming from ~A, and output is going to ~A.~%"
           (or (streamp in-stream) "the keyboard")
           (or (streamp out-stream) "the screen"))
  (format t "~:[~;The current input stream is logically closed.~%~]~%" File-Closed))

(defmacro IOStreams-Set (input output) `(setq in-stream ,input out-stream ,output))

(defmacro IOStreams-Clear (&optional (in t) (out t))
  `(progn (and (streamp in-stream) (close in-stream))
          (and (streamp out-stream) (close out-stream))
          (setq File-Closed nil)
          (IOStreams-Set ,in ,out)))

; 1. Data structure declarations (defstructs) for parsing objects
;
;               A. Line Buffer
;               B. Stack
;               C. Token
;               D. Reduction

; 1A. A Line Buffer
;
; The philosophy of lines is that
;
;       a) NEXT LINE will always get you a non-blank line or fail.
;       b) Every line is terminated by a blank character.
;
; Hence there is always a current character, because there is never a non-blank line,
; and there is always a separator character between tokens on separate lines.
; Also, when a line is read, the character pointer is always positioned ON the first
; character.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Line-Buffer, Line-Current-Char, Line-Current-Index, Line-Last-Index, Line-Number
;       Line-New-Line, Line-Advance-Char, Line-Past-End-P, Line-At-End-P
;       Make-Line

(defstruct Line "Line of input file to parse."
           (Buffer (make-string 0) :type string)
           (Current-Char #\Return :type character)
           (Current-Index 1 :type fixnum)
           (Last-Index 0 :type fixnum)
           (Number 0 :type fixnum))

(defun Line-Print (line)
  (format out-stream "~&~5D> ~A~%" (Line-Number line) (Line-Buffer Line))
  (format out-stream "~v@T^~%" (+ 7 (Line-Current-Index line))))

(defmacro Line-Clear (line)
  `(let ((l ,line))
     (setf (Line-Buffer l) (make-string 0)
           (Line-Current-Char l) #\Return
           (Line-Current-Index l) 1
           (Line-Last-Index l) 0
           (Line-Number l) 0)))

(defun Line-Current-Segment (line)
  "Buffer from current index to last index."
  (if (line-at-end-p line) (make-string 0)
      (subseq (Line-Buffer line)
              (Line-Current-Index line)
              (Line-Last-Index line))))

(defun Line-New-Line (string line &optional (linenum nil))
  "Sets string to be the next line stored in line."
  (setf (Line-Last-Index line) (1- (length string))
        (Line-Current-Index line) 0
        (Line-Current-Char line) (or (and (> (length string) 0) (elt string 0)) #\Return)
        (Line-Buffer line) string
        (Line-Number line) (or linenum (1+ (Line-Number line)))))

(defun Line-Advance-Char (line)
  (setf (Line-Current-Char line)
        (elt (Line-Buffer line) (incf (Line-Current-Index line)))))

(defun Line-Next-Char (line)
  (elt (Line-Buffer line) (1+ (Line-Current-Index line))))

(defun Line-Past-End-P (line)
  "Tests if line is empty or positioned past the last character."
  (> (line-current-index line) (line-last-index line)))

(defun Line-At-End-P (line)
  "Tests if line is empty or positioned past the last character."
  (>= (line-current-index line) (line-last-index line)))

; 1B. A Stack (of lines, tokens, or whatever)

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Make-Stack, Stack-Store, Stack-Size, Stack-Top, Stack-Load, Stack-Clear,
;       Stack-/-Empty, Stack-Push, Stack-Pop

(defstruct Stack                "A stack"
           (Store nil)          ; contents of the stack
           (Size 0)             ; number of elements in Store
           (Top nil)            ; first element of Store

           (Updated nil)        ; whether something has been pushed on the stack
                                ; since this flag was last set to NIL
)

(defun stack-load (list stack)
  (setf (stack-store stack) list
        (stack-size stack) (length list)
        (stack-top stack) (car list)))

(defun stack-clear (stack)
  (setf (stack-store stack) nil (stack-size stack) 0 (stack-top stack) nil
        (stack-updated stack) nil))

(defmacro stack-/-empty (stack) `(> (stack-size ,stack) 0))

(defun stack-push (x stack)
  (push x (stack-store stack))
  (setf (stack-top stack) x (stack-updated stack) t)
  (incf (stack-size stack))
  x)

(defun stack-pop (stack)
  (let ((y (pop (stack-store stack))))
    (decf (stack-size stack))
    (setf (stack-top stack) (if (stack-/-empty stack) (car (stack-store stack))))
    y))

; 1C. Token

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Make-Token, Token-Symbol, Token-Type, Token-Install, Token-Print

(defstruct Token
  "A token is a Symbol with a Type.
The type is either NUMBER, IDENTIFIER or SPECIAL-CHAR.
NonBlank is true if the token is not preceded by a blank."
  (Symbol nil)
  (Type nil)
  (NonBlank t))

(defparameter Prior-Token (make-token) "What did I see last")
(defparameter nonblank t "Is there no blank in front of the current token.")
(defparameter Current-Token (make-token) "Token at head of input stream.")
(defparameter Next-Token (make-token)    "Next token in input stream.")
(defparameter Valid-Tokens 0               "Number of tokens in buffer (0, 1 or 2)")

(defun Token-Install (symbol type token &optional (nonblank t))
  (setf (token-symbol token) symbol (token-type token) type
        (token-nonblank token) nonblank)
  token)

(defun Token-Print (token)
  (format out-stream "(token (symbol ~S) (type ~S))~%"
          (Token-Symbol token) (Token-Type token)))

; 1D. A Reduction
;

(defstruct (Reduction (:type list))
"A reduction of a rule is any S-Expression the rule chooses to stack."
  (Rule nil)            ; Name of rule
  (Value nil))

; 2. Recursive descent parsing support routines (semantically related to MetaLanguage)
;
; This section of the code contains:
;
;               A. Routines for stacking and retrieving reductions of rules.
;               B. Routines for applying certain metagrammatical elements
;                  of a production (e.g., Star).
;               C. Token-level parsing utilities (keywords, strings, identifiers).

; 2A. Routines for stacking and retrieving reductions of rules.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Push-Reduction Pop-Reduction

(defparameter Reduce-Stack (make-stack) "Stack of results of reduced productions.")

(defun Push-Reduction (rule redn)
  (stack-push (make-reduction :rule rule :value redn) Reduce-Stack))

(defun reduce-stack-show ()
  (let ((store (stack-store reduce-stack))
        (*print-pretty* t))
    (if store
        (progn (format t "~%Reduction stack contains:~%")
               (mapcar #'(lambda (x) (if (eq (type-of x) 'token)
                               #+Symbolics (zl:describe-defstruct x)
                               #-Symbolics (describe x)
                                         (print x)))
                       (stack-store reduce-stack)))
        (format t "~%There is nothing on the reduction stack.~%"))))

(defmacro reduce-stack-clear () `(stack-load nil reduce-stack))

(defun Pop-Reduction () (stack-pop Reduce-Stack))

#-:openmcl
(defmacro pop-stack-1 () '(reduction-value (Pop-Reduction)))
#+:openmcl
(defun pop-stack-1 () (reduction-value (Pop-Reduction)))

(defmacro pop-stack-2 ()
  `(let* ((top (Pop-Reduction)) (next (Pop-Reduction)))
     (stack-push top Reduce-Stack)
     (reduction-value next)))

(defmacro pop-stack-3 ()
  `(let* ((top (Pop-Reduction)) (next (Pop-Reduction)) (nnext (Pop-Reduction)))
     (stack-push next Reduce-Stack)
     (stack-push top Reduce-Stack)
     (reduction-value nnext)))

(defmacro pop-stack-4 ()
  `(let* ((top (Pop-Reduction))
          (next (Pop-Reduction))
          (nnext (Pop-Reduction))
          (nnnext (Pop-Reduction)))
     (stack-push nnext Reduce-Stack)
     (stack-push next Reduce-Stack)
     (stack-push top Reduce-Stack)
     (reduction-value nnnext)))

(defmacro nth-stack (x)
  `(reduction-value (nth (1- ,x) (stack-store Reduce-Stack))))

; 2B. Routines for applying certain metagrammatical elements
;     of a production (e.g., Star).

; Must means that if it is not present in the token stream, it is a syntax error.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Star, Bang, Must, Optional, Action, Sequence

(defmacro Star (lab prod)

"Succeeds if there are one or more of PROD, stacking as one unit
the sub-reductions of PROD and labelling them with LAB.
E.G., (Star IDs (parse-id)) with A B C will stack (3 IDs (A B C)),
where (parse-id) would stack (1 ID (A)) when applied once."

  `(prog ((oldstacksize (stack-size reduce-stack)))
         (if (not ,prod) ;(progn (format t "~&Star failed for ~A.~%" ',lab) (return nil)))
             (return nil))
    loop (if (not ,prod)
             (let* ((newstacksize (stack-size reduce-stack))
                    (number-of-new-reductions (- newstacksize oldstacksize)))
;              (format t "~&Starring ~A with ~D new reductions.~%"
;                      ',lab number-of-new-reductions)
               (if (> number-of-new-reductions 0)
                   (return (do ((i 0 (1+ i)) (accum nil))
                               ((= i number-of-new-reductions)
                                (Push-Reduction ',lab accum)
;                               (format t "~&Star accumulated ~D reductions.~%"
;                                       (length accum))
                                (return t))
                             (push (pop-stack-1) accum)))
                   (return t)))
             (go loop))))

(defmacro Bang (lab prod)

"If the execution of prod does not result in an increase in the size of
the stack, then stack a NIL. Return the value of prod."

  `(progn (setf (stack-updated reduce-stack) nil)
;         (format t "~&Banging ~A~:[~; and I think the stack is updated!~].~%" ',lab
;                 (stack-updated reduce-stack))
          (let* ((prodvalue ,prod)
                 (updated (stack-updated reduce-stack)))
;           (format t "~&Bang thinks that ~A ~:[didn't do anything~;did something~].~&"
;                   ',lab prodvalue)
            (if updated
                (progn ; (format t "~&Banged ~A and I think the stack is updated!~%" ',lab)
                       prodvalue)
                (progn (push-reduction ',lab nil)
                       ; (format t "~&Banged ~A.~%" ',lab)
                       prodvalue)))))

(defmacro must (dothis &optional (this-is nil) (in-rule nil))
  `(or ,dothis (meta-syntax-error ,this-is ,in-rule)))

; Optional means that if it is present in the token stream, that is a good thing,
; otherwise don't worry (like [ foo ] in BNF notation).

(defun Optional (dothis) (or dothis t))

; Action is something we do as a consequence of successful parsing; it is
; inserted at the end of the conjunction of requirements for a successful
; parse, and so should return T.

(defun action (dothis) (or dothis t))

; A sequence consists of a head, which if recognized implies that the
; tail must follow.   Following tail are actions, which
; are performed upon recognizing the head and tail.

#|
(defmacro sequence (subrules &optional (actions nil))
  `(and ,(pop subrules) . ,(append (mapcar #'(lambda (x) (list 'must x)) subrules)
                         (if actions `((progn . ,(append actions '(t))))))))
|#

; 3. Routines for handling lexical scanning
;
; Lexical scanning of tokens is performed off of the current line.  No
; token can span more than 1 line.  All real I/O is handled in a line-oriented
; fashion (in a slight paradox) below the character level.  All character
; routines implicitly assume the parameter Current-Line.  We do not make
; Current-Line an explicit optional parameter for reasons of efficiency.

(defparameter Current-Line (make-line)  "Current input line.")

(defmacro current-line-print () '(Line-Print Current-Line))

(defmacro current-line-show ()
  `(if (line-past-end-p current-line)
       (format t "~&The current line is empty.~%")
       (progn (format t "~&The current line is:~%~%")
              (current-line-print))))

(defmacro current-line-clear () `(Line-Clear Current-Line))

; 3A.  Manipulating the token stack and reading tokens

; This section is broken up into 3 levels:
;
;       (0) String grabbing:    Match String, Match Advance String
;       (1) Token handling:     Current Token, Next Token, Advance Token
;       (2) Character handling: Current Char, Next Char, Advance Char
;       (3) Line handling:      Next Line, Print Next Line
;       (X) Random Stuff

; A good test for lexing is:

(defmacro test-lexing ()
  '(with-open-file (in-stream "lisp>meta.meta" :direction :input)
    (with-open-file (out-stream "lisp>foo.pars" :direction :output :if-exists :supersede)
      (loop (let ((z (advance-token)))
              (if z (Token-Print z out-stream) (return nil)))))))

; 3A (0). String grabbing

; String grabbing is the art of matching initial segments of the current
; line, and removing them from the line before the get tokenized if they
; match (or removing the corresponding current tokens).

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Match-String, Match-Advance-String

(defun Match-String (x)
  "Returns length of X if X matches initial segment of inputstream."
  (unget-tokens)                        ; So we don't get out of synch with token stream
  (skip-blanks)
  (if (and (not (Line-Past-End-P Current-Line)) (Current-Char) )
      (initial-substring-p x
           (subseq (Line-Buffer Current-Line) (Line-Current-Index Current-Line)))))

(defun Match-Advance-String (x)
  "Same as MATCH-STRING except if successful, advance inputstream past X."
  (let ((y (if (>= (length (string x))
                   (length (string (quote-if-string (current-token)))))
               (Match-String x)
               nil))) ; must match at least the current token
    (if y (progn (incf (Line-Current-Index Current-Line) y)
                 (if (not (Line-Past-End-P Current-Line))
                     (setf (Line-Current-Char Current-Line)
                           (elt (Line-Buffer Current-Line)
                                (Line-Current-Index Current-Line)))
                     (setf (Line-Current-Char Current-Line) #\Space))
                 (setq prior-token
                       (make-token :Symbol (intern (string x))
                                   :Type 'identifier
                                   :nonBlank nonblank))
                 t))))

(defun initial-substring-p (part whole)
  "Returns length of part if part matches initial segment of whole."
  (let ((x (string-not-greaterp part whole)))
    (and x (= x (length part)) x)))

; 3A (1) Token Handling.

; Tokens are acquired from a stream of characters.  Lexical analysis is performed
; by the functiond Get Token.  One-token lookahead is maintained in variables
; Current-Token and Next-Token by procedures Current Token, Next Token, and
; Advance Token.  The functions Match Current Token and Match Next Token recognize
; classes of tokens, by type, or by type and symbol.  The current and next tokens
; can be shoved back on the input stream (to the current line) with Unget-Tokens.

(defmacro Defun-Parse-Token (token)
  `(defun ,(intern (concatenate 'string "PARSE-" (string token))) ()
     (let* ((tok (match-current-token ',token))
            (symbol (if tok (token-symbol tok))))
       (if tok (progn (Push-Reduction
                        ',(intern (concatenate 'string (string token)
                                               "-TOKEN"))
                        (copy-tree symbol))
                      (advance-token)
                      t)))))

(defun token-stack-show ()
  (if (= Valid-Tokens 0) (format t "~%There are no valid tokens.~%")
      (format t "~%The number of valid tokens is ~S.~%" Valid-Tokens))
  (if (> Valid-Tokens 0)
      (progn (format t "The current token is~%")
             #+Symbolics (zl:describe-defstruct current-token)
             #-Symbolics (describe current-token)
             ))
  (if (> Valid-Tokens 1)
      (progn (format t "The next token is~%")
             #+Symbolics (zl:describe-defstruct next-token)
             #-Symbolics (describe next-token)
             ))
  (if (token-type prior-token)
      (progn (format t "The prior token was~%")
             #+Symbolics (zl:describe-defstruct prior-token)
             #-Symbolics (describe prior-token)
             )))

(defmacro token-stack-clear ()
  `(progn (setq valid-tokens 0)
          (token-install nil nil current-token nil)
          (token-install nil nil next-token nil)
          (token-install nil nil prior-token nil)))

; Unget-Tokens

(defun quote-if-string (token)
  (if token   ;only use token-type on non-null tokens
  (case (token-type token)
    (bstring            (strconc "[" (token-symbol token) "]*"))
    (string             (strconc "'" (token-symbol token) "'"))
    (spadstring         (strconc "\"" (underscore (token-symbol token)) "\""))
    (number             (format nil "~v,'0D" (token-nonblank token)
                                (token-symbol token)))
    (special-char       (string (token-symbol token)))
    (identifier         (let ((id (symbol-name (token-symbol token)))
                              (pack (package-name (symbol-package
                                                   (token-symbol token)))))
                          (if (or $BOOT $SPAD)
                              (if (equal pack "BOOT")
                                  (escape-keywords (underscore id) (token-symbol token))
                                (concatenate 'string
                                             (underscore pack) "'" (underscore id)))
                            id)))
    (t                  (token-symbol token)))
   nil))

(defun escape-keywords (pname id)
  (if (member id keywords)
      (concatenate 'string "_" pname)
    pname))

(defun underscore (string)
  (if (every #'alpha-char-p string) string
    (let* ((size (length string))
           (out-string (make-array (* 2 size)
                                   :element-type 'character
                                   :fill-pointer 0))
           next-char)
      (dotimes (i size)
               (setq next-char (char string i))
               (if (not (alpha-char-p next-char))
                   (vector-push #\_ out-string))
               (vector-push next-char out-string))
      out-string)))

(defun Unget-Tokens ()
  (case Valid-Tokens
    (0 t)
    (1 (let* ((cursym (quote-if-string current-token))
              (curline (line-current-segment current-line))
              (revised-line (strconc cursym curline (copy-seq " "))))
         (line-new-line revised-line current-line (line-number current-line))
         (setq NonBlank (token-nonblank current-token))
         (setq Valid-Tokens 0)))
    (2 (let* ((cursym (quote-if-string current-token))
              (nextsym (quote-if-string next-token))
              (curline (line-current-segment current-line))
              (revised-line
                (strconc (if (token-nonblank current-token) "" " ")
                         cursym
                         (if (token-nonblank next-token) "" " ")
                         nextsym curline " ")))
         (setq NonBlank (token-nonblank current-token))
         (line-new-line revised-line current-line (line-number current-line))
         (setq Valid-Tokens 0)))
    (t (error "How many tokens do you think you have?"))))

; *** Match Token

(defun match-token (token type &optional (symbol nil))
  (if (and token (eq (token-type token) type))
      (if symbol (if (equal symbol (token-symbol token)) token) token)))

(defun match-current-token (type &optional (symbol nil))
  "Returns the current token if it has EQ type and (optionally) equal symbol."
  (match-token (current-token) type symbol))

(defun match-next-token (type &optional (symbol nil))
  "Returns the next token if it has equal type and (optionally) equal symbol."
  (match-token (next-token) type symbol))

; *** Current Token, Next Token, Advance Token

(defun try-get-token (token)
  (let ((tok (get-token token)))
    (if tok (progn (incf Valid-Tokens) token))))

(defun current-symbol () (make-symbol-of (current-token)))

(defun make-symbol-of (token)
  (let ((u (and token (token-symbol token))))
    (cond ((not u) nil)
          ((characterp u) (intern (string u)))
          (u))))

(defun current-token ()
  "Returns the current token getting a new one if necessary."
  (if (> Valid-Tokens 0)
      Current-Token
      (try-get-token Current-Token)))

(defun next-token ()
  "Returns the token after the current token, or NIL if there is none after."
  (current-token)
  (if (> Valid-Tokens 1)
      Next-Token
      (try-get-token Next-Token)))

(defun advance-token ()
  (current-token)                       ;don't know why this is needed
  "Makes the next token be the current token."
  (case Valid-Tokens
    (0 (try-get-token (Current-Token)))
    (1 (decf Valid-Tokens)
       (setq Prior-Token (copy-token Current-Token))
       (try-get-token Current-Token))
    (2 (setq Prior-Token (copy-token Current-Token))
       (setq Current-Token (copy-token Next-Token))
       (decf Valid-Tokens))))

(defparameter XTokenReader 'get-meta-token "Name of tokenizing function")

; *** Get Token

(defun get-token (token) (funcall XTokenReader token))

; 3A (2) Character handling.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Current-Char, Next-Char, Advance-Char

; *** Current Char, Next Char, Advance Char

(defun Current-Char ()
  "Returns the current character of the line, initially blank for an unread line."
  (if (Line-Past-End-P Current-Line) #\Return (Line-Current-Char Current-Line)))

(defun Next-Char ()
   "Returns the character after the current character, blank if at end of line.
The blank-at-end-of-line assumption is allowable because we assume that end-of-line
is a token separator, which blank is equivalent to."

  (if (Line-At-End-P Current-Line) #\Return (Line-Next-Char Current-Line)))

(defun Advance-Char ()
  "Advances IN-STREAM, invoking Next Line if necessary."
  (loop (cond ((not (Line-At-End-P Current-Line))
               (return (Line-Advance-Char Current-Line)))
              ((next-line in-stream)
               (return (current-char)))
              ((return nil)))))

; 3A 3. Line Handling.

; PARAMETERS DEFINED IN THIS SECTION:
;
;       Echo-Meta

; *** Next Line

(defparameter Echo-Meta nil                 "T if you want a listing of what has been read.")
(defparameter Line-Handler 'next-META-line "Who grabs lines for us.")

(defun next-line (&optional (in-stream t)) (funcall Line-Handler in-stream))

(defun make-string-adjustable (s)
  (cond ((adjustable-array-p s) s)
        (t (make-array (array-dimensions s) :element-type 'character
                       :adjustable t :initial-contents s))))

(defun get-a-line (stream)
  (if (IS-CONSOLE stream) (princ (MKPROMPT)))
  (let ((ll (read-a-line stream)))
    (if (stringp ll) (make-string-adjustable ll) ll)))

(defparameter Current-Fragment nil
  "A string containing remaining chars from readline; needed because
Symbolics read-line returns embedded newlines in a c-m-Y.")

(defun input-clear () (setq Current-Fragment nil))

#-:CCL
(defun read-a-line (&optional (stream t))
  (let (cp)
    (if (and Current-Fragment (> (length Current-Fragment) 0))
        (let ((line (with-input-from-string
                      (s Current-Fragment :index cp :start 0)
                      (read-line s nil nil))))
          (setq Current-Fragment (subseq Current-Fragment cp))
          line)
        (prog nil
              (if (stream-eof in-stream)
                  (progn (setq File-Closed t *EOF* t)
                         (Line-New-Line (make-string 0) Current-Line)
                         (return nil)))
              (if (setq Current-Fragment (read-line stream))
                  (return (read-a-line stream)))))))
#+:CCL
(defun read-a-line (&optional (stream t))
   (let ((line (read-line stream nil nil)))
      (if (null line)
           (progn (setq File-Closed t *EOF* t)
                  (Line-New-Line (make-string 0) Current-Line)
                   nil)
          line)))

; *** Print New Line

(defparameter Printer-Line-Stack (make-stack)
  "Stack of output listing lines waiting to print. [local to PRINT-NEW-LINE]")

(defparameter Read-Quietly nil
  "Whether or not to produce an output listing. [local to PRINT-NEW-LINE]")

(defun Print-New-Line (string &optional (strm *terminal-io*))
  "Makes output listings."
  (if Read-Quietly (stack-push (copy-tree string) Printer-Line-Stack)
      (progn (mapc #'(lambda (x) (format strm "; ~A~%" x) (terpri))
                   (nreverse (stack-store Printer-Line-Stack)))
             (stack-clear Printer-Line-Stack)
             (format strm "~&; ~A~%" string))))

; 3B. Error handling

(defparameter errcol nil)
(defparameter line nil)

(defparameter Meta_Errors_Occurred nil  "Did any errors occur")

(defparameter Meta_Error_Handler 'meta-meta-error-handler)

(defun meta-syntax-error (&optional (wanted nil) (parsing nil))
  (funcall Meta_Error_Handler wanted parsing))

; 3 C. Constructing parsing procedures

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Make-Parse-Function, GetGenSym

(MAKEPROP 'PROGN 'NARY T)       ; Setting for Make-Parse-Function

(defun make-parse-function (l op)
   (if (flagp op 'nary) (setq l (make-parse-func-flatten-1 l op nil)))
   (make-parse-function1 l op))

(defun make-parse-func-flatten (x op)
  (cond ((atom x) x)
        ((eq (car x) op) (cons op (make-parse-func-flatten-1 (cdr x) op nil)))
        (t (cons (make-parse-func-flatten (car x) op) (make-parse-func-flatten (cdr x) op)))))

(defun make-parse-func-flatten-1 (l op r)
  (let (x)
    (if (null l)
        r
        (make-parse-func-flatten-1
            (cdr l) op
            (append r (if (eqcar (setq x (make-parse-func-flatten (car l) op)) op)
                          (cdr x)
                          (list x)))))))

(defun make-parse-function1 (l op)
  (let (x)
    (case op
      (plus (cond ((eq 0 (setq x (length (setq l (s- l '(0 (zero))))))) 0)
                  ((eq 1 x) (car l))
                  (t `(+ . ,l))))
      (times (cond ((s* l '(0 (zero))) 0)
                   ((eq 0 (setq x (length (setq l (s- l '(1 (one))))))) 1)
                   ((eq 1 x) (car l))
                   (t `(times . ,l)) ))
      (quotient (cond ((> (length l) 2) (fail))
                      ((eq 0 (car l)) 0)
                      ((eq (cadr l) 1) (car l))
                      (t `(quotient . ,l)) ))
      (minus (cond ((cdr l) (fail))
                   ((numberp (setq x (car l))) (minus x))
                   ((eqcar x 'minus) (cadr x))
                   (t `(minus . ,l))  ))
      (- (cond ((> (length l) 2) (fail))
                        ((equal (car l) (cadr l)) '(zero))
                        ((member (car l) '(0 (zero))) (make-parse-function (cdr l) 'minus))
                        ((member (cadr l) '(0 (zero))) (car l))
                        ((eqcar (cadr l) 'minus)
                         (make-parse-function (list (car l) (cadadr l)) 'plus))
                        (t `(- . ,l)) ))
      (expt (cond ((> (length l) 2) (fail))
                  ((eq 0 (cadr l)) 1)
                  ((eq 1 (cadr l)) (car l))
                  ((member (car l) '(0 1 (zero) (one))) (car l))
                  (t `(expt . ,l)) ))
      (or (cond ((member 't l) ''t)
                ((eq 0 (setq x (length (setq l (delete nil l))))) nil)
                ((eq 1 x) (car l))
                (t `(or . ,l)) ))
      (|or| (cond ((member 't l) 't)
                  ((eq 0 (setq x (length (setq l (delete nil l))))) nil)
                  ((eq 1 x) (car l))
                  (t `(|or| . ,l)) ))
      (null (cond ((cdr l) (fail))
                  ((eqcar (car l) 'null) (cadar l))
                  ((eq (car l) 't) nil)
                  ((null (car l)) ''t)
                  (t `(null . ,l))))
      (|and| (cond ((eq 0 (setq x (length (setq l (delete 't (delete 'true l)))))) 't)
                   ((eq 1 x) (car l))
                   (t `(|and| . ,l)) ))
      (and (cond ((eq 0 (setq x (length (setq l (delete 't (delete 'true l)))))) ''t)
                 ((eq 1 x) (car l))
                 (t `(and . ,l)) ))
      (progn (cond ((and (not (atom l)) (null (last l)))
                    (cond ((cdr l) `(progn . ,l))
                          (t (car l))))
                   ((null (setq l (delete nil l))) nil)
                   ((cdr l) `(progn . ,l))
                   (t (car l)) ))
      (seq (cond ((eqcar (car l) 'exit) (cadar l))
                 ((cdr l) `(seq . ,l))
                 (t (car l))   ))
      (list (cond ((null l) nil) (t `(list . ,l))))
      (cons (cond ((cdr l) `(cons . ,l)) (t (car l)) ))
      (t (cons op l) ))))

(defparameter /genvarlst nil    "??")

(defun transpgvar (metapgvar) (remove-duplicates metapgvar))

(defparameter /gensymlist nil   "List of rule local variables generated by getgensym.")

(defun getgensym (n)
  "Used to create unique numerically indexed local variables for the use of rules."
  (loop
     (let ((m (length /gensymlist)))
       (if (< m n)
           (setq /gensymlist (nconc /gensymlist `(,(intern (format nil "G~D" (1+ m))))))
           (return (nth (1- n) /gensymlist))))))

;  4. Tracing routines

(defparameter debugmode 'yes "Can be either YES or NO")

(defun reduction-print (y rule)
  (format t "~&")
  (cond ((eq y t) (|sayBrightly| `(|%b| ,rule |%d| " reduced")))
        (y (|sayBrightlyNT| `(|%b| ,rule |%d|))
           (format t " reduced ~A~%" y)))
  y)

#+Symbolics
(defmacro rtrace (&rest rules)
  `(compiler-let () .
        ,(mapcar #'(lambda (x)
                    (let ((rule (intern (strconc "PARSE-" x))))
                      `(zl:advise ,rule :around nil nil
                               (reduction-print :do-it ',rule))))
                rules)))

#+Symbolics
(defmacro runtrace () `(zl:unadvise))

(defmacro tracemeta (&rest l) `(trmeta ',l))

(defparameter /depth 0 "Used in Debug.lisp.")

(defun trmeta (l) (setq /depth 0) (mapc #'trmeta1 l))

(defun trmeta1 (x)
  (let (y)
  (if (not (fboundp  x))
      (croak (format nil  "********* ~S MUST BE GIVEN PREFIX" x)))
  (/embed-1 x
   (sublislis
     (list (pname x) x (gensym))
     '(nam* fun* argl*)
     '(lambda (&rest argl*)
       (prog (v tok)
         (terpri)
         (trblanks (* 2 /depth))          (setq /depth (+ 1 /depth))
         (princ (stringimage /depth))  (princ "<")
         (princ nam*)              (trargprint argl*)   (princ "/")
         (princ "chr= ")           (prin1 (Current-Char))
         (princ "/tok= ")          (prin1 (setq tok (current-symbol)))
         (princ "/col= ")          (prin1 (line-current-index current-line))
 ;;      (princ "/icol= ")         (prin1 initcolumn)
         (cond ( (not nonblank) (go a1)))     (princ "/nblnk= T")
     a1  ;;(cond (ok (go b1)))               (princ "/ok= NIL")
     b1  ;;(cond ( (not stackx) (go c1)))   (princ "/stackx= ")
         ;;(prin1 stackx)
     c1  (cond ( (not (identp tok)) (go d1)))
         (princ "/isid= ")
        ;; (princ (cond (isid "T") (t "NIL")))
     d1  (princ "/stack= ")            (prin1 (stack-store reduce-stack))
         (setq v (apply fun* argl*))           (setq /depth (- /depth 1))
         (terpri)
         (trblanks (* 2 /depth))          (princ (stringimage (\1+ /depth)))
         (princ ">")                       (princ nam*)
         (princ "/chr= ")                  (prin1 (Current-Char))
         (princ "/tok= ")                  (prin1 (setq tok (current-symbol)))
         (princ "/col= ")            (prin1 (line-current-index current-line))
         (if (not nonblank) (go a2))          (princ "/nblnk= ")
         (princ (if nonblank "T" "NIL"))
     a2  ;;(if ok (go b2))                   (princ "/ok= ")          (prin1 ok)
     b2  ;;(if (not stackx) (go c2))        (princ "/stackx1= ")     (prin1 stackx)
     c2  (if (not (identp tok)) (go d2))
         (princ "/isid= ")
        ;; (princ (if isid "T" "NIL"))
     d2  (princ "/stack= ")            (prin1 (stack-store reduce-stack))
         (princ "/value= ")         (prin1 v)
         (return v)))))))

(defun /embed-1 (x y)
   (princ (strconc (pname x) " embedded"))
   (terpri)
   (/embed-q x y))

(defun /embed-q (x y)
   (setq /embednames (cons x /embednames))
   (embed x
          (cond ((eqcar y 'lambda) y)
                ((eqcar y 'before)
                 `(lambda ,(cadr y)
                    (prog2 ,(caddr y) ,(cons 'funcall (cons x (cadr y))))))
                ((eqcar y 'after)
                 `(lambda ,(cadr y)
                    (prog1 ,(cons 'funcall (cons x (cadr y))) ,(caddr y))))))
   (/embedreply))

(defun /embedreply ()
  (if (atom (embedded)) '(|none| |embedded|)
      (append (embedded) (list '|embedded|))))

(defun numofargs (fn) (numberofargs (car (/mdef (cons fn '(x))))))

(defparameter mdeftrace nil             "")

(defun /mdef (x)
  (let (u)
    (cond  ((atom x) x)
           ((or (null (atom (car x))) (not (mbpip (car x))))
            (mapcar #'/mdef x))
           ((equal x (setq u (mdef (car x) x))) x)
           (mdeftrace (print x) (princ " --> ") (print u) (/mdef u))
           ((/mdef u)))))

(defun trargprint (l) (mapc #'(lambda (x) (princ " / ") (prin1 x)) l))

(defun trblanks (n) (do ((i 1 (1+ i))) ((> i n)) (princ " ")))

;       5. Routines for inspecting and resetting total I/O system state
;
; The package largely assumes that:
;
;       A. One I/O stream pair is in effect at any moment.
;       B. There is a Current Line
;       C. There is a Current Token and a Next Token
;       D. There is a Reduction Stack
;
; This state may be examined and reset with the procedures IOSTAT and IOCLEAR.

(defun IOStat ()
  "Tell me what the current state of the parsing world is."
  ;(IOStreams-show)
  (current-line-show)
  (if (or $BOOT $SPAD) (next-lines-show))
  (token-stack-show)
  ;(reduce-stack-show)
  nil)

(defun IOClear (&optional (in t) (out t))
  ;(IOStreams-clear in out)
  (input-clear)
  (current-line-clear)
  (token-stack-clear)
  (reduce-stack-clear)
  (if (or $BOOT $SPAD) (next-lines-clear))
  nil)

;; auxiliary functions needed by the parser

(defun char-eq (x y) (char= (character x) (character y)))

(defun char-ne (x y) (char/= (character x) (character y)))

(Defun FLOATEXPID (X &aux S)
  (if (AND (IDENTP X) (char= (char-upcase (ELT (SETQ S (PNAME X)) 0)) #\E)
           (> (LENGTH S) 1)
           (SPADREDUCE AND 0 (COLLECT (STEP I 1 1 (MAXINDEX S))
                                      (DIGITP (ELT S I)))))
       (READ-FROM-STRING S t nil :start 1)
    NIL))

(defun |getToken| (x) (if (EQCAR x '|elt|) (third x) x))

(defun |dollarTran| (dom rand)
       (let ((eltWord (if |$InteractiveMode| '|$elt| '|elt|)))
         (if (and (not (atom rand)) (cdr rand))
             (cons (list eltWord dom (car rand)) (cdr rand))
             (list eltWord dom rand))))
