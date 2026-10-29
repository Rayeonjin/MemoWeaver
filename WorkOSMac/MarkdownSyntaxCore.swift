import Foundation

// Small, dependency-free helpers shared by the Markdown source editor and
// offline preview. These do not edit stored notes or normalize source text.
enum MarkdownListSyntax {
    struct Item {
        let indent: Int
        let contentColumn: Int
        let marker: String
        let text: String
        let ordered: Bool
        let start: Int
        var listKind: String { ordered ? (marker.hasSuffix(")") ? "ol)" : "ol.") : "ul\(marker)" }
    }

    private static let bullet = try! NSRegularExpression(pattern: #"^([ \t]*)([-+*]|[0-9]{1,9}[.)])([ \t]+)(.*)$"#)

    static func indentation(_ text: String) -> Int {
        var width = 0
        for character in text {
            if character == " " { width += 1 }
            else if character == "\t" { width += 4 - (width % 4) }
            else { break }
        }
        return width
    }

    static func item(_ line: String) -> Item? {
        let ns = line as NSString
        guard let match = bullet.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let leading = ns.substring(with: match.range(at: 1))
        let marker = ns.substring(with: match.range(at: 2))
        let whitespace = ns.substring(with: match.range(at: 3))
        let text = ns.substring(with: match.range(at: 4))
        let indent = indentation(leading)
        let ordered = marker.last == "." || marker.last == ")"
        let start = ordered ? (Int(marker.dropLast()) ?? 1) : 1
        // 1-4 spaces after the list marker are its padding in CommonMark.
        // Wider separators count as one padding space plus content whitespace.
        let padding = max(1, min(4, indentation(whitespace)))
        return Item(indent: indent, contentColumn: indent + marker.count + padding,
                    marker: marker, text: text, ordered: ordered, start: start)
    }

    static func render(lines: [String], start: Int,
                       renderInline: (String) -> String) -> (html: String, next: Int)? {
        guard start < lines.count, item(lines[start]) != nil else { return nil }
        struct Level {
            var indent: Int
            var contentColumn: Int
            var kind: String
        }
        var levels: [Level] = []
        var html = ""
        var position = start
        func opening(_ value: Item) -> String {
            if value.ordered { return value.start == 1 ? "<ol>" : "<ol start='\(value.start)'>" }
            return "<ul>"
        }
        func closing(_ value: String) -> String { value.hasPrefix("ol") ? "</ol>" : "</ul>" }
        func itemBody(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[ ] ") {
                return "<input type='checkbox' disabled> " + renderInline(String(trimmed.dropFirst(4)))
            }
            if trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
                return "<input type='checkbox' disabled checked> " + renderInline(String(trimmed.dropFirst(4)))
            }
            return renderInline(text)
        }
        while position < lines.count {
            let raw = lines[position]
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            if let entry = item(raw) {
                if levels.isEmpty {
                    html += opening(entry)
                    levels.append(Level(indent: entry.indent, contentColumn: entry.contentColumn, kind: entry.listKind))
                } else {
                    // Children must be at least as indented as the parent's
                    // content, which is determined by the marker width.
                    if entry.indent >= levels.last!.contentColumn {
                        html += opening(entry)
                        levels.append(Level(indent: entry.indent, contentColumn: entry.contentColumn, kind: entry.listKind))
                    } else {
                        while levels.count > 1 && entry.indent < levels.last!.indent {
                            html += "</li>" + closing(levels.removeLast().kind)
                        }
                        // After dedenting, the item may still be a child of
                        // the newly exposed parent rather than its sibling.
                        if entry.indent >= levels.last!.contentColumn {
                            html += opening(entry)
                            levels.append(Level(indent: entry.indent, contentColumn: entry.contentColumn, kind: entry.listKind))
                        } else {
                            html += "</li>"
                            if entry.listKind != levels.last!.kind {
                                html += closing(levels.removeLast().kind) + opening(entry)
                                levels.append(Level(indent: entry.indent, contentColumn: entry.contentColumn, kind: entry.listKind))
                            }
                        }
                    }
                }
                // The content column can differ between '1.' and '10.'.
                levels[levels.count - 1].contentColumn = entry.contentColumn
                // A list item is its own caret-sync target, not merely the
                // beginning of the entire nested list.
                html += "<li data-md-line='\(position + 1)'>" + itemBody(entry.text)
                position += 1
                continue
            }
            // CommonMark allows lazy paragraph continuation inside an item;
            // handle explicitly indented continuation without swallowing a
            // following normal paragraph or fenced block.
            if let top = levels.last, indentation(raw) >= top.contentColumn {
                html += "<br>" + renderInline(raw.trimmingCharacters(in: .whitespaces))
                position += 1
                continue
            }
            break
        }
        while let level = levels.popLast() { html += "</li>" + closing(level.kind) }
        return (html, position)
    }
}

