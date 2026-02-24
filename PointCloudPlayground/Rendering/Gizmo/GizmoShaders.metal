#include <metal_stdlib>
using namespace metal;

struct GizmoVertexIn {
  float3 position [[attribute(0)]];
  float3 color [[attribute(1)]];
};

struct CameraUniforms {
  float4x4 viewProjectionMatrix;
};

struct GizmoVertexOut {
  float4 position [[position]];
  float point_size [[point_size]];
  float4 color;
};

vertex GizmoVertexOut gizmo_vertex(GizmoVertexIn in [[stage_in]],
                                   constant CameraUniforms &camera [[buffer(1)]]) {
  GizmoVertexOut out;
  float4 worldPosition = float4(in.position, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  out.color = float4(in.color, 1.0);
  out.point_size = 1.0;
  return out;
}

fragment float4 gizmo_fragment(GizmoVertexOut in [[stage_in]]) {
  return in.color;
}
