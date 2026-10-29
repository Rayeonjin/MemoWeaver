# MemoWeaver v0.9.62 / Build 95 — 외부 라이브러리 라이선스 실물 감사

**검토일:** 2026-10-28  
**검토 대상:** `MemoWeaver_Mac_v0.9.62_MOUSE_SYMBOLS_GITHUB_READINESS_QA_CLT.zip`의 실제 파일·빌드 스크립트·압축 JavaScript.  
**판정:** **조건부 공개 가능 / 현재 ZIP 그대로 '라이선스 정리 완료'를 선언하거나 완성된 앱 바이너리를 배포하는 것은 보류.**  
**한계:** 소스/번들 정적 분석 및 공식 라이선스 원문 대조. 정확한 `node_modules` 트리와 lockfile, esbuild metafile이 없어 모든 하위 의존성의 버전·라이선스는 아직 검증되지 않았다. 법률 자문이나 배포 적법성의 최종 보증이 아니다.

## 1. 중요한 결론

- Mermaid 12.2.0, Markmap `markmap-lib`/`markmap-view` 0.18.12, KaTeX 0.16.27은 **MIT**. 원칙적으로 수정·재배포·상업적 이용·무료 배포·후원을 허용하되 해당 저작권 표시와 라이선스 문구를 함께 보존해야 한다.
- `official-diagrams.js` 안에는 **DOMPurify 3.4.17**이 포함돼 있으며, 이 라이브러리는 `MPL-2.0 OR Apache-2.0`이다. 사용자는 **Apache-2.0 경로를 선택할 수 있다.** 이 경우 메모위버 전체 소스를 MPL로 전환할 필요는 없으나, Apache-2.0 전문 제공, 해당 저작권·NOTICE(존재할 경우) 보존, 수정 표시 등 재배포 조건을 준수해야 한다.
- 동일한 번들에서 `regenerator-runtime`, Lodash(Underscore.js 파생 고지 포함), MIT 행사/보간/Promise 기여 코드, `@gera2ld/jsx-dom` 2.2.2(ISC)의 라이선스 배너가 발견된다. 현재 프로젝트의 `THIRD_PARTY_NOTICES.md`는 이들을 기록하지 않는다.
- `build.sh`는 `WorkOSMac/Resources/*.js`를 `.app`에 복사하지만 **`THIRD_PARTY_NOTICES.md`는 복사하지 않는다.** 최종 `.app`만 받는 사용자는 온전한 라이선스 자료를 받지 못한다.
- 저장소 루트 `LICENSE`가 없다. 공개 저장소에 업로드할 수는 있어도, 메모위버 자체를 '오픈소스'라고 공개하려면 권리자가 별도의 소스 라이선스를 정해야 한다.
- 외부 라이브러리의 **라이선스 준수 문제와 앱 서명·공증·Mac GUI 테스트는 서로 다른 배포 관문**이다. 어느 하나도 다른 하나를 대신하지 못한다.

## 2. ZIP에서 확인한 라이브러리

