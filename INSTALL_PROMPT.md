# 설치 프롬프트

저장소를 클론할 필요 없이, **아무 디렉터리에서 Claude Code 를 띄우고** 아래 박스 안 내용을 통째로 복사해서 채팅에 붙여넣기만 하면 됩니다.

---

```
다음 두 파일을 GitHub 에서 받아 ~/.claude/ 에 설치해줘. macOS 환경 가정.

소스 URL:
- statusline.sh: https://raw.githubusercontent.com/harucsx/jgy-cc-statusline/main/statusline.sh
- conf 예시:    https://raw.githubusercontent.com/harucsx/jgy-cc-statusline/main/jgy-cc-statusline.conf.example

1. ~/.claude/ 디렉터리 없으면 mkdir.
2. 기존 ~/.claude/settings.json 이 있으면 ~/.claude/settings.json.bak.<unix-timestamp> 로 백업. 없으면 빈 {} 로 새로 생성.
3. statusline.sh URL 을 curl -fsSL 로 받아 ~/.claude/statusline.sh 로 저장 + chmod +x.
   검증: 첫 줄이 "#!/bin/bash" 인지, bash -n 통과하는지. 실패 시 중단하고 보고.
4. ~/.claude/jgy-cc-statusline.conf 가 없을 때만 conf 예시 URL 을 curl 로 받아 그 경로로 저장.
   이미 있으면 건드리지 말 것 (사용자 설정 보존).
5. jq 로 ~/.claude/settings.json 에 다음 키를 set (다른 기존 키는 보존):
   "statusLine": {
     "type": "command",
     "command": "bash <ABSOLUTE_HOME>/.claude/statusline.sh"
   }
   * <ABSOLUTE_HOME> 은 $HOME 을 미리 풀어 절대경로로 박을 것. Claude Code 는 셸 변수 안 풀어줌.
6. 의존성 점검:
   - jq, curl 없으면 "brew install jq curl" 라고 사용자에게 안내 (자동 설치 금지)
   - lsof, git, bash 는 macOS 기본 설치
7. /tmp/claude-statusline-* 캐시 파일 모두 삭제 (rm -f) 해서 즉시 반영.
8. 끝나면 다음 형식으로 보고:
   - 성공:
     ✅ 설치 완료. 새 Claude Code 세션에서 statusline 적용됨.
     메시지·자동업데이트는 conf 기본값으로 활성. 본인 풀 쓰려면 ~/.claude/jgy-cc-statusline.conf 의 MESSAGE_URL 만 교체.
   - 실패: 무엇이 막혔는지 한 줄.

리눅스면 stat -f, date -j -f, lsof -iTCP 등 macOS 의존 부분이 있어서 일부 동작 안 할 수 있다고 안내.
```

---

## 설치 후 할 일 (선택)

기본값으로 메시지 풀(`messages.sample.txt`)·자동 업데이트가 모두 켜져 있어서 추가 설정 없어도 동작합니다. 커스터마이즈할 일 생기면:

- **본인/팀 전용 메시지 풀** 쓰려면: `~/.claude/jgy-cc-statusline.conf` 의 `MESSAGE_URL` 을 자기 gist raw URL 로 교체.
- **자동 업데이트 끄려면**: 같은 파일에서 `SCRIPT_URL=""` 로 비우기.
- **노출 주기/시간 조절**: `SHOW_INTERVAL`, `SHOW_DURATION` (초 단위).

## 트러블슈팅

statusline 이 안 보이면:

- `cat ~/.claude/settings.json | jq .statusLine` 으로 등록 확인
- `cat /tmp/claude-statusline-last.json | bash ~/.claude/statusline.sh` 로 직접 실행해서 출력 확인

메시지가 안 뜨면:

- `cat /tmp/claude-statusline-message.txt` 캐시 확인 (비어있으면 fetch 실패)
- `curl -fsSL "$(grep MESSAGE_URL ~/.claude/jgy-cc-statusline.conf | cut -d= -f2 | tr -d '\"')"` 로 URL 자체 확인
- `rm /tmp/claude-statusline-sync-meta.json` 으로 다음 redraw 때 재시도 강제
