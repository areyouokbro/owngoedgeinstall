#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具"
echo "=========================================================="

# 2. 智能获取参数
# 如果脚本后面没有跟参数，则开启交互式输入
if [ -z "$1" ]; then
    echo "💡 检测到未直接传入参数，请输入/粘贴后台生成的安装命令 (按回车确认):"
    echo "----------------------------------------------------------"
    # 读取一行，即使包含空格
    read -r RAW_INPUT
    FULL_ARGS="$RAW_INPUT"
else
    # 兼容一行流执行
    FULL_ARGS="$*"
fi

# 3. 提取参数 (增强正则兼容性)
RPC_ENDPOINTS=$(echo "$FULL_ARGS" | sed -n 's/.*rpc\.endpoints:[[:space:]]*\(\[[^]]*\]\).*/\1/p')
NODE_ID=$(echo "$FULL_ARGS" | sed -n 's/.*nodeId:[[:space:]]*"\([^"]*\)".*/\1/p')
SECRET=$(echo "$FULL_ARGS" | sed -n 's/.*secret:[[:space:]]*"\([^"]*\)".*/\1/p')

# 再次检查，如果还是没提取到，可能用户粘贴的是多行
if [ -z "$NODE_ID" ]; then
     # 尝试匹配不带引号或带引号的 nodeId
     NODE_ID=$(echo "$FULL_ARGS" | grep -oP 'nodeId:\s*"\K[^"]+' || echo "$FULL_ARGS" | grep -oP 'nodeId:\s*\K\S+')
     SECRET=$(echo "$FULL_ARGS" | grep -oP 'secret:\s*"\K[^"]+' || echo "$FULL_ARGS" | grep -oP 'secret:\s*\K\S+')
fi

if [ -z "$RPC_ENDPOINTS" ] || [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：无法解析配置信息。"
    echo "请确保输入包含 rpc.endpoints, nodeId 和 secret。"
    exit 1
fi

echo "✅ 解析成功！"
echo "   Endpoints: $RPC_ENDPOINTS"
echo "   Node ID  : $NODE_ID"

# --- 以下安装逻辑保持不变 ---
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && EDGE_ARCH="amd64"
[ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ] && EDGE_ARCH="arm64"

EDGE_VERSION=${VERSION:-"1.4.1"}
DOWNLOAD_URL="https://dl.goedge.cn/edge/v${EDGE_VERSION}/edge-node-linux-${EDGE_ARCH}-v${EDGE_VERSION}.zip"
INSTALL_DIR="/usr/local/goedge/edge-node"

# 安装依赖
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 清理与下载
[ -d "$INSTALL_DIR" ] && $INSTALL_DIR/bin/edge-node stop > /dev/null 2>&1 && rm -rf $INSTALL_DIR
mkdir -p /usr/local/goedge && cd /usr/local/goedge
wget -O edge-node.zip "$DOWNLOAD_URL" && unzip -o -q edge-node.zip && rm -f edge-node.zip

# 配置
mkdir -p $INSTALL_DIR/configs
cat > $INSTALL_DIR/configs/api.yaml <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 启动
cd $INSTALL_DIR && chmod +x bin/edge-node
./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start

echo "=========================================================="
echo "✅ 安装成功！节点已启动。"
echo "=========================================================="
