import SwiftUI

@MainActor
final class MemoWeaverUpdateController: ObservableObject {
    enum State: Equatable { case idle, checking, completed(MemoWeaverUpdateResult), failed(String) }
    @Published private(set) var state: State = .idle
    private let service: any MemoWeaverUpdateChecking
    private let currentVersion: String
    private var task: Task<Void, Never>?
    private var generation = UUID()
    init(service: any MemoWeaverUpdateChecking = MemoWeaverUpdateService(), currentVersion: String = WorkOSBuildInfo.updateVersion) {
        self.service = service; self.currentVersion = currentVersion
    }
    func check() {
        guard state != .checking else { return }
        let token = UUID()
        generation = token
        state = .checking
        task = Task { @MainActor in
            do {
                let result = try await service.check(currentVersion: currentVersion)
                guard generation == token, !Task.isCancelled else { return }
                state = .completed(result)
            } catch {
                guard generation == token, !Task.isCancelled else { return }
                let message = (error as? MemoWeaverUpdateError)?.localizedDescription
                    ?? "업데이트를 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요."
                state = .failed(message)
            }
            task = nil
        }
    }
    func cancel() {
        generation = UUID()
        task?.cancel(); task = nil
        if state == .checking { state = .idle }
    }
}

@MainActor
struct MemoWeaverUpdateCheckView: View {
    @StateObject private var controller: MemoWeaverUpdateController
    init(controller: MemoWeaverUpdateController? = nil) {
        _controller = StateObject(wrappedValue: controller ?? MemoWeaverUpdateController())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("업데이트 확인") { controller.check() }
                    .disabled(controller.state == .checking)
                    .accessibilityIdentifier("memoweaver.update.check")
                if controller.state == .checking {
                    ProgressView().controlSize(.small)
                    Text("확인 중…").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("버튼을 누를 때만 GitHub의 공개 버전을 확인합니다. 메모 내용이나 파일은 전송하지 않습니다.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            switch controller.state {
            case .completed(let result):
                Text(result.message).font(.callout.weight(.medium)).textSelection(.enabled)
                if result.latest.origin == .tag {
                    Text("공개된 소스 버전 태그 기준입니다.").font(.caption).foregroundStyle(.secondary)
                }
                if result.hasUpdate {
                    Text("새 버전 소스를 받은 뒤 동봉된 README의 설치 안내를 따라주세요. 앱을 교체하기 전에 메모를 백업해 주세요.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Link("공개 버전 보기", destination: result.latest.pageURL)
                    if result.hasUpdate { Link("소스 ZIP 받기", destination: result.latest.sourceURL) }
                }
            case .failed(let message):
                Text(message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            case .idle, .checking: EmptyView()
            }
            Link("GitHub에서 버전 확인", destination: MemoWeaverPublicVersion.repository.appendingPathComponent("tags"))
                .font(.caption)
        }
        .onDisappear { controller.cancel() }
    }
}
