#include <metal_stdlib>
using namespace metal;

struct ColoredVertexIn {
  float3 position [[attribute(0)]];
  float3 color [[attribute(1)]];
};

struct CameraUniforms {
  float4x4 viewProjectionMatrix;
};

struct VertexOut {
  float4 position [[position]];
  float point_size [[point_size]];
  float4 color;
};

vertex VertexOut point_vertex(const device float3 *vertices [[buffer(0)]],
                              constant CameraUniforms &camera [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {
  VertexOut out;
  float4 worldPosition = float4(vertices[vertexID].xzy, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  out.color = float4(float3(worldPosition.y / 80.0 + 0.5), 1.0);
  out.point_size = 600.0 / (length(out.position) + 0.01);
  return out;
}

vertex VertexOut colored_vertex(ColoredVertexIn in [[stage_in]],
                                constant CameraUniforms &camera [[buffer(1)]]) {
  VertexOut out;
  float4 worldPosition = float4(in.position, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  out.color = float4(in.color, 1.0);
  out.point_size = 1.0;
  return out;
}

fragment float4 basic_fragment(VertexOut in [[stage_in]]) {
  return in.color;
}
