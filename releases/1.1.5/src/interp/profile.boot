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

)package "BOOT"

--$profileCompiler := true
$profileAlist := nil

profileWrite() ==  --called from finalizeLisplib
  outStream := MAKE_-OUTSTREAM CONCAT(LIBSTREAM_-DIRNAME $libFile,'"/info")
  -- logically _*PRINT_-PRETTY_* should be local, but Common Lisp
  -- forces us to omit it.
  _*PRINT_-PRETTY_* := 'T
  PRINT_-FULL(profileTran $profileAlist,outStream)
  SHUT outStream

profileTran alist ==
  $profileHash := MAKE_-HASH_-TABLE()
  for [opSig,:info] in alist repeat
    op := opOf opSig
    sig := KAR KDR opSig
    HPUT($profileHash,op,[[sig,:info],:HGET($profileHash,op)])
  [[key,:HGET($profileHash,key)] for key in mySort HKEYS $profileHash]

profileRecord(label,name,info) ==  --name: info is var: type or op: sig
--$profileAlist is ((op . alist1) ...) where
--  alist1      is ((label . alist2) ...) where
--    alist2    is ((name . info) ...)
  if $insideCapsuleFunctionIfTrue then
    op := $op
    argl := CDR $form
    opSig := [$op,$signatureOfForm]
  else
    op := 'constructor
    argl := nil
    opSig := [op]
  if label = 'locals and MEMQ(name,argl) then label := 'arguments
  alist1        := LASSOC(opSig,$profileAlist)
  alist2        := LASSOC(label,alist1)
  newAlist2     := insertAlist(name,info,alist2)
  newAlist1     := insertAlist(label,newAlist2,alist1)
  $profileAlist := insertAlist(opSig,newAlist1,$profileAlist)
  $profileAlist

profileDisplay() ==
  profileDisplayOp('constructor,LASSOC('constructor,$profileAlist) )
  for [op,:alist1] in $profileAlist | op ~= 'constructor repeat
    profileDisplayOp(op,alist1)

profileDisplayOp(op,alist1) ==
  sayBrightly op
  if LASSOC('arguments,alist1) then
    sayBrightly '"  arguments"
    for [x,:t] in MSORT LASSOC('arguments,alist1) repeat
      sayBrightly concat('"     ",x,": ",prefix2String t)
  if LASSOC('locals,alist1) then
    sayBrightly '"  locals"
    for [x,:t] in MSORT LASSOC('locals,alist1) repeat
      sayBrightly concat('"     ",x,": ",prefix2String t)
  for [con,:alist2] in alist1 | not MEMQ(con,'(locals arguments)) repeat
    sayBrightly concat('"  ",prefix2String con)
    for [op1,:sig] in MSORT alist2 repeat
      sayBrightly ['"    ",:formatOpSignature(op1,sig)]
