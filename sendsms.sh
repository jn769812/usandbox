#!/usr/bin/env bash

# 开启严格模式：-u 变量未定义报错，-o pipefail 管道中间失败报错
set -uo pipefail

# 1. 参数校验
if [[ $# -lt 2 ]]; then
    echo "❌ 错误: 参数不足"
    echo "用法: $0 <GATEWAY_TOKEN> \"<消息内容>\""
    exit 1
fi

GATEWAY_TOKEN="$1"
shift
MESSAGE="$*"

echo "🟢 开始任务..."
echo "✉️ 消息内容: $MESSAGE"

# 2. 检查 openclaw 命令是否存在
if ! command -v openclaw &> /dev/null; then
    echo "❌ 错误: 未找到 'openclaw' 命令，请检查是否已安装并加入 PATH。"
    exit 1
fi

MAX_RETRIES=5
RETRY_DELAY=3
TRY_COUNT=0
WECHAT_ID=""

# 3. 循环获取会话 ID
while [[ $TRY_COUNT -lt $MAX_RETRIES ]]; do
    ((TRY_COUNT++))
    echo "🔁 第 $TRY_COUNT/$MAX_RETRIES 次尝试获取微信会话 ID..."

    # 执行命令并捕获标准错误到标准输出，方便调试
    SESSIONS_OUTPUT=$(openclaw gateway call sessions.list --params '{}' --token "$GATEWAY_TOKEN" 2>&1)
    
    # 调试：如果你发现总是找不到 ID，可以取消下面这行的注释查看原始返回
    # echo "DEBUG: 原始输出: $SESSIONS_OUTPUT"

    # 提取微信 ID (支持包含 @im.wechat 的字符串)
    # 使用 grep -a 防止二进制字符干扰，使用 -o 只输出匹配部分
    WECHAT_ID=$(echo "$SESSIONS_OUTPUT" | grep -oaE '[a-zA-Z0-9_\-]+@im\.wechat' | head -n1 || true)

    if [[ -n "$WECHAT_ID" ]]; then
        break
    fi

    echo "⚠️ 未找到有效 ID，${RETRY_DELAY}s 后重试..."
    sleep "$RETRY_DELAY"
done

# 4. 最终检查并发送
if [[ -z "$WECHAT_ID" ]]; then
    echo "❌ 失败: 尝试 $MAX_RETRIES 次后仍未获取到微信 ID。"
    echo "提示: 请检查 Gateway Token 是否有效，或 openclaw 是否已登录。"
    exit 1
fi

echo "📍 成功定位会话: $WECHAT_ID"
echo "📤 正在投递消息..."

# 执行发送，并捕获结果
if openclaw message send --target "$WECHAT_ID" --message "$MESSAGE"; then
    echo "✅ 恭喜！消息发送成功！"
else
    echo "❌ 错误: 消息发送指令执行失败。"
    exit 1
fi
