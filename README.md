# jgy-cc-statusline

Claude Code 의 statusline 을 두 줄(+포트 보너스 한 줄)로 풍성하게 채워주는 커스텀 스크립트입니다. 모델·브랜치·PR·diff 와 컨텍스트·rate limit·시계, 그리고 지금 LISTEN 중인 dev 포트까지 한눈에 보입니다. OSC 8 하이퍼링크가 박혀 있어서 Ghostty/iTerm2/WezTerm/kitty 같은 터미널에서는 클릭하면 바로 열려요.

## 보이는 모습

```
Opus 4.7 xhigh │ ⎇ main │ PR │ +303/-126
CTX 24% (256k/1M) │ 5h 92% (↻2h 30m) │ 7d 41% (↻5d 12h) │ 13:12:42
💬 오늘도 화이팅
3000·next  5173·vite  52946·node
```

- **브랜치명** 클릭 → GitHub/GitLab/Bitbucket 의 해당 브랜치 페이지
- **PR** 클릭 → 저장소의 PR/MR 목록 페이지
- **포트 번호** 클릭 → `http://localhost:<port>`
- 브랜치가 35자 넘으면 `…` 으로 줄여서 표시 (URL 은 풀 네임 그대로 유지)
- rate limit 은 단조증가 가드를 걸어둬서 캐시 갱신 직후 깜빡이는 현상 없음
- 💬 라인은 30분마다 약 30초 동안만 떴다가 사라짐 (config 로 조절 가능)

## 메시지 + 자동 업데이트

별도의 인프라 없이 Gist 한 개로 메시지를 운영할 수 있습니다.

- **메시지 소스**: 아무 URL 이나 가능 (한 줄 plain text 응답). Gist raw URL 추천.
- **새로고침**: 60분에 한 번 백그라운드 fetch. Claude Code 동작에 영향 없음.
- **반영**: 가져온 메시지가 캐시와 다르면 다음 노출 윈도우부터 새 내용 표시.
- **스크립트 자체 업데이트**: GitHub raw URL 등 신뢰할 수 있는 소스를 `SCRIPT_URL` 에 적어두면 60분마다 받아서 syntax 검증 후 본체를 atomic swap. 직전 버전은 `.bak` 으로 보관.

## 동작 환경

- macOS (lsof, `stat -f`, `date -j -f` 등 macOS 옵션 사용)
- Claude Code 의 `statusLine` 커스텀 명령
- jq (`brew install jq`)
- bash, git, lsof, curl — macOS 기본 설치

리눅스에서도 stat/date 호환 옵션 몇 줄만 손보면 동작합니다.

## 설치

### Claude Code 한테 시키기 (가장 편함)

이 저장소를 클론한 뒤 그 디렉터리에서 Claude Code 를 띄우고, [`INSTALL_PROMPT.md`](./INSTALL_PROMPT.md) 안의 프롬프트를 통째로 붙여넣으면 됩니다. 백업 → 복사 → settings.json 등록 → conf 파일 생성 → 캐시 정리까지 알아서 처리합니다.

### 수동 설치

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
cp jgy-cc-statusline.conf.example ~/.claude/jgy-cc-statusline.conf
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

## 메시지 운영 흐름 (Gist 추천)

1. <https://gist.github.com> 에서 새 gist 생성. public/secret 아무거나.
2. 파일명: `message.txt` (자유). 내용: 표시할 메시지 한 줄.
3. **Raw** 버튼 → URL 복사 (예: `https://gist.githubusercontent.com/<user>/<id>/raw`).
4. `~/.claude/jgy-cc-statusline.conf` 의 `MESSAGE_URL` 에 붙여넣기.
5. 끝. 메시지 바꾸고 싶을 때 gist 페이지에서 편집·저장만 하면 60분 안에 반영됨 (GitHub CDN 캐시로 약간 지연 가능).

랜덤 풀, 시간대별 메시지 등 로직이 필요해지면 [val.town](https://val.town) 같은 곳에 함수 하나 띄우고 URL 만 교체하면 됩니다.

## 자동 업데이트 운영

이 저장소를 GitHub 에 push 한 뒤 raw URL 을 `SCRIPT_URL` 에 박아두세요. 예:

```
SCRIPT_URL="https://raw.githubusercontent.com/<user>/jgy-cc-statusline/main/statusline.sh"
```

이후 저장소에 푸시하면 팀원 모두 60분 이내에 자동 반영됩니다. 검증 단계:

1. shebang `#!/bin/bash` 일치
2. `bash -n` syntax 통과
3. 해시 다를 때만 swap, 직전 버전은 `~/.claude/statusline.sh.bak` 으로 보관

자동 업데이트 끄고 싶으면 `SCRIPT_URL=""` 으로 비우면 됩니다.

## 자주 만지게 되는 부분

- **브랜치명 길이 제한**: `branch:0:34` 의 34 — 늘리거나 줄이세요.
- **포트 화이트리스트**: `lsof` 결과를 awk 로 거르는 정규식에 원하는 명령어를 추가. 기본은 node/python/go-tools 등 흔한 dev 서버.
- **포트 범위**: 1024–65535. ephemeral 영역(49152+) 이 시끄러우면 49999 정도로 낮추세요.
- **색감**: `B_CYAN` ↔ `CYAN`, `DIM` 으로 톤 조절. 색 변수는 파일 상단 "색상 팔레트" 섹션에 모여 있습니다.
- **메시지 주기/노출 시간**: `SHOW_INTERVAL`, `SHOW_DURATION` (conf 파일).
- **동기화 주기**: `SYNC_INTERVAL` (기본 3600초 = 1시간).

## 라이선스

MIT. 마음대로 가져다 고쳐 쓰세요.
