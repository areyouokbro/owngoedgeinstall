#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具"
echo "=========================================================="

# 2. 解析参数的黑科技逻辑
# 即使参数被换行或空格拆散，我们也把它们重新组合并清洗
ALL_PARAMS="$*"

# 提取 RPC Endpoints (匹配 [ ... ])
RPC_ENDPOINTS=$(echo "$ALL_PARAMS" | grep -o '\[[^]]*\]' | head -n 1)

# 提取 NodeID 和 Secret (忽略引号，直接取冒号后面的内容)
# 逻辑：找关键词，取其后第一个非空格字符串，并去掉引号
NODE_ID=$(echo "$ALL_PARAMS" | sed -n 's/.*nodeId:[[:space:]]*"\?\([^"[:space:]]*\)"\?.*/\1/p')
SECRET=$(echo "$ALL_PARAMS" | sed -n 's/.*secret:[[:space:]]*"\?\([^"[:space:]]*\)"\?.*/\1/p')

# 3. 如果通过参数没抓到，尝试开启“手动粘贴模式”
if [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "⚠️  自动解析失败，请直接粘贴 GoEdge 后台的那三行配置并回车："
    read -p "配置内容: " MANUAL_INPUT
    RPC_ENDPOINTS=$(echo "$MANUAL_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
    NODE_ID=$(echo "$MANUAL_INPUT" | sed -n 's/.*nodeId:[[:space:]]*"\?\([^"[:space:]]*\)"\?.*/\1/p')
    SECRET=$(echo "$MANUAL_INPUT" | sed -n 's/.*secret:[[:space:]]*"\?\([^"[:space:]]*\)"\?.*/\1/p')
fi

# 再次检查
if [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：无法获取配置信息。请检查参数是否正确。"
    exit 1
fi

echo "✅ 解析成功！"
echo "   Endpoints: $RPC_ENDPOINTS"
echo "   Node ID: $NODE_ID"

# 4. 架构识别与安装环境准备
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && EDGE_ARCH="amd64"
[ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ] && EDGE_ARCH="arm64"

EDGE_VERSION=${VERSION:-"1.4.1"}
DOWNLOAD_URL="https://dl.goedge.cn/edge/v${EDGE_VERSION}/edge-node-linux-${EDGE_ARCH}-v${EDGE_VERSION}.zip"
INSTALL_DIR="/usr/local/goedge/edge-node"

# 安装依赖
echo "📦 正在准备基础环境..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 5. 清理与下载执行
if [ -d "$INSTALL_DIR" ]; then
    $INSTALL_DIR/bin/edge-node stop > /dev/null 2>&1
    rm -rf $INSTALL_DIR
fi

mkdir -p /usr/local/goedge && cd /usr/local/goedge
echo "⬇️  正在下载 GoEdge Node v${EDGE_VERSION}..."
wget -O edge-node.zip "$DOWNLOAD_URL" && unzip -o -q edge-node.zip && rm -f edge-node.zip

# 6. 生成配置文件
mkdir -p $INSTALL_DIR/configs
cat > $INSTALL_DIR/configs/api.yaml <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 7. 启动服务
chmod +x $INSTALL_DIR/bin/edge-node
$INSTALL_DIR/bin/edge-node install > /dev/null 2>&1
$INSTALL_DIR/bin/edge-node start

echo "=========================================================="
echo "✅ 安装成功！节点已在后台启动。"
echo "您可以去后台查看节点状态了。"
