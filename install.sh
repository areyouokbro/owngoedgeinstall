#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具 (路径修复版)"
echo "=========================================================="

# 2. 核心参数提取逻辑 (已验证稳定)
RAW_INPUT="$*"
CLEAN_INPUT=$(echo "$RAW_INPUT" | tr -s '[:space:]' ' ' | sed 's/"//g')

RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

if [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：参数解析失败。请检查输入格式。"
    exit 1
fi

echo "✅ 参数解析成功！"
echo "   Endpoints: $RPC_ENDPOINTS"
echo "   Node ID  : $NODE_ID"

# 3. 架构识别
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) EDGE_ARCH="amd64" ;;
    aarch64|arm64) EDGE_ARCH="arm64" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac

# 4. 安装依赖
echo "📦 安装必要组件 (wget, unzip)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 5. 下载与安装目录处理
EDGE_VERSION=${VERSION:-"1.4.1"}
DOWNLOAD_URL="https://dl.goedge.cn/edge/v${EDGE_VERSION}/edge-node-linux-${EDGE_ARCH}-v${EDGE_VERSION}.zip"
BASE_DIR="/usr/local/goedge"
INSTALL_DIR="${BASE_DIR}/edge-node"

# 停止旧服务并清理旧目录
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️ 停止并清理旧版节点..."
    "$INSTALL_DIR/bin/edge-node" stop > /dev/null 2>&1
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$BASE_DIR" && cd "$BASE_DIR" || exit

echo "⬇️ 正在从官方下载 GoEdge Node v${EDGE_VERSION}..."
wget -qO edge-node.zip "$DOWNLOAD_URL"

if [ ! -f "edge-node.zip" ]; then
    echo "❌ 下载失败，请检查网络或版本号。"
    exit 1
fi

echo "📂 正在解压并整理文件..."
unzip -o -q edge-node.zip

# 【核心修复】：找到那个带版本号的长目录名，并重命名为标准的 edge-node
EXTRACTED_DIR=$(ls -d edge-node-linux-* 2>/dev/null | head -n 1)
if [ -n "$EXTRACTED_DIR" ]; then
    mv "$EXTRACTED_DIR" "edge-node"
    echo "✅ 目录重命名完成: $EXTRACTED_DIR -> edge-node"
else
    # 如果解压出来直接就是 edge-node（某些特定版本），则无需处理
    if [ ! -d "edge-node" ]; then
        echo "❌ 错误：解压后未找到预期的目录结构。"
        exit 1
    fi
fi

rm -f edge-node.zip

# 6. 生成配置文件
echo "⚙️ 生成配置文件 api.yaml..."
mkdir -p "$INSTALL_DIR/configs"
cat > "$INSTALL_DIR/configs/api.yaml" <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 7. 启动服务
echo "🚀 正在注册并启动服务..."
chmod +x "$INSTALL_DIR/bin/edge-node"
cd "$INSTALL_DIR" || exit
./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start

echo "=========================================================="
echo "🎉 安装完成！"
echo "📂 目录: $INSTALL_DIR"
echo "✅ 请前往 GoEdge 管理后台确认节点在线状态。"
echo "=========================================================="
