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

#define _PROJECT3D_C
#include "fricas_c_macros.h"
#include <string.h>

#include "header.h"
#include "draw.h"
#include "mode.h"   /* for #define components */

#include "all_3d.H1"

/*******************************************
 * void project(aViewTriple,someXpoints,i) *
 *                                         *
 *  orthogonal projection for a point      *
 *  setting the ith Xpoint as well         *
 *******************************************/

void
project(viewTriple * aViewTriple,XPoint *someXpoints,int i)
{
  float Vtmp[4], V[4], V1[4];

  V[0] = aViewTriple->x;  V[1] = aViewTriple->y;
  V[2] = aViewTriple->z;  V[3] = 1.0;

  if (isNaNPoint(V[0], V[1], V[2])) {
    (someXpoints+i)->x = aViewTriple->px = NotPoint;
    (someXpoints+i)->y = aViewTriple->py = NotPoint;
    return;
  }

  V[0] -= viewport->transX; V[1] -= viewport->transY;
  V[2] -= viewport->transZ;
  vectorMatrix4(V,R1,Vtmp);

  matrixMultiply4x4(S,R,transform);
  vectorMatrix4(Vtmp,transform,V1);

  aViewTriple->wx = V1[0]; aViewTriple->wy = V1[1];
  aViewTriple->wz = V1[2];

  V1[0] *= reScale;  V1[1] *= reScale;  V1[2] *= reScale;

  aViewTriple->pz = V1[2];
  if (viewData.perspective) {
    V1[0] *= projPersp(aViewTriple->pz);
    V1[1] *= projPersp(aViewTriple->pz);
  }

  matrixMultiply4x4(I,T,transform);
  vectorMatrix4(V1,transform,V);
  V[0] = V[0]*viewScale + xCenter;
  V[1] = vwInfo.height - (V[1]*viewScale + yCenter);

  (someXpoints+i)->x = aViewTriple->px = V[0];
  (someXpoints+i)->y = aViewTriple->py = V[1];
}


/***************************************************
 * void projectAPoint(aViewTriple)                 *
 *                                                 *
 *  orthogonal projection for a point. sort of     *
 *  like the above, but no Xpoint assignment       *
 ***************************************************/

void
projectAPoint(viewTriple *aViewTriple)
{
  float Vtmp[4], V[4], V1[4];

  V[0] = aViewTriple->x;  V[1] = aViewTriple->y;
  V[2] = aViewTriple->z;  V[3] = 1.0;

  if (isNaNPoint(V[0], V[1], V[2])) {
    aViewTriple->px = NotPoint;
    aViewTriple->py = NotPoint;
    return;
  }

  V[0] -= viewport->transX; V[1] -= viewport->transY;
  V[2] -= viewport->transZ;
  vectorMatrix4(V,R1,Vtmp);

  matrixMultiply4x4(S,R,transform);
  vectorMatrix4(Vtmp,transform,V1);

  aViewTriple->wx = V1[0]; aViewTriple->wy = V1[1];
  aViewTriple->wz = V1[2];

  V1[0] *= reScale;  V1[1] *= reScale;  V1[2] *= reScale;

  aViewTriple->pz = V1[2];
  if (viewData.perspective) {
    V1[0] *= projPersp(aViewTriple->pz);
    V1[1] *= projPersp(aViewTriple->pz);
  }

  matrixMultiply4x4(I,T,transform);
  vectorMatrix4(V1,transform,V);
  V[0] = V[0]*viewScale + xCenter;
  V[1] = vwInfo.height - (V[1]*viewScale + yCenter);

  aViewTriple->px = V[0];
  aViewTriple->py = V[1];
}


/***************************
 * void projectAllPoints() *
 ***************************/

void
projectAllPoints(void)
{

  int i,j,k;
  LLPoint *anLLPoint;
  LPoint *anLPoint;
  int *anIndex;

  anLLPoint = viewData.lllp.llp;
  for (i=0; i<viewData.lllp.numOfComponents; i++,anLLPoint++) {
    anLPoint = anLLPoint->lp;
    for (j=0; j<anLLPoint->numOfLists; j++,anLPoint++) {
      anIndex = anLPoint->indices;
      for (k=0; k<anLPoint->numOfPoints; k++,anIndex++) {
        projectAPoint(refPt3D(viewData,*anIndex));
      } /* for points in LPoints (k) */
    } /* for LPoints in LLPoints (j) */
  } /* for LLPoints in LLLPoints (i) */

} /* projectAllPoints() */


