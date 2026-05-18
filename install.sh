#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具 (v1.4.7 专用版)"
echo "=========================================================="

# 2. 核心参数提取
RAW_INPUT="$*"
CLEAN_INPUT=$(echo "$RAW_INPUT" | tr -s '[:space:]' ' ' | sed 's/"//g')

RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

if [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：无法从命令中解析出 nodeId 或 secret。"
    echo "请直接复制后台生成的整段命令运行。"
    exit 1
fi

# 3. 架构识别
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) EDGE_ARCH="amd64" ;;
    aarch64|arm64) EDGE_ARCH="arm64" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac

# 4. 依赖安装
echo "📦 正在安装必要组件 (wget, unzip)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 5. 下载处理
# 默认版本设为 1.4.7
EDGE_VERSION=${VERSION:-"1.4.7"}
DOWNLOAD_URL="https://dl.goedge.cn/edge/v${EDGE_VERSION}/edge-node-linux-${EDGE_ARCH}-v${EDGE_VERSION}.zip"
BASE_DIR="/usr/local/goedge"
INSTALL_DIR="${BASE_DIR}/edge-node"

mkdir -p "$BASE_DIR" && cd "$BASE_DIR" || exit

# 停止并清理旧服务
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️ 发现旧版节点，正在停止并清理..."
    "$INSTALL_DIR/bin/edge-node" stop > /dev/null 2>&1
    rm -rf "$INSTALL_DIR"
fi

echo "⬇️ 正在从官方下载 GoEdge Node v${EDGE_VERSION} (${EDGE_ARCH})..."
# 增加 --no-check-certificate 以防某些机器 SSL 证书过旧
wget --no-check-certificate -c --tries=3 --timeout=20 -O edge-node.zip "$DOWNLOAD_URL"

# 校验下载的文件
if [ ! -s "edge-node.zip" ]; then
    echo "❌ 下载失败：文件大小为 0。请检查网络或版本 v${EDGE_VERSION} 是否存在。"
    exit 1
fi

echo "📂 正在解压并配置路径..."
unzip -o -q edge-node.zip
if [ $? -ne 0 ]; then
    echo "❌ 解压失败！下载的文件可能不完整，请重新运行脚本。"
    rm -f edge-node.zip
    exit 1
fi

# 自动处理目录名
EXTRACTED_DIR=$(ls -d edge-node-linux-* 2>/dev/null | head -n 1)
if [ -n "$EXTRACTED_DIR" ]; then
    mv "$EXTRACTED_DIR" "edge-node"
fi
rm -f edge-node.zip

# 6. 生成配置
echo "⚙️ 生成配置文件..."
mkdir -p "$INSTALL_DIR/configs"
cat > "$INSTALL_DIR/configs/api.yaml" <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 7. 启动
echo "🚀 注册系统服务并启动..."
chmod +x "$INSTALL_DIR/bin/edge-node"
cd "$INSTALL_DIR" || exit
./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start

echo "=========================================================="
echo "✅ 安装成功！GoEdge 节点 v${EDGE_VERSION} 已启动。"
echo "📂 安装路径: $INSTALL_DIR"
echo "=========================================================="
