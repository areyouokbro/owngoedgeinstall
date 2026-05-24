#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具 (GitHub Release v1.0 最终版)"
echo "=========================================================="

# 2. 核心参数提取 (增强容错)
RAW_INPUT="$*"
CLEAN_INPUT=$(echo "$RAW_INPUT" | sed 's/\\//g; s/"//g' | tr -s '[:space:]' ' ')

RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -oE 'rpc\.endpoints:[[:space:]]*\[[^]]+\]' | sed 's/rpc\.endpoints:[[:space:]]*//' | head -n 1)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

if [ -z "$RPC_ENDPOINTS" ]; then
    RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
fi

if [ -z "$NODE_ID" ] || [ -z "$SECRET" ] || [ -z "$RPC_ENDPOINTS" ]; then
    echo "❌ 错误：参数解析失败。"
    echo "💡 提示: 复制面板生成的安装命令执行即可"
    exit 1
fi

# 3. 架构识别与严格阻断
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    echo "❌ 错误：检测到当前系统架构为 $ARCH。"
    echo "   该资源包仅支持 amd64 (x86_64) 架构，程序退出。"
    exit 1
fi

# 4. 依赖安装
echo "📦 正在检查并安装必要依赖 (wget, unzip, curl)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 5. 下载处理
DOWNLOAD_URL="https://github.com/areyouokbro/owngoedgeinstall/releases/download/v1.0/edge-node-linux-amd64-v1.3.9.zip"
BASE_DIR="/usr/local/goedge"
INSTALL_DIR="${BASE_DIR}/edge-node"

mkdir -p "$BASE_DIR" && cd "$BASE_DIR" || exit

if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 检测到旧版本，正在停止服务并清理..."
    if [ -x "$INSTALL_DIR/bin/edge-node" ]; then
        "$INSTALL_DIR/bin/edge-node" stop > /dev/null 2>&1
    fi
    rm -rf "$INSTALL_DIR"
fi

echo "⬇️ 正在从 GitHub Release (v1.0) 下载节点资源包..."
wget -t 3 -T 15 -c -O edge-node.zip "$DOWNLOAD_URL"

if [ ! -s "edge-node.zip" ]; then
    echo "❌ 下载失败：请检查网络是否能正常访问 GitHub。"
    exit 1
fi

# ================= 核心修复部分 =================
echo "📂 正在解压并智能识别目录结构..."
unzip -o -q edge-node.zip

# 方案 A: 压缩包里本身就叫 edge-node 目录
if [ -d "edge-node" ]; then
    echo "✅ 结构匹配: 识别到标准的 edge-node 目录"

# 方案 B: 压缩包里带了版本号后缀的目录 (如 edge-node-linux-amd64)
elif EXTRACTED_DIR=$(ls -d edge-node-linux-* 2>/dev/null | head -n 1) && [ -n "$EXTRACTED_DIR" ]; then
    echo "✅ 结构匹配: 识别到 $EXTRACTED_DIR，正在重命名..."
    mv "$EXTRACTED_DIR" "edge-node"

# 方案 C: 散装压缩 (用户压缩时选中了内部的所有文件而不是选中文件夹)
elif [ -f "bin/edge-node" ]; then
    echo "⚠️ 检测到散装解压结构，正在自动重组目录..."
    mkdir -p edge-node
    # 将解压出来的核心目录移入
    mv bin configs edge-node/ 2>/dev/null
else
    echo "❌ 错误：解压后未找到合法的 edge-node 结构！"
    echo "🔍 当前目录解压出了以下文件："
    ls -la
    rm -f edge-node.zip
    exit 1
fi

rm -f edge-node.zip
# ================================================

# 6. 生成配置
mkdir -p "$INSTALL_DIR/configs"
cat > "$INSTALL_DIR/configs/api.yaml" <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 7. 启动与验证
echo "🚀 正在初始化并启动 GoEdge v1.3.9 边缘节点..."
chmod +x "$INSTALL_DIR/bin/edge-node"
cd "$INSTALL_DIR" || exit

./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start > /dev/null 2>&1

sleep 2
if ps aux | grep "edge-node" | grep -v grep > /dev/null 2>&1; then
    echo "=========================================================="
    echo "✅ 安装成功！GoEdge 已成功在后台运行。"
    echo "=========================================================="
else
    echo "=========================================================="
    echo "⚠️ 启动状态异常，请手动检查："
    echo "   cd $INSTALL_DIR && ./bin/edge-node status"
    echo "=========================================================="
fi
