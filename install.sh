#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 开始安装并配置 GoEdge 边缘节点..."
echo "=========================================================="

# 2. 捕获所有参数并组合成单行字符串
# 使用 "$*" 可以把所有分散的参数（被 Shell 拆开的）重新组合起来
RAW_ARGS="$*"

# 提取逻辑：直接从原始字符串中匹配关键词后的内容
# 这种写法兼容性最强，无论用户是否加引号或换行
RPC_ENDPOINTS=$(echo "$RAW_ARGS" | grep -oP 'rpc\.endpoints:\s*\[[^\]]+\]' | sed 's/rpc\.endpoints:\s*//')
NODE_ID=$(echo "$RAW_ARGS" | grep -oP 'nodeId:\s*"?[a-zA-Z0-9]+"?' | sed -e 's/nodeId:\s*//' -e 's/"//g')
SECRET=$(echo "$RAW_ARGS" | grep -oP 'secret:\s*"?[a-zA-Z0-9]+"?' | sed -e 's/secret:\s*//' -e 's/"//g')

# 3. 校验解析结果
if [ -z "$RPC_ENDPOINTS" ] || [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：无法解析参数。"
    echo "请检查命令格式，确保包含 rpc.endpoints, nodeId 和 secret。"
    echo "----------------------------------------------------------"
    echo "当前捕获到的原始数据: $RAW_ARGS"
    exit 1
fi

echo "✅ 参数解析成功！"
echo "   - API 地址: $RPC_ENDPOINTS"
echo "   - 节点 ID : $NODE_ID"

# 4. 架构识别
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) EDGE_ARCH="amd64" ;;
    aarch64|arm64) EDGE_ARCH="arm64" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac

# 5. 安装与部署
EDGE_VERSION=${VERSION:-"1.4.1"}
DOWNLOAD_URL="https://dl.goedge.cn/edge/v${EDGE_VERSION}/edge-node-linux-${EDGE_ARCH}-v${EDGE_VERSION}.zip"
INSTALL_DIR="/usr/local/goedge/edge-node"

# 依赖安装
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 清理旧版
if [ -d "$INSTALL_DIR" ]; then
    $INSTALL_DIR/bin/edge-node stop > /dev/null 2>&1
    rm -rf $INSTALL_DIR
fi

# 下载解压
mkdir -p /usr/local/goedge && cd /usr/local/goedge
echo "⬇️ 正在从官方下载 v${EDGE_VERSION}..."
wget -O edge-node.zip "$DOWNLOAD_URL" && unzip -o -q edge-node.zip && rm -f edge-node.zip

# 写入配置
mkdir -p $INSTALL_DIR/configs
cat > $INSTALL_DIR/configs/api.yaml <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 启动服务
chmod +x $INSTALL_DIR/bin/edge-node
$INSTALL_DIR/bin/edge-node install > /dev/null 2>&1
$INSTALL_DIR/bin/edge-node start

echo "=========================================================="
echo "✅ 安装成功！节点已启动。"
echo "请在 GoEdge 后台检查节点在线状态。"
