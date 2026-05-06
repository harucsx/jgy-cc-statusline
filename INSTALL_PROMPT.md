# 설치 프롬프트

이 저장소를 클론한 디렉터리에서 Claude Code 를 띄운 다음, 아래 박스 안 내용을 통째로 복사해서 채팅에 붙여넣으면 됩니다.

---

```
이 디렉터리(jgy-cc-statusline)의 statusline.sh 와 jgy-cc-statusline.conf.example 을 ~/.claude/ 에 설치해줘. macOS 환경 가정.

1. ~/.claude/ 디렉터리가 없으면 mkdir.
2. 기존 ~/.claude/settings.json 이 있으면 ~/.claude/settings.json.bak.<unix-timestamp> 로 백업. 없으면 빈 {} 로 새로 생성.
3. 현재 cwd 의 statusline.sh 를 ~/.claude/statusline.sh 로 복사하고 chmod +x.
4. ~/.claude/jgy-cc-statusline.conf 가 없으면 jgy-cc-statusline.conf.example 을 그 경로로 복사. 이미 있으면 건드리지 말 것 (사용자 설정 보존).
5. jq 로 ~/.claude/settings.json 에 다음 키를 set (다른 기존 키 보존):
   "statusLine": {
     "type": "command",
     "command": "bash <ABSOLUTE_HOME>/.claude/statusline.sh"
   }
   * <ABSOLUTE_HOME> 은 $HOME 을 미리 풀어 절대경로로 박을 것. Claude Code 는 셸 변수 안 풀어줌.
6. 의존성 점검:
   - jq, curl 없으면 "brew install jq curl" 라고 사용자에게 안내 (자동 설치 금지)
   - lsof, git, bash 는 macOS 기본 설치
7. /tmp/claude-statusline-* 캐시 파일 모두 삭제 (rm -f) 해서 즉시 반영되게.
8. 끝나면 다음 형식으로 보고:
   - 성공:
     ✅ 설치 완료. 새 Claude Code 세션에서 statusline 적용됨.
     다음 단계: ~/.claude/jgy-cc-statusline.conf 를 열어 MESSAGE_URL / SCRIPT_URL 채우면 메시지·자동업데이트 활성.
     (둘 다 비워도 statusline 자체는 정상 동작)
   - 실패: 무엇이 막혔는지 한 줄.

리눅스에서 돌리는 거면 stat -f, date -j -f, lsof -iTCP 등 macOS 의존 부분이 있어서 일부 동작 안 할 수 있다고 안내.
```

---

## 설치 후 할 일

1. `~/.claude/jgy-cc-statusline.conf` 열기.
2. **메시지 기능** 쓰려면 `MESSAGE_URL` 에 gist raw URL 등 한 줄짜리 텍스트 응답 주는 URL 박기.
3. **자동 업데이트** 쓰려면 `SCRIPT_URL` 에 statusline.sh 의 raw URL (예: GitHub) 박기.
4. 다음 statusline 갱신부터 적용. 강제로 즉시 반영하고 싶으면 `rm -f /tmp/claude-statusline-*` 한 번.

## 트러블슈팅

statusline 이 안 보이면:

- `cat ~/.claude/settings.json | jq .statusLine` 으로 등록 확인
- `bash ~/.claude/statusline.sh < /tmp/claude-statusline-last.json` 으로 직접 실행해서 출력 확인 (이전 세션의 입력 JSON 필요)
- `cat /tmp/claude-statusline-last.json | bash ~/.claude/statusline.sh` 도 동일

메시지가 안 뜨면:

- `cat /tmp/claude-statusline-message.txt` 로 캐시 확인 (비어있으면 fetch 실패)
- `curl -fsSL "$MESSAGE_URL"` 로 URL 자체가 응답하는지 확인
- 1시간 이내라면 아직 fetch 가 안 일어났을 수 있음. `rm /tmp/claude-statusline-sync-meta.json` 으로 다음 redraw 때 재시도 강제.
