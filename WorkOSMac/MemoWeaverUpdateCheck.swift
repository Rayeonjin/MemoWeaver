import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Semantic precedence is local. GitHub never receives the installed version,
// note text, a database path, an account token or a file from the user's store.
struct MemoWeaverVersion: Comparable {
    let numbers: [Int]
    let prerelease: [String]

    init?(_ raw: String) {
        guard !raw.isEmpty, raw.utf8.count <= 200 else { return nil }
        let tag = raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
        let metadata = tag.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        func identifier(_ value: Substring) -> Bool {
            !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }
        }
        if metadata.count == 2 {
            guard metadata[1].split(separator: ".", omittingEmptySubsequences: false).allSatisfy(identifier) else { return nil }
        }
        let version = metadata[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let components = version[0].split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        var parsed: [Int] = []
        for component in components {
            guard !component.isEmpty, component.utf8.allSatisfy({ (48...57).contains($0) }),
                  component.count == 1 || component.first != "0", let number = Int(component) else { return nil }
            parsed.append(number)
        }
        let suffix = version.count == 2 ? version[1].split(separator: ".", omittingEmptySubsequences: false) : []
        guard suffix.allSatisfy(identifier) else { return nil }
        for part in suffix where part.utf8.allSatisfy({ (48...57).contains($0) }) {
            guard part.count == 1 || part.first != "0" else { return nil }
        }
        numbers = parsed
        prerelease = suffix.map(String.init)
    }

    static func < (a: Self, b: Self) -> Bool {
        if a.numbers != b.numbers { return a.numbers.lexicographicallyPrecedes(b.numbers) }
        if a.prerelease.isEmpty { return false }
        if b.prerelease.isEmpty { return true }
        for (left, right) in zip(a.prerelease, b.prerelease) where left != right {
            let lNumeric = left.utf8.allSatisfy { (48...57).contains($0) }
            let rNumeric = right.utf8.allSatisfy { (48...57).contains($0) }
            if lNumeric != rNumeric { return lNumeric }
            if lNumeric && left.count != right.count { return left.count < right.count }
            return left < right
        }
        return a.prerelease.count < b.prerelease.count
    }
}

struct MemoWeaverPublicVersion: Equatable {
    enum Origin: Equatable { case release, tag }
    let tag: String
    let version: MemoWeaverVersion
    let origin: Origin
    let isPrerelease: Bool
    static let repository = URL(string: "https://github.com/Rayeonjin/MemoWeaver")!
    var pageURL: URL {
        Self.repository.appendingPathComponent(origin == .release ? "releases/tag" : "tree").appendingPathComponent(tag)
    }
    var sourceURL: URL {
        Self.repository.appendingPathComponent("archive/refs/tags").appendingPathComponent(tag + ".zip")
    }
}

struct MemoWeaverUpdateResult: Equatable {
    let current: MemoWeaverVersion
    let latest: MemoWeaverPublicVersion
    var hasUpdate: Bool { current < latest.version }
    var isAhead: Bool { latest.version < current }
    var message: String {
        let suffix = latest.isPrerelease ? " · 사전 버전(QA/베타)" : ""
        if hasUpdate { return "새 버전이 있습니다: \(latest.tag)\(suffix)" }
        if isAhead { return "현재 앱이 공개 버전 \(latest.tag)보다 새로운 버전입니다." }
        return "현재 최신 버전입니다: \(latest.tag)\(suffix)"
    }
}

enum MemoWeaverUpdateError: LocalizedError {
    case invalidVersion, invalidResponse, rateLimited, noVersions, incompleteList, oversizedResponse
    var errorDescription: String? {
        switch self {
        case .invalidVersion: return "현재 앱의 버전 정보를 읽지 못했습니다. GitHub에서 버전을 확인해 주세요."
        case .rateLimited: return "GitHub 요청 한도에 도달했습니다. 잠시 후 다시 확인하거나 GitHub에서 버전을 확인해 주세요."
        case .noVersions: return "아직 확인할 수 있는 공개 버전이 없습니다."
        case .incompleteList: return "공개 버전 목록을 끝까지 확인하지 못했습니다. GitHub에서 버전을 확인해 주세요."
        case .invalidResponse, .oversizedResponse: return "GitHub의 버전 정보를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }
}

protocol MemoWeaverUpdateChecking {
    func check(currentVersion: String) async throws -> MemoWeaverUpdateResult
}

private final class MemoWeaverUpdateRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct MemoWeaverUpdateService: MemoWeaverUpdateChecking {
    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
    }
    private struct Tag: Decodable { let name: String }
    private let session: URLSession
    private static let publicSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config, delegate: MemoWeaverUpdateRedirectPolicy(), delegateQueue: nil)
    }()
    init(session: URLSession? = nil) { self.session = session ?? Self.publicSession }

    static func newest(_ values: [MemoWeaverPublicVersion]) -> MemoWeaverPublicVersion? {
        values.max { lhs, rhs in
            if lhs.version != rhs.version { return lhs.version < rhs.version }
            if lhs.origin != rhs.origin { return lhs.origin == .tag }
            return lhs.tag < rhs.tag
        }
    }

    func check(currentVersion: String) async throws -> MemoWeaverUpdateResult {
        guard let current = MemoWeaverVersion(currentVersion) else { throw MemoWeaverUpdateError.invalidVersion }
        var candidates: [MemoWeaverPublicVersion] = []
        // QA source tags are part of MemoWeaver's existing publication workflow.
        // Always check both feeds so an older Release cannot hide a newer tag.
        for feed in ["releases", "tags"] {
            for page in 1...5 {
                try Task.checkCancellation()
                var components = URLComponents(string: "https://api.github.com/repos/Rayeonjin/MemoWeaver/\(feed)")!
                components.queryItems = [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(page))]
                var request = URLRequest(url: components.url!)
                request.setValue("MemoWeaver-UpdateCheck", forHTTPHeaderField: "User-Agent")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      http.url == request.url else { throw MemoWeaverUpdateError.invalidResponse }
                if http.statusCode == 403 || http.statusCode == 429 { throw MemoWeaverUpdateError.rateLimited }
                guard http.statusCode == 200 else { throw MemoWeaverUpdateError.invalidResponse }
                guard data.count <= 4 * 1024 * 1024 else { throw MemoWeaverUpdateError.oversizedResponse }
                if feed == "releases" {
                    for release in try JSONDecoder().decode([Release].self, from: data) where !release.draft {
                        guard let version = MemoWeaverVersion(release.tag_name) else { continue }
                        candidates.append(.init(tag: release.tag_name, version: version, origin: .release,
                                                isPrerelease: release.prerelease || !version.prerelease.isEmpty))
                    }
                } else {
                    for tag in try JSONDecoder().decode([Tag].self, from: data) {
                        guard let version = MemoWeaverVersion(tag.name) else { continue }
                        candidates.append(.init(tag: tag.name, version: version, origin: .tag,
                                                isPrerelease: !version.prerelease.isEmpty))
                    }
                }
                // Follow only the presence of a next relation, never its URL.
                let link = http.value(forHTTPHeaderField: "Link") ?? ""
                let hasNext = link.range(of: #"\brel\s*=\s*\"?next\"?"#, options: .regularExpression) != nil
                if !hasNext { break }
                if page == 5 { throw MemoWeaverUpdateError.incompleteList }
            }
        }
        guard let latest = Self.newest(candidates) else { throw MemoWeaverUpdateError.noVersions }
        return .init(current: current, latest: latest)
    }
}
