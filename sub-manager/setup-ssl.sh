#!/bin/bash
# Nginx SSL 配置辅助脚本 - 使用 Let's Encrypt
# 兼容 CentOS/RHEL 8/9, 自动安装 Certbot 并处理 PATH 问题

set -e

echo "=========================================="
echo "  Nginx HTTPS 配置向导"
echo "=========================================="
echo ""

# 检查 Certbot - 使用绝对路径
CERTBOT_CMD="/usr/bin/certbot"
if ! $CERTBOT_CMD --version &> /dev/null 2>&1; then
    # 尝试通过包管理器安装 Certbot
    echo "正在尝试通过系统包管理器安装 Certbot..."
    if sudo dnf install -y certbot python3-certbot-nginx; then
        echo "✓ Certbot 通过 dnf 安装成功"
    else
        echo "正在通过 pip 安装 Certbot..."
        sudo pip3 install --upgrade certbot certbot-nginx
        CERTBOT_CMD="/usr/local/bin/certbot"
        if [ ! -f "$CERTBOT_CMD" ]; then
            CERTBOT_CMD=$(find /usr -name certbot -type f 2>/dev/null | head -1)
            if [ -z "$CERTBOT_CMD" ]; then
                echo "错误：无法找到 Certbot"
                exit 1
            fi
        fi
    fi
fi

# 设置默认域名（自动执行）
DOMAIN="sub.before30.site"
echo "使用域名: $DOMAIN"

if [ -z "$DOMAIN" ]; then
    echo "错误：域名不能为空"
    exit 1
fi

echo ""
echo "正在获取 SSL 证书..."
echo ""

# 获取证书（使用 standalone 模式，如果 80 端口被占用可改为 webroot）
sudo $CERTBOT_CMD certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email dingyi609@outlook.com \
    -d "$DOMAIN"

CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
CERT_FILE="$CERT_PATH/fullchain.pem"
KEY_FILE="$CERT_PATH/privkey.pem"

if [ ! -f "$CERT_FILE" ]; then
    echo "错误：证书获取失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "  配置 Nginx"
echo "=========================================="
echo ""

# 备份原配置
if [ -f /etc/nginx/conf.d/sub-manager.conf ]; then
    sudo cp /etc/nginx/conf.d/sub-manager.conf /etc/nginx/conf.d/sub-manager.conf.bak
fi

# 创建新配置
sudo tee /etc/nginx/conf.d/sub-manager.conf > /dev/null <<EOF
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS 服务
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    root /var/www/sub-manager;
    
    location / {
        try_files \$uri =404;
        add_header Content-Type text/yaml;
        add_header Content-Disposition "attachment; filename=merged.yaml";
    }
    
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    access_log /var/log/nginx/sub-manager-access.log combined;
    error_log /var/log/nginx/sub-manager-error.log warn;
}
EOF

echo "✓ Nginx 配置已更新"

# 测试 Nginx 配置
echo ""
echo "测试 Nginx 配置..."
if sudo nginx -t; then
    echo "✓ 配置测试通过"
    
    echo ""
    echo "重启 Nginx..."
    sudo systemctl restart nginx
    echo "✓ Nginx 已重启"
    
    # 设置证书自动续期
    echo ""
    echo "设置证书自动续期..."
    CRON_CMD="0 3 * * * $CERTBOT_CMD renew --quiet && /usr/bin/systemctl reload nginx"
    (sudo crontab -l 2>/dev/null || true; echo "$CRON_CMD") | sudo crontab -
    echo "✓ 证书续期已配置（每日凌晨 3:00）"
    
    echo ""
    echo "=========================================="
    echo "  配置完成"
    echo "=========================================="
    echo ""
    echo "HTTPS 信息:"
    echo "  域名: $DOMAIN"
    echo "  证书: $CERT_FILE"
    echo "  密钥: $KEY_FILE"
    echo ""
    echo "订阅 URL:"
    echo "  https://$DOMAIN/merged.yaml"
    echo ""
    echo "测试:"
    echo "  curl https://$DOMAIN/health"
    echo "  curl https://$DOMAIN/merged.yaml | head"
    echo ""
else
    echo "✗ 配置测试失败，已恢复备份"
    if [ -f /etc/nginx/conf.d/sub-manager.conf.bak ]; then
        sudo cp /etc/nginx/conf.d/sub-manager.conf.bak /etc/nginx/conf.d/sub-manager.conf
    fi
    sudo systemctl restart nginx
    exit 1
fi