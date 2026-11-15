# 폴더별 안내

앱을 설치하려면 [설치 안내](INSTALL.md)부터 읽어 주세요. 아래는 소스를 살펴보거나 개발할 때 필요한 폴더 설명입니다.

```text
MemoWeaver/
├── README.md                  # 소개, 화면 예시, 설치 시작점
├── LICENSE / NOTICE           # 프로젝트 라이선스와 고지
├── THIRD_PARTY_NOTICES.md      # 외부 라이브러리 고지
├── AGENTS.md                  # 개발 작업 지침
├── install-v0.9.69.sh          # 현재 버전 설치·검사
├── build.sh / install.sh      # 빌드와 설치 위치 지정
├── backup-before-real-use.sh  # 메모 데이터 백업
├── WorkOSMac/                 # 앱 소스와 리소스
├── Tests/
│   └── baselines/             # 이전 기준 소스의 해시 기록
├── scripts/
│   ├── install/legacy/        # 과거 버전 설치 스크립트
│   ├── tests/                 # 테스트 실행
│   ├── diagnostics/           # 진단 도구
│   └── renderers/             # 개발용 렌더러 도구
├── docs/
│   ├── development/           # 인계·개발·배포 절차
│   ├── reviews/               # 기능 검토와 테스트 기록
│   ├── releases/              # 버전별 변경 이력과 확인표
│   ├── legal/                 # 저작권·브랜드 안내
│   ├── images/                # 소개 이미지
│   └── examples/              # 예시 메모
├── tools/                     # 소스 공개·라이선스 검사 도구
├── Vendor/                    # 외부 코드와 감사 재구성 자료
└── THIRD_PARTY_LICENSES/       # 원문 라이선스와 출처 기록
```

## 이전 자료를 찾을 때

2026-11-16에 최상위 파일과 문서 폴더를 정리했습니다.

- 최상위의 v0.9.64~v0.9.68 설치 스크립트 → `scripts/install/legacy/`
- `COPYRIGHT.md`, `TRADEMARKS.md`, `BRAND_ASSETS.md` → `docs/legal/`
- `QA/`의 두 해시 명세 → `Tests/baselines/`
- 개발 인계·작업 절차·배포 체크리스트 → `docs/development/`
- 안정성·업데이트 확인·기억지도 테스트 기록 → `docs/reviews/`

현재 버전 설치·빌드·백업 명령은 그대로입니다. 앱 소스, 외부 라이브러리, 원문 라이선스의 내용도 바꾸지 않았습니다. 라이선스 문서 안에 적힌 경로는 저장소 최상위를 기준으로 읽으면 됩니다. 앱에 복사되는 고지 파일 이름은 이전과 같습니다.

과거 설치 스크립트는 해당 버전의 앱을 내려받는 도구가 아닙니다. 현재 체크아웃한 소스를 빌드하므로, 예전 앱을 빌드하려면 그 버전의 태그나 ZIP을 사용하세요. 기존 Git 태그는 당시 폴더 구조를 유지합니다.

이전 해시 명세는 당시 소스의 기록입니다. 현재 파일 구조에 맞추려고 해시나 명세 안의 경로를 다시 쓰지 않았습니다. `build/`는 로컬 빌드 결과 폴더이며 GitHub에 올리지 않습니다.
