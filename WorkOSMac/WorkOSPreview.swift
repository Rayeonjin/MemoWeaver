import AppKit
import SwiftUI
import WebKit
import PDFKit
import UniformTypeIdentifiers

struct WorkOSHTMLPreview: NSViewRepresentable {
    let html: String
    let focusLine: Int

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: conf)
        web.navigationDelegate = context.coordinator
        context.coordinator.lastHTML = html
        context.coordinator.desiredLine = max(1, focusLine)
        context.coordinator.beginLoad(html, in: web)
        return web
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let line = max(1, focusLine)
        coordinator.desiredLine = line
        if coordinator.lastHTML != html {
            coordinator.lastHTML = html
            // In-flight WebKit navigations are not repeatedly interrupted.
            // Keep only the latest desired snapshot and load it on completion.
            coordinator.enqueue(html, in: view)
        } else if coordinator.contentLoaded && coordinator.lastFocusedLine != line {
            coordinator.scrollToCaret(in: view)
        }
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""              // latest SwiftUI snapshot, not last displayed
        var desiredLine = 1
        var lastFocusedLine = 0
        var contentLoaded = false
        var previewEpoch = 0
        private var loading = false
        private var patching = false
        private var loadingHTML = ""
        private var navigationStartedAt: TimeInterval = 0
        private var queuedHTML: String?
        private var installedMath = false
        private var installedDiagrams = false
        private var styleSignature: String?

        func enqueue(_ html: String, in view: WKWebView) {
            // A long navigation or DOM patch must never replay every obsolete
            // intermediate snapshot. Only the newest body is retained.
            if loading || patching {
                queuedHTML = html
                return
            }
            apply(html, in: view)
        }

        private func apply(_ html: String, in view: WKWebView) {
            let incoming = MemoWeaverLivePreviewDocument(html: html)
            if contentLoaded,
               MemoWeaverLivePreviewUpdateCore.action(
                    currentStyle: styleSignature, mathLoaded: installedMath,
                    diagramsLoaded: installedDiagrams, incoming: incoming) == .patch,
               let incoming {
                patch(incoming, originalHTML: html, in: view)
            } else {
                beginLoad(html, in: view)
            }
        }

        func beginLoad(_ html: String, in view: WKWebView) {
            let incoming = MemoWeaverLivePreviewDocument(html: html)
            let wantsDiagrams = incoming?.requiresDiagrams ?? false
            // Add the 5.6 MB official engine only when first required. After
            // this, KEEP it installed: removing/readding scripts would trigger
            // a full WebKit navigation whenever a fence is edited or removed.
            if wantsDiagrams && !installedDiagrams {
                if let source = WorkOSOfficialDiagramRuntime.source {
                    view.configuration.userContentController.addUserScript(WKUserScript(
                        source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
                }
                // Even if the optional bundle is unavailable, fallback SVGs
                // can still update without repeated failed full navigations.
                installedDiagrams = true
            }
            installedMath = incoming?.requiresMath ?? false
            styleSignature = incoming?.styleSignature
            loading = true
            patching = false
            loadingHTML = html
            navigationStartedAt = Date.timeIntervalSinceReferenceDate
            contentLoaded = false
            lastFocusedLine = 0
            previewEpoch += 1
            view.loadHTMLString(html, baseURL: nil)
        }

        private static let patchScript = #"""
        const staging = document.createElement('div');
        staging.innerHTML = fragment;
        const nextArticle = staging.querySelector('article');
        const currentArticle = document.body.querySelector('article');
        if (!nextArticle || !currentArticle) throw new Error('preview article missing');
        const nextHeading = staging.querySelector('h1');
        const nextMeta = staging.querySelector('.metadata');
        // Preserve completed Mermaid and Markmap nodes if their source is
        // unchanged. This retains pan/zoom and avoids rebuilding SVG/observers
        // while the user is editing an unrelated paragraph or Math block.
        let newDiagrams = 0;
        const previousDiagrams = Array.from(currentArticle.querySelectorAll('[data-workos-diagram]'));
        const incomingDiagrams = Array.from(nextArticle.querySelectorAll('[data-workos-diagram]'));
        for (let i = 0; i < incomingDiagrams.length; i++) {
          const oldNode = previousDiagrams[i], newNode = incomingDiagrams[i];
          if (oldNode && oldNode.getAttribute('data-workos-diagram') === newNode.getAttribute('data-workos-diagram') &&
              oldNode.getAttribute('data-workos-source') === newNode.getAttribute('data-workos-source')) {
            newNode.replaceWith(oldNode);
          } else {
            newDiagrams++;
          }
        }
        // Reuse rendered MathML whenever its source and display mode did not
        // change. KaTeX output is expensive for long technical notes; copying
        // the ready element avoids re-typesetting ALL equations on each edit.
        // Unrendered (fallback) expressions are never copied as 'ready'.
        const previousFormulae = Array.from(currentArticle.querySelectorAll('.formula, .formula-inline'));
        const incomingFormulae = Array.from(nextArticle.querySelectorAll('.formula, .formula-inline'));
        for (let i = 0; i < incomingFormulae.length; i++) {
          const previous = previousFormulae[i], incoming = incomingFormulae[i];
          if (previous && previous.getAttribute('data-tex') === incoming.getAttribute('data-tex') &&
              previous.classList.contains('formula') === incoming.classList.contains('formula') &&
              previous.querySelector('math')) {
            incoming.replaceWith(previous);
          }
        }
        for (const existing of Array.from(document.body.children)) {
          if (existing.tagName === 'H1' || existing.classList.contains('metadata'))
            existing.remove();
        }
        currentArticle.replaceWith(nextArticle);
        if (nextHeading) { nextArticle.before(nextHeading); document.title = nextHeading.textContent || ''; }
        if (nextMeta) nextArticle.before(nextMeta);
        for (const el of nextArticle.querySelectorAll('.formula, .formula-inline')) {
          if (!window.WorkOSKaTeX) break;
          if (el.querySelector('math')) continue; // unchanged and already typeset
          try {
            el.innerHTML = window.WorkOSKaTeX.renderToString(el.getAttribute('data-tex') || '', {
              displayMode: el.classList.contains('formula'), output: 'mathml',
              throwOnError: false, trust: false, strict: 'warn', maxExpand: 200, maxSize: 25
            });
          } catch (_) { el.textContent = el.getAttribute('data-tex') || ''; }
        }
        // The official bridge already lives in this page. It renders new
        // wrappers asynchronously; never block live text/Math DOM updates.
        if (newDiagrams > 0 && window.MemoryHomeOfficialDiagrams) {
          // One active render and one latest-only rerender request. An edit
          // burst must not enqueue dozens of expensive Mermaid renders.
          if (window.__MWDiagramRefreshRunning) {
            window.__MWDiagramRefreshAgain = true;
          } else {
            window.__MWDiagramRefreshRunning = true;
            window.WorkOSReady = false;
            const previous = Promise.resolve(window.WorkOSDiagramReady).catch(() => {});
            const job = previous.then(async () => {
              do {
                window.__MWDiagramRefreshAgain = false;
                await window.MemoryHomeOfficialDiagrams.renderAll();
              } while (window.__MWDiagramRefreshAgain);
            }).catch(() => {}).finally(() => {
              window.__MWDiagramRefreshRunning = false;
              window.WorkOSReady = true;
            });
            window.WorkOSDiagramReady = job;
          }
        }
        return true;
        """#

        private func patch(_ document: MemoWeaverLivePreviewDocument,
                           originalHTML: String, in view: WKWebView) {
            patching = true
            let startedAt = Date.timeIntervalSinceReferenceDate
            let epoch = previewEpoch
            view.callAsyncJavaScript(Self.patchScript,
                                     arguments: ["fragment": document.fragment],
                                     in: nil, in: .page) { [weak self, weak view] result in
                guard let self, let view, epoch == self.previewEpoch else { return }
                self.patching = false
                MemoWeaverPreviewDiagnostics.record("dom-patch", startedAt: startedAt)
                switch result {
                case .success:
                    self.contentLoaded = true
                    self.scrollToCaret(in: view)
                    self.finishQueued(in: view, displayedHTML: originalHTML)
                case .failure:
                    // A terminated WebContent process or a failed DOM update
                    // must recover with a complete document, never leave a
                    // stale preview silently on screen.
                    let latest = self.queuedHTML ?? self.lastHTML
                    self.queuedHTML = nil
                    self.beginLoad(latest, in: view)
                }
            }
        }

        private func finishQueued(in view: WKWebView, displayedHTML: String) {
            guard let queued = queuedHTML else { return }
            queuedHTML = nil
            if queued != displayedHTML { apply(queued, in: view) }
        }

        private func finishLoad(in webView: WKWebView, succeeded: Bool) -> Bool {
            loading = false
            contentLoaded = succeeded
            MemoWeaverPreviewDiagnostics.record("full-navigation", startedAt: navigationStartedAt)
            if let queued = queuedHTML {
                queuedHTML = nil
                if queued != loadingHTML {
                    apply(queued, in: webView)
                    return false
                }
            }
            return succeeded
        }

        func scrollToCaret(in view: WKWebView) {
            let line = max(1, desiredLine)
            lastFocusedLine = line
            let script = """
            (function(){
              const src = \(line);
              const targets = document.querySelectorAll('[data-md-line]');
              let match = null, best = -1;
              for (const element of targets) {
                const n = Number(element.getAttribute('data-md-line'));
                if (Number.isFinite(n) && n <= src && n >= best) {
                  best = n; match = element;
                }
              }
              if (!match) return;
              const top = match.getBoundingClientRect().top;
              const h = Math.max(1, window.innerHeight);
              if (top < h*0.18 || top > h*0.68)
                window.scrollTo(0, Math.max(0, window.scrollY + top - h*0.30));
            })();
            """
            view.evaluateJavaScript(script, completionHandler: nil)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard finishLoad(in: webView, succeeded: true) else { return }
            scrollToCaret(in: webView)
            // A full navigation may introduce new Mermaid/Markmap objects.
            // Follow only the current epoch and do not delay newer edits.
            let finishScript = """
            await Promise.race([
              Promise.resolve(window.WorkOSDiagramReady).catch(() => {}),
              new Promise(resolve => setTimeout(resolve, 10000))
            ]);
            return true;
            """
            let epoch = previewEpoch
            webView.callAsyncJavaScript(finishScript, arguments: [:], in: nil,
                                        in: .page) { [weak self, weak webView] _ in
                guard let self, let webView, self.contentLoaded,
                      self.previewEpoch == epoch else { return }
                self.scrollToCaret(in: webView)
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            _ = finishLoad(in: webView, succeeded: false)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            _ = finishLoad(in: webView, succeeded: false)
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loading = false
            patching = false
            contentLoaded = false
            queuedHTML = nil
            beginLoad(lastHTML, in: webView)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.navigationType == .linkActivated ? .cancel : .allow)
        }
    }

}

// The unified right-side panel provides tabs and a single close action.
// This view only renders locally, with no editor or duplicate toolbar.
struct WorkOSSidePreviewPane: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("memoweaver.preview.appearance") private var previewAppearance = "system"
    let html: String
    let focusLine: Int

    private var darkPreview: Bool {
        previewAppearance == "dark" ||
            (previewAppearance == "system" && systemColorScheme == .dark)
    }

    var body: some View {
        WorkOSHTMLPreview(html: MemoWeaverPreviewAppearance.apply(html, dark: darkPreview),
                          focusLine: focusLine)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
enum WorkOSNoteExport {
    enum Format: String, CaseIterable {
        case markdown = "md"
        case html = "html"
        case pdf = "pdf"
        var title: String {
            switch self { case .markdown: return "Markdown"; case .html: return "HTML"; case .pdf: return "PDF" }
        }
    }

    static func export(_ note: WorkNote, format: Format, completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSSavePanel()
        let safeName = note.visibleTitle.replacingOccurrences(of: #"[/\\:]+"#, with: "_", options: .regularExpression)
        panel.nameFieldStringValue = String(safeName.prefix(70)) + "." + format.rawValue
        panel.allowedContentTypes = [UTType(filenameExtension: format.rawValue) ?? .data]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            switch format {
            case .markdown:
                let markdown = NoteDocuments.markdown(note: note)
                // A portable .md export needs its relative attachment files,
                // not just a link that works inside this Mac's app support.
                try MemoWeaverAttachments.exportMarkdownAssets(
                    from: markdown, to: destination.deletingLastPathComponent())
                try markdown.write(to: destination, atomically: true, encoding: .utf8)
                completion(.success(destination))
            case .html:
                try NoteDocuments.html(note: note).write(to: destination, atomically: true, encoding: .utf8)
                completion(.success(destination))
            case .pdf:
                WorkOSPDFJob.start(NoteDocuments.html(note: note), url: destination, completion: completion)
            }
        } catch { completion(.failure(error)) }
    }
}

// Export standard-sized PDF pages rather than a truncated, 60,000pt tall page.
// The WebKit render remains offline and retains MathML/diagram readiness wait.
@MainActor
final class WorkOSPDFJob: NSObject, WKNavigationDelegate {
    private static var running: [UUID: WorkOSPDFJob] = [:]
    private let id = UUID()
    private let url: URL
    private let completion: (Result<URL, Error>) -> Void
    private var web: WKWebView?
    private let combined = PDFDocument()
    private var currentPage = 0
    private var totalPages = 0
    private let pageWidth: CGFloat = 820
    private let pageHeight: CGFloat = 1140

    private init(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.url = url
        self.completion = completion
    }

    static func start(_ html: String, url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let job = WorkOSPDFJob(url: url, completion: completion)
        running[job.id] = job
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 820, height: 1140), configuration: config)
        job.web = view
        view.navigationDelegate = job
        view.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let waitScript = """
        const waitFor = window.WorkOSDiagramReady || Promise.resolve();
        // Inline attachment images also have to finish decoding before their
        // layout is measured and printed (including images below page one).
        const imagesReady = Promise.all(Array.from(document.images).map(img =>
          img.complete ? Promise.resolve() : new Promise(resolve => {
            img.addEventListener('load', resolve, { once: true });
            img.addEventListener('error', resolve, { once: true });
          })));
        await Promise.race([
          Promise.all([Promise.resolve(waitFor).catch(() => {}), imagesReady]),
          new Promise(resolve => setTimeout(resolve, 10000))
        ]);
        return Math.ceil(Math.max(document.documentElement.scrollHeight, document.body.scrollHeight));
        """
        webView.callAsyncJavaScript(waitScript, arguments: [:], in: nil, in: .page) { [weak self] result in
            guard let self else { return }
            guard let number = (try? result.get()) as? NSNumber else {
                self.fail("HTML 문서의 전체 높이를 읽지 못해 PDF 생성을 중단했습니다.")
                return
            }
            let pixels = number.doubleValue
            guard pixels.isFinite && pixels > 0 else {
                self.fail("PDF 원문의 높이가 유효하지 않습니다.")
                return
            }
            let pages = Int(ceil(pixels / Double(self.pageHeight)))
            // Do not silently truncate long documents. Fail with a clear reason
            // before consuming unlimited memory for pathological documents.
            guard pages > 0 && pages <= 3000 else {
                self.fail("PDF는 최대 3,000페이지까지 지원합니다. 더 긴 자료는 원문 Markdown/HTML로 내보내세요.")
                return
            }
            self.totalPages = pages
            self.exportNextPage()
        }
    }

    private func exportNextPage() {
        guard let web else { fail("PDF 렌더링 창이 닫혔습니다."); return }
        if currentPage >= totalPages {
            guard combined.pageCount == totalPages,
                  let data = combined.dataRepresentation(), !data.isEmpty else {
                fail("PDF 페이지 수가 원문과 일치하지 않아 파일을 저장하지 않았습니다.")
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                finish(.success(url))
            } catch { finish(.failure(error)) }
            return
        }
        let y = CGFloat(currentPage) * pageHeight
        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: y, width: pageWidth, height: pageHeight)
        web.createPDF(configuration: config) { [weak self] result in
            guard let self else { return }
            do {
                let data = try result.get()
                guard let page = PDFDocument(data: data)?.page(at: 0) else {
                    self.fail("PDF \(self.currentPage + 1)페이지를 변환하지 못했습니다.")
                    return
                }
                self.combined.insert(page, at: self.combined.pageCount)
                self.currentPage += 1
                self.exportNextPage()
            } catch { self.finish(.failure(error)) }
        }
    }

    private func fail(_ reason: String) {
        finish(.failure(NSError(domain: "MemoWeaver.PDF", code: 1,
            userInfo: [NSLocalizedDescriptionKey: reason])))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }
    private func finish(_ result: Result<URL, Error>) {
        web?.navigationDelegate = nil
        web = nil
        Self.running.removeValue(forKey: id)
        completion(result)
    }
}