// CommonMark-style fenced code markers: backticks or tildes, length >= 3,
// up to three spaces of indentation, and a matching closing fence.
enum MarkdownFenceSyntax {
    struct Fence {
        let marker: Character
        let count: Int
        let language: String
    }
    static func opening(_ line: String) -> Fence? {
        guard MarkdownListSyntax.indentation(line) <= 3 else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == marker }).count
        guard count >= 3 else { return nil }
        let info = String(trimmed.dropFirst(count))
        // Backticks cannot appear in a backtick fence's info string.
        if marker == "`" && info.contains("`") { return nil }
        return Fence(marker: marker, count: count,
                     language: String(info.split(whereSeparator: { $0.isWhitespace }).first ?? "").lowercased())
    }
    static func closes(_ line: String, fence: Fence) -> Bool {
        guard MarkdownListSyntax.indentation(line) <= 3 else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let count = trimmed.prefix(while: { $0 == fence.marker }).count
        return count >= fence.count && trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum MarkdownEditingContext: Equatable {
    case normal, math, mermaid, mermaidXY, mermaidPie, mermaidGantt, mermaidTimeline,
         mermaidSequence, mermaidClass, mermaidState, mermaidER, mermaidGit, mermaidJourney,
         mermaidQuadrant, markmap, code
}

// The slash palette header belongs to the context model, not an untested
// SwiftUI switch. Keeping this exhaustive in a Foundation-only file makes
// future enum additions fail the cross-platform smoke build if unhandled.
extension MarkdownEditingContext {
    var slashPaletteTitle: String {
        switch self {
        case .normal: return "메모 삽입"
        case .math: return "수식 코드"
        case .mermaid: return "Mermaid 흐름도"
        case .mermaidXY: return "Mermaid XY 차트"
        case .mermaidPie: return "Mermaid 원형 차트"
        case .mermaidGantt: return "Mermaid Gantt 일정"
        case .mermaidTimeline: return "Mermaid Timeline 이력"
        case .mermaidSequence: return "Mermaid Sequence 순서도"
        case .mermaidClass: return "Mermaid 클래스 구조"
        case .mermaidState: return "Mermaid 상태 전이"
        case .mermaidER: return "Mermaid ER 관계"
        case .mermaidGit: return "Mermaid Git 이력"
        case .mermaidJourney: return "Mermaid 사용자 여정"
        case .mermaidQuadrant: return "Mermaid 사분면"
        case .markmap: return "마인드맵"
        case .code: return "코드"
        }
    }
}

// Determine the Mermaid dialect from the currently open fence, not from the
// user's note body. Prevent inserting flowchart arrows into XY/pie charts.
enum MermaidEditingDialect {
    static func context(lines: [String]) -> MarkdownEditingContext {
        var inFrontMatter = false
        var sawFrontMatter = false
        for line in lines {
            let trim = line.trimmingCharacters(in: .whitespaces)
            if trim.isEmpty || trim.hasPrefix("%%") { continue }
            if trim == "---" && !sawFrontMatter {
                inFrontMatter = true; sawFrontMatter = true; continue
            }
            if inFrontMatter {
                if trim == "---" { inFrontMatter = false }
                continue
            }
            let directive = String(trim.split(whereSeparator: { $0.isWhitespace }).first ?? "")
            if directive == "xychart" || directive == "xychart-beta" { return .mermaidXY }
            if directive == "pie" { return .mermaidPie }
            if directive == "gantt" { return .mermaidGantt }
            if directive == "timeline" { return .mermaidTimeline }
            if directive == "sequenceDiagram" { return .mermaidSequence }
            if directive == "classDiagram" { return .mermaidClass }
            if directive == "stateDiagram" || directive == "stateDiagram-v2" { return .mermaidState }
            if directive == "erDiagram" { return .mermaidER }
            if directive.lowercased() == "gitgraph" { return .mermaidGit }
            if directive == "journey" { return .mermaidJourney }
            if directive == "quadrantChart" { return .mermaidQuadrant }
            return .mermaid
        }
        return .mermaid
    }
}

enum MarkdownContextCore {
    static func context(in source: String, utf16Offset: Int) -> MarkdownEditingContext {
        let ns = source as NSString
        let offset = max(0, min(utf16Offset, ns.length))
        let prefix = ns.substring(to: offset)
        var fence: MarkdownFenceSyntax.Fence?
        var math = false
        var mermaidLines: [String] = []
        for line in prefix.components(separatedBy: "\n") {
            if let active = fence {
                if MarkdownFenceSyntax.closes(line, fence: active) { fence = nil }
                else if active.language == "mermaid" { mermaidLines.append(line) }
                continue
            }
            if let opening = MarkdownFenceSyntax.opening(line), !math {
                fence = opening
                mermaidLines = []
                continue
            }
            if MarkdownListSyntax.indentation(line) <= 3 {
                let marker = line.trimmingCharacters(in: .whitespaces)
                if marker == "$$" || marker == #"\["# || marker == #"\]"# {
                    if marker == "$$" { math.toggle() }
                    else if marker == #"\["# { math = true }
                    else { math = false }
                }
            }
        }
        if let fence {
            if fence.language == "mermaid" { return MermaidEditingDialect.context(lines: mermaidLines) }
            if fence.language == "latex" || fence.language == "tex" || fence.language == "math" { return .math }
            if fence.language == "markmap" { return .markmap }
            // A fenced Markdown example is still source code: do not show
            // live Markdown insertion tools inside it.
            return .code
        }
        return math ? .math : .normal
    }
}

// Context-sensitive editing palette: all commands insert plain source into
// NSTextView. Grouping is a UI convenience; there is no parallel rich editor.
enum MarkdownAssistGroup: String, CaseIterable {
    case mathBasic, mathOperators, mathSymbols, mathLayout
    case diagramNodes, diagramLinks, diagramPatterns
    case chartAxes, chartPlots, chartPie
    case ganttParts, timelineEvents, sequenceActors, markmapOutline

