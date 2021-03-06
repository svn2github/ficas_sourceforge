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


; NAME:    Boot Package
; PURPOSE: Provide forward references to Boot Code for functions to be at
;          defined at the boot level, but which must be accessible
;          not defined at lower levels.

(in-package "BOOT")

(defmacro def-boot-fun (f args where)
   `(eval-when (:compile-toplevel :load-toplevel :execute)
     (defun ,f ,args ,where (print (list ',f . ,args)))
     (export '(,f) "BOOT")))

(defmacro def-boot-var (p where)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (defparameter ,p nil ,where)
     (export '(,p) "BOOT")))

(defmacro def-boot-val (p val where)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (defparameter ,p ,val ,where)
     (export '(,p) "BOOT")))

(def-boot-fun |initializeSetVariables| (arg) "early temp def")
(def-boot-fun |updateSourceFiles| (x) "temp def")
#-:CCL
(def-boot-val |$timerTicksPerSecond| INTERNAL-TIME-UNITS-PER-SECOND
    "for TEMPUS-FUGIT and $TOTAL-ELAPSED-TIME")
#+:CCL
(def-boot-val |$timerTicksPerSecond| 1000
    "for TEMPUS-FUGIT and $TOTAL-ELAPSED-TIME")
(def-boot-val $boxString
  (concatenate 'string (list (code-char #x1d) (code-char #xe2)))
  "this string of 2 chars displays as a box")
(def-boot-val |$quadSymbol| $boxString "displays an APL quad")
(def-boot-val |$quadSym| '|$quadSym| "unbound symbol referenced in format.boot")
(def-boot-val $escapeString  (string (code-char 27))
   "string for single escape character")
(def-boot-val |$boldString| (concatenate 'string $escapeString "[12m")
  "switch into bold font")
(def-boot-val |$normalString| (concatenate 'string $escapeString "[0;10m")
  "switch back into normal font")
(def-boot-val $COMPILE t  "checked in COMP-2 to skip compilation")
(def-boot-var |$abbreviationTable|                  "???")
(def-boot-val |$algebraList|
        '(|QuotientField| |Polynomial|
          |UnivariatePoly|
          |MultivariatePolynomial|
          |DistributedMultivariatePolynomial|
          |HomogeneousDistributedMultivariatePolynomial|
          |Gaussian| |SquareMatrix|
          |RectangularMatrix|)                  "???")
(def-boot-val |$BasicDomains|
          '(|Integer| |Float| |Symbol|
            |Boolean| |String|)                 "???")
(def-boot-val |$BasicPredicates|
          '(FIXP STRINGP FLOATP)                "???")
(def-boot-val |$BFtag| '-BF-       "big float marker")
(def-boot-val |$BigFloat| '(|Float|)                "???")
(def-boot-val |$BigFloatOpt| '(|BigFloat| . OPT)    "???")
(def-boot-val |$Boolean| '(|Boolean|)               "???")
(def-boot-val |$BooleanOpt| '(|Boolean| . OPT)      "???")
(def-boot-val |$bootStrapMode| ()  "if T compCapsule skips body")
(def-boot-val |$bootstrapDomains| () "bootstrap Domains")
(def-boot-fun |bootUnionPrint| (x s tt)             "Interpreter>Coerce.boot")
(def-boot-fun |break| (msg)                         "Interpreter>Trace.boot")
(def-boot-fun |breaklet| (fn vars)                  "Interpreter>Trace.boot")
(def-boot-var |$brightenCommentsFlag|               "???")
(def-boot-var |$brightenCommentsIfTrue|             "???")
(def-boot-val |$BreakMode| '|query|                 "error.boot")
(def-boot-var |$cacheAlist|                         "Interpreter>System.boot")
(def-boot-val |$cacheCount| 0                       "???")
(def-boot-val |$Category| '(|Category|)             "???")
;  modemap:==  ( <map> (p e) (p e) ... (p e) )
;  modemaplist:= ( modemap ... )

(def-boot-val |$CategoryFrame|
          '((((|Category| . ((|modemap| (((|Category|) (|Category|)) (T *)))))
              (|Join| . ((|modemap|
      (((|Category|) (|Category|) (|Category|) (|Category|)) (T *))
      (((|Category|) (|Category|) (|List| |Category|)) (|Category|)) (T *))
        )))))
        "Compiler>CUtil.boot")
(def-boot-val |$CategoryNames|
        '(|Category| |CATEGORY| |RecordCategory| |Join|
          |StringCategory| |SubsetCategory| |UnionCategory|)
        "???")
(def-boot-val |$clamList|
          '((|getModemapsFromDatabase| |hash| UEQUAL |count|)
            (|getOperationAlistFromLisplib| |hash| UEQUAL |count|)
            (|getFileProperty| |hash| UEQUAL |count|)
            (|canCoerceFrom| |hash| UEQUAL |count|)
            (|selectMms1| |hash| UEQUAL |count|)
            (|coerceMmSelection| |hash| UEQUAL |count|)
            (|isValidType| |hash| UEQUAL |count|))
                                                "Interpreter>Clammed.boot")

(def-boot-var |$compCount|                          "???")
(def-boot-var |$compileMapFlag|                     "Interpreter>SetVars.boot")
(def-boot-var |$compUniquelyIfTrue|                 "Compiler>Compiler.boot")
(def-boot-val |$ConstructorCache| (MAKE-HASHTABLE 'ID)  "???")
(def-boot-var |$constructorsNotInDatabase|          "Interpreter>Database.boot")
(def-boot-var |$createUpdateFiles|                  "Interpreter>SetVarT.boot")
(def-boot-var |$croakIfTrue|                        "See moan in U.")
(def-boot-var |$currentFunction|                    "???")
(def-boot-val |$currentLine|    ""          "current input line for history")
(def-boot-val $delay 0                              "???")
(def-boot-var $Directory                            "???")
(def-boot-var $DISPLAY                              "???")
(def-boot-val |$Domain| '(|Domain|)                 "???")
(def-boot-var |$DomainFrame|                        "???")
(def-boot-val |$DomainNames|
        '(|Integer| |Float| |Symbol| |Boolean|
          |String| |Expression|
          |Mapping| |SubDomain| |List| |Union|
          |Record| |Vector|)                    "???")
(def-boot-val |$DomainsInScope| '(NIL)              "???")
(def-boot-val |$domainTraceNameAssoc| ()    "association list of trace domains")
(def-boot-val |$DomainVariableList|
  '($1 $2 $3 $4 $5 $6 $7 $8 $9 $10 $11
       $12 $13 $14 $15)                         "???")
(def-boot-val |$DoubleQuote| "\""                   "???")
(def-boot-val |$DummyFunctorNames|
          '(|Boolean| |Mapping|)                "???")
(def-boot-var |$eltIfNil|                           "SpecialFunctions>PSpad.boot")
(def-boot-val |$EmptyEnvironment| '((NIL))          "???")
(def-boot-val |$EmptyList| ()                       "???")
(def-boot-val |$EmptyMode| '|$EmptyMode|    "compiler constant")
(def-boot-val |$EM| |$EmptyMode|                    "???")
(def-boot-val |$EmptyString| ""                     "???")
(def-boot-val |$EmptyVector| '#()                    "???")
(def-boot-val |$Expression| '(|Expression|)         "???")
(def-boot-val |$ExpressionOpt|
          '(|Expression| . OPT)                 "???")
(def-boot-var |$evalDomain|                         "???")
(def-boot-val |$Exit| '(Exit)         "compiler constant")
(def-boot-var |$exitMode|                           "???")
(def-boot-var |$exitModeStack|                      "???")
(def-boot-val |$failure| (GENSYM)           "Symbol denoting a failed operation.")
(def-boot-val |$false| NIL                          "???")
(def-boot-val |$Float| '(|Float|)                   "???")
(def-boot-val |$FloatOpt| '(|Float| . OPT)          "???")
(def-boot-val |$FontTable| '(|FontTable|)           "???")
(def-boot-var |$forceDatabaseUpdate|                "See load function.")
(def-boot-var |$form|                               "???")
(def-boot-val |$FormalMapVariableList|
  '(\#1 \#2 \#3 \#4 \#5 \#6 \#7 \#8 \#9
    \#10 \#11 \#12 \#13 \#14 \#15)              "???")
(def-boot-val |$FormalMapVariableList2|
  '(\#\#1 \#\#2 \#\#3 \#\#4 \#\#5 \#\#6 \#\#7 \#\#8 \#\#9
    \#\#10 \#\#11 \#\#12 \#\#13 \#\#14 \#\#15)              "???")
(def-boot-var |$fromSpadTrace|                      "Interpreter>Trace.boot")
(def-boot-var $function                             "Interpreter>System.boot")
(def-boot-var $FunName                              "???")
(def-boot-var $FunName_Tail                         "???")
(def-boot-val |$ConstructorNames|
        '(|SubDomain| |List| |Union| |Record| |Vector|)
        "Used in isFunctor test, and compDefine.")
(def-boot-val |$gauss01| '(|gauss| 0 1)             "???")
(def-boot-var |$genFVar|                            "???")
(def-boot-val |$genSDVar| 0         "counter for genSomeVariable" )
(def-boot-val |$hasCategoryTable| (MAKE-HASHTABLE 'UEQUAL) "???")
(def-boot-var |$hasYield|                           "???")
(def-boot-var |$ignoreCommentsIfTrue|               "???")
(def-boot-var |$Index|                              "???")
(def-boot-val |$InitialDomainsInScope|
          '((|Boolean|) |$EmptyMode| |$NoValueMode|)
          "???")
(def-boot-val |$InitialModemapFrame| '((NIL))       "???")
(def-boot-var |$inLispVM|                           "Interpreter>Eval.boot")
(def-boot-var |$insideCapsuleFunctionIfTrue|        "???")
(def-boot-var |$insideCategoryIfTrue|               "???")
(def-boot-var |$insideCoerceInteractiveHardIfTrue|  "???")
(def-boot-val |$insideCompTypeOf| NIL  "checked in comp3")
(def-boot-val |$insideConstructIfTrue| NIL "checked in parse.boot")
(def-boot-var |$insideExpressionIfTrue|             "???")
(def-boot-var |$insideFunctorIfTrue|                "???")
(def-boot-var |$insideWhereIfTrue|                  "???")
(def-boot-val |$instantRecord| (MAKE-HASHTABLE 'ID) "???")
(def-boot-val |$Integer| '(|Integer|)               "???")
(def-boot-val |$IntegerOpt| '(|Integer| . OPT)      "???")
(def-boot-val |$InteractiveFrame| '((NIL))          "top level environment")
(def-boot-var |$InteractiveMode|                    "Interactive>System.boot")
(def-boot-val |$InteractiveModemapFrame| '((NIL))   "???")
(def-boot-var |$InteractiveTimingStatsIfTrue|       "???")
(def-boot-var |$LastCxArg|                          "???")
(def-boot-val $lastprefix "S-"                      "???")
(def-boot-val |$lastUntraced| NIL      "Used for )restore option of )trace.")
(def-boot-var |$leaveLevelStack|                    "???")
(def-boot-var |$leaveMode|                          "???")
(def-boot-val |$leftPren| "("                       "For use in SAY expressions.")
(def-boot-val |$letAssoc| NIL       "Used for trace of assignments in SPAD code.")
(def-boot-var |$libFile|                            "Compiler>LispLib.boot")
(def-boot-var $LINENUMBER                           "???")
(def-boot-var $linestack                            "???")
(def-boot-val |$Lisp| '(|Lisp|)                     "???")
(def-boot-val $LISPLIB nil                  "whether to produce a lisplib or not")
(def-boot-var |$lisplibDependentCategories|         "Compiler>LispLib.boot")
(def-boot-var |$lisplibDomainDependents|            "Compiler>LispLib.boot")
(def-boot-var |$lisplibForm|                        "Compiler>LispLib.boot")
(def-boot-var |$lisplibKind|                        "Compiler>LispLib.boot")
(def-boot-var |$lisplibModemapAlist|                "Compiler>LispLib.boot")
(def-boot-var |$lisplibModemap|                     "Compiler>LispLib.boot")
(def-boot-var |$lisplibOperationAlist|              "Compiler>LispLib.boot")
(def-boot-var |$lisplibSignatureAlist|              "Compiler>LispLib.boot")
(def-boot-var |$lisplibVariableAlist|               "Compiler>LispLib.boot")
(def-boot-val |$LocalFrame| '((NIL))                "???")
(def-boot-var |$mapSubNameAlist|                    "Interpreter>Trace.boot")
(def-boot-var |$mathTrace|                          "Interpreter>Trace.boot")
(def-boot-var |$mathTraceList|              "Controls mathprint output for )trace.")
(def-boot-var $maxlinenumber                        "???")
(def-boot-val |$Mode| '(Mode)      "compiler constant")
(def-boot-var |$ModemapFrame|                       "???")
(def-boot-val |$ModeVariableList|
  '(&1 &2 &3 &4 &5 &6 &7 &8 &9 &10 &11
       &12 &13 &14 &15)                         "???")
(def-boot-var |$mostRecentOpAlist|                  "???")
(def-boot-var $NBOOT                                "???")
(def-boot-val |$NegativeIntegerOpt| '(|NegativeInteger| . OPT) "???")
(def-boot-val |$NegativeInteger| '(|NegativeInteger|) "???")
(def-boot-val |$NETail| (CONS |$EmptyEnvironment| NIL) "???")
(def-boot-var $NEWLINSTACK                          "???")
(def-boot-var |$noEnv|                              "???")
(def-boot-val |$NonMentionableDomainNames| '($ |Rep| |Mapping|) "???")
(def-boot-val |$NonNegativeIntegerOpt| '(|NonNegativeInteger| . OPT) "???")
(def-boot-val |$NonNegativeInteger| '(|NonNegativeInteger|) "???")
(def-boot-val |$NonPositiveIntegerOpt| '(|NonPositiveInteger| . OPT) "???")
(def-boot-val |$NonPositiveInteger| '(|NonPositiveInteger|) "???")
(def-boot-var |$noParseCommands|                    "???")
(def-boot-val |$NoValueMode| '|$NoValueMode|   "compiler literal")
(def-boot-val |$NoValue| '|$NoValue|   "compiler literal")
(def-boot-val $num_of_meta_errors 0                 "Number of errors seen so far")
(def-boot-var $OLDLINE                              "Used to output command lines.")
(def-boot-val |$oldTime| 0                          "???")
(def-boot-val |$One| '(|One|)                       "???")
(def-boot-val |$OneCoef| '(1 1 . 1)                 "???")
(def-boot-val |$operationNameList| NIL           "op names for apropos")
(def-boot-var |$opFilter|                           "Used to /s a function")
(def-boot-var |OptionList|                          "???")
(def-boot-val |$optionAlist| nil       "info for trace boot")
(def-boot-var |$OutsideStringIfTrue|                "???")
(def-boot-val |$PatternVariableList|
  '(*1 *2 *3 *4 *5 *6 *7 *8 *9 *10 *11
       *12 *13 *14 *15)                         "???")
(def-boot-var |$PolyMode|                           "???")
(def-boot-val |$Polvar| '(WRAPPED . ((1 . 1)))      "???")
(def-boot-var |$polyDefaultAssoc|                   "???")
(def-boot-val |$PolyDomains|
        '(|Polynomial| |MultivariatePolynomial|
          |UnivariatePoly|
          |DistributedMultivariatePolynomial|
          |HomogeneousDistributedMultivariatePolynomial|)
        "???")
(def-boot-val |$PositiveIntegerOpt| '(|PositiveInteger| . OPT) "???")
(def-boot-val |$PositiveInteger| '(|PositiveInteger|) "???")
(def-boot-var |$postStack|                          "???")
(def-boot-var |$prefix|                             "???")
(def-boot-val |$PrettyPrint| nil "if t generated code is prettyprinted")
(def-boot-var |$previousTime|                       "???")
(def-boot-val |$PrimitiveDomainNames| nil
"Used in mkCategory to avoid generating vector slot
for primitive domains.  Also used by putInLocalDomainReferences and optCal.")
(def-boot-val |$optimizableDomainNames|
      '(|FactoredForm| |List| |Vector|
        |Integer| |NonNegativeInteger| |PositiveInteger|
        |SmallInteger| |String| |Boolean| |Symbol| |BooleanFunctions|)
   "used in optCall to decide which domains can be optimized")
(def-boot-val |$PrintBox| '(|PrintBox|)             "???")
(def-boot-var |$PrintCompilerMessagesIfTrue|        "???")
(def-boot-val |$printConStats| nil  "display constructor cache totals")
(def-boot-val |$printLoadMsgs|  '|on|          "Interpreter>SetVarT.boot")
(def-boot-var |$PrintOnly|                          "Compiler>LispLib.boot")
(def-boot-val |$UserSynonyms| ()    "list of user defined synonyms")
(def-boot-val |$SystemSynonyms| () "list of system defined synonyms")
(def-boot-val |$QuickCode| NIL      "Controls generation of QREFELT, etc.")
(def-boot-val |$QuickLet| NIL       "Set to T for no LET tracing.")
(def-boot-var |$QuietIfNil|                         "???")
(def-boot-val |$RationalNumberOpt| '(|RationalNumber| . OPT) "???")
(def-boot-val |$RationalNumber| '(|RationalNumber|) "???")
(def-boot-var |$readingFile|                        "???")
(def-boot-val |$report3| nil     "addMap report info")
(def-boot-var |$reportBottomUpFlag|                 "Interpreter>SetVarT.boot")
(def-boot-var |$reportCoerce|                       "???")
(def-boot-var |$reportCoerceIfTrue|                 "???")
(def-boot-var |$reportCompilation|                  "???")
(def-boot-var |$reportExitModeStack|                "???")
(def-boot-var |$reportFlag|                         "Interpreter>SetVars.boot")
(def-boot-val |$reportSpadTrace| ()    "report list of traced functions")
(def-boot-var |$resolveFlag|                        "Interpreter>SetVars.boot")
(def-boot-var |$returnMode|                         "???")
(def-boot-val |$rightPren| ")"                      "???")
(def-boot-var |$scanModeFlag|                       "???")
(def-boot-var |$semanticErrorStack|                 "???")
(def-boot-val |$SetFunctions| nil  "checked in SetFunctionSlots")
(def-boot-val |$SideEffectFreeFunctionList|
  '(|null| |case| |Zero| |One| \: \:\: |has| |Mapping|
    |elt| = \> \>= \< \<= MEMBER |is| |isnt| ATOM
    $= $\> $\>= $\< $\<= $^= $MEMBER)           "???")
(def-boot-var |$slamFlag|                           "Interpreter>SetVars.boot")
(def-boot-val |$SmallInteger| '(|SmallInteger|)     "???")
(def-boot-val |$SmallIntegerOpt| '(|SmallInteger| . OPT) "???")
(def-boot-val |$sourceFileTypes|
          '(SPAD BOOT LISP LISP370 META)
          "Interpreter>System.boot")
(def-boot-val $SPAD nil                             "Is this Spad code?")
(def-boot-var $SPAD_ERRORS                          "???")
(def-boot-val |$spadLibFT| 'LISPLIB                 "???")
(def-boot-var |$spadSystemDisks|                    "Interpreter>Database.boot")
(def-boot-val |$SpecialDomainNames|
  '(|add| |CAPSULE| |SubDomain| |List| |Union| |Record| |Vector|)
  "Used in isDomainForm, addEmptyCapsuleIfnecessary.")
(def-boot-var |$streamAlist|                        "???")
(def-boot-val |$streamCount| 0                      "???")
(def-boot-var |$streamIndexing|                     "???")
(def-boot-val |$StreamIndex| 0                      "???")
(def-boot-val |$StringCategory| '(|StringCategory|) "???")
(def-boot-val |$StringOpt| '(|String| . OPT)        "???")
(def-boot-val |$String| '(|String|)                 "???")
(def-boot-var |$suffix|                             "???")
(def-boot-val |$Symbol| '(|Symbol|)                 "???")
(def-boot-val |$SymbolOpt| '(|Symbol| . OPT)        "???")
(def-boot-var |$systemCommands|                     "Interpreter>System.boot")
(def-boot-val |$systemCreation| (currenttime)       "???")
(def-boot-val |$systemLastChanged|
          |$systemCreation|                     "???")
(def-boot-val |$tempCategoryTable| (MAKE-HASHTABLE 'UEQUAL) "???")
(def-boot-val |$ThrowAwayMode| '|$ThrowAwayMode|    "interp constant")
(def-boot-val |$timerOn| t                          "???")
(def-boot-var |$topOp|                             "See displayPreCompilationErrors")
(def-boot-var |$tokenCommands|                      "???")
(def-boot-var $TOKSTACK                             "???")
(def-boot-val $TOP_LEVEL t                          "???")
(def-boot-var $top_stack                            "???")
(def-boot-var |$tracedModemap|                      "Interpreter>Trace.boot")
(def-boot-val |$traceDomains| t                      "enables domain tracing")
(def-boot-val |$TraceFlag| t                        "???")
(def-boot-var |$tracedSpadModemap|                  "Interpreter>Trace.boot")
(def-boot-var |$traceletFunctions|                  "???")
(def-boot-var |$traceNoisely|                       "Interpreter>Trace.boot")
(def-boot-var |$TranslateOnly|                      "???")
(def-boot-var |$tripleCache|                        "Compiler>Compiler.boot")
(def-boot-val |$true| ''T                           "???")
(def-boot-var $Type                                 "???")
(def-boot-val |$underDomainAlist|
        '((|DistributedMultivariatePolynomial| . 2)
          (|FactoredForm| . 1)
          (|FactoredRing| . 1)
          (|Gaussian| . 1)
          (|List| . 1)
          (|Matrix| . 1)
          (|MultivariatePolynomial| . 2)
          (|HomogeneousDistributedMultivariatePolynomial| . 2)
          (|Polynomial| . 1)
          (|QuotientField| . 1)
          (|RectangularMatrix| . 3)
          (|SquareMatrix| . 2)
          (|UnivariatePoly| . 2)
          (|Vector| . 1)
          (|VVectorSpace| . 2))                 "???")

(def-boot-val |$updateCatTableIfTrue| T    "update category table on load")
(def-boot-var |$updateIfTrue|
          "Should SPAD databases be updated&squeezed?")
(def-boot-val |$useBFasDefault| T
          "Determines whether to use BF as default floating point type.")
(def-boot-val |$useDCQnotLET| () "checked in DEF-LET for use of DCQ")
(def-boot-fun BUMPCOMPERRORCOUNT ()                 "errorSupervisor1")
(def-boot-var |$VariableCount|                      "???")
(def-boot-val |$Void| '(|Void|) "compiler constant")
(def-boot-var |$warningStack|                       "???")
(def-boot-val |$whereList| () "referenced in format boot formDecl2String")
(def-boot-var |$xCount|                             "???")
(def-boot-var |$xeditIsConsole|                     "???")
(def-boot-var |$xyCurrent|                          "???")
(def-boot-var |$xyInitial|                          "???")
(def-boot-var |$xyMax|                              "???")
(def-boot-var |$xyMin|                              "???")
(def-boot-var |$xyStack|                            "???")
(def-boot-val |$Zero| '(|Zero|)                     "???")

(def-boot-val |$domainsWithUnderDomains|
          (mapcar #'car |$underDomainAlist|)    "???")
(def-boot-val |$inputPromptType| '|step|  "checked in MKPROMPT")
(def-boot-val |$IOindex| 0                 "step counter")

