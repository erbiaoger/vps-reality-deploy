# 部署说明

## 系统要求

- Ubuntu 22.04/24.04
- root 权限
- 可访问 GitHub、Cloudflare 等外网
- TCP 22、80、443 可用

## 脚本参数

`PUBLIC_IP`：服务器公网 IPv4。未设置时脚本自动检测；建议显式指定。

`SUBSCRIPTION_TOKEN`：订阅路径令牌。未设置时随机生成；建议每台 VPS 使用不同令牌。

示例：

```bash
PUBLIC_IP=203.0.113.10 SUBSCRIPTION_TOKEN=$(openssl rand -hex 20) bash deploy.sh
```

## 生成内容

- `/usr/local/etc/xray/config.json`：Xray 服务端配置。
- `/var/www/html/<令牌>`：Clash/Mihomo YAML 订阅。
- `/etc/nginx/sites-available/subscription`：订阅文件静态服务。
- `xray.service`、`nginx.service`：系统服务。

## 验证

```bash
systemctl is-active xray nginx
ss -lntup | grep -E ':80|:443'
curl http://服务器IP/订阅令牌
```

导入 Clash 后选择 `PROXY -> VPS-Reality`。国内常用服务按规则直连，其余未匹配流量走 VPS。
