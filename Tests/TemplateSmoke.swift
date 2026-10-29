import Foundation
@main
struct TemplateSmoke {
    static func main() {
        let raw = "**안녕하세요 {{이름}}님.** {{프로젝트}} 진행 상황은 {{상태}}입니다. 다시 {{이름}} 확인 부탁드립니다."
        assert(WorkOSTemplate.variables(in: raw) == ["이름", "프로젝트", "상태"])
        let filled = WorkOSTemplate.fill(raw, values: ["이름": "Kim", "프로젝트": "API", "상태": "완료"])
        assert(filled.contains("Kim님") && filled.contains("다시 Kim") && filled.contains("API") && filled.contains("완료"))
        assert(WorkOSTemplate.plain(filled).hasPrefix("안녕하세요 Kim님."))
        assert(WorkOSTemplate.fill("{{ 미지정 }}", values: [:]) == "{{ 미지정 }}")
        print("PASS reusable prompt/Telegram variable expansion")
    }
}
