#ifndef PointCloudPlayground_Bridging_Header_h
#define PointCloudPlayground_Bridging_Header_h

typedef struct PointCloudRenderUniforms {
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
