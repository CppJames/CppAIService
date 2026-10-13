#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "配置文件不存在: $ENV_FILE，请参考 .env.example 创建。" >&2
    exit 1
fi

# .env 使用 KEY=value 格式；导出后供 C++ 的 std::getenv 读取。
set -a
source "$ENV_FILE"
set +a

missing_config=()
for name in DASHSCOPE_API_KEY Knowledge_Base_ID BAIDU_CLIENT_ID BAIDU_CLIENT_SECRET DOUBAO_API_KEY; do
    if [[ -z "${!name:-}" ]]; then
        missing_config+=("$name")
    fi
    # 恢复历史会话时会创建默认 AI 策略，需要 getenv 能读取到变量。
    export "$name=${!name:-}"
done
if ((${#missing_config[@]})); then
    echo "未配置: ${missing_config[*]}。继续启动基础服务；使用对应 AI 功能前请填写 $ENV_FILE 并重启。" >&2
fi

cd "${APP_BUILD_DIR:-${SCRIPT_DIR}/build}"
service mysql start
rabbitmq-server -detached
# 等待 RabbitMQ 就绪，避免启动命令与后台初始化发生竞争。
ready=false
for ((attempt = 0; attempt < 60; attempt++)); do
    if rabbitmqctl status >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 1
done
if [[ "$ready" != true ]]; then
    echo "RabbitMQ 未能就绪" >&2
    exit 1
fi
rabbitmqctl start_app
rabbitmqctl status
exec ./http_server -p 8117
