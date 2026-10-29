import SwiftUI

// Used by both the list filters and the current note's property menus.
// Category creation is explicit; the editor's Markdown body never changes.
struct MemoWeaverCategoryCreationSheet: View {
    @EnvironmentObject private var model: WorkOSModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var name = ""
    let kind: String
    let onCreated: (String) -> Void

    private var isBook: Bool { kind == "book" }
    private var title: String { isBook ? "새 노트북" : "새 메모 종류" }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.title3.bold())
            Text(isBook ? "노트북을 만든 뒤 선택합니다. 현재 메모 내용은 바뀌지 않습니다." :
                          "메모 종류를 만든 뒤 선택합니다. 현재 메모 내용은 바뀌지 않습니다.")
                .font(.caption).foregroundStyle(.secondary)
            TextField(isBook ? "노트북 이름" : "종류 이름", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(create)
            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("추가", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear { nameFocused = true }
    }

    private func create() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        let existing = isBook ? model.books : model.types
        // Reuse a matching name rather than silently creating duplicates.
        if let found = existing.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            onCreated(found.id)
            dismiss()
            return
        }
        let oldIDs = Set(existing.map(\.id))
        model.createCategory(kind: kind, name: name)
        let refreshed = isBook ? model.books : model.types
        // Model.createCategory reports failures through model.alertText.
        guard let created = refreshed.first(where: { !oldIDs.contains($0.id) && $0.name == name }) else {
            return
        }
        onCreated(created.id)
        dismiss()
    }
}
