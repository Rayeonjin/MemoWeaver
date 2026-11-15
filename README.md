# MemoWeaver

Markdown 원문과 미리보기를 나란히 놓고 쓰는 Mac 메모 앱입니다.

메모는 내 Mac에 저장됩니다. 수식이나 다이어그램도 원문으로 작성하고 옆에서 결과를 확인할 수 있습니다. 메모가 쌓이면 기억지도에서 서로 어떤 업무로 이어지는지 살펴볼 수 있고요. AI 기능을 쓰고 싶다면 Ollama를 연결하면 됩니다.

**현재 버전: v0.9.70 · 빌드 103 · 검증 후보(QA)**

[변경 이력](docs/releases/CHANGELOG_v0.9.70.md) · [설치·업데이트 안내](docs/INSTALL.md) · [문서 모음](docs/README.md)

![MemoWeaver의 Markdown 원문 편집창과 Mermaid·LaTeX·표 미리보기](docs/images/editor-preview.jpg)

*소개용 메모를 넣고 촬영한 실제 앱 화면입니다.*

## 주요 기능

- Markdown 원문 편집과 미리보기, 창 비율 조절
- 표의 행·열 편집, 본문 변경 이력 비교·복원, 비동기 이미지 붙여넣기
- LaTeX 수식, Mermaid 다이어그램, Markmap 마인드맵, 표, 코드 블록
- `[[메모 제목]]` 링크와 이 메모를 참조하는 역방향 링크
- 업무 관계와 원문 근거를 보여 주는 기억지도, 확대·축소와 드래그
- 노트북 분류, 검색, 고정, 자동 저장, 이미지 붙여넣기, JSON 백업
- Ollama를 이용한 로컬 AI 질문과 관계 분석

메모 작성과 미리보기는 AI 없이도 쓸 수 있습니다. 수식과 다이어그램을 표시하는 데 필요한 파일도 앱에 들어 있습니다.

## 어떤 식으로 쓰나요?

### 편집창과 미리보기

위 화면의 왼쪽은 원문, 오른쪽은 미리보기입니다. 같은 메모 안에 업무 흐름도와 진행률 수식, 표를 넣었습니다. 창 사이의 경계를 움직여 편한 비율로 맞출 수 있습니다.

[화면에 사용한 예시 메모](docs/examples/introduction.md)를 복사해 직접 편집해 보세요.

### 기억지도

![MemoWeaver 기억지도: 고객 요청·설계 변경·검증 완료의 관계와 양쪽 원문 근거](docs/images/memory-map.jpg)

“고객 요청 때문에 설계를 바꿨고, 시험으로 결과를 확인했다”는 예시입니다. 기억지도는 이런 업무 관계를 연결해 보여 줍니다. 비슷한 단어가 들어 있다는 이유만으로 선을 긋지는 않습니다.

지도를 확대하거나 메모를 드래그해 살펴보세요. 연결을 누르면 왜 이어졌는지 설명과 양쪽 메모의 원문을 함께 볼 수 있습니다.

화면 속 메모와 관계는 촬영용으로 미리 준비했습니다. 실제 AI가 분석한 결과는 아닙니다. [촬영에 사용한 데이터와 방법](docs/images/README.md)

## 설치

현재는 소스를 내려받아 Mac에서 직접 빌드하는 방식입니다. 완성된 `.app`이나 `.dmg` 파일은 배포하지 않습니다. 아래 순서대로 설치하면 응용 프로그램 폴더에 `MemoWeaver.app`이 생깁니다.

### 1. 소스 받기

