import Foundation

@MainActor
extension WorkOSModel {
    // The editor, archive viewer and semantic search use the same immutable
    // one-based pointers. Cached pointers are valid only for the current source.
    func virtualSource(kind: String, id: String) -> String? {
        if kind == "archive" {
            guard archives.contains(where: { $0.id == id }) else { return nil }
            return try? database?.archiveText(id: id)
        }
        guard kind == "note", let note = notes.first(where: { $0.id == id && $0.deletedAt.isEmpty }) else { return nil }
        // Match the actual plain editor document, not plainBody's additional
        // progress/WorkOSBlocks fields (which have different line numbers).
        return LegacyNoteTextConverter.editableText(for: note)
    }

    func reloadVirtualMemories() {
        invalidateMemoryDisplayCaches()
        guard let database else { return }
        do {
            let stored = try database.virtualMemories()
            var signatures: [String: String] = [:]
            var stale: Set<String> = []
            // Resolve revisions once. Looking up the parent note/archived file
            // for each segment otherwise scales as O(source segments * notes).
            let noteRevisions = Dictionary(uniqueKeysWithValues:
                notes.filter { $0.deletedAt.isEmpty }.map { ($0.id, $0.updatedAt) })
            let archiveRevisions = Dictionary(uniqueKeysWithValues:
                archives.map { ($0.id, $0.addedAt) })
            virtualMemories = stored.filter { item in
                let key = item.sourceKind + ":" + item.sourceID
                if signatures[key] == nil {
                    let revision = item.sourceKind == "note"
                        ? noteRevisions[item.sourceID] : archiveRevisions[item.sourceID]
                    if let revision, let cached = virtualSourceSignatureCache[key],
                       cached.revision == revision {
                        signatures[key] = cached.signature
                    } else {
                        let signature = virtualSource(kind: item.sourceKind, id: item.sourceID)
                            .map(VirtualMemoryCore.signature) ?? "missing"
                        signatures[key] = signature
                        if let revision {
                            virtualSourceSignatureCache[key] = (revision: revision, signature: signature)
                        } else {
                            virtualSourceSignatureCache.removeValue(forKey: key)
                        }
                    }
                }
                if signatures[key] == item.sourceSignature { return true }
                stale.insert(key)
                return false
            }
            staleVirtualSources = stale
        } catch { statusMessage = "가상 메모 목록을 불러오지 못함: \(error.localizedDescription)" }
    }

    /// Ordinary editing invalidates only the edited source. A large imported
    /// scratchpad must not force hashing every other 10,000-line source on save.
    func invalidateVirtualSourceAfterEdit(kind: String, id: String) {
        let key = kind + ":" + id
        virtualSourceSignatureCache.removeValue(forKey: key)
        let matching = virtualMemories.filter { $0.sourceKind == kind && $0.sourceID == id }
        guard !matching.isEmpty else { return }
        let signature = virtualSource(kind: kind, id: id).map(VirtualMemoryCore.signature) ?? "missing"
        if matching.contains(where: { $0.sourceSignature != signature }) {
            virtualMemories.removeAll { $0.sourceKind == kind && $0.sourceID == id }
            staleVirtualSources.insert(key)
        }
    }

    func virtualSourceTexts() -> [String: String] {
        var result: [String: String] = [:]
        for segment in virtualMemories {
            let key = segment.sourceKind + ":" + segment.sourceID
            if result[key] == nil {
                result[key] = virtualSource(kind: segment.sourceKind, id: segment.sourceID)
            }
        }
        return result
    }

    func allMemoryIndexItems(notes: [WorkNote], chunks: [WorkChunk]) -> [MemoryIndexItem] {
        let noteIDs = Set(notes.map(\.id))
        let archiveIDs = Set(chunks.map(\.sourceID))
        let included = virtualMemories.filter {
            ($0.sourceKind == "note" && noteIDs.contains($0.sourceID)) ||
            ($0.sourceKind == "archive" && archiveIDs.contains($0.sourceID))
        }
        var contents: [String: String] = [:]
        for segment in included {
            let key = segment.sourceKind + ":" + segment.sourceID
            if contents[key] == nil { contents[key] = virtualSource(kind: segment.sourceKind, id: segment.sourceID) }
        }
        return MemoryEngine.items(notes: notes, chunks: chunks, virtualMemories: included,
            virtualSourceTexts: contents)
    }

    func virtualMemories(kind: String, id: String) -> [VirtualMemory] {
        virtualMemories.filter { $0.sourceKind == kind && $0.sourceID == id }
    }

    func openVirtualMemory(_ segment: VirtualMemory) {
        guard let source = virtualSource(kind: segment.sourceKind, id: segment.sourceID),
              VirtualMemoryCore.available(segment, source: source) else {
            statusMessage = "원문이 변경되어 해당 가상 메모 위치를 검증할 수 없습니다. 다시 분석하세요."
            return
        }
        if segment.sourceKind == "archive" {
            openArchiveExcerpt(segment.sourceID, fromLine: segment.fromLine, toLine: segment.toLine)
        } else {
            openNote(segment.sourceID, focusLine: segment.fromLine)
        }
        statusMessage = "가상 메모 · 원문 \(segment.lineLabel) · \(segment.title)"
    }

