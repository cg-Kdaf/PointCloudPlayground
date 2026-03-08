//
//  ObjectPropertiesView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 8/03/2026.
//

import SwiftUI

struct ObjectPropertiesView: View {
  @ObservedObject var object: SceneObject
  @ObservedObject var pointCloudData: PointCloudDataBlock
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Object Properties")
        .font(.subheadline.bold())
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Name")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            TextField("Object name", text: $object.name)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .font(.system(.body, design: .default))
          }
          
          Divider().padding(.vertical, 4)
          
          VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Color")
                .font(.caption)
                .foregroundColor(.secondary)
              HStack(spacing: 12) {
                ColorPicker("", selection: $pointCloudData.color, supportsOpacity: true)
                  .labelsHidden()
                  .frame(width: 40, height: 40)
                
                HStack(spacing: 8) {
                  Circle()
                    .fill(pointCloudData.color)
                    .frame(width: 12, height: 12)
                  Text("Selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
            
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Point Size")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f", pointCloudData.pointSize))
                  .font(.caption.monospacedDigit())
                  .fontWeight(.medium)
              }
              Slider(value: $pointCloudData.pointSize, in: 0.5...20.0)
            }
          }
          
          Divider().padding(.vertical, 4)
          
          VStack(alignment: .leading, spacing: 10) {
            Text("Transform")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            
            TransformEditorView(
              translation: $object.translation,
              rotation: $object.rotation,
              scale: $object.scale
            )
          }
          
          Divider().padding(.vertical, 4)
          
          VStack(alignment: .leading, spacing: 10) {
            Text("Information")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            
            InfoRow(label: "Points", value: String(format: "%d", pointCloudData.pointsCount))
            InfoRow(label: "Size", value: String(format: "%.2f MB", Double(pointCloudData.pointsCount) * 16 / 1_000_000))
          }
          
          Divider().padding(.vertical, 4)
          
          VStack(alignment: .leading, spacing: 6) {
            Text("File Path")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            Text(pointCloudData.filePath ?? "Unknown file path")
              .font(.system(.caption2, design: .monospaced))
              .foregroundColor(.secondary)
              .lineLimit(2)
              .truncationMode(.middle)
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }
}