/*******************************
 * void projectAllPolys(pList) *
 *                             *
 * orthogonal projection of    *
 * all the polygons in a given *
 * list in one go. pz holds    *
 * the projected depth info    *
 * for hidden surface removal. *
 * Polygons totally outside of *
 * the window dimensions after *
 * projection are discarded    *
 * from the list.              *
 *******************************/

void
projectAllPolys (poly *pList)
{

  int i,clipped,clippedPz;
  float x0=0.0;
  float y0=0.0;
  float xA=0.0;
  float yA=0.0;
  float xB=0.0;
  float yB=0.0;
  int *anIndex;
  viewTriple *aPt;

  strcpy(control->message,"         Projecting Polygons        ");
  writeControlMessage();

  projectAllPoints();
  for (;pList != NIL(poly);pList=pList->next) {
      /* totalClip==yes => partialClip==yes (of course) */
    pList->totalClipPz = yes;  /* start with 1, AND all points with Pz<0 */
    pList->partialClipPz = no; /* start with 0, OR any points with Pz<0 */
    pList->totalClip = yes;  /* same idea, only wrt clip volume */
    pList->partialClip = no;
    for (i=0,anIndex=pList->indexPtr; i<pList->numpts; i++,anIndex++) {
      aPt = refPt3D(viewData,*anIndex);
      clipped = outsideClippedBoundary(aPt->x, aPt->y, aPt->z);
      pList->totalClip = pList->totalClip && clipped;
      pList->partialClip = pList->partialClip || clipped;
      clippedPz = behindClipPlane(aPt->pz);
      pList->totalClipPz = pList->totalClipPz && clippedPz;
      pList->partialClipPz = pList->partialClipPz || clippedPz;

        /* stuff for figuring out normalFacingOut, after the loop */
      if (!i) {
        x0 = aPt->px; y0 = aPt->py;
      } else if (i==1) {
        xA = x0 - aPt->px; yA = y0 - aPt->py;
        x0 = aPt->px;      y0 = aPt->py;
      } else if (i==2) {
        xB = aPt->px - x0; yB = aPt->py - y0;
      }
    } /* for i */
    /* store face facing info */
    /* For now, we shall give faces facing the user a factor of -1,
       and faces facing away from the user a factor of +1. this is
       to mimic the eye vector (pointing away from the user) dotted
       into the surface normal.
       This routine is being done because the surface normal in object
       space does not transform over to image space linearly and so
       has to be recalculated. but the triple product is zero in the
       X and Y directions so we just take the Z component, of which,
       we just examine the sign. */
    if ((x0 = xA*yB - yA*xB) > machine0) pList->normalFacingOut = 1;
    else if (x0 < machine0) pList->normalFacingOut = -1;
    else pList->normalFacingOut = 0;

  }
  strcpy(control->message,viewport->title);
  writeControlMessage();

}   /* projectAllPolys */



/*******************************
 * void projectAPoly(p)        *
 *                             *
 * orthogonal projection of    *
 * all a polygon. pz holds     *
 * the projected depth info    *
 * for hidden surface removal  *
 *******************************/