[설치 스크립트가 반영된 최신 소스 ZIP](https://github.com/Rayeonjin/MemoWeaver/archive/refs/heads/main.zip)을 내려받아 압축을 풉니다. GitHub 로그인은 필요하지 않습니다.

[v0.9.69 당시 소스 ZIP](https://github.com/Rayeonjin/MemoWeaver/archive/refs/tags/v0.9.69-qa.zip)도 보관하고 있습니다. 이 과거 ZIP은 사용자 응용 프로그램 폴더에 설치하는 이전 방식을 사용합니다.

### 2. Apple 개발 도구 설치

macOS 14 이상에서 터미널을 열고 실행합니다.

```bash
xcode-select --install
```

이미 설치되어 있다는 메시지는 정상입니다. 유료 Apple Developer 계정이나 전체 Xcode 설치는 필요하지 않습니다.

### 3. 폴더로 이동해 설치

터미널에 `cd `를 입력한 다음 압축을 푼 소스 폴더를 끌어다 놓고 Enter를 누릅니다. 기존 MemoWeaver가 실행 중이면 먼저 종료하세요.

```bash
chmod +x *.sh
./install-v0.9.70.sh
```

빌드가 끝나면 **`/Applications/MemoWeaver.app`**에 설치하고 실행합니다. Finder의 **응용 프로그램**에서 찾을 수 있습니다. 기존 앱이 사용자 폴더에 있어도 기본 설치 위치는 같습니다. 폴더에 쓰기 권한이 없으면 관리자 암호를 물을 수 있습니다.

설치 위치를 직접 고르거나 검사만 실행하려면 [설치 안내](docs/INSTALL.md)를 참고하세요.

## 처음 실행했다면

환영 메모에 간단한 사용법을 적어 두었습니다. 새 메모를 만들어 쓰거나, 위의 예시 메모를 복사해서 수식과 다이어그램부터 바꿔 보세요. 다른 메모를 연결할 때는 `[[메모 제목]]`을 쓰면 됩니다.

AI 기능은 Ollama와 모델을 따로 준비한 뒤 앱의 AI 설정에서 연결하세요. AI가 제안한 관계는 원문을 읽고 맞는지 확인하는 것이 좋습니다.

기억지도에서 가까이 놓인 메모가 반드시 더 관련 있는 것은 아닙니다. 연결선의 설명을 확인해 주세요. 드래그한 위치와 확대 상태는 현재 지도에서만 유지됩니다.

## 업데이트와 백업

설정 → 앱 정보의 **업데이트 확인**에서 새 버전이 나왔는지 볼 수 있습니다. 설치는 직접 진행해야 합니다.

업데이트할 소스를 별도 폴더에 풀고, 앱을 종료한 뒤 그 폴더에서 실행합니다.

```bash
./backup-before-real-use.sh
./install-v0.9.70.sh
```

위 명령은 기존 메모가 있을 때 쓰는 순서입니다. 처음 설치한다면 백업은 건너뛰세요. 새 버전에서는 그 버전의 README에 적힌 설치 명령을 사용하면 됩니다.

설치 프로그램은 이전 앱을 날짜가 붙은 숨김 파일로 남겨 둡니다. 다만 이것은 앱만 보관하는 것이므로 메모는 위 백업 명령으로 따로 보관해야 합니다. [백업 위치와 이전 앱으로 되돌리는 방법](docs/INSTALL.md)

## 테스트한 범위

v0.9.70에서 자동 검사 12개 묶음과 macOS 빌드를 통과했습니다. 한글·이모지가 있는 표 편집, 본문 복원, 이미지 삽입의 실행 취소·다시 실행과 입력 조합 보호를 임시 데이터로 검사했습니다. 설치 전후 기존 데이터 파일과 DB 테이블의 해시도 일치했습니다.

직접 입력한 한글의 실행 취소·다시 실행과 화면 전환 후 보존도 확인했습니다. 다만 실제 입력기의 조합 중 상태는 감지하지 못했으므로, 조합 중 동작은 자동 검사 통과와 구분해 미확인으로 남깁니다. Ollama의 관계 판단 품질, 알림 수신, 실제 트랙패드 핀치도 수동 확인 항목으로 남아 있습니다. [편집기 변경 기록](docs/reviews/EDITOR_IMPROVEMENTS_2026-11-16.md) · [검사 결과와 남은 항목](docs/releases/MAC_ACCEPTANCE_v0.9.70.md)

## 개발 응원하기

MemoWeaver를 잘 쓰고 계신다면 후원으로 개발을 응원해 주세요.

**[🧚 Fairy에서 개발 응원하기](https://fairy.hada.io/@catoshi)**

다른 후원 경로: [☕ Buy Me a Coffee](https://buymeacoffee.com/rayeonjin) · [♥ Ko-fi](https://ko-fi.com/rayeonjin)

후원하지 않아도 모든 기능을 똑같이 사용할 수 있습니다. 업데이트나 문의 응답에도 후원 여부에 따른 차이를 두지 않습니다.

## 라이선스와 저작권

Copyright (c) 2026 **Rayeonjin**.

프로젝트 자체 코드는 [Apache License 2.0](LICENSE)을 따릅니다. 사용·수정·재배포 시 해당 라이선스와 저작권·고지 유지 조건을 준수해야 합니다. 외부 라이브러리에는 각자의 라이선스가 적용됩니다.

[저작권 안내](docs/legal/COPYRIGHT.md) · [프로젝트 고지](NOTICE) · [외부 라이브러리 고지](THIRD_PARTY_NOTICES.md)

MemoWeaver 이름과 로고의 사용 범위는 [이름 정책](docs/legal/TRADEMARKS.md)과 [브랜드 자산 정책](docs/legal/BRAND_ASSETS.md)을 참고하세요. 파생 앱을 공식 MemoWeaver로 오인하게 하는 브랜딩은 허용하지 않습니다.

## 개발과 문의

버그와 개선 제안은 [GitHub Issues](https://github.com/Rayeonjin/MemoWeaver/issues)에 남겨 주세요. 개인 메모나 데이터베이스, 키·토큰은 첨부하지 마세요.

| 위치 | 내용 |
|---|---|
| `WorkOSMac/` | macOS 앱 소스와 앱에 포함되는 리소스 |
| `Tests/` | 회귀 테스트 코드와 `baselines/`의 기준 해시 |
| `scripts/` | 테스트·진단 도구, `install/legacy/`의 과거 설치 스크립트 |
| `docs/` | 설치 안내와 문서 목록 |
| `docs/development/` | 개발 절차, 인계, 배포 체크리스트 |
| `docs/reviews/`, `docs/releases/` | 테스트·검토 기록과 버전별 변경 이력 |
| `docs/legal/` | 저작권·이름·브랜드 안내 |
| `docs/images/`, `docs/examples/` | 소개 이미지와 예시 메모 |
| `Vendor/`, `THIRD_PARTY_LICENSES/` | 외부 리소스와 원문 라이선스 |

최상위의 `install-v0.9.70.sh`, `build.sh`, `install.sh`, `backup-before-real-use.sh`는
지금 사용하는 설치·빌드·백업 명령입니다. 과거 버전 설치 스크립트는
`scripts/install/legacy/`에 모아 두었습니다. [폴더별 안내](docs/REPOSITORY_LAYOUT.md)

개발 시 [작업 지침](AGENTS.md), [최신 인계](docs/development/LATEST_HANDOFF_SUMMARY.md), [검사 안내](scripts/README.md)를 먼저 확인하세요. 저장소에는 개인 메모·백업·모델 파일·서명 인증서를 포함하지 않습니다.
