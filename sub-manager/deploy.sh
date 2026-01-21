#!/bin/bash
# 自动化部署脚本 - 用于 CentOS VPS

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="sub-manager"
SERVER_NAME="sub.before30.site"
INSTALL_PATH="/opt/sub-manager"
WEB_ROOT="/var/www/sub-manager"
VENV_PATH="${INSTALL_PATH}/venv"
SCRIPT_USER="nobody"

echo -e "${GREEN}=== 订阅管理系统自动化部署 ===${NC}"
echo "目标系统: CentOS 7/8"
echo "安装路径: ${INSTALL_PATH}"
echo "Web 路径: ${WEB_ROOT}"
echo ""

# ===================================
# 发送 ntfy 推送
# 参数1: 消息内容
# ===================================
send_ntfy() {
    local MESSAGE="$1"
    local TOPIC="sub-us-2026"        # 自定义主题
    local NTFY_URL="https://ntfy.sh" # ntfy 服务器

    # 发送通知
    curl -s -d "$MESSAGE" "$NTFY_URL/$TOPIC"
}

# 检查系统
check_system() {
    # 1. 检查通用的 os-release 文件
    if [ -f /etc/os-release ]; then
        # 导入系统变量
        . /etc/os-release
        # $ID 变量通常是 centos, rhel, rocky, almalinux 等
        if [[ "$ID" == "centos" || "$ID" == "rhel" || "$ID_LIKE" == *"centos"* || "$ID_LIKE" == *"rhel"* ]]; then
            echo -e "${GREEN}✓ $NAME 系统检查通过${NC}"
            return 0
        fi
    fi
    # 2. 兜底方案：检查传统的 redhat-release（包含 CentOS/Fedora/RH）
    if [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}✓ 检测到类 RedHat 系统: $(cat /etc/redhat-release)${NC}"
        return 0
    fi

    # 3. 都不匹配则报错
    echo -e "${RED}❌ 此脚本仅支持 CentOS 或类 RHEL 系统${NC}"
    exit 1
}
#检查公网链接
get_public_ip() {
    IP=""
    IP=$(curl -s https://api.ipify.org) || true
    if [ -z "$IP" ]; then
        IP=$(curl -s https://ifconfig.me) || true
    fi
    if [ -z "$IP" ]; then
        IP=$(curl -s https://ip.sb) || true
    fi
    if [ -z "$IP" ]; then
        IP="你的VPS公网IP"
    fi
    echo "$IP"
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}>>> 安装系统依赖${NC}"
    sudo yum update -y
    sudo yum install -y \
        python3 \
        python3-pip \
        git \
        curl \
        wget \
        nginx \
        cronie \
        cronie-anacron
    
    # 安装 Python 依赖
    pip3 install --upgrade pip setuptools
    pip3 install \
        pyyaml \
        requests \
        python-dotenv
    
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
}

# 创建项目目录
setup_directories() {
    echo -e "${YELLOW}>>> 创建项目目录${NC}"
    
    sudo mkdir -p "${INSTALL_PATH}"
    sudo mkdir -p "${WEB_ROOT}"
    sudo mkdir -p "${INSTALL_PATH}/logs"
    sudo mkdir -p "${INSTALL_PATH}/cache"
    sudo mkdir -p "${INSTALL_PATH}/backups"
    
    # 设置权限
    sudo chown -R "${SCRIPT_USER}:${SCRIPT_USER}" "${INSTALL_PATH}"
    sudo chown -R "${SCRIPT_USER}:${SCRIPT_USER}" "${WEB_ROOT}"
    
    echo -e "${GREEN}✓ 目录创建完成${NC}"
}

# 复制项目文件
copy_project_files() {
    echo -e "${YELLOW}>>> 复制项目文件${NC}"
    
    # 这里假设脚本从项目目录执行
    sudo cp -r ./scripts "${INSTALL_PATH}/"
    sudo cp -r ./config "${INSTALL_PATH}/"
    sudo cp -r ./templates "${INSTALL_PATH}/"
    sudo cp -r ./rules "${INSTALL_PATH}/"
    sudo cp -r ./local-nodes "${INSTALL_PATH}"
    # sudo mkdir -p "${INSTALL_PATH}/local-nodes"
    
    # 更新配置路径
    sudo sed -i "s|./local-nodes|${INSTALL_PATH}/local-nodes|g" \
        "${INSTALL_PATH}/config/config.yaml"
    sudo sed -i "s|./rules|${INSTALL_PATH}/rules|g" \
        "${INSTALL_PATH}/config/config.yaml"
    sudo sed -i "s|./templates|${INSTALL_PATH}/templates|g" \
        "${INSTALL_PATH}/config/config.yaml"
    sudo sed -i "s|./output|${WEB_ROOT}|g" \
        "${INSTALL_PATH}/config/config.yaml"
    
    echo -e "${GREEN}✓ 项目文件复制完成${NC}"
}

# 配置 Nginx
setup_nginx() {
    echo -e "${YELLOW}>>> 配置 Nginx${NC}"
    
    # 创建 Nginx 配置文件（先配置HTTP，SSL证书获取后会更新）
    sudo tee /etc/nginx/conf.d/sub-manager.conf > /dev/null <<'EOF'
# HTTP 服务（用于证书验证）
server {
    listen 80;
    server_name sub.before30.site;
    
    client_max_body_size 100M;
    root /var/www/sub-manager;
    
    # 设置默认访问
    location / {
        try_files $uri =404;
    }
    
    # 健康检查
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    # 访问日志
    access_log /var/log/nginx/sub-manager-access.log combined;
    error_log /var/log/nginx/sub-manager-error.log warn;
}
EOF
    
    # 检查配置并启动
    sudo nginx -t && sudo systemctl restart nginx
    
    echo -e "${GREEN}✓ Nginx 基础配置完成${NC}"
}

# 创建 Systemd Service
setup_systemd_service() {
    echo -e "${YELLOW}>>> 创建 Systemd 服务${NC}"
    
    sudo tee /etc/systemd/system/sub-manager-update.service > /dev/null <<EOF
[Unit]
Description=Subscription Manager Update Service
After=network.target

[Service]
Type=oneshot
User=${SCRIPT_USER}
WorkingDirectory=${INSTALL_PATH}
ExecStart=/usr/bin/python3 ${INSTALL_PATH}/scripts/merge_subscriptions.py \
    ${INSTALL_PATH}/config/config.yaml ${WEB_ROOT}/merged.yaml
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/sub-manager-update.timer > /dev/null <<EOF
[Unit]
Description=Subscription Manager Update Timer
Requires=sub-manager-update.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable sub-manager-update.timer
    
    echo -e "${GREEN}✓ Systemd 服务创建完成${NC}"
}

# 创建 Crontab 任务（可选备份方案）
setup_crontab() {
    echo -e "${YELLOW}>>> 配置 Crontab 定时任务${NC}"
    
    # 创建 crontab 脚本
    sudo tee "${INSTALL_PATH}/cron-update.sh" > /dev/null <<EOF
#!/bin/bash
cd ${INSTALL_PATH}
/usr/bin/python3 ${INSTALL_PATH}/scripts/merge_subscriptions.py \
    ${INSTALL_PATH}/config/config.yaml ${WEB_ROOT}/merged.yaml >> ${INSTALL_PATH}/logs/cron.log 2>&1

# ===================================
# 发送 ntfy 推送
# ===================================
TOPIC="sub-us-2026"                 # 自定义主题
NTFY_URL="https://ntfy.sh"          #ntfy 服务器
MESSAGE="⏰ VPS (${HOSTNAME}) 自动订阅更新完成: ${WEB_ROOT}/merged.yaml"

# 发送通知
curl -s -d "$MESSAGE" "$NTFY_URL/$TOPIC"
EOF
    
    sudo chmod +x "${INSTALL_PATH}/cron-update.sh"
    
    # 添加到 crontab
    # 每天 9:00 执行
    (sudo crontab -l 2>/dev/null || true; echo "0 9 * * * ${INSTALL_PATH}/cron-update.sh") | \
        sudo crontab -
    
    echo -e "${GREEN}✓ Crontab 配置完成${NC}"
}

# 执行初始合并
initial_merge() {
    echo -e "${YELLOW}>>> 执行初始合并${NC}"
    
    cd "${INSTALL_PATH}"
    sudo -u "${SCRIPT_USER}" python3  \
        "${INSTALL_PATH}/scripts/convert_nodes.py"

    sudo -u "${SCRIPT_USER}" python3 \
        "${INSTALL_PATH}/scripts/merge_subscriptions.py" \
        "${INSTALL_PATH}/config/config.yaml" \
        "${WEB_ROOT}/merged.yaml"
    
    echo -e "${GREEN}✓ 初始合并完成${NC}"
}

# 设置日志轮转
setup_logrotate() {
    echo -e "${YELLOW}>>> 配置日志轮转${NC}"
    
    sudo tee /etc/logrotate.d/sub-manager > /dev/null <<EOF
${INSTALL_PATH}/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 ${SCRIPT_USER} ${SCRIPT_USER}
    sharedscripts
}
EOF
    
    echo -e "${GREEN}✓ 日志轮转配置完成${NC}"
}

# 自动配置 SSL/HTTPS
setup_ssl_auto() {
    echo -e "${YELLOW}>>> 配置 SSL/HTTPS${NC}"
    
    # 先运行 Certbot 获取证书
    echo "正在安装 Certbot 并获取 SSL 证书..."
    
    # 尝试用系统包管理器安装 Certbot
    if ! command -v certbot &> /dev/null; then
        echo "安装 Certbot..."
        sudo dnf install -y certbot python3-certbot-nginx 2>/dev/null || \
        sudo pip3 install --upgrade certbot certbot-nginx
    fi
    
    # 获取 SSL 证书（使用 standalone 模式）
    CERT_PATH="/etc/letsencrypt/live/${SERVER_NAME}"
    if [ ! -f "${CERT_PATH}/fullchain.pem" ]; then
        echo "获取 SSL 证书..."
        sudo /usr/local/bin/certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email dingyi609@outlook.com \
            -d "${SERVER_NAME}" || true
    else
        echo "SSL 证书已存在，跳过获取步骤"
    fi
    
    # 配置 HTTPS Nginx 配置文件
    if [ -f "${CERT_PATH}/fullchain.pem" ]; then
        echo "配置 HTTPS..."
        
        sudo tee /etc/nginx/conf.d/sub-manager.conf > /dev/null <<EOF
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name ${SERVER_NAME};
    return 301 https://\$server_name\$request_uri;
}

# HTTPS 服务
server {
    listen 443 ssl http2;
    server_name ${SERVER_NAME};
    
    ssl_certificate ${CERT_PATH}/fullchain.pem;
    ssl_certificate_key ${CERT_PATH}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    client_max_body_size 100M;
    root ${WEB_ROOT};
    
    # 设置默认访问
    location / {
        try_files \$uri =404;
        add_header Content-Type text/yaml;
        add_header Content-Disposition "attachment; filename=merged.yaml";
    }
    
    # 健康检查
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    # 访问日志
    access_log /var/log/nginx/sub-manager-access.log combined;
    error_log /var/log/nginx/sub-manager-error.log warn;
}
EOF
        
        # 测试配置
        if sudo nginx -t; then
            echo "重启 Nginx..."
            sudo systemctl restart nginx
            echo -e "${GREEN}✓ HTTPS 配置完成${NC}"
            
            # 设置证书自动续期
            echo "设置证书自动续期..."
            CRON_CMD="0 3 * * * /usr/local/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx"
            (sudo crontab -l 2>/dev/null || true; echo "$CRON_CMD") | sudo crontab -
            echo -e "${GREEN}✓ 证书续期已配置${NC}"
        else
            echo -e "${RED}✗ Nginx 配置失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ SSL 证书获取失败，跳过 HTTPS 配置${NC}"
    fi
}

