# GitHub에서 소스 받기와 개발하기

공개 저장소: [Rayeonjin/MemoWeaver](https://github.com/Rayeonjin/MemoWeaver) · 기본 브랜치: `main`

## 로그인 없이 다른 Mac에서 받기

[현재 검증 후보 v0.9.69 ZIP](https://github.com/Rayeonjin/MemoWeaver/archive/refs/tags/v0.9.69-qa.zip) 또는 [최신 개발 소스 ZIP](https://github.com/Rayeonjin/MemoWeaver/archive/refs/heads/main.zip)을 내려받을 수 있습니다. ZIP은 소스 코드이며, [설치 안내](INSTALL.md)에 따라 Mac에서 빌드해야 합니다.

Git을 사용할 경우:

```bash
git clone https://github.com/Rayeonjin/MemoWeaver.git
cd MemoWeaver
./install-v0.9.69.sh --verify
```

마지막 명령은 검사와 빌드만 수행합니다. 설치하려면 앱을 정상 종료하고 `./install-v0.9.69.sh`를 실행하세요. 새 설치 위치는 `~/Applications/MemoWeaver.app`입니다.

이후 최신 개발 소스를 받을 때:

```bash
git pull --ff-only origin main
```

업데이트한 README에서 현재 버전의 설치 명령을 확인하세요. 공개 저장소의 다운로드·clone·pull에는 GitHub 로그인이 필요하지 않습니다.

## 집에서 변경 사항 올리기

프로젝트 운영 원칙상 집 컴퓨터에서 소스를 수정하고 GitHub에 올립니다. 다른 컴퓨터에서는 내려받기와 로컬 빌드만 진행합니다.

```bash
git switch main
git pull --ff-only origin main
git switch -c weekly/YYYY-MM-DD-topic
```

변경 후에는 관련 검사와 공개 소스 검사를 수행합니다. 앱을 변경하는 경우 현재 전체 검증 명령은 `./install-v0.9.69.sh --verify`입니다. 공개 전에는 `./tools/public-source-preflight.sh`를 실행합니다. 자세한 절차는 [개발 지침](WEEKLY_CODEX_PLAYBOOK.md)을 따릅니다.

강제 푸시나 이력 재작성은 하지 않습니다. 앱 결과물, 개인 메모, SQLite, 첨부 파일, 백업, 키·토큰은 업로드하지 않습니다. QA 태그는 해당 소스의 위치를 표시하며 정식 안정성 인증을 뜻하지 않습니다.

## 저장소 이력

2026-10-29 소유자의 요청으로 `Rayeonjin`으로 이전하고 로그인 없는 소스 다운로드를 위해 공개했습니다. 기존 커밋과 태그는 유지했습니다. 최초 `v0.9.64-qa`는 안정성 수정 이전의 기준 소스입니다.

로컬 이전 자료의 `PUBLIC_REPOSITORY/MemoWeaver`만 Git 저장소이며, `PRIVATE_KEEP_OFF_GITHUB`는 저장소 밖에 보관합니다. 이 디렉터리 구성은 소스 ZIP을 받는 사용자에게 필요하지 않습니다.
