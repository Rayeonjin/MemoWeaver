import AppKit
import SwiftUI

struct WorkOSTemplateCopySheet: View {
    @Environment(\.dismiss) private var dismiss
    let markdown: String
    @State private var values: [String: String] = [:]
    @State private var copied = false

    private var variables: [String] { WorkOSTemplate.variables(in: markdown) }
    private var preview: String { WorkOSTemplate.fill(markdown, values: values) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("문구 · 프롬프트 활용").font(.title2.bold())
            Text("본문에 {{이름}} 같은 변수를 넣어두면 복사할 때 값을 채울 수 있습니다. 저장된 원본은 변경되지 않습니다.")
                .font(.caption).foregroundStyle(.secondary)
            if variables.isEmpty {
                Text("변수가 없습니다. 이 메모를 그대로 복사할 수 있습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(variables, id: \.self) { variable in
                            HStack {
                                Text(variable).frame(width: 125, alignment: .leading)
                                TextField("치환할 내용", text: Binding(
                                    get: { values[variable] ?? "" },
                                    set: { values[variable] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .frame(maxHeight: 175)
            }
            Text("복사할 내용 미리보기").font(.caption.bold())
            ScrollView {
                Text(preview)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(minHeight: 110, maxHeight: 220)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                if copied { Label("클립보드에 복사됨", systemImage: "checkmark.circle").foregroundStyle(.green) }
                Spacer()
                Button("일반 텍스트 복사") { copy(WorkOSTemplate.plain(preview)) }
                Button("Markdown 복사") { copy(preview) }
                    .buttonStyle(.borderedProminent)
                Button("닫기") { dismiss() }
            }
        }
        .padding(22)
        .frame(width: 590, height: 480)
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        copied = pasteboard.setString(text, forType: .string)
    }
}
