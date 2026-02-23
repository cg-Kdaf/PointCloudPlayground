#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position;
  //  float3 color;
};

struct CameraUniforms {
  float4x4 viewProjectionMatrix;
};

//struct VertexOut {
//  float4 position [[position]];
//  float3 color;
//};

struct VertexOut {
  float4 position [[position]];
  float point_size [[point_size]]; // Tells Metal how big the dot should be
  float4 color;
};

vertex VertexOut basic_vertex(const device float3 *vertices [[buffer(0)]],
                              constant CameraUniforms &camera [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {
  VertexOut out;
  float4 worldPosition = float4(vertices[vertexID].xzy, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  out.color = float4(float3(worldPosition.y / 80.0 + 0.5), 1.0);
  out.point_size = 600.0 / (length(out.position) + 0.01);
  return out;
}

fragment float4 basic_fragment(VertexOut in [[stage_in]]) {
  return in.color;
}
