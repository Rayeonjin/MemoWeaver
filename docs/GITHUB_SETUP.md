# GitHub에서 소스 받기

공개 저장소: [Rayeonjin/MemoWeaver](https://github.com/Rayeonjin/MemoWeaver) · 기본 브랜치: `main`

## 로그인 없이 다른 Mac에서 받기

[현재 검증 후보 v0.9.70 ZIP](https://github.com/Rayeonjin/MemoWeaver/archive/refs/tags/v0.9.70-qa.zip) 또는 [최신 개발 소스 ZIP](https://github.com/Rayeonjin/MemoWeaver/archive/refs/heads/main.zip)을 내려받을 수 있습니다. ZIP 안에는 소스 코드가 들어 있습니다. 압축을 푼 뒤 [설치 안내](INSTALL.md)를 따라 앱을 빌드하세요.

Git으로 받으려면 터미널에서 다음 명령을 실행하세요.

```bash
git clone https://github.com/Rayeonjin/MemoWeaver.git
cd MemoWeaver
./install-v0.9.70.sh --verify
```

마지막 명령은 테스트와 빌드만 합니다. 설치하려면 앱을 정상 종료하고 `./install-v0.9.70.sh`를 실행하세요. 최신 소스의 기본 설치 위치는 `/Applications/MemoWeaver.app`입니다. 과거 태그 ZIP은 당시 설치 방식을 유지합니다.

같은 폴더에서 최신 변경 사항을 받으려면 다음 명령을 실행하세요.

```bash
git pull --ff-only origin main
```

소스를 갱신한 뒤에는 README에서 설치 명령도 확인해 주세요. ZIP 다운로드와 위의 clone·pull 명령은 로그인 없이 사용할 수 있습니다.

## 개발용: 변경 사항 올리기

이 프로젝트는 집 컴퓨터에서 수정하고 GitHub에 올리는 방식으로 관리합니다. 다른 컴퓨터에서는 소스를 내려받아 빌드합니다. 앱을 설치해서 쓰려는 분은 이 아래 절차를 따라 할 필요가 없습니다.

```bash
git switch main
git pull --ff-only origin main
git switch -c weekly/YYYY-MM-DD-topic
```

앱 코드를 수정했다면 관련 테스트를 실행하세요. 현재 전체 테스트와 빌드 명령은 `./install-v0.9.70.sh --verify`입니다. 공개 전에는 `./tools/public-source-preflight.sh`를 실행합니다. 자세한 절차는 [개발 지침](development/WEEKLY_CODEX_PLAYBOOK.md)을 따릅니다.

강제 푸시나 이력 재작성은 하지 않습니다. 앱 결과물, 개인 메모, SQLite, 첨부 파일, 백업, 키·토큰은 업로드하지 않습니다. QA 태그는 테스트할 버전의 소스를 찾기 위한 표시입니다. 정식 안정 버전이라는 뜻은 아닙니다.

## 저장소 이력

2026-10-29 저장소를 `Rayeonjin`으로 옮겼습니다. 다른 Mac에서도 로그인 없이 소스를 받을 수 있도록 공개했으며, 기존 커밋과 태그는 그대로 남겼습니다. 최초 `v0.9.64-qa`는 안정성 수정 이전의 기준 소스입니다.

개발 컴퓨터에서는 `PUBLIC_REPOSITORY/MemoWeaver`만 Git으로 관리하고, `PRIVATE_KEEP_OFF_GITHUB`는 저장소 밖에 둡니다. ZIP으로 소스를 받았다면 이런 폴더를 따로 만들 필요는 없습니다.
