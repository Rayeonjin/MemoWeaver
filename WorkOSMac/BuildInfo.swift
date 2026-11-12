import Foundation

enum WorkOSBuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "개발 버전"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
    static var updateVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "MemoWeaverReleaseTag") as? String ?? version
    }
    static var display: String { "v\(version) · 빌드 \(build)" }
}