    var context: MarkdownEditingContext {
        switch self {
        case .mathBasic, .mathOperators, .mathSymbols, .mathLayout: return .math
        case .diagramNodes, .diagramLinks, .diagramPatterns: return .mermaid
        case .chartAxes, .chartPlots: return .mermaidXY
        case .chartPie: return .mermaidPie
        case .ganttParts: return .mermaidGantt
        case .timelineEvents: return .mermaidTimeline
        case .sequenceActors: return .mermaidSequence
        case .markmapOutline: return .markmap
        }
    }
    var symbol: String {
        switch self {
        case .mathBasic: return "function"
        case .mathOperators: return "plus.forwardslash.minus"
        case .mathSymbols: return "character.book.closed"
        case .mathLayout: return "square.grid.2x2"
        case .diagramNodes: return "square.on.circle"
        case .diagramLinks: return "arrow.right"
        case .diagramPatterns: return "arrow.triangle.branch"
        case .chartAxes: return "chart.xyaxis.line"
        case .chartPlots: return "chart.bar"
        case .chartPie: return "chart.pie"
        case .ganttParts: return "calendar"
        case .timelineEvents: return "clock"
        case .sequenceActors: return "bubble.left.and.bubble.right"
        case .markmapOutline: return "brain.head.profile"
        }
    }
    var title: String {
        switch self {
        case .mathBasic: return "기본"
        case .mathOperators: return "연산"
        case .mathSymbols: return "기호"
        case .mathLayout: return "배열·정렬"
        case .diagramNodes: return "노드"
        case .diagramLinks: return "연결"
        case .diagramPatterns: return "구조"
        case .chartAxes: return "축"
        case .chartPlots: return "데이터"
        case .chartPie: return "항목"
        case .ganttParts: return "일정"
        case .timelineEvents: return "이력"
        case .sequenceActors: return "참여자·메시지"
        case .markmapOutline: return "가지·연결"
        }
    }
}

enum MarkdownAssistSnippet: String, CaseIterable {
    case fraction, superscript, subscriptValue, squareRoot, nthRoot, parentheses, absoluteValue
    case summation, product, integral, definiteIntegral, limit, partialDerivative, vector
    case alpha, beta, theta, pi, delta, times, approximate, lessEqual, greaterEqual, rightArrow, infinity
    // Additional KaTeX-supported symbols; always accessible from icon menus
    // and the contextual slash palette through the shared command catalog.
    case epsilon, zeta, eta, iota, kappa, mu, nu, xi, omicron, rho, sigma, tau, upsilon, phi, chi, psi, lowerDelta, varepsilon, vartheta, varphi, varrho
    case upperGamma, upperTheta, upperLambda, upperXi, upperPi, upperSigma, upperPhi, upperPsi, upperOmega
    case equivalent, congruent, similar, muchLess, muchGreater, nearlyEqual, perpendicular, parallel, subsetStrict, supersetStrict, supersetEqual
    case setDifference, naturalNumbers, integers, rationals, reals, complexNumbers
    case notExists, implies, iff, logicalNot, becauseSymbol
    case plusMinus, minusPlus, divideSymbol, circOperator, tensorProduct, directSum, nabla, partialSymbol, contourIntegral, doubleIntegral, ellipsisHorizontal, ellipsisCenter
    case leftArrow, doubleRightArrow, doubleLeftArrow, doubleArrow, mapsTo, upArrow, downArrow, upDownArrow
    case matrix2x2, casesBlock, gatheredEquations, alignedEquations, textInMath
    case node, decision, circle, connection, labeledConnection, branch, chain, comment
    case xyXAxis, xyYAxis, xyBar, xyLine, pieSlice
    case ganttSection, ganttTask, ganttMilestone, timelineEvent
    case sequenceParticipant, sequenceMessage, sequenceReply
    case markmapHeading, markmapChild, markmapLink
    case binomial, overline, dotProduct, derivative, gamma, lambdaSymbol, omega, notEqual, proportional, elementOf, matrix3x3, pmatrix2x2,
         forallSymbol, existsSymbol, emptySet, subsetEqual, unionSymbol, intersectionSymbol,
         notElement, logicalAnd, logicalOr, thereforeSymbol, roundedNode, databaseNode, dottedConnection, twoWayConnection, subgraphBlock, xyTitle, xySecondLine, pieAnotherSlice, ganttDateFormat, ganttExcludes, timelineSection, sequenceNote, sequenceActivation, sequenceAlternative, sequenceLoop, markmapTask, markmapBold, markmapCode

