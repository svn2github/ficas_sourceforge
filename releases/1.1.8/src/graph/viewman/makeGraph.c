/*
Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    - Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    - Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the
      distribution.

    - Neither the name of The Numerical ALgorithms Group Ltd. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#define _MAKEGRAPH_C
#include "axiom-c-macros.h"

#include <stdlib.h>
#include <stdio.h>

#include "viewman.h"

#include "sockio-c.H1"
#include "makeGraph.H1"

graphStruct *
makeGraphFromSpadData(void)
{

  graphStruct     *graphData;
  pointListStruct *pL;
  pointStruct     *p;
  int i,j;

  if (!(graphData = (graphStruct *)malloc(sizeof(graphStruct)))) {
    fprintf(stderr,"The viewport manager ran out of memory trying to create a new graph (graphStruct).\n");
    exit(-1);
  }

  graphData->xmin = get_float(spadSock);   /* after everything is normalized */
  graphData->xmax = get_float(spadSock);
  graphData->ymin = get_float(spadSock);   /* view2D */
  graphData->ymax = get_float(spadSock);

  graphData->xNorm = 1/(graphData->xmax - graphData->xmin);
  graphData->yNorm = 1/(graphData->ymax - graphData->ymin);

  graphData->spadUnitX = get_float(spadSock);
  graphData->spadUnitY = get_float(spadSock);

  graphData->unitX = graphData->spadUnitX * graphData->xNorm;
  graphData->unitY = graphData->spadUnitY * graphData->yNorm;

  graphData->originX = -graphData->xmin * graphData->xNorm - 0.5;
  graphData->originY = -graphData->ymin * graphData->yNorm - 0.5;


  graphData->numberOfLists = get_int(spadSock);
  if (!(pL = (pointListStruct *)malloc(graphData->numberOfLists * sizeof(pointListStruct)))) {
    fprintf(stderr,"The viewport manager ran out of memory trying to create a new graph (pointListStruct).\n");
    exit(-1);
  }
  graphData->listOfListsOfPoints = pL;

  for (i=0; i<graphData->numberOfLists; i++) {

    pL->numberOfPoints = get_int(spadSock);
    if (!(p = (pointStruct *)malloc(pL->numberOfPoints * sizeof(pointStruct)))) {
      fprintf(stderr,"The viewport manager ran out of memory trying to create a new graph (pointStruct).\n");
      exit(-1);
    }
    pL->listOfPoints = p;             /** point to current point list **/

    for (j=0; j<pL->numberOfPoints; j++) {
      p->x     = get_float(spadSock);         /* get numbers from AXIOM */
      p->y     = get_float(spadSock);
      p->hue   = get_float(spadSock) - 1;     /* make zero based */
      p->shade = get_float(spadSock) - 1;
        /* normalize to range [-0.5..0.5] */
      p->x = (p->x - graphData->xmin) * graphData->xNorm - 0.5;
      p->y = (p->y - graphData->ymin) * graphData->yNorm - 0.5;
      p++;
    }
        /* for now, getting hue, shade - do hue * totalHues + shade */
    pL->pointColor = get_int(spadSock);
    pL->lineColor = get_int(spadSock);
    pL->pointSize = get_int(spadSock);
    pL++;                          /** advance to next point list **/
  }


  graphData->key = graphKey++;

  send_int(spadSock,(graphKey-1));          /* acknowledge to spad */


  return(graphData);

}


void
discardGraph (graphStruct *theGraph)
{

  pointListStruct *pL;
  int j;

  for (j=0, pL=theGraph->listOfListsOfPoints; j<theGraph->numberOfLists; j++,pL++)
    free(pL->listOfPoints);
  free(theGraph->listOfListsOfPoints);
  free(theGraph);

}
