#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具 (GitHub Release v1.0 版)"
echo "=========================================================="

# 2. 核心参数提取 (增强容错)
RAW_INPUT="$*"
# 清理可能存在的反斜杠、双引号及多余空格
CLEAN_INPUT=$(echo "$RAW_INPUT" | sed 's/\\//g; s/"//g' | tr -s '[:space:]' ' ')

# 使用更精准的正则匹配，确保提取的是 rpc.endpoints 后面的数组
RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -oE 'rpc\.endpoints:[[:space:]]*\[[^]]+\]' | sed 's/rpc\.endpoints:[[:space:]]*//' | head -n 1)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

# 兜底逻辑：如果上面没匹配到，尝试直接匹配标准 JSON/YAML 风格的硬编码
if [ -z "$RPC_ENDPOINTS" ]; then
    RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
fi

if [ -z "$NODE_ID" ] || [ -z "$SECRET" ] || [ -z "$RPC_ENDPOINTS" ]; then
    echo "❌ 错误：参数解析失败。"
    echo "💡 正确格式示例: sh install.sh rpc.endpoints: [\"1.1.1.1:8001\"] nodeId: your_id secret: your_secret"
    exit 1
fi

# 3. 架构识别与严格阻断
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    echo "❌ 错误：检测到当前系统架构为 $ARCH。"
    echo "   该资源包仅支持 amd64 (x86_64) 架构，程序退出。"
    exit 1
fi

# 4. 依赖安装 (静默且带锁等待)
echo "📦 正在检查并安装必要依赖 (wget, unzip, curl)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 5. 下载处理 (指向 GitHub Release v1.0 里的 1.3.9 资源包)
# 这里的 Tag 路径已改为 v1.0，文件名保持 edge-node-linux-amd64-v1.3.9.zip
DOWNLOAD_URL="https://github.com/areyouokbro/owngoedgeinstall/releases/download/v1.0/edge-node-linux-amd64-v1.3.9.zip"
BASE_DIR="/usr/local/goedge"
INSTALL_DIR="${BASE_DIR}/edge-node"

mkdir -p "$BASE_DIR" && cd "$BASE_DIR" || exit

# 停止并清理旧服务
if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 检测到旧版本，正在停止服务并清理..."
    if [ -x "$INSTALL_DIR/bin/edge-node" ]; then
        "$INSTALL_DIR/bin/edge-node" stop > /dev/null 2>&1
    fi
    rm -rf "$INSTALL_DIR"
fi

echo "⬇️ 正在从 GitHub Release (v1.0) 下载节点资源包..."
# 增加 3 次重试，每次超时 15 秒
wget -t 3 -T 15 -c -O edge-node.zip "$DOWNLOAD_URL"

if [ ! -s "edge-node.zip" ]; then
    echo "❌ 下载失败：请检查网络是否能正常访问 GitHub，或 Release 标签 (v1.0) 中是否包含该文件。"
    echo "🔗 尝试下载的链接: $DOWNLOAD_URL"
    exit 1
fi

echo "📂 正在解压并配置结构..."
unzip -o -q edge-node.zip

# 动态模糊匹配解压出的目录
EXTRACTED_DIR=$(ls -d edge-node-linux-* 2>/dev/null | head -n 1)
if [ -n "$EXTRACTED_DIR" ]; then
    mv "$EXTRACTED_DIR" "edge-node"
else
    echo "❌ 错误：未找到解压后的 edge-node 目录，请确认压缩包内根目录名称。"
    rm -f edge-node.zip
    exit 1
fi

rm -f edge-node.zip

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

# 验证是否成功运行
sleep 2
if ps aux | grep "edge-node" | grep -v grep > /dev/null 2>&1; then
    echo "=========================================================="
    echo "✅ 安装成功！GoEdge 已成功在后台运行。"
    echo "=========================================================="
else
    echo "=========================================================="
    echo "⚠️ 启动可能失败或仍在初始化，请手动执行查看状态："
    echo "   cd $INSTALL_DIR && ./bin/edge-node status"
    echo "=========================================================="
fi
