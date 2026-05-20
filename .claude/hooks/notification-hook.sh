#!/bin/bash
# Claude Code Notification 훅 - 권한 요청 및 사용자 입력 대기 알림
#
# 이 스크립트는 Claude Code가 Notification 이벤트를 발생시킬 때 실행됩니다.
# 주로 권한 요청이나 사용자 입력 대기 상황에서 Slack 알림을 보냅니다.

# UTF-8 로케일 명시적 설정 (한글/이모지 인코딩 문제 해결)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# CLAUDE_PROJECT_DIR 미설정 시 스크립트 위치로부터 상위 디렉토리 추정
if [ -z "$CLAUDE_PROJECT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CLAUDE_PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
fi

# .env 파일에서 Slack 웹훅 URL 로드
if [ -f "$CLAUDE_PROJECT_DIR/.env" ]; then
    source "$CLAUDE_PROJECT_DIR/.env"
else
    echo "오류: .env 파일을 찾을 수 없습니다: $CLAUDE_PROJECT_DIR/.env" >&2
    exit 1
fi

# Slack 웹훅 URL 확인
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "오류: SLACK_WEBHOOK_URL이 설정되지 않았습니다." >&2
    exit 1
fi

# JSON 입력에서 메시지 추출 (Python으로 처리, jq 의존성 제거)
MESSAGE=$(echo "$HOOK_INPUT" | python3 -c "import json, sys; data = json.load(sys.stdin) if sys.stdin.read() else {}; print(data.get('message', '알림'))" 2>/dev/null || echo "알림")

# 프로젝트명 추출
PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR")

# 현재 시간
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 디버깅을 위한 변수 출력 (stderr로 출력)
echo "DEBUG: MESSAGE = '$MESSAGE'" >&2
echo "DEBUG: PROJECT_NAME = '$PROJECT_NAME'" >&2
echo "DEBUG: TIMESTAMP = '$TIMESTAMP'" >&2

# 메시지 텍스트 생성
TEXT=$(printf '🔔 권한 요청 알림\n\n프로젝트: %s\n상태: %s\n시간: %s\n\nClaude Code에서 알림이 도착했습니다.' "$PROJECT_NAME" "$MESSAGE" "$TIMESTAMP")

# Python을 사용하여 안전한 JSON payload 생성 (한글/이모지/특수문자 안전 처리)
# PYTHONIOENCODING을 UTF-8로 설정하여 Windows cp949 인코딩 문제 해결
PAYLOAD=$(PYTHONIOENCODING=utf-8 python3 -c "
import json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
data = {
    'channel': '#claude-code',
    'username': 'Claude Code',
    'text': sys.argv[1],
    'icon_emoji': ':bell:'
}
print(json.dumps(data, ensure_ascii=False))
" "$TEXT")

echo "DEBUG: PAYLOAD = '$PAYLOAD'" >&2

# Slack으로 알림 전송 (현재 권장 방식: Content-Type: application/json)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-raw "$PAYLOAD" \
  "$SLACK_WEBHOOK_URL")

# 성공 여부 확인 (HTTP 200~299는 성공)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "Slack 알림이 성공적으로 전송되었습니다. (HTTP $HTTP_CODE)" >&2
else
    echo "Slack 알림 전송에 실패했습니다. (HTTP $HTTP_CODE)" >&2
    exit 1
fi