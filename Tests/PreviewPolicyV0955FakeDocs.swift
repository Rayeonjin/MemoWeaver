import Foundation
// Only supplies a stand-in for the serialized renderer, not the HTML format.
enum MarkdownPreviewMode: String, Sendable { case memo, standard }
enum NoteDocuments {
    static func markdownPreviewHTML(title: String, noteDate: String, status: String,
                                    markdown: String, mode: MarkdownPreviewMode) -> String {
        "\(title)|\(noteDate)|\(status)|\(markdown)|\(mode.rawValue)"
    }
}
