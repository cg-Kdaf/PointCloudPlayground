#include <metal_stdlib>
#include "../PointCloudPlayground-Bridging-Header.h"
using namespace metal;

struct CameraUniforms {
  float4x4 viewProjectionMatrix;
};

struct PointVertexOut {
  float4 position [[position]];
  float point_size [[point_size]];
  float4 color;
};

struct point_vertex {
  float4 position;
};

vertex PointVertexOut point_vertex_shader(const device point_vertex *vertices [[buffer(0)]],
                                          constant CameraUniforms &camera [[buffer(1)]],
                                          constant PointCloudRenderUniforms &uniforms [[buffer(2)]],
                                          uint vertexID [[vertex_id]]) {
  PointVertexOut out;
  float4 worldPosition = float4(vertices[vertexID].position.xyz, 1.0);
  out.position = camera.viewProjectionMatrix * worldPosition;
  float shading = (vertices[vertexID].position.z - uniforms.bboxMinZ) / (uniforms.bboxMaxZ - uniforms.bboxMinZ);
  float3 color = float3(uniforms.colorR, uniforms.colorG, uniforms.colorB);
  out.color = float4(color * shading, uniforms.colorA);
  out.point_size = uniforms.pointSize * 600.0 / (length(out.position) + 0.01);;
  return out;
}

fragment float4 point_fragment(PointVertexOut in [[stage_in]]) {
  return in.color;
}
