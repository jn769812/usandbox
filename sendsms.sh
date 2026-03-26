#!/usr/bin/env bash

# 退出 on 错误（除了 grep 没匹配这种）
set -eo pipefail

# 校验传参
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

until [[ -n "$WECHAT_ID" || $TRY_COUNT -ge $MAX_RETRIES ]]; do
  ((TRY_COUNT++))
  echo "🔁 第 $TRY_COUNT 次尝试获取微信 ID..."

  # 获取 sessions 输出
  SESSIONS_OUTPUT=$(openclaw gateway call sessions.list \
    --params '{}' \
    --token "$GATEWAY_TOKEN" \
    2>/dev/null || true)

  # 提取第一个 @im.wechat ID
  WECHAT_ID=$(echo "$SESSIONS_OUTPUT" \
    | grep -oE '[a-zA-Z0-9_-]+@im\.wechat' \
    | head -n1 || true)

  if [[ -z "$WECHAT_ID" ]]; then
    echo "⚠️ 未找到微信 ID，等待 $RETRY_DELAY 秒后重试..."
    sleep "$RETRY_DELAY"
  fi
done

if [[ -z "$WECHAT_ID" ]]; then
  echo "❌ 获取微信 ID 失败（尝试 $MAX_RETRIES 次）"
  exit 1
fi

echo "📍 找到微信会话 ID: $WECHAT_ID"
echo "📤 正在发送消息..."

openclaw message send \
  --target "$WECHAT_ID" \
  --message "$MESSAGE"

echo "🚀 消息发送完成！"
