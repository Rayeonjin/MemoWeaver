import AppKit
import Foundation

// Adaptive, resumable local AI. Persistent SQLite signatures identify stale
// embeddings and relations after a crash/relaunch; these in-memory IDs are
// only a light wake-up queue. No background task changes the note source.
@MainActor
extension WorkOSModel {
    var preferredBackgroundMode: MemoryIdlePolicy.Mode {
        let value = UserDefaults.standard.string(forKey: MemoryIdlePolicy.defaultsKey)
        return MemoryIdlePolicy.Mode(rawValue: value ?? "automatic") ?? .automatic
    }

    func editorWasUsed() {
        let now = Date()
        lastEditorActivityAt = now
        backgroundLastAppActivityAt = now
        // A waiting idle scheduler already checks these dates before it can
        // start a model request. Cancelling/recreating it per keystroke made
        // the editor do unrelated MainActor work on every input event.
        // Interrupt an ACTUALLY running automatic AI task promptly, with a
        // short limit on duplicate cancellation while the task unwinds.
        if (isAutomaticMemoryIndexing || isAutomaticRelationAnalysis),
           now.timeIntervalSince(lastEditorAIPauseAt) >= 0.75 {
            lastEditorAIPauseAt = now
            pauseAutomaticAI()
        }
        // Only starts a scheduler if none is already waiting; no DB/AI on
        // the editor typing path.
        if backgroundAITask == nil { scheduleBackgroundAI() }
    }

    func appDidReturnToForeground() {
        backgroundLastAppActivityAt = Date()
        pauseAutomaticAI()
        scheduleBackgroundAI()
    }

    func appMovedToBackground() {
        backgroundLastAppActivityAt = Date()
        scheduleBackgroundAI()
    }

    func backgroundModeDidChange() {
        pauseAutomaticAI()
        if preferredBackgroundMode == .manual {
            backgroundAIStatus = "수동 모드 · 자동 AI 분석 중지"
        } else {
            requestBackgroundCorpusIndex()
        }
    }

    // Local IDs only; never serialize note content or credentials in a queue.
    private func persistBackgroundQueues() {
        UserDefaults.standard.set(backgroundNoteQueue.sorted(), forKey: "workos.ai.pendingNoteIDs")
        UserDefaults.standard.set(backgroundRelationQueue.sorted(), forKey: "workos.ai.pendingRelationIDs")
    }

    private func restoreBackgroundQueuesOnce() {
        guard !backgroundQueueRestored else { return }
        backgroundQueueRestored = true
        let current = Set(notes.filter { $0.deletedAt.isEmpty }.map(\.id))
        var validEntities = Set(current.map { "note:" + $0 })
        validEntities.formUnion(virtualMemories.map { "virtual:" + $0.id })
        validEntities.formUnion(archives.map { "archive:" + $0.id })
        let noteIDs = UserDefaults.standard.stringArray(forKey: "workos.ai.pendingNoteIDs") ?? []
        let relationIDs = UserDefaults.standard.stringArray(forKey: "workos.ai.pendingRelationIDs") ?? []
        backgroundNoteQueue.formUnion(noteIDs.filter { current.contains($0) })
        // v0.9.12 saved raw note IDs. Migrate them to typed entity IDs.
        let restored = relationIDs.map { $0.contains(":") ? $0 : "note:" + $0 }
        backgroundRelationQueue.formUnion(restored.filter { validEntities.contains($0) })
        persistBackgroundQueues()
    }

    // On startup check only SQLite signatures while idle, not at launch.
    func requestBackgroundCorpusIndex() {
        guard preferredBackgroundMode != .manual else { return }
        restoreBackgroundQueuesOnce()
        backgroundCorpusPending = true
        scheduleBackgroundAI()
    }

    func requestBackgroundIndex(noteID: String) {
        guard preferredBackgroundMode != .manual else { return }
        backgroundNoteQueue.insert(noteID)
        backgroundRelationQueue.insert("note:" + noteID)
        persistBackgroundQueues()
        scheduleBackgroundAI()
    }

    // One-click initial migration: fill a persistent queue of independent
    // notes and validated virtual segments. This queues work but NEVER runs
    // inference on the editor/typing path. The automatic idle policy still
    // controls when it is executed; users may pause by choosing manual mode.
    func scheduleFullMemoryAnalysis() {
        restoreBackgroundQueuesOnce()
        let dividedNotes = Set(virtualMemories.filter { $0.sourceKind == "note" }.map(\.sourceID))
        let dividedArchives = Set(virtualMemories.filter { $0.sourceKind == "archive" }.map(\.sourceID))
        for note in notes where note.deletedAt.isEmpty && !dividedNotes.contains(note.id) {
            backgroundRelationQueue.insert("note:" + note.id)
        }
        for segment in virtualMemories where !staleVirtualSources.contains(segment.sourceKind + ":" + segment.sourceID) {
            backgroundRelationQueue.insert("virtual:" + segment.id)
        }
        for archive in archives where !dividedArchives.contains(archive.id) {
            backgroundRelationQueue.insert("archive:" + archive.id)
        }
        persistBackgroundQueues()
        backgroundCorpusPending = true
        backgroundAIStatus = "과거 기록 관계 분석 예약 · 대기 \(backgroundRelationQueue.count)개 · 유휴 시 처리"
        scheduleBackgroundAI()
    }