| 구성 요소 | 버전/탐지 근거 | 라이선스 | 현재 판단 |
|---|---|---|---|
| Mermaid | `Vendor/official-diagrams/package.json`에 12.2.0 고정, 번들 렌더러 | MIT | 사용·재배포 가능; 저작권/라이선스 전문 고지 보완 |
| Markmap (`markmap-lib`, `markmap-view`) | 같은 manifest에 0.18.12 고정 | MIT | 사용·재배포 가능; 고지 보완 |
| KaTeX | 별도 `katex-mathml.js`, 기존 notices에 0.16.27, 공식 엔진 번들에도 KaTeX 코드 확인 | MIT | 기존 KaTeX 고지는 있으나 번들 내부 KaTeX의 정확한 패키지 버전은 재현 이력 필요 |
| DOMPurify | `official-diagrams.js` 내 `/*! @license DOMPurify 3.4.17 ... */` | Apache-2.0 **또는** MPL-2.0 | **고지 누락**. Apache-2.0 선택 및 전문/저작권 조건 정리 필요 |
| `@gera2ld/jsx-dom` | 번들 `/*! @gera2ld/jsx-dom v2.2.2 \| ISC License */` | ISC | **고지 누락**. ISC 전문·권리자 저작권 필요 |
| `regenerator-runtime` | 번들 `/*! regenerator-runtime ... license (MIT) */` | MIT | **고지 누락** |
| Lodash custom build 및 Underscore.js 파생 표기 | 번들 Lodash `@license` 주석 | MIT 기반 | **고지 누락**. Lodash + Underscore 표시 보존 |
| Promise Thenable / jQuery events 기반 코드 / 그래프 애니메이션 기여 코드 | 번들 내 `/*! ... */` 표시 | 해당 주석에서 MIT 명시 | 각각 해당 저작권/고지 확인 및 보존 |
| D3, Day.js, Markdown-it, Cytoscape 등 | 번들 코드 식별자·직접 패키지의 알려진 의존성 | 패키지별로 상이 | 번들에 실제 포함된 세부 패키지·버전을 metafile로 확정 후 고지 |
| `highlight.js` 등 Markmap 트리상 의존성 | npm 패키지 의존성 목록에 표시 | 예: highlight.js BSD-3-Clause | **현재 JS 파일에 실제 포함됐는지는 미확정**. tree-shaking 후 출력 확인 필요 |
| esbuild 0.25.12 | `Vendor/official-diagrams/package.json`의 `devDependencies` | MIT | **빌드 도구**. 해당 실행파일/코드를 앱에 포함하지 않음 |
| macOS Apple 프레임워크, 시스템 SQLite3 | Swift `import` 및 `-lsqlite3` | Apple 시스템/SQLite 조건 | npm 번들 서드파티 배포와 구별. ZIP에 별도 SQLite 바이너리 없음 |
| Ollama 및 AI 모델 | 로컬 서비스 호출 소스, 모델 파일 ZIP 내 미탐지 | 서비스/모델 각각 상이 | **배포물이 모델 가중치나 Ollama 실행파일을 포함하지 않아 현재 재배포 대상 아님**. 향후 동봉 시 별도 재검토 |

**주의:** 위 목록은 **실물에서 확인된 것과 미확정 후보를 명시적으로 구별한 예비 목록**이다. 누락 없는 SBOM으로 오인하지 말 것.

## 3. 재배포를 막는 확인된 공백 (P0)

### P0-1 — 재현할 수 없는 번들/부족한 하위 의존성 목록

- `Vendor/official-diagrams/`에는 `package.json`, `entry.js`만 있고 `package-lock.json`이 없다.
- `prepare-official-renderers.sh`는 임시 디렉터리에서 `npm install --no-save`를 호출한다. 직접 의존성은 버전을 고정했지만, **그때의 하위 의존성 버전은 잠금 파일로 보존하지 않는다.**
- `--legal-comments=inline`을 사용하므로 일부 법적 주석이 번들에 남아 있지만 **각 패키지의 완전한 저작권/라이선스 문서를 제공하는 대체물은 아니다.**
- `--metafile` 또는 원본 번들 생성 시 `node_modules`의 재현 정보가 없다. 현재 `entry.js`는 생성물과 일치하지 않는 정황이 있다. 예: 현재 소스에는 SVG 자연폭 및 `maxWidth = 'none'`이 있지만 번들에는 `maxWidth="100%"` 경로가 있다.

**보완:** 원본 패키지 버전 확정 → lockfile 생성 → `npm ci` 기반 재현 빌드 → esbuild `--metafile=...` 출력 → 실제 번들에 들어간 파일의 npm 패키지와 버전을 역추적 → 패키지별 라이선스 원문/NOTICE 수집 → 산출물 해시·버전·SBOM을 릴리스 자료로 보존. 재빌드한 JS는 도식 렌더링의 Mac UI 회귀 검증 후 교체.

