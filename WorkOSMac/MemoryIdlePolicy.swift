import Foundation

// Pure scheduling policy, independent of AppKit and Ollama. No model call is
// allowed on the typing path. This can be tested with simulated activity.
enum MemoryIdlePolicy {
    enum Mode: String, CaseIterable {
        case automatic, systemIdle, manual
    }
    static let defaultsKey = "workos.ai.backgroundMode"
    static func mayRun(mode: Mode, appActive: Bool, secondsSinceEditorActivity: TimeInterval,
                       secondsSinceAppActivity: TimeInterval, systemIdleSeconds: TimeInterval,
                       lowPower: Bool, thermalPressure: Bool) -> Bool {
        if mode == .manual || lowPower || thermalPressure { return false }
        if mode == .systemIdle { return systemIdleSeconds >= 120 && secondsSinceEditorActivity >= 15 }
        // Auto mode: editing is protected even while another app is active.
        // A switch to another app is not proof that the Mac is otherwise idle.
        if !appActive { return secondsSinceEditorActivity >= 12 && secondsSinceAppActivity >= 8 }
        return secondsSinceEditorActivity >= 35 && secondsSinceAppActivity >= 12
    }
}
