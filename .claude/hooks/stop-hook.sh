#!/bin/bash
# Claude Code Stop 훅 - 작업 완료 알림
#
# 이 스크립트는 Claude Code가 Stop 이벤트를 발생시킬 때 실행됩니다.
# Claude가 응답을 완료했을 때 Slack 알림을 보냅니다.

# UTF-8 로케일 + Python 인코딩 명시적 설정
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PYTHONIOENCODING=utf-8

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

# 프로젝트명 추출
PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR")

# 현재 시간
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Python으로 전체 메시지와 JSON payload를 안전하게 생성
# bash 이모지 처리 불안정성 제거, Python의 안정적 UTF-8 처리 사용
PAYLOAD=$(python3 << 'PYTHON_EOF'
import json
import sys
from datetime import datetime

project_name = sys.argv[1]
timestamp = sys.argv[2]

text = f"""✅ 작업 완료 알림

프로젝트: {project_name}
상태: Stop
시간: {timestamp}

Claude Code 작업이 완료되었습니다."""

data = {
    "channel": "#claude-code",
    "username": "Claude Code",
    "text": text,
    "icon_emoji": ":white_check_mark:"
}

print(json.dumps(data, ensure_ascii=False))
PYTHON_EOF
"$PROJECT_NAME" "$TIMESTAMP")

echo "DEBUG: PROJECT_NAME = '$PROJECT_NAME'" >&2
echo "DEBUG: TIMESTAMP = '$TIMESTAMP'" >&2
echo "DEBUG: PAYLOAD = '$PAYLOAD'" >&2

# Slack으로 알림 전송
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