### P0-2 — 라이선스 안내 문서 자체가 불충분

현재 `THIRD_PARTY_NOTICES.md`는 KaTeX의 MIT 전문과 Mermaid·Markmap 한 줄 안내는 있으나, 실제 번들에 발견된 DOMPurify 및 여러 구성 요소를 누락한다. **Mermaid·Markmap 각각의 원래 저작권 고지와 허가문 조건도 명시적으로 정리하는 편이 안전하다.**

**보완:** `THIRD_PARTY_NOTICES.md` 및 `THIRD_PARTY_LICENSES/`에 실제 포함된 패키지의 이름, 버전, 원본 URL, SPDX 식별자, 원래 권리자 표시, 요구되는 라이선스 전문과 NOTICE를 보관. DOMPurify는 `Apache-2.0` 옵션을 명시하여 이 조건으로 준수. 각 출처의 라이선스 텍스트는 임의로 요약하거나 생략하지 않는다.

### P0-3 — `.app` 배포 시 문서 누락

`build.sh`는 `katex-mathml.js`, `official-diagrams.js`만 `Contents/Resources/`로 복사한다. 서드파티 고지 문서를 `.app` 안에 복사하지 않음. 별도로 제공하는 소스 ZIP에만 고지를 두어서는 **앱 단독 배포 시** 충분하지 않다.

**보완:** 위 라이선스 문서 완성 후 `Contents/Resources/Licenses/`로 함께 패키징한다. 앱 설정 또는 앱 정보 화면에서 '오픈소스 라이선스' 메뉴를 추가하면 사용자가 확인하기 쉽다. 실제 `.app`의 자원 파일 존재 여부를 빌드 후 자동 테스트.

### P0-4 — 메모위버 자체 라이선스 선택

루트 `LICENSE`가 없는 상태에서는 소스가 공개돼도 다른 사용자가 재사용·기여할 수 있는 일반적인 오픈소스 권한을 명확하게 제공하지 않는다.

- **MIT**: 허용적인 재사용, 포크, 상업적 재배포까지 수용한다면 가장 단순한 선택. 자발적 후원과 양립 가능하다.
- **GPLv3**: 파생 배포물에 소스 공개 조건을 유지하려면 고려할 수 있으나 전체 의존성 호환성 및 배포 의무를 한 번 더 확인해야 한다.
- 앱 자체 `LICENSE`와 서드파티 `THIRD_PARTY_NOTICES`는 **서로 별개의 문서**다. 앱의 라이선스가 외부 라이브러리의 기존 허가 조건을 덮어쓰지는 않는다.

권리자 표시(실제 저작권자 이름/단체)는 프로젝트 소유자가 결정해야 하므로 임의로 채우지 않았다.

## 4. 배포 시나리오별 판정

| 배포 시나리오 | 판정 | 조건 |
|---|---|---|
| 개인이 자기 Mac에서만 사용 | **가능** | 일반적으로 재배포 조건은 발생하지 않음 |
| GitHub에 현재 파일을 '검토 중인 소스'로 게시 | **가능하나 비권장** | 저작권 표기와 서드파티 고지 미완성·이력 파일 관리에 주의. 오픈소스/라이선스 완전 준수 표현 금지 |
| GitHub에서 누구나 수정·배포할 수 있는 오픈소스 프로젝트로 공개 | **조건부 가능** | 루트 LICENSE + 서드파티 고지 및 SBOM 정리 필요 |
| `.app`을 다운로드해 실행하도록 일반 배포 | **현재 보류 권장** | 완전한 라이선스 문서 포함, 실제 Mac 안정성 QA, 서명/공증 정책 마련 |
| 공개 무료 배포 + GitHub Sponsors 후원 | **조건부 가능** | 위 라이선스 의무 준수 시 외부 MIT/Apache/ISC 라이브러리 사용과 후원 간 본질적 충돌 없음 |
| 유료 앱 판매 | **원칙적으로 가능** | 서드파티 조건, 메모위버 자체 선택 라이선스의 의무, 상표/서비스 고지 별도 검토 |