    var group: MarkdownAssistGroup {
        switch self {
        case .fraction, .superscript, .subscriptValue, .squareRoot, .nthRoot, .parentheses, .absoluteValue:
            return .mathBasic
        case .summation, .product, .integral, .definiteIntegral, .limit, .partialDerivative, .vector:
            return .mathOperators
        case .alpha, .beta, .theta, .pi, .delta, .times, .approximate, .lessEqual, .greaterEqual, .rightArrow, .infinity:
            return .mathSymbols
        case .matrix2x2, .casesBlock, .gatheredEquations, .alignedEquations, .textInMath:
            return .mathLayout
        case .node, .decision, .circle: return .diagramNodes
        case .connection, .labeledConnection, .branch: return .diagramLinks
        case .chain, .comment: return .diagramPatterns
        case .xyXAxis, .xyYAxis: return .chartAxes
        case .xyBar, .xyLine: return .chartPlots
        case .pieSlice: return .chartPie
        case .ganttSection, .ganttTask, .ganttMilestone: return .ganttParts
        case .timelineEvent: return .timelineEvents
        case .sequenceParticipant, .sequenceMessage, .sequenceReply: return .sequenceActors
        case .markmapHeading, .markmapChild, .markmapLink: return .markmapOutline
        case .binomial, .overline: return .mathBasic
        case .dotProduct, .derivative: return .mathOperators
        case .gamma, .lambdaSymbol, .omega, .notEqual, .proportional, .elementOf,
             .forallSymbol, .existsSymbol, .emptySet, .subsetEqual, .unionSymbol,
             .intersectionSymbol, .notElement, .logicalAnd, .logicalOr, .thereforeSymbol:
            return .mathSymbols
        case .epsilon, .zeta, .eta, .iota, .kappa, .mu, .nu, .xi,
             .omicron, .rho, .sigma, .tau, .upsilon, .phi, .chi, .psi,
             .lowerDelta, .varepsilon, .vartheta, .varphi, .varrho, .upperGamma, .upperTheta, .upperLambda,
             .upperXi, .upperPi, .upperSigma, .upperPhi, .upperPsi, .upperOmega, .equivalent, .congruent,
             .similar, .muchLess, .muchGreater, .nearlyEqual, .perpendicular, .parallel, .subsetStrict, .supersetStrict,
             .supersetEqual, .setDifference, .naturalNumbers, .integers, .rationals, .reals, .complexNumbers, .notExists,
             .implies, .iff, .logicalNot, .becauseSymbol, .plusMinus, .minusPlus, .divideSymbol, .circOperator,
             .tensorProduct, .directSum, .nabla, .partialSymbol, .contourIntegral, .doubleIntegral, .ellipsisHorizontal, .ellipsisCenter,
             .leftArrow, .doubleRightArrow, .doubleLeftArrow, .doubleArrow, .mapsTo, .upArrow, .downArrow, .upDownArrow: return .mathSymbols
        case .matrix3x3, .pmatrix2x2: return .mathLayout
        case .roundedNode, .databaseNode: return .diagramNodes
        case .dottedConnection, .twoWayConnection: return .diagramLinks
        case .subgraphBlock: return .diagramPatterns
        case .xyTitle: return .chartAxes
        case .xySecondLine: return .chartPlots
        case .pieAnotherSlice: return .chartPie
        case .ganttDateFormat, .ganttExcludes: return .ganttParts
        case .timelineSection: return .timelineEvents
        case .sequenceNote, .sequenceActivation, .sequenceAlternative, .sequenceLoop: return .sequenceActors
        case .markmapTask, .markmapBold, .markmapCode: return .markmapOutline
        }
    }
    var compactMathLabel: String {
        switch self {
        case .fraction: return "a⁄b"
        case .squareRoot: return "√x"
        case .superscript: return "xⁿ"
        default: return title
        }
    }

    var context: MarkdownEditingContext { group.context }

    var title: String {
        switch self {
        case .fraction: return "분수"
        case .superscript: return "위첨자"
        case .subscriptValue: return "아래첨자"
        case .squareRoot: return "제곱근"
        case .nthRoot: return "n제곱근"
        case .parentheses: return "괄호"
        case .absoluteValue: return "절댓값"
        case .summation: return "∑"
        case .product: return "∏"
        case .integral: return "∫"
        case .definiteIntegral: return "정적분"
        case .limit: return "극한"
        case .partialDerivative: return "편미분"
        case .vector: return "벡터"
        case .alpha: return "α"
        case .beta: return "β"
        case .theta: return "θ"
        case .pi: return "π"
        case .delta: return "Δ"
        case .times: return "×"
        case .approximate: return "≈"
        case .lessEqual: return "≤"
        case .greaterEqual: return "≥"
        case .rightArrow: return "→"
        case .infinity: return "∞"
        case .matrix2x2: return "2×2 행렬"
        case .casesBlock: return "조건식"
        case .gatheredEquations: return "\u{C5EC}\u{B7EC} \u{C904} \u{C218}\u{C2DD}"
        case .alignedEquations: return "식 정렬"
        case .textInMath: return "문자"
        case .node: return "사각형"
        case .decision: return "조건 마름모"
        case .circle: return "원형"
        case .connection: return "화살표"
        case .labeledConnection: return "라벨 연결"
        case .branch: return "예/아니오 분기"
        case .chain: return "3단계 흐름"
        case .comment: return "주석"
        case .xyXAxis: return "가로축"
        case .xyYAxis: return "세로축"
        case .xyBar: return "막대값"
        case .xyLine: return "선값"
        case .pieSlice: return "원형 항목"
        case .ganttSection: return "단계"
        case .ganttTask: return "작업"
        case .ganttMilestone: return "마일스톤"
        case .timelineEvent: return "사건"
        case .sequenceParticipant: return "참여자"
        case .sequenceMessage: return "요청"
        case .sequenceReply: return "응답"
        case .markmapHeading: return "제목"
        case .markmapChild: return "하위 가지"
        case .markmapLink: return "링크"
        case .binomial: return "이항계수"
        case .overline: return "위선"
        case .dotProduct: return "점곱"
        case .derivative: return "미분"
        case .gamma: return "γ"
        case .lambdaSymbol: return "λ"
        case .omega: return "ω"
        case .notEqual: return "≠"
        case .proportional: return "∝"
        case .elementOf: return "∈"
        case .forallSymbol: return "∀"
        case .existsSymbol: return "∃"
        case .emptySet: return "∅"
        case .subsetEqual: return "⊆"
        case .unionSymbol: return "∪"
        case .intersectionSymbol: return "∩"
        case .notElement: return "∉"
        case .logicalAnd: return "∧"
        case .logicalOr: return "∨"
        case .thereforeSymbol: return "∴"
        case .epsilon: return "ε"
        case .zeta: return "ζ"
        case .eta: return "η"
        case .iota: return "ι"
        case .kappa: return "κ"
        case .mu: return "μ"
        case .nu: return "ν"
        case .xi: return "ξ"
        case .omicron: return "ο"
        case .rho: return "ρ"
        case .sigma: return "σ"
        case .tau: return "τ"
        case .upsilon: return "υ"
        case .phi: return "φ"
        case .chi: return "χ"
        case .psi: return "ψ"
        case .lowerDelta: return "δ"
        case .varepsilon: return "ϵ"
        case .vartheta: return "ϑ"
        case .varphi: return "ϕ"
        case .varrho: return "ϱ"
        case .upperGamma: return "Γ"
        case .upperTheta: return "Θ"
        case .upperLambda: return "Λ"
        case .upperXi: return "Ξ"
        case .upperPi: return "Π"
        case .upperSigma: return "Σ"
        case .upperPhi: return "Φ"
        case .upperPsi: return "Ψ"
        case .upperOmega: return "Ω"
        case .equivalent: return "≡"
        case .congruent: return "≅"
        case .similar: return "∼"
        case .muchLess: return "≪"
        case .muchGreater: return "≫"
        case .nearlyEqual: return "≃"
        case .perpendicular: return "⊥"
        case .parallel: return "∥"
        case .subsetStrict: return "⊂"
        case .supersetStrict: return "⊃"
        case .supersetEqual: return "⊇"
        case .setDifference: return "∖"
        case .naturalNumbers: return "ℕ"
        case .integers: return "ℤ"
        case .rationals: return "ℚ"
        case .reals: return "ℝ"
        case .complexNumbers: return "ℂ"
        case .notExists: return "∄"
        case .implies: return "⇒"
        case .iff: return "⇔"
        case .logicalNot: return "¬"
        case .becauseSymbol: return "∵"
        case .plusMinus: return "±"
        case .minusPlus: return "∓"
        case .divideSymbol: return "÷"
        case .circOperator: return "∘"
        case .tensorProduct: return "⊗"
        case .directSum: return "⊕"
        case .nabla: return "∇"
        case .partialSymbol: return "∂"
        case .contourIntegral: return "∮"
        case .doubleIntegral: return "∬"
        case .ellipsisHorizontal: return "…"
        case .ellipsisCenter: return "⋯"
        case .leftArrow: return "←"
        case .doubleRightArrow: return "⇒"
        case .doubleLeftArrow: return "⇐"
        case .doubleArrow: return "⇔"
        case .mapsTo: return "↦"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .upDownArrow: return "↕"
        case .matrix3x3: return "3×3 행렬"
        case .pmatrix2x2: return "소괄호 행렬"
        case .roundedNode: return "둥근 노드"
        case .databaseNode: return "데이터 노드"
        case .dottedConnection: return "점선 연결"
        case .twoWayConnection: return "양방향 연결"
        case .subgraphBlock: return "하위 그룹"
        case .xyTitle: return "차트 제목"
        case .xySecondLine: return "추가 선값"
        case .pieAnotherSlice: return "추가 원형 항목"
        case .ganttDateFormat: return "날짜 형식"
        case .ganttExcludes: return "주말 제외"
        case .timelineSection: return "이력 구역"
        case .sequenceNote: return "대화 주석"
        case .sequenceActivation: return "활성 구간"
        case .sequenceAlternative: return "조건 분기"
        case .sequenceLoop: return "반복 실행"
        case .markmapTask: return "할 일"
        case .markmapBold: return "강조 가지"
        case .markmapCode: return "코드 가지"
        }
    }

