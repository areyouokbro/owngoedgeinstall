# GoEdge 边缘节点一键部署工具
这是一个用于快速部署 **GoEdge** 边缘节点 (Edge Node) 的自动化脚本。通过该脚本，你可以直接复制 GoEdge 管理后台生成的参数，在任何 Linux 服务器上一键完成安装、配置和启动。
## 🌟 特点
 * **极简安装**：无需手动修改配置文件，直接通过命令行参数传递配置。
 * **自动适配**：自动识别系统架构（AMD64 / ARM64）。
 * **服务化管理**：自动注册系统服务，支持开机自启。
 * **清理机制**：重复执行脚本会自动覆盖旧版本，方便更新。
## 🚀 快速开始
在你的边缘节点服务器上执行以下命令（请根据你的管理后台替换对应的参数值）：
```bash
bash <(curl -sL https://raw.githubusercontent.com/areyouokbro/owngoedgeinstall/main/install.sh) \
rpc.endpoints: [ "http://你的后台IP:8001" ] \
nodeId: "你的节点ID" \
secret: "你的节点密钥"

```
> **注意**：脚本需要以 root 用户运行。如果不是 root 用户，请先执行 sudo -i。
> 
## 🛠️ 常用管理命令
安装完成后，你可以通过以下路径的二进制文件管理节点：
| 操作 | 命令 |
|---|---|
| **查看状态** | /usr/local/goedge/edge-node/bin/edge-node status |
| **启动节点** | /usr/local/goedge/edge-node/bin/edge-node start |
| **停止节点** | /usr/local/goedge/edge-node/bin/edge-node stop |
| **重启节点** | /usr/local/goedge/edge-node/bin/edge-node restart |
| **查看日志** | tail -f /usr/local/goedge/edge-node/logs/run.log |
## 📂 文件结构
 * **安装路径**: /usr/local/goedge/edge-node
 * **配置文件**: /usr/local/goedge/edge-node/configs/api.yaml
## ⚠️ 卸载
如果你需要彻底卸载节点，请执行：
```bash
/usr/local/goedge/edge-node/bin/edge-node stop
/usr/local/goedge/edge-node/bin/edge-node uninstall
rm -rf /usr/local/goedge

```
## 🔗 相关链接
 * GoEdge 官网
 * GoEdge 官方文档
### 💡 提示
如果你想指定安装特定的版本，可以在执行脚本前设置环境变量：
```bash
export VERSION=1.4.0 && bash <(curl -sL https://raw.githubusercontent.com/areyouokbro/owngoedgeinstall/main/install.sh) ...

```
