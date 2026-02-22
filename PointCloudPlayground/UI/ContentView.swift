//
//  ContentView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import simd

@Model
final class PointCloudEntry {
  var filePath: String
  var colorRed: Double
  var colorGreen: Double
  var colorBlue: Double
  var createdAt: Date

  init(filePath: String,
       colorRed: Double,
       colorGreen: Double,
       colorBlue: Double,
       createdAt: Date = .now) {
    self.filePath = filePath
    self.colorRed = colorRed
    self.colorGreen = colorGreen
    self.colorBlue = colorBlue
    self.createdAt = createdAt
  }

  var color: Color {
    Color(red: colorRed, green: colorGreen, blue: colorBlue)
  }

  var simdColor: SIMD3<Float> {
    SIMD3(Float(colorRed), Float(colorGreen), Float(colorBlue))
  }
}

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \PointCloudEntry.createdAt) private var pointClouds: [PointCloudEntry]

  @State private var selectedPath: String?
  @State private var isImporterPresented = false
  private let newCloudColor = Color.white

  private let lazType = UTType(filenameExtension: "laz") ?? .data

  private var selectedCloud: PointCloudEntry? {
    pointClouds.first { $0.filePath == selectedPath }
  }

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Point Clouds")
          .font(.headline)

        Picker("Displayed Cloud", selection: $selectedPath) {
          Text("None")
            .tag(Optional<String>.none)
          ForEach(pointClouds, id: \.persistentModelID) { cloud in
            Text(URL(fileURLWithPath: cloud.filePath).lastPathComponent)
              .tag(Optional(cloud.filePath))
          }
        }

        if let selectedCloud {
          ColorPicker("Color", selection: colorBinding(for: selectedCloud))
        }

        Divider()

        Button("Add .laz file") {
          isImporterPresented = true
        }

        Spacer()
      }
      .padding(12)
      .frame(width: 300)

      Divider()

      MetalView(selectedFilePath: selectedCloud?.filePath,
                selectedColor: selectedCloud?.simdColor)
    }
    .fileImporter(isPresented: $isImporterPresented,
                  allowedContentTypes: [lazType],
                  allowsMultipleSelection: false,
                  onCompletion: handleImportResult)
    .onAppear {
      if selectedPath == nil {
        selectedPath = pointClouds.first?.filePath
      }
    }
    .onChange(of: pointClouds.map(\.filePath)) { _, filePaths in
      if let selectedPath, filePaths.contains(selectedPath) {
        return
      }
      self.selectedPath = filePaths.first
    }
  }

  private func colorBinding(for cloud: PointCloudEntry) -> Binding<Color> {
    Binding(
      get: {
        cloud.color
      },
      set: { newColor in
        let rgbColor = NSColor(newColor).usingColorSpace(.deviceRGB)
        cloud.colorRed = Double(rgbColor?.redComponent ?? 1.0)
        cloud.colorGreen = Double(rgbColor?.greenComponent ?? 1.0)
        cloud.colorBlue = Double(rgbColor?.blueComponent ?? 1.0)
      }
    )
  }

  private func handleImportResult(_ result: Result<[URL], Error>) {
    guard case let .success(urls) = result,
          let url = urls.first else {
      return
    }

    if let existing = pointClouds.first(where: { $0.filePath == url.path }) {
      let rgbColor = NSColor(newCloudColor).usingColorSpace(.deviceRGB)
      existing.colorRed = Double(rgbColor?.redComponent ?? 1.0)
      existing.colorGreen = Double(rgbColor?.greenComponent ?? 1.0)
      existing.colorBlue = Double(rgbColor?.blueComponent ?? 1.0)
      selectedPath = existing.filePath
      return
    }

    let rgbColor = NSColor(newCloudColor).usingColorSpace(.deviceRGB)
    let entry = PointCloudEntry(filePath: url.path,
                                colorRed: Double(rgbColor?.redComponent ?? 1.0),
                                colorGreen: Double(rgbColor?.greenComponent ?? 1.0),
                                colorBlue: Double(rgbColor?.blueComponent ?? 1.0))
    modelContext.insert(entry)
    selectedPath = entry.filePath
  }
}

#Preview {
  ContentView()
}
