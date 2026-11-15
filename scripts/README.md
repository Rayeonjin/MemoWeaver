# 스크립트 안내

터미널에서 README와 `build.sh`가 있는 폴더로 이동한 뒤 실행하세요.

```bash
./install-v0.9.70.sh --verify
```

현재 버전의 테스트를 실행하고 앱을 빌드합니다. 설치된 앱은 교체하지 않습니다.
특정 테스트만 실행하려면 같은 폴더에서 다음처럼 입력하세요.

```bash
./scripts/tests/test-review-stability.sh
./scripts/tests/test-third-party-licenses.sh
```

| 폴더 | 용도 |
|---|---|
| `install/legacy/` | 과거 버전 설치 스크립트 |
| `tests/` | 현재 및 과거 버전의 테스트 실행 스크립트 |
| `renderers/` | 개발용 렌더러 준비·이전 도구 |
| `diagnostics/` | 클립보드 등 진단 도구 |

이전 버전의 테스트도 기록으로 남아 있습니다. 당시 버전 번호나 폴더 구조를
확인하는 테스트가 있어, 지금 실행하면 실패할 수 있습니다. 현재 실행할
테스트는 `install-v0.9.70.sh`에 적힌 목록을 기준으로 확인하세요.

`renderers/`의 도구는 앱에 들어가는 JavaScript 파일을 바꾸는 개발용 도구입니다.
메모를 쓰거나 소스에서 앱을 빌드할 때는 실행하지 않아도 됩니다.
