#include <metal_stdlib>
using namespace metal;

struct CameraUniforms {
  float4x4 viewProjectionMatrix;
};

struct PointVertexOut {
  float4 position [[position]];
  float point_size [[point_size]];
  float4 color;
};

struct laszip_point {
  float4 position;
};

vertex PointVertexOut point_vertex(const device laszip_point *vertices [[buffer(0)]],
                                   constant CameraUniforms &camera [[buffer(1)]],
                                   uint vertexID [[vertex_id]]) {
  PointVertexOut out;
  float4 worldPosition = float4(vertices[vertexID].position.xyz, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  out.color = float4(float3(worldPosition.z / 80.0 + 0.5), 1.0);
  out.point_size = 600.0 / (length(out.position) + 0.01);
  return out;
}

fragment float4 point_fragment(PointVertexOut in [[stage_in]]) {
  return in.color;
}
