#!/usr/bin/env bash
# VPS Reality 节点一键部署脚本
#
# 用途：在 Ubuntu VPS 上安装 Xray VLESS + Reality 和 Nginx，生成 Clash/Mihomo 与 Shadowrocket 订阅。
# 用法：
#   PUBLIC_IP=203.0.113.10 bash deploy.sh
#   # PUBLIC_IP 可省略，脚本会尝试自动检测公网 IPv4。
#
# 输出：完成后打印订阅 URL、节点 UUID、Reality 公钥和 short-id。
# 注意：私钥只写入服务器配置，不会打印或上传；请保护终端输出中的订阅 URL。

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "错误：请使用 root 运行。" >&2
  exit 1
fi

PUBLIC_IP="${PUBLIC_IP:-$(curl -4fsS --max-time 8 https://api.ipify.org || true)}"
if [[ -z "${PUBLIC_IP}" ]]; then
  echo "错误：无法自动获取公网 IPv4，请设置 PUBLIC_IP。" >&2
  exit 1
fi

SUBSCRIPTION_TOKEN="${SUBSCRIPTION_TOKEN:-$(openssl rand -hex 20)}"
SHADOWROCKET_TOKEN="${SHADOWROCKET_TOKEN:-$(openssl rand -hex 20)}"
XRAY_CONFIG=/usr/local/etc/xray/config.json
WEB_ROOT=/var/www/html
SUBSCRIPTION_FILE="${WEB_ROOT}/${SUBSCRIPTION_TOKEN}"
SHADOWROCKET_FILE="${WEB_ROOT}/${SHADOWROCKET_TOKEN}.txt"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl nginx openssl

if ! command -v xray >/dev/null 2>&1; then
  bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install
fi

UUID="$(cat /proc/sys/kernel/random/uuid)"
KEYS="$(xray x25519)"
PRIVATE_KEY="$(printf '%s\n' "${KEYS}" | awk '/^PrivateKey:/ {print $2}')"
PUBLIC_KEY="$(printf '%s\n' "${KEYS}" | awk '/Password \(PublicKey\):/ {print $3}')"
SHORT_ID="$(openssl rand -hex 4)"

install -d -m 0755 "${WEB_ROOT}"
cat > "${XRAY_CONFIG}" <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {"clients": [{"id": "${UUID}"}], "decryption": "none"},
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "www.cloudflare.com:443",
        "xver": 0,
        "serverNames": ["www.cloudflare.com"],
        "privateKey": "${PRIVATE_KEY}",
        "shortIds": ["${SHORT_ID}"]
      }
    }
  }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}, {"protocol": "blackhole", "tag": "block"}]
}
EOF

URI="vless://${UUID}@${PUBLIC_IP}:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#VPS-Reality"
printf '%s' "${URI}" | base64 -w0 > "${SHADOWROCKET_FILE}"

cat > "${SUBSCRIPTION_FILE}" <<EOF
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
proxies:
  - name: VPS-Reality
    type: vless
    server: ${PUBLIC_IP}
    port: 443
    uuid: ${UUID}
    network: tcp
    udp: true
    tls: true
    servername: www.cloudflare.com
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}
    client-fingerprint: chrome
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - VPS-Reality
      - DIRECT
rules:
  - DOMAIN-SUFFIX,wechat.com,DIRECT
  - DOMAIN-SUFFIX,weixin.qq.com,DIRECT
  - DOMAIN-SUFFIX,wx.qq.com,DIRECT
  - DOMAIN-SUFFIX,qpic.cn,DIRECT
  - DOMAIN-SUFFIX,qlogo.cn,DIRECT
  - DOMAIN-SUFFIX,qq.com,DIRECT
  - DOMAIN-SUFFIX,tencent.com,DIRECT
  - DOMAIN-SUFFIX,tenpay.com,DIRECT
  - DOMAIN-SUFFIX,douyin.com,DIRECT
  - DOMAIN-SUFFIX,douyinvod.com,DIRECT
  - DOMAIN-SUFFIX,snssdk.com,DIRECT
  - DOMAIN-SUFFIX,pstatp.com,DIRECT
  - DOMAIN-SUFFIX,douyincdn.com,DIRECT
  - DOMAIN-SUFFIX,bilibili.com,DIRECT
  - DOMAIN-SUFFIX,bilivideo.com,DIRECT
  - DOMAIN-SUFFIX,bilivideo.cn,DIRECT
  - DOMAIN-SUFFIX,biliapi.com,DIRECT
  - DOMAIN-SUFFIX,taobao.com,DIRECT
  - DOMAIN-SUFFIX,tmall.com,DIRECT
  - DOMAIN-SUFFIX,jd.com,DIRECT
  - DOMAIN-SUFFIX,weibo.com,DIRECT
  - DOMAIN-SUFFIX,zhihu.com,DIRECT
  - DOMAIN-SUFFIX,netease.com,DIRECT
  - DOMAIN-SUFFIX,163.com,DIRECT
  - DOMAIN-SUFFIX,youku.com,DIRECT
  - DOMAIN-SUFFIX,iqiyi.com,DIRECT
  - DOMAIN-SUFFIX,meituan.com,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF

cat > /etc/nginx/sites-available/subscription <<'EOF'
server { listen 80 default_server; server_name _; root /var/www/html; location / { default_type text/plain; } }
EOF
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/subscription /etc/nginx/sites-enabled/subscription
nginx -t
systemctl enable --now xray nginx
systemctl restart xray nginx

if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp >/dev/null || true
  ufw allow 80/tcp >/dev/null || true
  ufw allow 443/tcp >/dev/null || true
fi

echo
echo "部署完成。"
echo "Clash/Mihomo 订阅：http://${PUBLIC_IP}/${SUBSCRIPTION_TOKEN}"
echo "Shadowrocket 订阅：http://${PUBLIC_IP}/${SHADOWROCKET_TOKEN}"
echo "节点名称：VPS-Reality"
echo "请立即保存订阅链接，并修改 root 密码。"
