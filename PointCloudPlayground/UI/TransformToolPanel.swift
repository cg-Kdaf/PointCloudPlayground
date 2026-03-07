import SwiftUI

struct TransformToolPanel: View {
    @Binding var referenceMode: TransformReferenceMode
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transform Tool")
                .font(.headline)
            Picker("Reference", selection: $referenceMode) {
                ForEach(TransformReferenceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor)))
    }
}
