import SwiftUI
import AppKit

// Separate from NoteEditorScreen's large SwiftUI body to keep CLT type
// checking predictable, and to avoid introducing a second editor.
struct WorkOSInkPalette: View {
    let onPreset: (WorkOSInkPreset) -> Void
    let onCustom: (String) -> Void
    @State private var customInk = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("글자색").font(.headline)
            ForEach(WorkOSInkPreset.allCases) { preset in
                Button {
                    onPreset(preset)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: preset == .automatic ? "textformat" : "circle.fill")
                            .foregroundStyle(Color(nsColor: preset.color))
                        Text(preset.label)
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: 150, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            Divider()
            ColorPicker("사용자 지정 색상", selection: $customInk, supportsOpacity: false)
            Button("선택한 색상 적용") {
                let source = NSColor(customInk)
                guard let rgb = source.usingColorSpace(.deviceRGB) else { return }
                let hex = String(format: "#%02X%02X%02X",
                    Int((rgb.redComponent * 255).rounded()),
                    Int((rgb.greenComponent * 255).rounded()),
                    Int((rgb.blueComponent * 255).rounded()))
                onCustom(hex)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(width: 215)
    }
}
