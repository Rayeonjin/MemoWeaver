import Foundation
import SwiftUI

private final class UpdateProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String, [String:String]))?
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            Self.requests.append(request)
            guard let handler = Self.handler else { throw URLError(.notConnectedToInternet) }
            let (code, body, headers) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self, didLoad:Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError:error) }
    }
    override func stopLoading() {}
}
private actor DelayedChecker: MemoWeaverUpdateChecking {
    var pending: [CheckedContinuation<MemoWeaverUpdateResult, Error>] = []
    func check(currentVersion: String) async throws -> MemoWeaverUpdateResult {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
    func count() -> Int { pending.count }
    func finish(_ result: MemoWeaverUpdateResult) { pending.removeFirst().resume(returning:result) }
}
@main struct UpdateCheckSmoke {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
    static func candidate(_ tag: String, _ origin: MemoWeaverPublicVersion.Origin = .tag) -> MemoWeaverPublicVersion {
        .init(tag: tag, version: MemoWeaverVersion(tag)!, origin: origin, isPrerelease: !MemoWeaverVersion(tag)!.prerelease.isEmpty)
    }
    @MainActor static func main() async throws {
        let order = ["0.9.9", "0.9.66-qa.2", "0.9.66-qa.10", "0.9.66", "0.9.67-qa", "0.9.67", "0.10.0", "1.0.0"]
        let versions=order.map { MemoWeaverVersion($0)! }
        check(versions.sorted() == versions, "numeric semantic order and prerelease precedence")
        check(MemoWeaverVersion("v1.2.3+build.001") == MemoWeaverVersion("1.2.3"), "v prefix/metadata ignore precedence")
        for invalid in ["", "v", "1.2", "1.2.3.4", "01.2.3", "1.2.3-", "1.2.3-qa.01", "1.2.3+", "1.2.3+bad/metadata", "../1.2.3", "1.2.3/other", "1.2.3-한글", "99999999999999999999999999999999999.0.0"] {
            check(MemoWeaverVersion(invalid)==nil, "invalid version accepted: "+invalid)
        }
        let stable=candidate("v0.9.67",.release), beta=candidate("v0.9.68-beta.1")
        check(MemoWeaverUpdateService.newest([stable,beta])==beta, "new public beta included")
        check(MemoWeaverUpdateService.newest([candidate("v0.9.67"), stable])==stable, "release preferred for equal tag")
        check(beta.pageURL.absoluteString == "https://github.com/Rayeonjin/MemoWeaver/tree/v0.9.68-beta.1", "safe tag link")
        check(stable.pageURL.absoluteString == "https://github.com/Rayeonjin/MemoWeaver/releases/tag/v0.9.67", "safe release link")
        check(beta.sourceURL.host == "github.com" && beta.sourceURL.path.hasSuffix(".zip"), "fixed source ZIP origin")
        let config=URLSessionConfiguration.ephemeral; config.protocolClasses=[UpdateProtocol.self]
        let session=URLSession(configuration:config); defer { session.invalidateAndCancel() }
        let service=MemoWeaverUpdateService(session:session)
        UpdateProtocol.handler={ request in
            precondition(request.url?.host == "api.github.com" && request.httpBody == nil)
            precondition(request.value(forHTTPHeaderField:"Authorization")==nil && request.value(forHTTPHeaderField:"Cookie")==nil)
            precondition(request.value(forHTTPHeaderField:"User-Agent")=="MemoWeaver-UpdateCheck")
            if request.url!.path.hasSuffix("releases") {
                return (200,#"[{"tag_name":"v99.0.0","draft":true,"prerelease":false},{"tag_name":"broken","draft":false,"prerelease":false},{"tag_name":"v0.9.66-qa","draft":false,"prerelease":true,"html_url":"https://untrusted.example"}]"#,[:])
            }
            let page=URLComponents(url:request.url!,resolvingAgainstBaseURL:false)!.queryItems!.first { $0.name=="page" }!.value
            if page=="1" { return (200,#"[{"name":"v0.9.66-qa"}]"#,["Link":"<https://untrusted.example/next>; rel=\"next\""]) }
            return (200,#"[{"name":"v0.9.67-qa"}]"#,[:])
        }
        let result=try await service.check(currentVersion:"0.9.66-qa")
        check(result.hasUpdate && result.latest.tag=="v0.9.67-qa", "newer tag must not be hidden by older Release")
        check(UpdateProtocol.requests.count==3, "fixed pagination and both feeds")
        check(result.latest.pageURL.host=="github.com", "untrusted API URL ignored")
        UpdateProtocol.handler={ _ in (200,"[]",[:]) }
        do { _=try await service.check(currentVersion:"0.9.67"); preconditionFailure("empty feed claimed current") }
        catch MemoWeaverUpdateError.noVersions {}
        for status in [403,429,500,404] {
            UpdateProtocol.handler={ _ in (status,"[]",[:]) }
            do { _=try await service.check(currentVersion:"0.9.67");preconditionFailure("HTTP failure claimed current") }
            catch { check(error is MemoWeaverUpdateError,"typed HTTP error") }
        }
        UpdateProtocol.handler={ _ in (200,"invalid JSON",[:]) }
        do { _=try await service.check(currentVersion:"0.9.67");preconditionFailure("malformed feed claimed current") } catch {}
        UpdateProtocol.handler={ _ in throw URLError(.notConnectedToInternet) }
        do { _=try await service.check(currentVersion:"0.9.67");preconditionFailure("offline claimed current") } catch {}
        UpdateProtocol.handler={ _ in (200,"[]",["Link":"<https://anything.invalid>; rel=\"next\""]) }
        do { _=try await service.check(currentVersion:"0.9.67");preconditionFailure("incomplete feed claimed current") }
        catch MemoWeaverUpdateError.incompleteList {}
        let equal=MemoWeaverUpdateResult(current:MemoWeaverVersion("0.9.67-qa")!,latest:candidate("v0.9.67-qa"))
        check(!equal.hasUpdate && !equal.isAhead, "QA tag compares equal to matching app tag")
        check(MemoWeaverUpdateResult(current:MemoWeaverVersion("0.9.68")!,latest:equal.latest).isAhead, "local development build ahead")
        // The controller never contacts the network during construction. A
        // cancelled old completion cannot overwrite a later manual request.
        let delayed=DelayedChecker()
        let controller=MemoWeaverUpdateController(service:delayed,currentVersion:"0.9.67-qa")
        check(controller.state == .idle,"initial state")
        let initialRequests=await delayed.count(); check(initialRequests==0,"startup made a request")
        controller.check();controller.check()
        while await delayed.count()<1 { await Task.yield() }
        let duplicateRequests=await delayed.count(); check(duplicateRequests==1,"duplicate button check")
        controller.cancel();controller.check()
        while await delayed.count()<2 { await Task.yield() }
        await delayed.finish(.init(current:MemoWeaverVersion("0.9.67-qa")!,latest:candidate("v9.0.0")))
        for _ in 0..<10 { await Task.yield() }
        check(controller.state == .checking,"old cancelled response overwrote new request")
        await delayed.finish(equal)
        while controller.state == .checking { await Task.yield() }
        check(controller.state == .completed(equal),"active request result missing")
        print("PASS: semantic/QA versions, fixed public endpoints, stable/beta/tag selection, paging, no credentials/body, error safety, manual-only request and cancellation generation")
    }
}
