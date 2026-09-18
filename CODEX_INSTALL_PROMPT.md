# Codex CLI 설치 프롬프트

아무 디렉터리에서 Codex CLI를 띄우고 아래 내용을 채팅에 붙여넣으세요. 저장소를 클론하지 않아도 됩니다. Claude Code용은 [`INSTALL_PROMPT.md`](./INSTALL_PROMPT.md)를 사용하세요.

```text
jgy-cc-statusline의 Codex CLI 프리셋을 설치해줘.

소스:
https://raw.githubusercontent.com/harucsx/jgy-cc-statusline/main/install-codex.py

1. codex --version과 python3 --version을 확인해줘.
   Python 3.11 이상이 필요하고, 이 프리셋은 Codex CLI 0.154.0 기준으로 검증됐어.
   의존성이 없으면 필요한 설치 방법을 알려주고 중단해줘. 자동 설치하지 마.
2. 임시 디렉터리를 만들고 위 URL을 curl -fsSL로 받아 install-codex.py로 저장해줘.
   다운로드가 실패하면 중단하고, 기존 파일이나 오류 응답을 실행하지 마.
3. 스크립트를 읽고 Codex 내장 상태바 설정을 적용하는 파일인지 확인해줘.
   Claude의 statusline.sh나 셸 conf를 Codex에 설치하지 마.
4. python3 <다운로드한 경로>/install-codex.py --dry-run을 실행해줘.
   기본 대상은 $CODEX_HOME/config.toml이고, CODEX_HOME이 없으면 ~/.codex/config.toml이야.
   설정 보존 검증에 실패하면 중단하고 원인을 알려줘. 설정 파일 전체를 출력하지 마.
5. 미리보기가 성공하면 같은 스크립트를 옵션 없이 실행해줘.
   기존 파일은 config.toml.bak.<고유값>으로 백업하고,
   tui.status_line과 tui.status_line_use_colors 외의 설정은 보존해야 해.
6. --show로 저장된 상태바 설정을 다시 확인해줘.
   새 Codex CLI 세션에서 적용되며 /statusline으로 항목·순서를 바꿀 수 있다고 알려줘.
   설정 저장 확인과 실제 TUI 표시 확인은 구분해서 보고해줘.
7. 다운로드에 사용한 임시 파일을 정리하고, 결과와 설정·백업 경로를 알려줘.

이 프리셋은 모델·추론 강도, Git 브랜치, 브랜치 변경량,
컨텍스트 사용률·크기, 5시간·주간 한도를 표시해.
branch-changes는 기본 브랜치 대비 커밋된 변경량이며 세션 수정량과는 달라.
데이터가 없는 항목은 생략될 수 있어.
메시지 풀, 포트, 시계, 여러 줄 출력, 클릭 링크, 스크립트 자동 업데이트는 제공하지 않아.
~/.claude/ 설정과 /tmp/claude-statusline-* 캐시는 수정하지 마.
```