void
projectAPoly (poly *p)
{

  int i,clipped,clippedPz;
  float Vtmp[4],V[4],V1[4];
  float x0=0.0;
  float y0=0.0;
  float xA=0.0;
  float yA=0.0;
  float xB=0.0;
  float yB=0.0;

  int *anIndex;
  viewTriple *aPt;

/*  totalClip==yes => partialClip==yes */
  p->totalClipPz = yes; /*  start with 1, AND all points with Pz<0 */
  p->partialClipPz = no;  /* start with 0, OR any points with Pz<0 */
  p->totalClip = yes;  /* same idea, only with respect to clip volume */
  p->partialClip = no;
  for (i=0,anIndex=p->indexPtr; i<p->numpts; i++,anIndex++) {
    aPt  = refPt3D(viewData,*anIndex);
    V[0] = aPt->x;  V[1] = aPt->y;  V[2] = aPt->z;  V[3] = 1.0;

    V[0] -= viewport->transX; V[1] -= viewport->transY;
    V[2] -= viewport->transZ;
    vectorMatrix4(V,R1,Vtmp);

    matrixMultiply4x4(S,R,transform);
    vectorMatrix4(Vtmp,transform,V1);

    aPt->wx = V1[0];  aPt->wy = V1[1];  aPt->wz = V1[2];

    V1[0] *= reScale;  V1[1] *= reScale;  V1[2] *= reScale;

    aPt->pz = V1[2];
    if (viewData.perspective) {
      V1[0] *= projPersp(V1[2]);
      V1[1] *= projPersp(V1[2]);
    }

    matrixMultiply4x4(I,T,transform);
    vectorMatrix4(V1,transform,V);
    V[0] = V[0]*viewScale + xCenter;
    V[1] = vwInfo.height - (V[1]*viewScale + yCenter);

    aPt->px = V[0];  aPt->py = V[1];

    clipped = outsideClippedBoundary(aPt->x, aPt->y, aPt->z);
    p->totalClip = p->totalClip && clipped;
    p->partialClip = p->partialClip || clipped;
    clippedPz = behindClipPlane(aPt->pz);
    p->totalClipPz = p->totalClipPz && clippedPz;
    p->partialClipPz = p->partialClipPz || clippedPz;

    /* stuff for figuring out normalFacingOut, after the loop */
    if (!i) {
      x0 = aPt->px; y0 = aPt->py;
    } else if (i==1) {
      xA = x0 - aPt->px; yA = y0 - aPt->py;
      x0 = aPt->px;      y0 = aPt->py;
    } else if (i==2) {
      xB = aPt->px - x0; yB = aPt->py - y0;
    }
  }

  if ((x0 = xA*yB - yA*xB) > machine0) p->normalFacingOut = 1;
  else if (x0 < machine0) p->normalFacingOut = -1;
  else p->normalFacingOut = 0;

}  /*  projectAPoly */



/**********************************
 * void projectStuff(x,y,z,px,py) *
 *                                *
 * sort of like the project stuff *
 * in tube.c but used exclusively *
 * for the functions of two       *
 * variables. probably will need  *
 * to be changed later to be more *
 * general (i.e. have everybody   *
 * use the viewTriple point       *
 * structure).                    *
 **********************************/

void
projectStuff(float x,float y,float z,int *px,int *py,float *Pz)
{
  float tempx,tempy,tempz,temps,V[4],V1[4],stuffScale=100.0;

  tempx = viewport->scaleX;
  tempy = viewport->scaleY;
  tempz = viewport->scaleZ;
  temps = viewScale;

  if (viewport->scaleX > 5.0) viewport->scaleX = 5.0;
  if (viewport->scaleY > 5.0) viewport->scaleY = 5.0;
  if (viewport->scaleZ > 3.0) viewport->scaleZ = 3.0;
  if (viewScale > 5.0) viewScale = 5.0;

  V[0] = x;  V[1] = y;
  V[2] = z;  V[3] = 1.0;

  V[0] -= viewport->transX*stuffScale;
  V[1] -= viewport->transY*stuffScale;
  V[2] -= viewport->transZ*stuffScale;

  matrixMultiply4x4(S,R,transform);
  vectorMatrix4(V,transform,V1);
  *Pz = V1[2];

  if (viewData.perspective) {
    V1[0] *= projPersp(V1[2]);
    V1[1] *= projPersp(V1[2]);
  }

  matrixMultiply4x4(I,T,transform);
  vectorMatrix4(V1,transform,V);

  V[0] = V[0]*viewScale + xCenter;
  V[1] = vwInfo.height - (V[1]*viewScale + yCenter);

  *px = V[0];
  *py = V[1];

  viewport->scaleX = tempx;
  viewport->scaleY = tempy;
  viewport->scaleZ = tempz;
  viewScale = temps;
}