    // Only Mermaid flowchart constructs rendered by our OFFLINE SVG subset
    // are offered as diagram commands. Sequence/Gantt would falsely promise
    // support until their renderers are bundled and verified.
    var source: String {
        switch self {
        case .fraction: return #"\frac{a}{b}"#
        case .superscript: return #"x^{n}"#
        case .subscriptValue: return #"x_{n}"#
        case .squareRoot: return #"\sqrt{x}"#
        case .nthRoot: return #"\sqrt[3]{x}"#
        case .parentheses: return #"\left(x\right)"#
        case .absoluteValue: return #"\left|x\right|"#
        case .summation: return #"\sum_{i=1}^{n}"#
        case .product: return #"\prod_{i=1}^{n}"#
        case .integral: return #"\int f(x)\,dx"#
        case .definiteIntegral: return #"\int_{a}^{b} f(x)\,dx"#
        case .limit: return #"\lim_{x\to 0}"#
        case .partialDerivative: return #"\frac{\partial f}{\partial x}"#
        case .vector: return #"\vec{v}"#
        case .alpha: return #"\alpha"#
        case .beta: return #"\beta"#
        case .theta: return #"\theta"#
        case .pi: return #"\pi"#
        case .delta: return #"\Delta"#
        case .times: return #"\times"#
        case .approximate: return #"\approx"#
        case .lessEqual: return #"\leq"#
        case .greaterEqual: return #"\geq"#
        case .rightArrow: return #"\rightarrow"#
        case .infinity: return #"\infty"#
        case .matrix2x2: return #"\begin{bmatrix} a & b \\ c & d \end{bmatrix}"#
        case .casesBlock: return #"\begin{cases} x & x\ge 0 \\ -x & x<0 \end{cases}"#
        case .gatheredEquations: return #"\begin{gathered}"# + "\n" + #"a+b=c \\"# + "\n" + #"d+e=f"# + "\n" + #"\end{gathered}"#
        case .alignedEquations: return #"\begin{aligned}"# + "\n" + #"a &= b \\"# + "\n" + #"c &= d"# + "\n" + #"\end{aligned}"#
        case .textInMath: return #"\text{설명}"#
        case .node: return "A[작업]"
        case .decision: return "B{조건}"
        case .circle: return "C((완료))"
        case .connection: return "A --> B"
        case .labeledConnection: return "A -->|예| B"
        case .branch: return "A{조건} -->|예| B\nA -->|아니오| C"
        case .chain: return "A[시작] --> B[처리]\nB --> C[완료]"
        case .comment: return "%% 설명을 적으세요"
        case .xyXAxis: return "x-axis [\"1월\", \"2월\", \"3월\"]"
        case .xyYAxis: return "y-axis \"건수\" 0 --> 50"
        case .xyBar: return "bar [12, 28, 21]"
        case .xyLine: return "line [12, 28, 21]"
        case .pieSlice: return "\"새 항목\" : 10"
        case .ganttSection: return "section 개발"
        case .ganttTask:
            return "작업 :task1, \(String(ISO8601DateFormatter().string(from: Date()).prefix(10))), 3d"
        case .ganttMilestone: return "검토 완료 :milestone, m1, after task1, 0d"
        case .timelineEvent: return "오늘 : 새로운 결정"
        case .sequenceParticipant: return "participant C as 새 참여자"
        case .sequenceMessage: return "A->>B: 요청 내용"
        case .sequenceReply: return "B-->>A: 응답 내용"
        case .markmapHeading: return "# 새 주제"
        case .markmapChild: return "  - 새 항목"
        case .markmapLink: return "[참고](https://example.com)"
        case .binomial: return "\\binom{n}{k}"
        case .overline: return "\\overline{x}"
        case .dotProduct: return "\\cdot"
        case .derivative: return "\\frac{d y}{d x}"
        case .gamma: return "\\gamma"
        case .lambdaSymbol: return "\\lambda"
        case .omega: return "\\omega"
        case .notEqual: return "\\neq"
        case .proportional: return "\\propto"
        case .elementOf: return "\\in"
        case .forallSymbol: return "\\forall"
        case .existsSymbol: return "\\exists"
        case .emptySet: return "\\emptyset"
        case .subsetEqual: return "\\subseteq"
        case .unionSymbol: return "\\cup"
        case .intersectionSymbol: return "\\cap"
        case .notElement: return "\\notin"
        case .logicalAnd: return "\\land"
        case .logicalOr: return "\\lor"
        case .thereforeSymbol: return "\\therefore"
        case .epsilon: return #"\epsilon"#
        case .zeta: return #"\zeta"#
        case .eta: return #"\eta"#
        case .iota: return #"\iota"#
        case .kappa: return #"\kappa"#
        case .mu: return #"\mu"#
        case .nu: return #"\nu"#
        case .xi: return #"\xi"#
        case .omicron: return #"o"#
        case .rho: return #"\rho"#
        case .sigma: return #"\sigma"#
        case .tau: return #"\tau"#
        case .upsilon: return #"\upsilon"#
        case .phi: return #"\phi"#
        case .chi: return #"\chi"#
        case .psi: return #"\psi"#
        case .lowerDelta: return #"\delta"#
        case .varepsilon: return #"\varepsilon"#
        case .vartheta: return #"\vartheta"#
        case .varphi: return #"\varphi"#
        case .varrho: return #"\varrho"#
        case .upperGamma: return #"\Gamma"#
        case .upperTheta: return #"\Theta"#
        case .upperLambda: return #"\Lambda"#
        case .upperXi: return #"\Xi"#
        case .upperPi: return #"\Pi"#
        case .upperSigma: return #"\Sigma"#
        case .upperPhi: return #"\Phi"#
        case .upperPsi: return #"\Psi"#
        case .upperOmega: return #"\Omega"#
        case .equivalent: return #"\equiv"#
        case .congruent: return #"\cong"#
        case .similar: return #"\sim"#
        case .muchLess: return #"\ll"#
        case .muchGreater: return #"\gg"#
        case .nearlyEqual: return #"\simeq"#
        case .perpendicular: return #"\perp"#
        case .parallel: return #"\parallel"#
        case .subsetStrict: return #"\subset"#
        case .supersetStrict: return #"\supset"#
        case .supersetEqual: return #"\supseteq"#
        case .setDifference: return #"\setminus"#
        case .naturalNumbers: return #"\mathbb{N}"#
        case .integers: return #"\mathbb{Z}"#
        case .rationals: return #"\mathbb{Q}"#
        case .reals: return #"\mathbb{R}"#
        case .complexNumbers: return #"\mathbb{C}"#
        case .notExists: return #"\nexists"#
        case .implies: return #"\implies"#
        case .iff: return #"\iff"#
        case .logicalNot: return #"\neg"#
        case .becauseSymbol: return #"\because"#
        case .plusMinus: return #"\pm"#
        case .minusPlus: return #"\mp"#
        case .divideSymbol: return #"\div"#
        case .circOperator: return #"\circ"#
        case .tensorProduct: return #"\otimes"#
        case .directSum: return #"\oplus"#
        case .nabla: return #"\nabla"#
        case .partialSymbol: return #"\partial"#
        case .contourIntegral: return #"\oint"#
        case .doubleIntegral: return #"\iint"#
        case .ellipsisHorizontal: return #"\ldots"#
        case .ellipsisCenter: return #"\cdots"#
        case .leftArrow: return #"\leftarrow"#
        case .doubleRightArrow: return #"\Rightarrow"#
        case .doubleLeftArrow: return #"\Leftarrow"#
        case .doubleArrow: return #"\Leftrightarrow"#
        case .mapsTo: return #"\mapsto"#
        case .upArrow: return #"\uparrow"#
        case .downArrow: return #"\downarrow"#
        case .upDownArrow: return #"\updownarrow"#
        case .matrix3x3: return "\\begin{bmatrix} a & b & c \\\\ d & e & f \\\\ g & h & i \\end{bmatrix}"
        case .pmatrix2x2: return "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"
        case .roundedNode: return "A(작업)"
        case .databaseNode: return "D[(데이터)]"
        case .dottedConnection: return "A -.-> B"
        case .twoWayConnection: return "A <--> B"
        case .subgraphBlock: return "subgraph G[그룹]\n  A[작업]\nend"
        case .xyTitle: return "title \"성과 추이\""
        case .xySecondLine: return "line [6, 8, 11]"
        case .pieAnotherSlice: return "\"다른 항목\" : 20"
        case .ganttDateFormat: return "dateFormat YYYY-MM-DD"
        case .ganttExcludes: return "excludes weekends"
        case .timelineSection: return "section 주요 이벤트"
        case .sequenceNote: return "Note over A,B: 참고 사항"
        case .sequenceActivation: return "activate B\nB-->>A: 처리 완료\ndeactivate B"
        case .sequenceAlternative: return "alt 성공\n  A-->>B: 응답\nelse 실패\n  A-->>B: 오류\nend"
        case .sequenceLoop: return "loop 재시도\n  A->>B: 확인\nend"
        case .markmapTask: return "- [ ] 확인할 일"
        case .markmapBold: return "- **중요 주제**"
        case .markmapCode: return "- `코드`"
        }
    }

