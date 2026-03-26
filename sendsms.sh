#!/usr/bin/env bash

# 不使用严格的 set -e（因为我们需要手动处理失败）
set -uo pipefail

# 参数检查
if [[ $# -lt 2 ]]; then
  echo "用法: $0 <GATEWAY_TOKEN> \"<消息内容>\""
  exit 1
fi

GATEWAY_TOKEN="$1"
shift
MESSAGE="$*"

echo "🟢 使用 Gateway Token: $GATEWAY_TOKEN"
echo "✉️ 准备发送的消息: $MESSAGE"

MAX_RETRIES=9
RETRY_DELAY=3
TRY_COUNT=0
WECHAT_ID=""

while [[ -z "$WECHAT_ID" && $TRY_COUNT -lt $MAX_RETRIES ]]; do
  ((TRY_COUNT++))
  echo "🔁 第 $TRY_COUNT 次尝试获取微信会话 ID..."

  # 调用 sessions.list，但不要让失败退出整个脚本
  SESSIONS_OUTPUT=$(openclaw gateway call sessions.list \
    --params '{}' \
    --token "$GATEWAY_TOKEN" 2>/dev/null)

  # 提取微信 ID
  WECHAT_ID=$(echo "$SESSIONS_OUTPUT" \
    | grep -oE '[a-zA-Z0-9_-]+@im\.wechat' \
    | head -n1)

  if [[ -z "$WECHAT_ID" ]]; then
    echo "⚠️ 未找到微信 ID，等待 $RETRY_DELAY 秒后重试..."
    sleep "$RETRY_DELAY"
  fi
done

if [[ -z "$WECHAT_ID" ]]; then
  echo "❌ 获取微信 ID 失败（尝试 $MAX_RETRIES 次）。"
  exit 1
fi

echo "📍 找到微信会话 ID: $WECHAT_ID"
echo "📤 正在发送消息..."

# 发送消息（这种命令不会自动退出）
openclaw message send \
  --target "$WECHAT_ID" \
  --message "$MESSAGE" || {
    echo "❌ 消息发送失败"
    exit 1
  }

echo "🚀 消息发送成功！"
