#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position;
  float3 color;
};

struct CameraUniforms {
  float4x4 viewProjectionMatrix;
};

struct VertexOut {
  float4 position [[position]];
  float3 color;
};

vertex VertexOut basic_vertex(const device VertexIn *vertices [[buffer(0)]],
                              constant CameraUniforms &camera [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {
  VertexOut out;
  float4 worldPosition = float4(vertices[vertexID].position, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  out.color = vertices[vertexID].color;
  return out;
}

fragment float4 basic_fragment(VertexOut in [[stage_in]]) {
  return float4(in.color, 1.0);
}