    // The focus token includes delimiters so the caret will not accidentally
    // target a character inside e.g. the \\frac command itself.
    private var focusToken: String? {
        switch self {
        case .fraction: return "{a}"
        case .superscript, .subscriptValue: return "{n}"
        case .squareRoot, .nthRoot: return "{x}"
        case .parentheses: return "(x"
        case .absoluteValue: return "|x"
        case .summation, .product: return "{i=1}"
        case .integral, .definiteIntegral: return "f(x)"
        case .limit: return "{x\\to 0}"
        case .partialDerivative: return "{\\partial f}"
        case .vector: return "{v}"
        case .matrix2x2: return " a & b"
        case .gatheredEquations: return "a+b=c"
        case .alignedEquations: return "a &="
        case .casesBlock: return " x &"
        case .textInMath: return "{설명}"
        case .node: return "[작업]"
        case .decision: return "{조건}"
        case .circle: return "((완료))"
        case .connection, .labeledConnection: return " B"
        case .branch: return "{조건}"
        case .chain: return "[시작]"
        case .comment: return "설명을"
        case .xyXAxis: return "1월"
        case .xyYAxis: return "건수"
        case .xyBar, .xyLine: return "12"
        case .pieSlice: return "새 항목"
        case .ganttSection: return "개발"
        case .ganttTask: return "작업"
        case .ganttMilestone: return "검토 완료"
        case .timelineEvent: return "새로운 결정"
        case .sequenceParticipant: return "새 참여자"
        case .sequenceMessage: return "요청 내용"
        case .sequenceReply: return "응답 내용"
        case .markmapHeading: return "새 주제"
        case .markmapChild: return "새 항목"
        case .markmapLink: return "참고"
        case .binomial: return "{n}"
        case .overline: return "{x}"
        case .derivative: return "{d y}"
        case .matrix3x3, .pmatrix2x2: return " a & b"
        case .roundedNode: return "(작업)"
        case .databaseNode: return "(데이터)"
        case .subgraphBlock: return "[그룹]"
        case .xyTitle: return "성과 추이"
        case .pieAnotherSlice: return "다른 항목"
        case .sequenceNote: return "참고 사항"
        case .markmapTask: return "확인할 일"
        case .markmapBold: return "중요 주제"
        case .markmapCode: return "코드"
        default: return nil
        }
    }
    private var focusOffset: Int {
        switch self {
        case .fraction, .superscript, .subscriptValue, .squareRoot, .nthRoot,
             .summation, .product, .limit, .partialDerivative, .vector,
             .textInMath, .decision, .node, .branch, .chain,
             .binomial, .overline, .derivative, .matrix3x3, .pmatrix2x2: return 1
        case .parentheses, .absoluteValue, .matrix2x2, .casesBlock,
             .connection, .labeledConnection: return 1
        case .circle: return 2
        case .gatheredEquations, .alignedEquations: return 0
        case .integral, .definiteIntegral: return 0
        case .xyXAxis, .xyYAxis, .xyBar, .xyLine, .pieSlice: return 0
        default: return 0
        }
    }
    var caretBack: Int {
        guard let token = focusToken else { return 0 }
        let ns = source as NSString
        let match = ns.range(of: token)
        return match.location == NSNotFound ? 0 : ns.length - (match.location + focusOffset)
    }
    // If a user highlights an expression before pressing the math button,
    // wrap that expression in the construct rather than silently deleting it.
    // Replaces one source character at the focus caret when appropriate.
    var wrapsSelection: Bool {
        switch self {
        case .fraction, .superscript, .subscriptValue, .squareRoot, .nthRoot,
             .parentheses, .absoluteValue, .vector, .overline: return true
        default: return false
        }
    }
    var beginsOnNewLine: Bool {
        switch self {
        case .branch, .chain, .comment, .xyXAxis, .xyYAxis, .xyBar, .xyLine, .pieSlice,
             .ganttSection, .ganttTask, .ganttMilestone, .timelineEvent,
             .sequenceParticipant, .sequenceMessage, .sequenceReply,
             .markmapHeading, .markmapChild, .roundedNode, .databaseNode,
             .dottedConnection, .twoWayConnection, .subgraphBlock,
             .xyTitle, .xySecondLine, .pieAnotherSlice,
             .ganttDateFormat, .ganttExcludes, .timelineSection,
             .sequenceNote, .sequenceActivation, .sequenceAlternative, .sequenceLoop,
             .markmapTask, .markmapBold, .markmapCode: return true
        default: return false
        }
    }
    var help: String { "원문에 삽입: \(source.replacingOccurrences(of: "\n", with: "  "))" }
}

