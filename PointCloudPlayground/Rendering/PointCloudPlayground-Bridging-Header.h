#ifndef PointCloudPlayground_Bridging_Header_h
#define PointCloudPlayground_Bridging_Header_h

#include <simd/simd.h>

typedef struct PointCloudRenderUniforms {
  matrix_float4x4 modelMatrix;
  float bboxMaxX;
  float bboxMinX;
  float bboxMaxY;
  float bboxMinY;
  float bboxMaxZ;
  float bboxMinZ;
  float pointSize;
  float colorR;
  float colorG;
  float colorB;
  float colorA;
} PointCloudRenderUniforms;

#endif /* PointCloudPlayground_Bridging_Header_h */
