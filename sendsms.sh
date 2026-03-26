#!/usr/bin/env bash
set -euo pipefail

# —— Step 1: 从外部接收 Gateway Token 和 MESSAGE —— #

if [[ $# -lt 2 ]]; then
  echo "用法: $0 <GATEWAY_TOKEN> \"<消息内容>\""
  exit 1
fi

GATEWAY_TOKEN="$1"
shift
MESSAGE="$*"

echo "🟢 使用 Gateway Token: $GATEWAY_TOKEN"
echo "✉️ 要发送的消息: $MESSAGE"

# —— Step 2: 获取会话列表并提取微信 ID —— #

echo "🔍 正在调用 Gateway 获取 session 列表…"

WECHAT_ID=$(openclaw gateway call sessions.list \
  --params '{}' \
  --token "$GATEWAY_TOKEN" \
  | grep -oE '[a-zA-Z0-9_-]+@im\.wechat' \
  | head -n1)

if [[ -z "$WECHAT_ID" ]]; then
  echo "❌ 未提取到任何 @im.wechat 会话 ID，退出"
  exit 1
fi

echo "📍 找到微信会话 ID: $WECHAT_ID"

# —— Step 3: 发消息 —— #

echo "📤 正在发送消息到微信…"

openclaw message send \
  --target "$WECHAT_ID" \
  --message "$MESSAGE"

echo "✅ 消息发送完成 🎉"
