#!/bin/bash
# ====================================================
# GoEdge 边缘节点 (Edge Node) 自动化一键部署脚本
# 仓库：https://github.com/areyouokbro/owngoedgeinstall
# ====================================================

# 1. 确保以 root 身份运行
if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🚀 开始安装并配置 GoEdge 边缘节点..."
echo "=========================================================="

# 2. 接收和解析节点参数
# 将所有传入的命令参数合并为一段字符串
FULL_ARGS="$*"

if [ -z "$FULL_ARGS" ]; then
    echo "❌ 错误：未提供节点配置参数！"
    echo "用法示例："
    echo "bash <(curl -sL ...) rpc.endpoints: [ \"http://...\" ] nodeId: \"...\" secret: \"...\""
    exit 1
fi

# 使用 sed 命令安全地从输入参数中提取所需的配置值
RPC_ENDPOINTS=$(echo "$FULL_ARGS" | sed -n 's/.*rpc\.endpoints:[[:space:]]*\(\[[^]]*\]\).*/\1/p')
NODE_ID=$(echo "$FULL_ARGS" | sed -n 's/.*nodeId:[[:space:]]*"\([^"]*\)".*/\1/p')
SECRET=$(echo "$FULL_ARGS" | sed -n 's/.*secret:[[:space:]]*"\([^"]*\)".*/\1/p')

# 校验参数是否提取成功
if [ -z "$RPC_ENDPOINTS" ] || [ -z "$NODE_ID" ] || [ -z "$SECRET" ]; then
    echo "❌ 错误：无法解析参数，请确保格式正确。"
    echo "当前提取结果 - RPC: $RPC_ENDPOINTS | NodeID: $NODE_ID | Secret: $SECRET"
    exit 1
fi

echo "✅ 成功获取并解析节点配置:"
echo "   - RPC Endpoints: $RPC_ENDPOINTS"
echo "   - Node ID      : $NODE_ID"
echo "   - Secret       : ******${SECRET: -4}"

# 3. 自动判断系统架构
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    EDGE_ARCH="amd64"
elif [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
    EDGE_ARCH="arm64"
else
    echo "❌ 不支持的系统架构: $ARCH"
    exit 1
fi

# 4. 配置安装版本及路径 (此处默认 1.4.1，可根据需要直接在脚本中修改)
EDGE_VERSION=${VERSION:-"1.4.1"}
DOWNLOAD_URL="https://dl.goedge.cn/edge/v${EDGE_VERSION}/edge-node-linux-${EDGE_ARCH}-v${EDGE_VERSION}.zip"
INSTALL_DIR="/usr/local/goedge/edge-node"

# 5. 安装必备依赖 (兼容 Debian/Ubuntu 和 CentOS/RHEL)
echo "📦 正在检查并安装必要组件 (wget, unzip)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl > /dev/null 2>&1
fi

# 6. 清理可能存在的旧版本
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️ 检测到旧节点服务，正在停止并清理..."
    $INSTALL_DIR/bin/edge-node stop > /dev/null 2>&1
    $INSTALL_DIR/bin/edge-node uninstall > /dev/null 2>&1
    rm -rf $INSTALL_DIR
fi
mkdir -p /usr/local/goedge
cd /usr/local/goedge || exit

# 7. 下载和解压
echo "⬇️ 正在下载 GoEdge Node v${EDGE_VERSION} (${EDGE_ARCH})..."
wget -O edge-node.zip "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "❌ 下载失败！请检查 GoEdge 官方下载节点网络。"
    exit 1
fi

echo "📂 正在解压..."
unzip -o -q edge-node.zip
rm -f edge-node.zip

# 8. 写入配置文件 api.yaml
echo "⚙️ 正在生成配置文件 api.yaml ..."
mkdir -p $INSTALL_DIR/configs
cat > $INSTALL_DIR/configs/api.yaml <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 9. 注册并启动节点服务
echo "🚀 正在注册为系统服务并启动..."
cd $INSTALL_DIR || exit
chmod +x bin/edge-node
./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start

echo "=========================================================="
echo "🎉 部署完毕：GoEdge 边缘节点已在后台启动！"
echo "📂 安装目录: $INSTALL_DIR"
echo "📄 配置文件: $INSTALL_DIR/configs/api.yaml"
echo "=========================================================="
echo "请前往 GoEdge 管理控制台查看该节点的在线状态。"
