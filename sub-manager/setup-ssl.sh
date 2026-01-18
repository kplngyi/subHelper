#!/bin/bash
# Nginx SSL 配置辅助脚本 - 使用 Let's Encrypt

set -e

echo "=========================================="
echo "  Nginx HTTPS 配置向导"
echo "=========================================="
echo ""

# 检查 Certbot
if ! command -v certbot &> /dev/null; then
    echo "正在安装 Certbot..."
    sudo yum install certbot certbot-nginx -y
fi

# 获取域名
read -p "请输入你的域名 (例: sub.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "错误：域名不能为空"
    exit 1
fi

echo ""
echo "正在获取 SSL 证书..."
echo ""

# 获取证书
sudo certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email admin@example.com \
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
sudo cp /etc/nginx/conf.d/sub-manager.conf /etc/nginx/conf.d/sub-manager.conf.bak

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
    
    # SSL 证书配置
    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;
    
    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # 配置
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

# 测试配置
echo ""
echo "测试 Nginx 配置..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✓ 配置测试通过"
    
    echo ""
    echo "重启 Nginx..."
    sudo systemctl restart nginx
    
    echo "✓ Nginx 已重启"
    
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
    echo "证书更新:"
    echo "  系统会在证书过期前自动续期（需启用 Crontab）"
    echo "  手动续期: sudo certbot renew"
    echo ""
    echo "测试:"
    echo "  curl https://$DOMAIN/health"
    echo "  curl https://$DOMAIN/merged.yaml | head"
    echo ""
    
    # 设置证书自动续期
    echo "设置证书自动续期..."
    (sudo crontab -l 2>/dev/null || true; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | \
        sudo crontab -
    
    echo "✓ 证书续期已配置（每日凌晨 3:00）"
    
else
    echo "✗ 配置测试失败，已恢复备份"
    sudo cp /etc/nginx/conf.d/sub-manager.conf.bak /etc/nginx/conf.d/sub-manager.conf
    sudo systemctl restart nginx
    exit 1
fi

echo ""
echo "=========================================="
echo "  所有操作已完成！"
echo "=========================================="
