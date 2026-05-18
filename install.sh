#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具 (GitHub 资源版)"
echo "=========================================================="

# 2. 核心参数提取
RAW_INPUT="$*"
CLEAN_INPUT=$(echo "$RAW_INPUT" | tr -s '[:space:]' ' ' | sed 's/"//g')

RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

if [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：参数解析失败。请确保命令包含 nodeId 和 secret。"
    exit 1
fi

# 3. 架构识别 (目前你的仓库提供的是 amd64 版)
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "❌ 警告：检测到架构为 $ARCH，但仓库仅提供 amd64 资源包。"
    # 如果以后你有 arm 包，可以在这里做判断
fi

# 4. 依赖安装
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 5. 下载处理 (指向你的 GitHub 仓库地址)
# 注意：raw 链接不带 /blob/
DOWNLOAD_URL="https://raw.githubusercontent.com/areyouokbro/owngoedgeinstall/main/edge-node-linux-amd64-plus-v1.4.7.zip"
BASE_DIR="/usr/local/goedge"
INSTALL_DIR="${BASE_DIR}/edge-node"

mkdir -p "$BASE_DIR" && cd "$BASE_DIR" || exit

# 停止并清理旧服务
if [ -d "$INSTALL_DIR" ]; then
    "$INSTALL_DIR/bin/edge-node" stop > /dev/null 2>&1
    rm -rf "$INSTALL_DIR"
fi

echo "⬇️ 正在从 GitHub 仓库下载节点资源包..."
wget -c -O edge-node.zip "$DOWNLOAD_URL"

if [ ! -s "edge-node.zip" ]; then
    echo "❌ 下载失败：请检查 GitHub 仓库链接是否正确。"
    exit 1
fi

echo "📂 正在解压并配置..."
unzip -o -q edge-node.zip

# 查找解压出的文件夹并重命名
# 适配 plus 版本的文件夹名
EXTRACTED_DIR=$(ls -d edge-node-linux-amd64-plus-* 2>/dev/null | head -n 1)
if [ -n "$EXTRACTED_DIR" ]; then
    mv "$EXTRACTED_DIR" "edge-node"
else
    # 兼容性处理
    EXTRACTED_DIR_ALT=$(ls -d edge-node-linux-* 2>/dev/null | head -n 1)
    [ -n "$EXTRACTED_DIR_ALT" ] && mv "$EXTRACTED_DIR_ALT" "edge-node"
fi

rm -f edge-node.zip

# 6. 生成配置
mkdir -p "$INSTALL_DIR/configs"
cat > "$INSTALL_DIR/configs/api.yaml" <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 7. 启动
chmod +x "$INSTALL_DIR/bin/edge-node"
cd "$INSTALL_DIR" || exit
./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start

echo "=========================================================="
echo "✅ 安装成功！GoEdge 1.4.7 Plus 已启动。"
echo "=========================================================="
