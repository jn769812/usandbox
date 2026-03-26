#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "用法: $0 <GATEWAY_TOKEN> \"<消息内容>\""
  exit 1
fi

GATEWAY_TOKEN="$1"
shift
MESSAGE="$*"

MAX_RETRIES=9
RETRY_DELAY=3   # 每次失败后等待秒数
TRY_COUNT=0

echo "🟢 使用 Gateway Token: $GATEWAY_TOKEN"
echo "✉️ 准备发送的消息: $MESSAGE"

WECHAT_ID=""

until [[ -n "$WECHAT_ID" || "$TRY_COUNT" -ge "$MAX_RETRIES" ]]; do
  ((TRY_COUNT++))
  echo "🔁 第 $TRY_COUNT 次尝试获取微信 Session ID..."

  WECHAT_ID=$(openclaw gateway call sessions.list \
    --params '{}' \
    --token "$GATEWAY_TOKEN" 2>/dev/null \
    | grep -oE '[a-zA-Z0-9_-]+@im\.wechat' \
    | head -n1)

  if [[ -z "$WECHAT_ID" ]]; then
    echo "⚠️ 第 $TRY_COUNT 次获取失败，将在 $RETRY_DELAY 秒后重试..."
    sleep "$RETRY_DELAY"
  fi
done

if [[ -z "$WECHAT_ID" ]]; then
  echo "❌ 无法获取微信 ID（已尝试 $MAX_RETRIES 次），脚本退出"
  exit 1
fi

echo "📍 找到微信会话 ID: $WECHAT_ID"
echo "📤 正在发送消息..."

openclaw message send \
  --target "$WECHAT_ID" \
  --message "$MESSAGE"

echo "🚀 消息发送成功"
exit 0