    func startVirtualAnalysis(kind: String, id: String, useAI: Bool) {
        guard !isAnalyzingVirtual, let database,
              let source = virtualSource(kind: kind, id: id),
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            virtualAnalysisStatus = "분석할 원문이 없습니다."
            return
        }
        let selectedModel = aiModels.first { $0.name == aiModelName && $0.supportsChat }
            ?? aiModels.first { $0.supportsChat }
        if useAI && (!aiConnected || selectedModel == nil) {
            virtualAnalysisStatus = "로컬 AI 연결 확인 후 채팅 모델을 선택하세요. 빠른 분석은 AI 없이도 실행할 수 있습니다."
            return
        }
        let sourceSignature = VirtualMemoryCore.signature(source)
        let sourceLines = VirtualMemoryCore.lines(source)
        let batches = VirtualMemoryCore.batches(source)
        guard !batches.isEmpty else { return }
        isAnalyzingVirtual = true
        virtualAnalysisProgress = 0
        virtualAnalysisStatus = useAI ? "Ollama가 \(batches.count)개 구간을 순서대로 분석합니다. 원본은 변경하지 않습니다." :
            "원문 구조를 빠르게 분석하는 중입니다."
        virtualAnalysisTarget = kind + ":" + id
        virtualAnalysisTask = Task { @MainActor in
            defer {
                isAnalyzingVirtual = false
                virtualAnalysisTarget = ""
                virtualAnalysisTask = nil
            }
            do {
                var result: [VirtualMemory] = []
                var fallbackCount = 0
                let sourceTitle = kind == "archive" ?
                    (archives.first(where: { $0.id == id })?.name ?? "오래된 기록") :
                    (notes.first(where: { $0.id == id })?.visibleTitle ?? "메모")
                for (index, batch) in batches.enumerated() {
                    try Task.checkCancellation()
                    var groups: [VirtualMemoryAIGroup]?
                    if useAI, let selectedModel {
                        let response = try await ollama.analyzeVirtualBatch(batch, model: selectedModel.name)
                        try Task.checkCancellation()
                        groups = VirtualMemoryCore.decodeGroups(response, blockCount: batch.blocks.count)
                        if groups == nil { fallbackCount += 1 }
                    }
                    result += VirtualMemoryCore.make(source: source, kind: kind, sourceID: id,
                        sourceTitle: sourceTitle, batch: batch, groups: groups, ai: groups != nil,
                        sourceSignature: sourceSignature, sourceLines: sourceLines)
                    virtualAnalysisProgress = Double(index + 1) / Double(batches.count)
                    virtualAnalysisStatus = "분석 중 · \(index + 1)/\(batches.count) 구간 · 임시 메모 \(result.count)개"
                    if !useAI && index.isMultiple(of: 50) { await Task.yield() }
                }
                try Task.checkCancellation()
                guard virtualSource(kind: kind, id: id).map(VirtualMemoryCore.signature) == sourceSignature else {
                    virtualAnalysisStatus = "분석 도중 원문이 수정되어 결과를 저장하지 않았습니다. 다시 분석하세요."
                    return
                }
                guard VirtualMemoryCore.valid(result, source: source, kind: kind, id: id) else {
                    virtualAnalysisStatus = "원문 줄 범위 검증 실패 · 기존 색인은 보존했습니다."
                    return
                }
                try database.saveVirtualMemories(result, source: source, kind: kind, id: id)
                reloadVirtualMemories()
                // Re-analyzed virtual IDs may be reused; remove any cached
                // inference rows that SQLite invalidated with old segments.
                inferredMemoryRelations = try database.aiMemoryRelations()
                inferredMemoryFacts = try database.aiMemoryFacts()
                // The vectors will be refreshed explicitly by the existing
                // bge-m3 index command; never block normal editing here.
                memoryCacheLoaded = false
                memoryVectors = []
                requestBackgroundCorpusIndex()
                regenerateMemoryGraphIfVisible()
                virtualAnalysisStatus = "\(result.count)개 가상 메모 생성 · 원문 전체 \(VirtualMemoryCore.lines(source).count)행 보존" +
                    (fallbackCount > 0 ? " · AI 응답 오류 \(fallbackCount)개 구간은 임시 분할" : "") +
                    " · 기억 지도에서 의미 색인을 실행하면 연결됩니다."
            } catch is CancellationError {
                virtualAnalysisStatus = "분석 취소됨 · 기존 가상 메모는 그대로 유지됩니다."
            } catch {
                virtualAnalysisStatus = "분석 실패 · 기존 가상 메모 유지: \(error.localizedDescription)"
            }
        }
    }

    func stopVirtualAnalysis() { virtualAnalysisTask?.cancel() }

    func clearVirtualAnalysis(kind: String, id: String) {
        guard !isAnalyzingVirtual, let database else { return }
        do {
            try database.removeVirtualMemories(kind: kind, id: id)
            reloadVirtualMemories()
            inferredMemoryRelations = try database.aiMemoryRelations()
            inferredMemoryFacts = try database.aiMemoryFacts()
            memoryVectors = []
            memoryCacheLoaded = false
            virtualAnalysisStatus = "가상 메모 색인만 삭제했습니다. 원본은 변경하지 않았습니다."
            regenerateMemoryGraphIfVisible()
        } catch { show(error) }
    }
}
