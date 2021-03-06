-- Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
--     - Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--
--     - Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in
--       the documentation and/or other materials provided with the
--       distribution.
--
--     - Neither the name of The Numerical ALgorithms Group Ltd. nor the
--       names of its contributors may be used to endorse or promote products
--       derived from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
-- IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
-- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
-- PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
-- LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


-- Scratchpad-II server

-- Assoc list of interpreter frame names and unique integer identifiers

SETANDFILEQ($frameAlist, nil)
SETANDFILEQ($frameNumber, 0)
SETANDFILEQ($currentFrameNum, 0)
SETANDFILEQ($EndServerSession, false)
SETANDFILEQ($NeedToSignalSessionManager, false)
SETANDFILEQ($sockBufferLength, 9217)

serverReadLine(stream) ==
-- used in place of read_-line in a scratchpad server system.
  FORCE_-OUTPUT()
  not $SpadServer => 
    read_-line(stream)
  IN_-STREAM: fluid := stream
  _*EOF_*: fluid := NIL
  line :=
   while not $EndServerSession and not _*EOF_* repeat
    if $NeedToSignalSessionManager then
      sockSendInt($SessionManager, $EndOfOutput)
    $NeedToSignalSessionManager := false
    action := serverSwitch()
    action = $CallInterp =>
      l := read_-line(stream)
      $NeedToSignalSessionManager := true
      return l
    action = $CreateFrame =>
      frameName := GENTEMP('"frame")
      addNewInterpreterFrame(frameName)
      $frameAlist := [[$frameNumber,:frameName], :$frameAlist]
      $currentFrameNum := $frameNumber
      sockSendInt($SessionManager, $CreateFrameAnswer)
      sockSendInt($SessionManager, $frameNumber)
      $frameNumber := $frameNumber + 1
--  MRX I'm not sure whether I should call ioHook("startPrompt")/ioHook("endOfPrompt") here
      sockSendString($SessionManager, MKPROMPT())
    action = $SwitchFrames =>
      $currentFrameNum := sockGetInt($SessionManager)
      currentFrame := LASSOC($currentFrameNum, $frameAlist)
      changeToNamedInterpreterFrame currentFrame
    action = $EndSession =>
      $EndServerSession := true
    action = $LispCommand =>
      $NeedToSignalSessionManager := true
      stringBuf := sockGetStringFrom($MenuServer)
      form := unescapeStringsInForm READ_-FROM_-STRING stringBuf
      protectedEVAL form
    action = $QuietSpadCommand =>
      $NeedToSignalSessionManager := true
      executeQuietCommand()
    action = $SpadCommand =>
      $NeedToSignalSessionManager := true
      stringBuf := sockGetStringFrom($MenuServer)
      CATCH('coerceFailure,CATCH('top__level, CATCH('SPAD__READER,
        parseAndInterpret stringBuf)))
--  MRX I'm not sure whether I should call ioHook("startPrompt")/ioHook("endOfPrompt") here
      princPrompt()
      FINISH_-OUTPUT()
    action = $NonSmanSession =>
      $SpadServer := nil
    action = $KillLispSystem => 
      QUIT()
    NIL
  line => line
  ""

parseAndInterpret str ==
  $InteractiveMode :fluid := true
  $BOOT: fluid := NIL
  $SPAD: fluid := true
  $e:fluid := $InteractiveFrame
  $useNewParser =>
    ncParseAndInterpretString str
  oldParseAndInterpret str

oldParseAndInterpret str ==
  tree := string2SpadTree str
  tree => processInteractive(parseTransform postTransform tree, NIL)
  NIL

executeQuietCommand() ==
  $QuietCommand: fluid := true
  sockGetStringFrom($MenuServer)
  CATCH('coerceFailure,CATCH('top__level, CATCH('SPAD__READER,
    parseAndInterpret stringBuf)))

parseAndEvalToHypertex str ==
  lines := parseAndEvalToStringForHypertex str
  len := LENGTH lines
  sockSendInt($MenuServer, len)
  for s in lines repeat
    sockSendString($MenuServer, s)

parseAndEvalToString str ==
  $collectOutput:local := true
  $outputLines: local := nil
  $IOindex: local := nil
  v := CATCH('SPAD__READER, CATCH('top__level, parseAndEvalStr str))
  v = 'restart => ['"error"]
  NREVERSE $outputLines

parseAndEvalToStringForHypertex str ==
  $collectOutput:local := true
  $outputLines: local := nil
  v := CATCH('SPAD__READER, CATCH('top__level, parseAndEvalStr str))
  v = 'restart => ['"error"]
  NREVERSE $outputLines

parseAndEvalToStringEqNum str ==
  $collectOutput:local := true
  $outputLines: local := nil
  v := CATCH('SPAD__READER, CATCH('top__level, parseAndEvalStr str))
  v = 'restart => ['"error"]
  NREVERSE $outputLines

parseAndInterpToString str ==
  v := applyWithOutputToString('parseAndEvalStr, [str])
  breakIntoLines CDR v

parseAndEvalStr string ==
  $InteractiveMode :fluid := true
  $BOOT: fluid := NIL
  $SPAD: fluid := true
  $e:fluid := $InteractiveFrame
  parseAndEvalStr1 string

parseAndEvalStr1 string ==
  string.0 = char '")" =>
    doSystemCommand SUBSEQ(string, 1)
  processInteractive(ncParseFromString string, NIL)

protectedEVAL x ==
  error := true
  val := NIL
  UNWIND_-PROTECT((val := EVAL x; error := NIL),
                   error => (resetStackLimits(); sendHTErrorSignal()))
  val