## 5. 권장 실행 순서

1. 메모위버 자체 라이선스 정책 결정(MIT 또는 다른 오픈소스 라이선스).
2. **현재 해시의 JS가 어떤 의존성 버전에서 생성됐는지** 재확인. 원본 build provenance가 없으면 현재 기능의 재현 빌드를 만들고 미리보기 화면을 실기기에서 회귀 검증.
3. lockfile + esbuild metafile + 완전한 라이선스/NOTICE 자료로 SBOM 완성. 라이선스 불명, GPL/AGPL, 상표 및 폰트/아이콘 문제를 별도 재검토.
4. 완성한 문서를 소스와 `.app`에 모두 포함하고 빌드 자동 검증 추가.
5. 기존 사용 데이터와 스크린샷·QA 샘플·문서에 개인 정보나 남의 저작물/브랜드 자산이 섞였는지 별도로 확인.
6. 소스 오픈베타 → 신뢰할 수 있는 설치 릴리스 → 후원 안내 순으로 진행. 후원 링크는 실제 승인된 계정으로 연결.

## 6. 검증된 기술적 증거

- 배포 ZIP SHA-256: `001499350d07c0ba91d052c6bfdf22cb603b30e1171269801277c2fdb5faa36a`.
- `WorkOSMac/Resources/official-diagrams.js`: 5,587,950 bytes, SHA-256 `9bbaa30a1961ce26626502392bc5f63280ec5822cfa45b7a9702092c96d1eff5`.
- `WorkOSMac/Resources/katex-mathml.js`: 265,168 bytes, SHA-256 `8852a8b8326f1d3e85412a7cd16de09f10186c1aefd70434607b001bbe443edc`.
- JS 법적 저작권·라이선스 주석: DOMPurify / regenerator-runtime / Lodash / Thenable / jQuery 기반 이벤트 / Bezier / Runge-Kutta / jsx-dom 등이 발견됨.
- `THIRD_PARTY_NOTICES.md`는 있으나 루트 `LICENSE`가 없고, `build.sh`에서 고지 문서 복사를 수행하지 않으며, 번들 lockfile/metafile이 제공되지 않음.
- 별도 `.ttf`, `.woff`, `.css` 등 리소스 파일은 현재 앱 `Resources/`에서 보이지 않음(아이콘 PNG와 두 JS 파일만 확인). 이 사실이 번들 내부의 모든 이미지·SVG의 권리 확인을 면제하지는 않음.

## 7. 공식·원문 참고 링크

- Mermaid MIT LICENSE: https://github.com/mermaid-js/mermaid/blob/develop/LICENSE
- Markmap MIT LICENSE: https://github.com/markmap/markmap/blob/master/LICENSE
- KaTeX MIT: https://github.com/KaTeX/KaTeX
- DOMPurify 이중 라이선스: https://github.com/cure53/DOMPurify , https://github.com/cure53/DOMPurify/blob/main/LICENSE
- Apache-2.0 재배포 조건: https://www.apache.org/licenses/LICENSE-2.0
- esbuild `legalComments`, `metafile`: https://esbuild.github.io/api/
- GitHub 저장소 라이선스 안내: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository
- GitHub Sponsors: https://docs.github.com/en/sponsors/receiving-sponsorships-through-github-sponsors

**결론:** 핵심 라이브러리의 라이선스는 공개·후원을 막지 않는다. 아직 해결되지 않은 문제는 **라이선스를 준수했다는 완전한 증거를 가진 배포물로 묶지 않은 것**이다. 따라서 '불법'이라고 단정할 근거도 없지만, 현재 파일을 '검증된 공개 배포판'으로 판정할 근거도 없다.
