# VPS Reality 节点部署项目

用于在全新 Ubuntu 24.04 VPS 上自动部署 Xray VLESS + Reality 节点，并同时生成 Clash/Mihomo YAML 和 Shadowrocket Base64 订阅。

## 目录

- `scripts/deploy.sh`：一键安装 Xray、Nginx、防火墙规则，并同时生成 Clash 和小火箭订阅。
- `config/rules.yaml`：国内常用服务直连、其余流量代理的规则模板。
- `docs/DEPLOYMENT.md`：部署流程、参数和故障排查。
- `docs/SECURITY.md`：密钥、订阅链接和 root 账户安全说明。

## 快速使用

在本地执行：

```bash
scp scripts/deploy.sh root@服务器IP:/root/deploy.sh
ssh root@服务器IP 'bash /root/deploy.sh'
```

脚本完成后会输出 Clash/Mihomo 和 Shadowrocket 两条订阅地址。

也可以在服务器上指定公网 IP：

```bash
PUBLIC_IP=203.0.113.10 bash deploy.sh
```

脚本只适用于用户本人拥有或获授权管理的 VPS。不要把生成的订阅链接、UUID、Reality 私钥或 root 密码提交到 Git 仓库。