// Pure projection used by the native editor, tested without AppKit.
enum MarkdownAssistInsertionCore {
    struct Prepared {
        let source: String
        let caretBack: Int
    }
    static func prepare(source: String, caretBack: Int,
                        selectedText: String, wrapsSelection: Bool) -> Prepared {
        let ns = source as NSString
        let insertionPoint = ns.length - caretBack
        guard wrapsSelection, !selectedText.isEmpty, insertionPoint >= 0,
              insertionPoint < ns.length else { return Prepared(source: source, caretBack: caretBack) }
        let updated = ns.replacingCharacters(in: NSRange(location: insertionPoint, length: 1), with: selectedText)
        let after = insertionPoint + (selectedText as NSString).length
        return Prepared(source: updated, caretBack: (updated as NSString).length - after)
    }
}

// Pure input transformations let us test nesting without macOS/AppKit.
enum MarkdownIndentCore {
    struct Change {
        let range: NSRange
        let replacement: String
        let selection: NSRange
    }
    static func change(in source: String, selection: NSRange, outdent: Bool) -> Change? {
        let ns = source as NSString
        let location = min(max(0, selection.location), ns.length)
        let end = min(ns.length, location + max(0, selection.length))
        let caretLineRange = ns.lineRange(for: NSRange(location: location, length: 0))
        if !outdent && selection.length == 0 {
            // A lone '-' (or numbered marker) is not a Markdown list yet.
            // Tab immediately after it completes the separator, rather than
            // moving the marker and surprising the user.
            let rawLine = ns.substring(with: caretLineRange).trimmingCharacters(in: .newlines)
            let leading = rawLine.prefix(while: { $0 == " " || $0 == "\t" })
            let marker = String(rawLine.dropFirst(leading.count))
            if marker.range(of: #"^(?:[-+*]|[0-9]{1,9}[.)])$"#,
                            options: .regularExpression) != nil &&
                location == caretLineRange.location + (rawLine as NSString).length {
                return Change(range: NSRange(location: location, length: 0), replacement: " ",
                              selection: NSRange(location: location + 1, length: 0))
            }
        }
        // A selection ending at the start of a next line does not include it.
        let effectiveEnd = end > location ? end - 1 : end
        let startLine = caretLineRange.location
        let lastLine = ns.lineRange(for: NSRange(location: effectiveEnd, length: 0))
        let lineRange = NSRange(location: startLine, length: NSMaxRange(lastLine) - startLine)
        let text = ns.substring(with: lineRange)
        let lines = text.components(separatedBy: "\n")
        let multi = lineRange.length != caretLineRange.length
        // When indenting several list items, use ONE step so mixed 9./10.
        // markers stay at the same nesting level.
        let commonStep: Int? = multi ? lines.compactMap(MarkdownListSyntax.item)
            .map { max(2, $0.marker.count + 1) }.max() : nil
        var edited: [String] = []
        var firstDelta = 0
        var lineOffset = lineRange.location
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 && line.isEmpty && text.hasSuffix("\n") {
                edited.append(line)
                continue
            }
            let existing = line.prefix(while: { $0 == " " || $0 == "\t" })
            let indentWidth = MarkdownListSyntax.indentation(String(existing))
            let list = MarkdownListSyntax.item(line)
            var step = commonStep ?? list.map { max(2, $0.marker.count + 1) } ?? 2
            // The nearest earlier shallower list controls the child column.
            // Unlike a raw four-column tab, '10.' requires four spaces,
            // while '-' requires two. Do not alter old notes proactively.
            var earlier: [MarkdownListSyntax.Item] = []
            if !multi && lineOffset > 0 {
                let preceding = ns.substring(to: lineOffset).components(separatedBy: "\n")
                earlier = preceding.dropLast().compactMap(MarkdownListSyntax.item)
            }
            if !multi, let current = list {
                if outdent, let parent = earlier.reversed().first(where: {
                    $0.indent < current.indent && $0.contentColumn <= current.indent
                }) {
                    step = current.indent - parent.indent
                } else if !outdent, let peer = earlier.last, peer.indent == current.indent {
                    step = max(step, peer.contentColumn - current.indent)
                }
            } else if !multi && !outdent && line.trimmingCharacters(in: .whitespaces).isEmpty,
                      let prior = earlier.last {
                // A blank line immediately after a list item follows the
                // item's content column when Tab is pressed.
                let previousLine = ns.substring(to: lineOffset).components(separatedBy: "\n")
                if previousLine.count >= 2,
                   MarkdownListSyntax.item(previousLine[previousLine.count - 2]) != nil,
                   indentWidth < prior.contentColumn {
                    step = prior.contentColumn - indentWidth
                }
            }
            let changed: String
            if outdent {
                if line.hasPrefix("\t") {
                    changed = String(line.dropFirst())
                } else {
                    changed = String(line.dropFirst(min(step, existing.count)))
                }
            } else {
                changed = String(repeating: " ", count: step) + line
            }
            if index == 0 { firstDelta = (changed as NSString).length - (line as NSString).length }
            edited.append(changed)
            lineOffset += (line as NSString).length + 1
        }
        let replacement = edited.joined(separator: "\n")
        guard replacement != text else { return nil }
        let newSelection: NSRange
        if multi || selection.length > 0 {
            newSelection = NSRange(location: lineRange.location, length: (replacement as NSString).length)
        } else {
            newSelection = NSRange(location: max(lineRange.location, location + firstDelta), length: 0)
        }
        return Change(range: lineRange, replacement: replacement, selection: newSelection)
    }

    static func nextListPrefix(after line: String) -> String? {
        guard let item = MarkdownListSyntax.item(line) else { return nil }
        if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
        let leading = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let marker = item.ordered ? String(item.start + 1) + String(item.marker.last!) : item.marker
        let task = item.text.hasPrefix("[ ] ") || item.text.hasPrefix("[x] ") || item.text.hasPrefix("[X] ") ? "[ ] " : ""
        return leading + marker + " " + task
    }
}
