#!/bin/bash

# ==========================================================
# 🚀 GoEdge 自动化大师版 (install_ddns.sh)
# 功能：安装节点 + IP变动检测 + 自动覆盖旧IP + DNS解析强制同步
# ==========================================================

if [ "$(id -u)" != "0" ]; then
    echo "❌ 错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "=========================================================="
echo "🔄 正在解析全量参数并准备自动化部署..."
echo "=========================================================="

# 1. 参数提取逻辑
RAW_INPUT="$*"
CLEAN_INPUT=$(echo "$RAW_INPUT" | tr -s '[:space:]' ' ' | sed 's/"//g')

# 基础节点参数
RPC_ENDPOINTS=$(echo "$CLEAN_INPUT" | grep -o '\[[^]]*\]' | head -n 1)
NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeId:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SECRET=$(echo "$CLEAN_INPUT" | grep -oE 'secret:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

# API 与 DDNS 参数
AK_ID=$(echo "$CLEAN_INPUT" | grep -oE 'AccessKeyID:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
AK_KEY=$(echo "$CLEAN_INPUT" | grep -oE 'AccessKey:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
SYNC_NODE_ID=$(echo "$CLEAN_INPUT" | grep -oE 'nodeid:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')
CLUSTER_ID=$(echo "$CLEAN_INPUT" | grep -oE 'clusterid:[[:space:]]*[^[:space:]]+' | cut -d':' -f2 | tr -d ' ')

# 从 RPC 地址自动提取管理后台 IP
ADMIN_IP=$(echo "$RPC_ENDPOINTS" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$NODE_ID" ] || [ -z "$AK_ID" ] || [ -z "$AK_KEY" ] || [ -z "$CLUSTER_ID" ]; then
    echo "❌ 错误：参数解析不完整！"
    echo "请检查是否包含: nodeId, secret, AccessKeyID, AccessKey, nodeid, clusterid"
    exit 1
fi

# 2. 环境准备
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y -q wget unzip curl cron > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q wget unzip curl crontabs > /dev/null 2>&1
fi

# 3. 安装 GoEdge 节点
DOWNLOAD_URL="https://raw.githubusercontent.com/areyouokbro/owngoedgeinstall/main/edge-node-linux-amd64-plus-v1.4.7.zip"
BASE_DIR="/usr/local/goedge"
INSTALL_DIR="${BASE_DIR}/edge-node"

mkdir -p "$BASE_DIR" && cd "$BASE_DIR" || exit

if [ -d "$INSTALL_DIR" ]; then
    "$INSTALL_DIR/bin/edge-node" stop > /dev/null 2>&1
    rm -rf "$INSTALL_DIR"
fi

echo "⬇️ 正在从仓库下载 1.4.7 Plus 资源包..."
wget -c -O edge-node.zip "$DOWNLOAD_URL"
unzip -o -q edge-node.zip
EXTRACTED_DIR=$(ls -d edge-node-linux-amd64-plus-* 2>/dev/null | head -n 1)
[ -n "$EXTRACTED_DIR" ] && mv "$EXTRACTED_DIR" "edge-node"
rm -f edge-node.zip

# 4. 写入节点初始配置
mkdir -p "$INSTALL_DIR/configs"
cat > "$INSTALL_DIR/configs/api.yaml" <<EOF
rpc.endpoints: ${RPC_ENDPOINTS}
nodeId: "${NODE_ID}"
secret: "${SECRET}"
EOF

# 5. 生成核心 DDNS + DNS同步脚本 (update_ip.sh)
cat > "$INSTALL_DIR/update_ip.sh" <<EOF
#!/bin/bash
# --- 自动化配置 ---
API_BASE="http://${ADMIN_IP}:8001"
CACHE_FILE="$INSTALL_DIR/current_ip.txt"
LOG_FILE="$INSTALL_DIR/ip_update.log"

# 1. 获取公网 IP
NEW_IP=\$(curl -s --connect-timeout 5 https://api.ipify.org || curl -s --connect-timeout 5 ifconfig.me)

if [ -z "\$NEW_IP" ]; then
    exit 1
fi

# 2. 比对缓存
OLD_IP=""
[ -f "\$CACHE_FILE" ] && OLD_IP=\$(cat "\$CACHE_FILE")

if [ "\$NEW_IP" == "\$OLD_IP" ]; then
    exit 0
fi

# 3. 执行更新：第一步 - 修改节点 IP (全量覆盖旧 IP)
RES_NODE=\$(curl -s -X POST "\$API_BASE/NodeService/updateNodeIPAddresses" \
     -H "Content-Type: application/json" \
     -H "AccessKeyId: ${AK_ID}" \
     -H "AccessKeySecret: ${AK_KEY}" \
     -d "{
        \"nodeId\": ${SYNC_NODE_ID},
        \"ipAddresses\": [{\"ip\": \"\$NEW_IP\", \"name\": \"DDNS自动上报\", \"canOut\": true, \"isOn\": true}]
     }")

# 4. 执行更新：第二步 - 触发 DNS 解析同步到服务商
RES_DNS=\$(curl -s -X POST "\$API_BASE/NodeClusterService/executeNodeClusterDNSChanges" \
     -H "Content-Type: application/json" \
     -H "AccessKeyId: ${AK_ID}" \
     -H "AccessKeySecret: ${AK_KEY}" \
     -d "{
        \"nodeClusterId\": ${CLUSTER_ID}
     }")

# 5. 记录日志与更新缓存
if [[ \$RES_NODE == *"\"code\":200"* ]] || [[ \$RES_NODE == *"{}"* ]]; then
    echo "\$NEW_IP" > "\$CACHE_FILE"
    echo "[\$(date)] IP变动: 从 \$OLD_IP 变为 \$NEW_IP | DNS同步结果: \$RES_DNS" >> "\$LOG_FILE"
else
    echo "[\$(date)] 更新失败: \$RES_NODE" >> "\$LOG_FILE"
fi
EOF

chmod +x "$INSTALL_DIR/update_ip.sh"

# 6. 注册定时任务 (每 5 分钟自动巡检)
service cron start > /dev/null 2>&1 || systemctl start crond > /dev/null 2>&1
(crontab -l 2>/dev/null | grep -v "update_ip.sh"; echo "*/5 * * * * bash $INSTALL_DIR/update_ip.sh") | crontab -

# 7. 启动节点并执行首次同步
chmod +x "$INSTALL_DIR/bin/edge-node"
cd "$INSTALL_DIR" || exit
./bin/edge-node install > /dev/null 2>&1
./bin/edge-node start
bash "$INSTALL_DIR/update_ip.sh"

echo "=========================================================="
echo "✅ 全部部署完成！"
echo "🌍 当前公网 IP: \$(cat $INSTALL_DIR/current_ip.txt)"
echo "⚙️  已自动关联集群 ID: $CLUSTER_ID"
echo "📬 DNS 同步任务已加入计划，每 5 分钟检查一次变动。"
echo "=========================================================="
