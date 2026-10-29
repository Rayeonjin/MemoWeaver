import AppKit
import SwiftUI

// One quiet visual language for editor, note list and auxiliary footers.
// The native notes, clipboard, pane layout and persistence code are independent.
// Shared horizontal rule across the list and editor. Keep the native split
// width logic independent of this vertical-only chrome alignment.
enum MemoWeaverWorkspaceHeaderMetrics {
    // The native unified titlebar is the FIRST visual row. This is the
    // content-only height for the existing metadata+insert / three filters.
    static let height: CGFloat = 106
}

// A drawn glyph (not an SF Symbol variant that can resolve to an empty image)
// keeps the panel toggle visible in BOTH open and closed states on macOS 14+.
struct MemoWeaverPaneToggleGlyph: View {
    enum Side { case left, right }
    let side: Side
    let isOpen: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.primary.opacity(0.78), lineWidth: 1.25)
            HStack(spacing: 0) {
                if side == .right { Spacer(minLength: 0) }
                Rectangle()
                    .fill(Color.primary.opacity(isOpen ? 0.70 : 0.17))
                    .frame(width: 5)
                if side == .left { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(width: 17, height: 14)
        .accessibilityHidden(true)
    }
}

enum MemoWeaverPaneFooterMetrics {
    static let height: CGFloat = 30
    static let controlHeight: CGFloat = 26
    static let horizontalPadding: CGFloat = 9
}

struct MemoWeaverPaneFooter<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 5) { content }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, MemoWeaverPaneFooterMetrics.horizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: MemoWeaverPaneFooterMetrics.height)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct MemoWeaverFooterControl: ViewModifier {
    let selected: Bool
    @State private var hovered = false

    init(selected: Bool = false) { self.selected = selected }

    func body(content: Content) -> some View {
        content
            .frame(height: MemoWeaverPaneFooterMetrics.controlHeight)
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(selected ? Color.primary.opacity(0.10) :
                          (hovered ? Color.primary.opacity(0.065) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .onHover { hovered = $0 }
    }
}

// Use when the existing footer owns a ViewThatFits and must retain its
// separate expanded and compact status layouts.
struct MemoWeaverPaneFooterSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, MemoWeaverPaneFooterMetrics.horizontalPadding)
            .frame(height: MemoWeaverPaneFooterMetrics.height)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}

// Borderless icon actions in the editor header, workspace header and side
// tabs use the same hover and selected treatment. No blue outlined pills.
struct MemoWeaverHeaderIconSurface: ViewModifier {
    var selected = false
    var height: CGFloat = 30
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.primary.opacity(0.10) :
                          (hovered ? Color.primary.opacity(0.065) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovered = $0 }
    }
}

// App and preview retain independent AppStorage keys, with a shared compact
// one-click system -> light -> dark -> system cycle in the pane footers.
enum MemoWeaverThemeOption: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "시스템"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

enum MemoWeaverThemePresentation {
    case threeButtons
    case compactMenu
    case cycleButton
}

struct MemoWeaverThemePicker: View {
    @Binding var selection: String
    let scope: String
    var presentation: MemoWeaverThemePresentation = .threeButtons

    var body: some View {
        Group {
            switch presentation {
            case .cycleButton:
                let active = MemoWeaverThemeOption(rawValue: selection) ?? .system
                let next = MemoWeaverThemeOption(rawValue:
                    MemoWeaverThemeCycleCore.next(after: selection)) ?? .system
                Button {
                    selection = MemoWeaverThemeCycleCore.next(after: selection)
                } label: {
                    Image(systemName: active.icon)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 27, height: MemoWeaverPaneFooterMetrics.controlHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .modifier(MemoWeaverFooterControl())
                .memoTooltip("\(scope) \u{D14C}\u{B9C8}: \(active.title) \u{00B7} \u{B2E4}\u{C74C} \u{B204}\u{B974}\u{BA74} \(next.title)")
                .accessibilityLabel("\(scope) \u{D14C}\u{B9C8} \u{C21C}\u{D658}")
                .accessibilityValue(active.title)
            case .threeButtons:
                HStack(spacing: 2) {
                    ForEach(MemoWeaverThemeOption.allCases) { option in
                        Button { selection = option.rawValue } label: {
                            Image(systemName: option.icon)
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 27, height: MemoWeaverPaneFooterMetrics.controlHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .modifier(MemoWeaverFooterControl(selected: selection == option.rawValue))
                        .accessibilityLabel("\(scope) · \(option.title) 모드")
                        .accessibilityValue(selection == option.rawValue ? "선택됨" : "선택되지 않음")
                    }
                }
                .padding(.horizontal, 2)
                .background(Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 6))
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(scope) 테마")
            case .compactMenu:
                Menu {
                    ForEach(MemoWeaverThemeOption.allCases) { option in
                        Button {
                            selection = option.rawValue
                        } label: {
                            if selection == option.rawValue {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: MemoWeaverThemeOption(rawValue: selection)?.icon ?? "circle.lefthalf.filled")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .font(.system(size: 12))
                    .frame(width: 40, height: MemoWeaverPaneFooterMetrics.controlHeight)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .modifier(MemoWeaverFooterControl())
                .memoTooltip("\(scope) 테마")
                .accessibilityLabel("\(scope) 테마 선택")
                .accessibilityValue(MemoWeaverThemeOption(rawValue: selection)?.title ?? "시스템")
            }
        }
    }
}
