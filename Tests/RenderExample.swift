import Foundation
@main struct RenderExample {
 static func main() throws {
  let note = WorkNote.from(["id":"example","title":"WorkOS 메모 시각화 테스트","body":"<p>오늘의 검토 결과</p>",
        "noteDate":"2026-10-16","status":"진행 중","workosBlocks":WorkBlock.encode([
         .make(.table),WorkBlock(id:"m",kind:.equation,source:#"\frac{a}{b} + \sqrt{x}"#),.make(.mermaid)])])
  try NoteDocuments.html(note:note).write(to:URL(fileURLWithPath:"/mnt/data/workos_render_preview.html"),atomically:true,encoding:.utf8)
 }
}
