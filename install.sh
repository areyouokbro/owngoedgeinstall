#!/bin/bash

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 GoEdge 边缘节点一键部署工具 (兼容性增强版)"
echo "=========================================================="

# 2. 核心参数提取逻辑
# 将所有输入参数合并，并把所有空白字符（含换行）转为空格，同时去掉所有引号
RAW_INPUT="$*"
CLEAN_INPUT=$(echo "$RAW_INPUT" | tr -s '[:space:]' ' ' | sed 's/"//g')

# 提取 RPC Endpoints (保留中括号内的内容)
RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)

# 提取 NodeID (定位 nodeId: 后面的非空字符串)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

# 提取 Secret (定位 secret: 后面的非空字符串)
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

# 3. 校验解析结果
if [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：参数解析失败。"
    echo "----------------------------------------------------------"
    echo "原始输入: $RAW_INPUT"
    echo "尝试手动解析结果:"
    echo "RPC: $RPC_ENDPOINTS"
    echo "NodeID: $NODE_ID"
    echo "Secret: $SECRET"
    echo "----------------------------------------------------------"
    echo "💡 提示：如果依然失败，请直接运行脚本而不带参数，然后根据提示粘贴。"
    exit 1
fi

echo "✅ 解析成功！"
echo "   Endpoints: $RPC_ENDPOINTS"
echo "   Node ID: $NODE_ID"

# 4. 架构识别
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) EDGE_ARCH="amd64" ;;
    aarch64|arm64) EDGE_ARCH="arm64" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac

# 5. 安装准备
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

# 清理旧版
if [ -d "$INSTALL_DIR" ]; then
    $INSTALL_DIR/bin/edge-node stop > /dev/null 2>&1
    rm -rf $INSTALL_DIR
fi

# 下载解压
mkdir -p /usr/local/goedge && cd /usr/local/goedge
echo "⬇️ 正在从官方下载并安装..."
wget -qO edge-node.zip "$DOWNLOAD_URL" && unzip -o -q edge-node.zip && rm -f edge-node.zip

# 6. 生成配置文件 (YAML 格式)
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
echo "🎉 安装成功！节点已启动。"
echo "请在 GoEdge 管理后台确认节点状态。"
