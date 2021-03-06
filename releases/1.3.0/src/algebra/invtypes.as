\documentclass{article}
\usepackage{axiom}
\begin{document}
\title{\$SPAD/src/algebra invtypes.as}
\author{The Axiom Team}
\maketitle
\begin{abstract}
\end{abstract}
\eject
\tableofcontents
\eject
\section{IVSimpleInnerNode}
<<IVSimpleInnerNode>>=
#include "axiom"

import from IVValue, Symbol;

POINT ==> Point DoubleFloat;
NNI ==> NonNegativeInteger;

IVSimpleInnerNode: with {
	new: 	   ()                -> %;
	addChild!: (%, IVNodeObject) -> ();
	children:   %                -> List IVNodeObject;
	fields:     %                -> List IVField;

	=: (%, %) -> Boolean;

} == add {
	Rep ==> Record(lst: List IVNodeObject);
	import from Rep;

	new(): % == per [[]];
	addChild!(v: %, new: IVNodeObject): () == {
		rep(v).lst := concat!(rep(v).lst, new);
	}

	children(v: %): List IVNodeObject == rep(v).lst;

	fields(node: %): List IVField == [];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVInnerNodes";
}

@
\section{IVSeparator}
<<IVSeparator>>=
IVSeparator: IVNodeCategory with {
	new: () -> %;
} == IVSimpleInnerNode add {
	className(v: %): String == "Separator";
}

@
\section{IVGroup}
<<IVGroup>>=
IVGroup: IVNodeCategory with {
	new: () -> %;
} == IVSimpleInnerNode add {
	className(v: %): String == "Group";
}

@
\section{IVCoordinate3}
<<IVCoordinate3>>=
IVCoordinate3: IVLeafNodeCategory with {
	new: List POINT -> %;
} == add {
	Rep ==> List POINT;
	className(x: %): String == "Coordinate3";

	new(l: List POINT): % == per l;
	fields(v: %): List IVField == [ new("point", pointlist rep v)];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVCoord3";
}

@
\section{IVCoordinate4}
<<IVCoordinate4>>=
IVCoordinate4: IVLeafNodeCategory with {
	new: List POINT -> %;
} == add {
	Rep ==> List POINT;
	import from Rep;

	className(x: %): String == "Coordinate4";

	new(l: List POINT): % == per l;
	fields(v: %): List IVField == [ new("point", pointlist rep v)];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVCoord4";
}

@
\section{IVQuadMesh}
<<IVQuadMesh>>=
IVQuadMesh: IVLeafNodeCategory with {
	new: (SingleInteger, SingleInteger, SingleInteger) -> %;
} == add {
	Rep ==> Record( rowc: SingleInteger,
			colc: SingleInteger,
			start: SingleInteger);
	import from Rep;

	className(x: %): String == "QuadMesh";

	new(rc: SingleInteger, cc: SingleInteger, start: SingleInteger): % ==
		per [rc, cc, start];

	fields(v: %): List IVField == [
		new("verticesPerColumn", int rep(v).colc),
		new("verticesPerRow",    int rep(v).rowc),
		new("startIndex", 	 int rep(v).start)
	];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVQuadMesh";
}

@
\section{IVBaseColor}
<<IVBaseColor>>=
IVBaseColor: IVLeafNodeCategory with {
	new: List POINT -> %;
} == add {
	Rep ==> List POINT;
	import from Rep;

	className(x: %): String == "BaseColor";

	new(l: List POINT): % == per l;
	fields(v: %): List IVField == [ new("rgb", pointlist rep v) ];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVBaseColor";
}

@
\section{IVIndexedLineSet}
<<IVIndexedLineSet>>=
IVIndexedLineSet: IVLeafNodeCategory with {
	new: List NNI -> %;
	new: List SingleInteger -> %;
} == add {
	Rep ==> List SingleInteger;
	import from Rep;

	className(x: %): String == "IndexedLineSet";

	new(l: List SingleInteger): % == per l;
	new(l: List NNI): 	    % == new [ coerce n for n in l];

	fields(v: %): List IVField == [ new("points", intlist rep v) ];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVBaseColor";
}

@
\section{IVFaceSet}
<<IVFaceSet>>=
IVFaceSet: IVLeafNodeCategory with {
	new: (SingleInteger, SingleInteger) -> %;
} == add {
	Rep ==> Record(startIndex: SingleInteger, numVertices: SingleInteger);
	import from Rep;

	className(x: %): String == "FaceSet";

	new(x: SingleInteger, y: SingleInteger): % == per [x,y];
	fields(v: %): List IVField == [
		new("numVertices", int rep(v).numVertices),
		new("startIndex",  int rep(v).startIndex)
	];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVFaceSet";
}

@
\section{IVPointSet}
<<IVPointSet>>=
IVPointSet: IVLeafNodeCategory with {
	new: (SingleInteger, SingleInteger) -> %;
} == add {
	Rep ==> Record(startIndex: SingleInteger, numPoints: SingleInteger);
	import from Rep;

	className(x: %): String == "PointSet";

	new(x: SingleInteger, y: SingleInteger): % == per [x,y];

	fields(v: %): List IVField == [
		new("numPoints", int rep(v).numPoints),
		new("startIndex",  int rep(v).startIndex)
	];

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVFaceSet";
}

@
\section{IVBasicNode}
<<IVBasicNode>>=
IVBasicNode: IVNodeCategory with {
	make: String -> %;
	addField!: (%, IVField) -> ();
	addField!: (%, Symbol, IVValue) -> ();
} == add {
	Rep ==> Record(class: String,
		       kids: List IVNodeObject,
		       fields: List IVField);
	import from Rep, IVField;

	make(name: String): % == per [name, [], []];

	className(node: %): String == rep(node).class;
	children(node: %): List IVNodeObject == rep(node).kids;
	fields(node: %): List IVField == rep(node).fields;

	addField!(node: %, fld: IVField): () == {
		rep(node).fields := cons(fld, rep(node).fields);
	}

	addChild!(node: %, kid: IVNodeObject): () == {
		rep(node).kids := cons(kid, rep(node).kids);
	}

	addField!(node: %, sym: Symbol, val: IVValue): () ==
		addField!(node, new(sym, val));

	--
	sample: % == % pretend %;
	(=)(a: %, b: %): Boolean == error "no equality on IVBasicNode";
}

@
\section{License}
<<license>>=
--Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
--All rights reserved.
--
--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are
--met:
--
--    - Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--
--    - Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in
--      the documentation and/or other materials provided with the
--      distribution.
--
--    - Neither the name of The Numerical ALgorithms Group Ltd. nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.
--
--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
--IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
--TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
--PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
--OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
--EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
--PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
--PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
--LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
--NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
@
<<*>>=
<<license>>

<<IVSimpleInnerNode>>
<<IVSeparator>>
<<IVGroup>>
<<IVCoordinate3>>
<<IVCoordinate4>>
<<IVQuadMesh>>
<<IVBaseColor>>
<<IVIndexedLineSet>>
<<IVFaceSet>>
<<IVPointSet>>
<<IVBasicNode>>
@
\eject
\begin{thebibliography}{99}
\bibitem{1} nothing
\end{thebibliography}
\end{document}
