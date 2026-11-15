import SwiftUI

struct MemoWeaverRevisionCompareView: View {
    let revisions: [[String: Any]]
    let current: String
    let onRestore: (String) -> Void
    let onClose: () -> Void
    @State private var selected = 0

    private var bodySource: String {
        guard revisions.indices.contains(selected) else { return "" }
        let revision = revisions[selected]
        let source = WorkOSJSON.string(revision, "body")
        return WorkOSJSON.string(revision, "bodyFormat") == "markdown"
            ? source : LegacyNoteTextConverter.text(from: source)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("본문 변경 이력").font(.headline)
            if revisions.isEmpty {
                Text("아직 저장된 이력이 없습니다.").foregroundStyle(.secondary)
            } else {
                Picker("저장 시점", selection: $selected) {
                    ForEach(revisions.indices, id: \.self) { index in
                        Text(WorkOSDate.display(WorkOSJSON.string(revisions[index], "at"))).tag(index)
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    sourcePane("현재 본문", current)
                    sourcePane("선택한 이력", bodySource)
                }
                Text("본문만 복원합니다. 현재 내용은 이력에 남으며, 복원 직후 실행 취소로 되돌릴 수 있습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("닫기", action: onClose).keyboardShortcut(.cancelAction)
                Button("선택한 본문 복원") { onRestore(bodySource) }
                    .disabled(revisions.isEmpty || bodySource == current)
            }
        }.padding(20).frame(minWidth: 760, minHeight: 460)
    }
    private func sourcePane(_ title: String, _ source: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline.bold())
            ScrollView([.horizontal, .vertical]) {
                Text(source).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(10)
            }.background(Color(nsColor: .textBackgroundColor)).border(Color.secondary.opacity(0.3))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