# 显示安装总结
show_summary() {
    echo ""
    echo -e "${GREEN}=== 安装完成 ===${NC}"
    echo ""
    echo "📍 安装信息:"
    echo "   项目路径: ${INSTALL_PATH}"
    echo "   Web 路径: ${WEB_ROOT}"
    echo "   配置文件: ${INSTALL_PATH}/config/config.yaml"
    echo ""
    echo "🚀 快速开始:"
    echo "   1. 编辑配置文件:"
    echo "      sudo nano ${INSTALL_PATH}/config/config.yaml"
    echo ""
    echo "   2. 添加本地节点:"
    echo "      sudo nano ${INSTALL_PATH}/local-nodes/private-nodes.yaml"
    echo ""
    echo "   3. 手动执行合并:"
    echo "      sudo python3 ${INSTALL_PATH}/scripts/merge_subscriptions.py \\"
    echo "          ${INSTALL_PATH}/config/config.yaml ${WEB_ROOT}/merged.yaml"
    echo ""
    echo "   4. 查看服务状态:"
    echo "      sudo systemctl status sub-manager-update.timer"
    echo "      sudo journalctl -u sub-manager-update.service -f"
    echo ""
    echo "📍 访问订阅:"
    PUBLIC_IP=$(get_public_ip)
    echo "   订阅地址:"
    echo "   https://${SERVER_NAME}/merged.yaml (HTTPS - 推荐)"
    echo "   http://${PUBLIC_IP}:4567/merged.yaml (HTTP备用)"
    send_ntfy "🚀 VPS (${HOSTNAME}) 订阅管理系统部署完成! HTTPS访问: https://${SERVER_NAME}/merged.yaml"
    echo ""
    echo "📝 日志文件:"
    echo "   应用日志: ${INSTALL_PATH}/logs/merge_subscriptions.log"
    echo "   Cron 日志: ${INSTALL_PATH}/logs/cron.log"
    echo "   Nginx 日志: /var/log/nginx/sub-manager-*.log"
    echo ""
    echo "⚙️  定时更新:"
    echo "   - 使用 Systemd Timer (推荐): 每天 09:00 自动更新"
    echo "   - 或使用 Crontab: 同样的配置已设置"
    echo ""
    echo "🔒 HTTPS/SSL 状态:"
    echo "   ✓ SSL 证书已自动配置"
    echo "   ✓ HTTPS 访问已启用"
    echo "   ✓ 证书自动续期已设置"
    echo "   测试访问: curl https://${SERVER_NAME}/health"
    echo ""
}

# 主程序
main() {
    check_system
    
    # 检查是否以 root 权限运行
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}❌ 此脚本需要 root 权限运行${NC}"
        exit 1
    fi
    
    install_dependencies
    setup_directories
    copy_project_files
    setup_nginx
    setup_systemd_service
    setup_crontab
    setup_logrotate
    initial_merge
    setup_ssl_auto
    show_summary
}

main "$@"
