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

-- Dequeue functions

-- dqUnit makes a unit dq i.e. a dq with one item, from the item

-- dqUnitCopy copies a unit dq

-- dqAppend appends 2 dq's, destroying the first

-- dqConcat concatenates a list of dq's, destroying all but the last

-- dqToList transforms a dq to a list

dqUnit s==(a:=[s];CONS(a,a))

dqUnitCopy s== dqUnit(CAAR s)

dqAppend(x,y)==
    if null x
    then y
    else if null y
         then x
         else
              RPLACD (CDR x,CAR y)
              RPLACD (x,    CDR y)
              x

dqConcat ld==
    if null ld
    then nil
    else if null rest ld
         then first ld
         else dqAppend(first ld,dqConcat rest ld)

dqToList s==if null s then nil else CAR s

dqAddAppend(x,y)==
    if null x
    then nil
    else if null y
         then nil
         else
              RPLACD (CDR x,CAR y)
              RPLACD (x,    CDR y)
              x