    private func pauseAutomaticAI() {
        backgroundAIRevision += 1
        backgroundAITask?.cancel()
        backgroundAITask = nil
        if isAutomaticMemoryIndexing { memoryIndexTask?.cancel() }
        if isAutomaticRelationAnalysis { relationInferenceTask?.cancel() }
    }

    private func scheduleBackgroundAI() {
        guard preferredBackgroundMode != .manual, backgroundAITask == nil,
              backgroundCorpusPending || !backgroundNoteQueue.isEmpty || !backgroundRelationQueue.isEmpty else { return }
        backgroundAIRevision += 1
        let revision = backgroundAIRevision
        backgroundAITask = Task { @MainActor in
            defer { if backgroundAIRevision == revision { backgroundAITask = nil } }
            while !Task.isCancelled {
                // Return without spinning if all incremental changes are done.
                if !backgroundCorpusPending && backgroundNoteQueue.isEmpty && backgroundRelationQueue.isEmpty { return }
                let systemIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
                let allowed = MemoryIdlePolicy.mayRun(
                    mode: preferredBackgroundMode, appActive: NSApp.isActive,
                    secondsSinceEditorActivity: Date().timeIntervalSince(lastEditorActivityAt),
                    secondsSinceAppActivity: Date().timeIntervalSince(backgroundLastAppActivityAt),
                    systemIdleSeconds: systemIdle,
                    lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    thermalPressure: ProcessInfo.processInfo.thermalState == .serious ||
                                     ProcessInfo.processInfo.thermalState == .critical)
                if !allowed || isIndexingMemory || isInferringMemory || isAnalyzingVirtual {
                    do { try await Task.sleep(nanoseconds: 3_000_000_000) }
                    catch { return }
                    continue
                }
                if !embeddingAvailable || !aiConnected {
                    await checkAI() // only when idle, never during typing/on app launch
                }
                guard !Task.isCancelled else { return }
                if !embeddingAvailable {
                    backgroundAIStatus = "Ollama / bge-m3 대기 · 메모 작성은 정상 사용 가능"
                    do { try await Task.sleep(nanoseconds: 45_000_000_000) }
                    catch { return }
                    continue
                }
                if backgroundCorpusPending {
                    backgroundAIStatus = "유휴 시간에 변경된 메모 색인 갱신 중"
                    startMemoryIndex(automatic: true)
                    while isIndexingMemory && !Task.isCancelled {
                        do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                        catch { return }
                    }
                    if memoryIndexStatus.contains("색인 완료") || memoryIndexStatus.contains("최신 상태") {
                        backgroundCorpusPending = false
                    } else if !Task.isCancelled {
                        // Ollama offline or transient error: no busy retry loop.
                        do { try await Task.sleep(nanoseconds: 45_000_000_000) }
                        catch { return }
                    }
                } else if let noteID = backgroundNoteQueue.sorted().first {
                    backgroundAIStatus = "변경된 메모의 의미 색인 갱신 중"
                    let succeeded = await updateMemoryForNote(noteID)
                    if succeeded && !Task.isCancelled {
                        backgroundNoteQueue.remove(noteID)
                        persistBackgroundQueues()
                    }
                    else if !Task.isCancelled {
                        do { try await Task.sleep(nanoseconds: 15_000_000_000) }
                        catch { return }
                    }
                } else if aiConnected, let entityID = backgroundRelationQueue.sorted().first {
                    // Process actual memory entities, including 10k-line virtual
                    // records. All completed pairs are cached by signature.
                    backgroundAIStatus = "업무 관계 분석 · 남은 기억 \(backgroundRelationQueue.count)개"
                    startRelationAnalysis(centerID: entityID, automatic: true)
                    while isInferringMemory && !Task.isCancelled {
                        do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                        catch { return }
                    }
                    if !Task.isCancelled {
                        if inferenceStatus.contains("관계 분석 완료") || inferenceStatus.contains("관계 후보가 없습니다") {
                            backgroundRelationQueue.remove(entityID)
                            persistBackgroundQueues()
                        } else {
                            // Preserve the note ID on failure; retry only
                            // after a backoff, not every scheduler iteration.
                            do { try await Task.sleep(nanoseconds: 45_000_000_000) }
                            catch { return }
                        }
                    }
                } else if !backgroundRelationQueue.isEmpty {
                    backgroundAIStatus = "채팅 모델을 연결하면 관계 분석을 재개합니다"
                    do { try await Task.sleep(nanoseconds: 45_000_000_000) }
                    catch { return }
                }
            }
        }
    }
}
