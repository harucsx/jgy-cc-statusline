# jgy-cc-statusline

Claude Code와 Codex CLI에서 모델·브랜치·컨텍스트·사용 한도를 확인하는 상태바입니다.

- **Claude Code**: 여러 줄로 표시하는 커스텀 스크립트. PR 링크, 시계, dev 포트, 메시지도 제공합니다.
- **Codex CLI**: 내장 상태바에 표시 항목과 색상을 설정하는 프리셋. [Codex 설치 안내](#codex-cli-설치) 또는 [Codex 설치 프롬프트](./CODEX_INSTALL_PROMPT.md)를 사용하세요.

두 도구를 함께 사용해도 됩니다. Claude 설치는 `~/.claude/settings.json`, Codex 설치는 `${CODEX_HOME:-~/.codex}/config.toml`을 사용합니다.

## Claude Code에서 보이는 모습

두 줄(+포트 보너스 한 줄)로 표시합니다. OSC 8 하이퍼링크를 지원하는 Ghostty/iTerm2/WezTerm/kitty 같은 터미널에서는 클릭하면 바로 열려요.

```
💬 어제의 나보다 한 끗 나아지면 그게 실력이다.
Opus 4.7 xhigh │ ⎇ main │ PR │ +303/-126
CTX 24% (256k/1M) │ 5h 92% (↻2h 30m) │ 7d 41% (↻5d 12h) │ 13:12:42
3000·next  5173·vite  52946·node
```

- **브랜치명** 클릭 → GitHub/GitLab/Bitbucket 의 해당 브랜치 페이지
- **PR** 클릭 → 저장소의 PR/MR 목록 페이지
- **포트 번호** 클릭 → `http://localhost:<port>`
- 브랜치가 35자 넘으면 `…` 으로 줄여서 표시 (URL 은 풀 네임 그대로 유지)
- rate limit 은 단조증가 가드를 걸어둬서 캐시 갱신 직후 깜빡이는 현상 없음
- 💬 라인은 30분마다 약 30초 동안만 떴다가 사라짐 (config 로 조절 가능)

## Claude Code 메시지 + 자동 업데이트

별도의 인프라 없이 Gist 한 개로 메시지를 운영할 수 있습니다.

- **메시지 소스**: 아무 URL 이나 가능 (한 줄 plain text 응답). Gist raw URL 추천.
- **새로고침**: 60분에 한 번 백그라운드 fetch. Claude Code 동작에 영향 없음.
- **반영**: 가져온 메시지가 캐시와 다르면 다음 노출 윈도우부터 새 내용 표시.
- **스크립트 자체 업데이트**: GitHub raw URL 등 신뢰할 수 있는 소스를 `SCRIPT_URL` 에 적어두면 60분마다 받아서 syntax 검증 후 본체를 atomic swap. 직전 버전은 `.bak` 으로 보관.

## Claude Code 동작 환경

- macOS (lsof, `stat -f`, `date -j -f` 등 macOS 옵션 사용)
- Claude Code 의 `statusLine` 커스텀 명령
- jq (`brew install jq`)
- bash, git, lsof, curl — macOS 기본 설치

리눅스에서도 stat/date 호환 옵션 몇 줄만 손보면 동작합니다.

## Claude Code 설치

### 가장 편함 — 클론 없이 프롬프트 한 번만

아무 디렉터리에서 Claude Code 를 띄우고 [`INSTALL_PROMPT.md`](./INSTALL_PROMPT.md) 의 박스 안 내용을 그대로 채팅에 붙여넣으세요. statusline 본체와 conf 를 GitHub raw 에서 받아 `~/.claude/` 에 설치하고 settings.json 까지 자동 등록합니다.

### 수동 설치

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/harucsx/jgy-cc-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
[ ! -f ~/.claude/jgy-cc-statusline.conf ] && curl -fsSL https://raw.githubusercontent.com/harucsx/jgy-cc-statusline/main/jgy-cc-statusline.conf.example -o ~/.claude/jgy-cc-statusline.conf
```

`~/.claude/settings.json` 에 다음 키를 추가하세요 (다른 키는 그대로 두고).

```json
"statusLine": {
  "type": "command",
  "command": "bash /Users/YOUR_USERNAME/.claude/statusline.sh"
}
```

`$HOME` 같은 셸 변수는 Claude Code 가 풀어주지 않으니 절대경로로 박아야 합니다.

`~/.claude/jgy-cc-statusline.conf` 의 `MESSAGE_URL` / `SCRIPT_URL` 에 원하는 URL 을 넣어주세요. 빈 값이면 해당 기능만 OFF 됩니다.

마지막으로 캐시를 비우면 즉시 반영됩니다.

```bash
rm -f /tmp/claude-statusline-*
```

## Codex CLI 설치

Codex CLI는 내장 상태바의 `tui.status_line` 항목을 설정합니다. [`install-codex.py`](./install-codex.py)를 한 번 실행하면 다음 구성이 적용됩니다.

```text
모델·추론 강도 · Git 브랜치 · 브랜치 변경량 · 컨텍스트 사용률 · 컨텍스트 크기 · 5시간 한도 · 주간 한도
```

실제 문구와 표시 여부는 Codex 버전, 계정, 세션 데이터, 터미널 너비에 따라 달라집니다. 데이터가 없는 항목은 생략될 수 있습니다.

### 동작 환경

- `/statusline`을 지원하는 Codex CLI. 이 프리셋은 **0.154.0**에서 검증했습니다. 항목을 인식하지 못하면 Codex를 업데이트하세요.
- **Python 3.11 이상**. 추가 Python 패키지는 필요 없습니다.
- macOS에서 검증. 설치 스크립트는 macOS 전용 명령을 사용하지 않으며 Linux/WSL에서도 같은 명령으로 실행할 수 있습니다. Windows 네이티브 환경은 검증하지 않았습니다.

Codex용 설치에는 `jq`, `lsof`, Claude Code가 필요 없습니다. Python을 설치하기 어려우면 아래 수동 설정을 사용하세요.

### 클론 없이 설치

[`CODEX_INSTALL_PROMPT.md`](./CODEX_INSTALL_PROMPT.md)의 내용을 Codex CLI 채팅에 붙여넣거나, 터미널에서 다음 명령을 실행하세요.

```bash
curl -fsSL https://raw.githubusercontent.com/harucsx/jgy-cc-statusline/main/install-codex.py -o install-codex.py &&
python3 install-codex.py --dry-run &&
python3 install-codex.py
```

저장소를 클론했다면 해당 디렉터리에서 두 `python3` 명령만 실행하면 됩니다. 새 Codex CLI 세션부터 적용됩니다. 설치 후 `install-codex.py` 파일은 삭제해도 됩니다.

### 설정 보존과 확인

설치 대상은 `$CODEX_HOME/config.toml`이며, `CODEX_HOME`이 없으면 `~/.codex/config.toml`입니다. 다른 파일을 지정하려면 `--config /path/to/config.toml`을 붙이세요.

- `[tui]`의 `status_line`, `status_line_use_colors` 두 키를 설정합니다. 이미 같은 값이면 파일을 다시 쓰지 않습니다.
- 기존 파일은 같은 디렉터리에 `config.toml.bak.<고유값>`으로 백업합니다. 나머지 설정이 보존됐는지 TOML로 비교한 뒤 원자적으로 저장합니다.
- `--dry-run`은 저장 없이 적용할 항목과 변경 여부를 확인합니다. `--show`는 저장된 상태바 두 키만 출력합니다.
- TOML 오류나 안전하게 수정할 수 없는 형식이면 설정을 쓰지 않고 종료합니다. `tui = { ... }` 또는 `tui.status_line = ...` 형태는 `[tui]` 섹션으로 옮기거나 `/statusline`으로 설정하세요.
- 심볼릭 링크로 관리하는 설정은 링크를 유지하고 실제 대상 파일을 백업·수정합니다.

```bash
python3 install-codex.py --show
```

항목과 순서는 Codex 안에서 `/statusline`으로 바꿀 수 있습니다. 이후 설치 스크립트를 다시 실행하면 이 저장소의 프리셋으로 돌아갑니다. 색상은 `[tui]`의 `status_line_use_colors = false`로 끌 수 있습니다.

### 수동 설정

대상 `config.toml`에 다음 설정을 넣으세요. 이미 `[tui]`가 있으면 그 섹션의 두 키만 수정하고, 섹션을 중복으로 추가하지 마세요.

```toml
[tui]
status_line = [
  "model-with-reasoning",
  "git-branch",
  "branch-changes",
  "context-used",
  "context-window-size",
  "five-hour-limit",
  "weekly-limit",
]
status_line_use_colors = true
```

### Claude Code와의 기능 차이

| 항목 | Codex 프리셋 |
| --- | --- |
| 모델·추론 강도 | `model-with-reasoning` |
| Git 브랜치 | `git-branch`. Git 저장소에서 표시 |
| 수정 줄 수 | `branch-changes`. 기본 브랜치 대비 커밋된 변경량이며, Claude의 세션 수정량과 다름 |
| 컨텍스트 | `context-used`, `context-window-size` |
| 사용 한도 | `five-hour-limit`, `weekly-limit`. Codex가 제공하는 한도 정보 표시 |
| PR 링크·클릭 링크·여러 줄 출력 | 이 프리셋에서 제공하지 않음 |
| 메시지 풀·시계·리스닝 포트·리셋까지 남은 시간 | 이 프리셋에서 제공하지 않음 |
| 스크립트 자동 업데이트 | 사용하지 않음. 상태바는 Codex가 직접 그림 |

`statusline.sh`, `jgy-cc-statusline.conf.example`, `MESSAGE_URL`, `SCRIPT_URL`은 Claude 전용입니다. Codex 설정에는 등록하지 않습니다. Codex 설치 스크립트는 실행 중에 메시지를 가져오거나 캐시를 만들지 않습니다.

### 되돌리기와 문제 해결

- **숨기기**: `[tui]`에서 `status_line = []`로 설정하세요.
- **Codex 기본값으로 복구**: `status_line`, `status_line_use_colors` 두 키를 제거하세요. `[tui]` 안의 다른 설정은 유지하세요.
- **설치 직전 상태로 복구**: 출력된 백업 파일에서 두 키의 이전 값을 복원하세요. 전체 백업으로 교체하면 설치 이후 바꾼 다른 설정도 되돌아갑니다.
- **상태바가 안 보이거나 항목이 빠짐**: 새 세션에서 `/statusline`으로 선택 상태를 확인하세요. Git 저장소 여부, 계정의 한도 정보 제공 여부, 터미널 너비도 확인하세요.
- **다른 설정이 적용됨**: `/debug-config`로 설정 계층을 확인하세요. 프로젝트/프로필 설정이나 실행 시 `-c` 옵션이 사용자 설정을 덮어쓸 수 있습니다. `--show`는 지정한 파일만 읽습니다.

근거: OpenAI 공식 문서의 [설정 참조](https://developers.openai.com/codex/config-reference/)와 [`/statusline` 명령](https://learn.chatgpt.com/docs/developer-commands#configure-footer-items-with-statusline).

## Claude Code 메시지 운영

기본값으로 `MESSAGE_URL` 이 이 저장소의 `messages.sample.txt` 를 가리키게 박혀있습니다. 즉 설치만 해도 위 샘플 메시지 풀에서 랜덤으로 한 줄씩 떠요. 메시지 풀 자체를 바꾸고 싶으면 두 가지 방법:

**A. 이 저장소의 `messages.sample.txt` 를 편집 (팀 공통 풀)**

push 하면 1시간 안에 모든 팀원에게 반영. 추천.

**B. 본인 전용 풀로 분리하고 싶을 때 (Gist)**

1. <https://gist.github.com> 에서 새 gist 생성.
2. 파일명 `messages.txt`, 내용은 한 줄에 한 메시지씩.
3. **Raw** 버튼 → URL 복사.
4. `~/.claude/jgy-cc-statusline.conf` 의 `MESSAGE_URL` 을 그 URL 로 교체.

랜덤 픽은 노출 윈도우마다 한 번 (30초 동안 같은 메시지 유지). 빈 줄은 자동으로 건너뜀.

시간대별 메시지, 외부 API 결합 등 로직이 필요해지면 [val.town](https://val.town) 같은 곳에 함수 하나 띄우고 URL 만 교체하면 됩니다.

## Claude Code 자동 업데이트 운영

이 저장소를 GitHub 에 push 한 뒤 raw URL 을 `SCRIPT_URL` 에 박아두세요. 예:

```
SCRIPT_URL="https://raw.githubusercontent.com/<user>/jgy-cc-statusline/main/statusline.sh"
```

이후 저장소에 푸시하면 팀원 모두 60분 이내에 자동 반영됩니다. 검증 단계:

1. shebang `#!/bin/bash` 일치
2. `bash -n` syntax 통과
3. 해시 다를 때만 swap, 직전 버전은 `~/.claude/statusline.sh.bak` 으로 보관

자동 업데이트 끄고 싶으면 `SCRIPT_URL=""` 으로 비우면 됩니다.

## Claude Code에서 자주 만지게 되는 부분

- **브랜치명 길이 제한**: `branch:0:34` 의 34 — 늘리거나 줄이세요.
- **포트 화이트리스트**: `lsof` 결과를 awk 로 거르는 정규식에 원하는 명령어를 추가. 기본은 node/python/go-tools 등 흔한 dev 서버.
- **포트 범위**: 1024–65535. ephemeral 영역(49152+) 이 시끄러우면 49999 정도로 낮추세요.
- **색감**: `B_CYAN` ↔ `CYAN`, `DIM` 으로 톤 조절. 색 변수는 파일 상단 "색상 팔레트" 섹션에 모여 있습니다.
- **메시지 주기/노출 시간**: `SHOW_INTERVAL`, `SHOW_DURATION` (conf 파일).
- **동기화 주기**: `SYNC_INTERVAL` (기본 3600초 = 1시간).

## 개발 검증

```bash
python3 -m unittest discover -s tests -v
bash -n statusline.sh
```

Codex 설치 테스트는 임시 디렉터리에서 새 설치, 재실행, 기존 설정·백업 보존, 미리보기, 잘못된 TOML, 심볼릭 링크, 저장 실패를 확인합니다.

macOS의 Codex CLI 0.154.0에서 임시 설정으로 `--strict-config` 실행과 실제 TUI 표시도 확인했습니다. `/statusline`에서 7개 항목과 색상 선택을 확인했고, 상태바에 모델·추론 강도, 브랜치, `+1 -0` 변경량, 컨텍스트 사용률, 주간 한도가 표시됐습니다. 5시간 한도와 컨텍스트 크기는 해당 대기 세션에서 데이터가 없어 생략됐습니다. 모델 요청을 보내는 검증은 수행하지 않았습니다.

## 라이선스

MIT. 마음대로 가져다 고쳐 쓰세요.
