//
//  TransformEditorView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 8/03/2026.
//

import SwiftUI
import simd

struct TransformEditorView: View {
  @Binding var translation: SIMD3<Float>
  @Binding var rotation: SIMD3<Float>
  @Binding var scale: SIMD3<Float>
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Translation
      VStack(alignment: .leading, spacing: 6) {
        Text("Translation")
          .font(.caption.bold())
          .foregroundColor(.secondary)
        
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Text("X").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { translation.x },
              set: { translation.x = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Y").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { translation.y },
              set: { translation.y = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Z").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { translation.z },
              set: { translation.z = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
        }
      }
      
      Divider().padding(.vertical, 4)
      
      // Rotation
      VStack(alignment: .leading, spacing: 6) {
        Text("Rotation (Radians)")
          .font(.caption.bold())
          .foregroundColor(.secondary)
        
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Text("X").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { rotation.x },
              set: { rotation.x = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Y").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { rotation.y },
              set: { rotation.y = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Z").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { rotation.z },
              set: { rotation.z = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
        }
      }
      
      Divider().padding(.vertical, 4)
      
      // Scale
      VStack(alignment: .leading, spacing: 6) {
        Text("Scale")
          .font(.caption.bold())
          .foregroundColor(.secondary)
        
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Text("X").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { scale.x },
              set: { scale.x = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Y").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { scale.y },
              set: { scale.y = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Z").font(.caption2).foregroundColor(.secondary)
            TextField("", value: Binding(
              get: { scale.z },
              set: { scale.z = $0 }
            ), format: FloatingPointFormatStyle<Float>())
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.caption, design: .monospaced))
          }
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var translation = SIMD3<Float>(1, 2, 3)
  @Previewable @State var rotation = SIMD3<Float>(0, 0, 0)
  @Previewable @State var scale = SIMD3<Float>(1, 1, 1)
  
  return TransformEditorView(
    translation: $translation,
    rotation: $rotation,
    scale: $scale
  )
  .padding()
}
