import Foundation

// Data-only symbol catalog shared by the large mouse picker and its smoke test.
// Do not create alternate LaTeX spellings: the existing MarkdownAssistSnippet
// source is authoritative for both toolbar and slash-command insertion.
enum MemoWeaverMathSymbolCatalog {
    struct Section {
        let title: String
        let symbols: [MarkdownAssistSnippet]
    }

    static let sections: [Section] = [
        Section(title: "그리스 소문자", symbols: [
            .alpha, .beta, .gamma, .lowerDelta, .epsilon, .zeta, .eta,
            .theta, .iota, .kappa, .lambdaSymbol, .mu, .nu, .xi,
            .omicron, .pi, .rho, .sigma, .tau, .upsilon, .phi,
            .chi, .psi, .omega, .varepsilon, .vartheta, .varphi, .varrho
        ]),
        Section(title: "그리스 대문자", symbols: [
            .upperGamma, .delta, .upperTheta, .upperLambda,
            .upperXi, .upperPi, .upperSigma, .upperPhi,
            .upperPsi, .upperOmega
        ]),
        Section(title: "비교·관계", symbols: [
            .approximate, .nearlyEqual, .equivalent, .congruent,
            .similar, .notEqual, .lessEqual, .greaterEqual,
            .muchLess, .muchGreater, .proportional,
            .perpendicular, .parallel
        ]),
        Section(title: "집합·수 체계", symbols: [
            .elementOf, .notElement, .emptySet,
            .subsetStrict, .subsetEqual, .supersetStrict,
            .supersetEqual, .unionSymbol, .intersectionSymbol,
            .setDifference, .naturalNumbers, .integers,
            .rationals, .reals, .complexNumbers
        ]),
        Section(title: "논리", symbols: [
            .forallSymbol, .existsSymbol, .notExists,
            .logicalAnd, .logicalOr, .logicalNot,
            .thereforeSymbol, .becauseSymbol, .implies, .iff
        ]),
        Section(title: "연산·미적분", symbols: [
            .times, .plusMinus, .minusPlus, .divideSymbol,
            .circOperator, .tensorProduct, .directSum,
            .nabla, .partialSymbol, .contourIntegral,
            .doubleIntegral, .infinity, .ellipsisHorizontal,
            .ellipsisCenter
        ]),
        Section(title: "화살표", symbols: [
            .leftArrow, .rightArrow, .doubleLeftArrow,
            .doubleRightArrow, .doubleArrow, .mapsTo,
            .upArrow, .downArrow, .upDownArrow
        ])
    ]

    static var allSymbols: [MarkdownAssistSnippet] {
        sections.flatMap(\.symbols)
    }
}
