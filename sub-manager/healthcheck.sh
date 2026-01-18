#!/bin/bash
# CentOS VPS 快速检查和故障排查脚本

echo "=========================================="
echo "  订阅系统 - VPS 健康检查"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_passed() {
    echo -e "${GREEN}✓${NC} $1"
}

check_failed() {
    echo -e "${RED}✗${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

INSTALL_PATH="/opt/sub-manager"
WEB_ROOT="/var/www/sub-manager"

echo -e "${YELLOW}=== 系统环境${NC}"
echo ""

# 检查系统
if [ -f /etc/centos-release ]; then
    version=$(cat /etc/centos-release)
    check_passed "CentOS 系统: $version"
else
    check_warning "非 CentOS 系统，可能会有兼容性问题"
fi

# 检查 Python
if command -v python3 &> /dev/null; then
    version=$(python3 --version 2>&1 | awk '{print $2}')
    check_passed "Python 3: $version"
else
    check_failed "未安装 Python 3"
fi

# 检查 pip
if command -v pip3 &> /dev/null; then
    check_passed "pip3 已安装"
else
    check_failed "未安装 pip3"
fi

echo ""
echo -e "${YELLOW}=== Python 依赖${NC}"
echo ""

# 检查 PyYAML
if python3 -c "import yaml" 2>/dev/null; then
    version=$(python3 -c "import yaml; print(yaml.__version__)" 2>/dev/null || echo "unknown")
    check_passed "PyYAML: $version"
else
    check_failed "缺少 PyYAML，运行: pip3 install pyyaml"
fi

# 检查 requests
if python3 -c "import requests" 2>/dev/null; then
    version=$(python3 -c "import requests; print(requests.__version__)" 2>/dev/null || echo "unknown")
    check_passed "requests: $version"
else
    check_failed "缺少 requests，运行: pip3 install requests"
fi

echo ""
echo -e "${YELLOW}=== 项目文件${NC}"
echo ""

# 检查项目目录
if [ -d "$INSTALL_PATH" ]; then
    check_passed "项目目录存在: $INSTALL_PATH"
    
    # 检查关键文件
    files=("scripts/merge_subscriptions.py" "config/config.yaml" "templates/base-config.yaml")
    for file in "${files[@]}"; do
        if [ -f "$INSTALL_PATH/$file" ]; then
            check_passed "  ✓ $file"
        else
            check_failed "  ✗ 缺少 $file"
        fi
    done
else
    check_failed "项目目录不存在: $INSTALL_PATH"
fi

# 检查 Web 目录
if [ -d "$WEB_ROOT" ]; then
    check_passed "Web 目录存在: $WEB_ROOT"
    if [ -f "$WEB_ROOT/merged.yaml" ]; then
        size=$(du -h "$WEB_ROOT/merged.yaml" | cut -f1)
        mtime=$(stat -c %y "$WEB_ROOT/merged.yaml" | cut -d' ' -f1,2)
        check_passed "  ✓ 输出文件 ($size, 更新于 $mtime)"
    else
        check_warning "  输出文件不存在，请运行一次合并"
    fi
else
    check_failed "Web 目录不存在: $WEB_ROOT"
fi

echo ""
echo -e "${YELLOW}=== 服务状态${NC}"
echo ""

# 检查 Nginx
if systemctl is-active --quiet nginx; then
    check_passed "Nginx 运行中"
    if curl -s http://localhost/health &> /dev/null; then
        check_passed "  ✓ 健康检查通过"
    else
        check_warning "  健康检查失败"
    fi
else
    check_failed "Nginx 未运行"
fi

# 检查 Systemd timer
if systemctl is-enabled sub-manager-update.timer &> /dev/null; then
    if systemctl is-active --quiet sub-manager-update.timer; then
        check_passed "Systemd Timer 运行中"
        next=$(systemctl list-timers sub-manager-update.timer --no-pager 2>/dev/null | tail -1 | awk '{print $3, $4, $5}')
        [ -n "$next" ] && check_passed "  下次执行: $next"
    else
        check_warning "Systemd Timer 未运行"
    fi
else
    check_warning "Systemd Timer 未启用"
fi

# 检查 Crontab
if crontab -l &> /dev/null && crontab -l | grep -q "sub-manager\|merge_subscriptions"; then
    check_passed "Crontab 任务已配置"
else
    check_warning "未找到 Crontab 任务"
fi

echo ""
echo -e "${YELLOW}=== 日志文件${NC}"
echo ""

# 检查日志
logs=(
    "/opt/sub-manager/logs/merge_subscriptions.log:应用日志"
    "/opt/sub-manager/logs/cron.log:Cron 日志"
    "/var/log/nginx/sub-manager-access.log:Nginx 访问日志"
    "/var/log/nginx/sub-manager-error.log:Nginx 错误日志"
)

for log_entry in "${logs[@]}"; do
    log_file="${log_entry%:*}"
    log_name="${log_entry#*:}"
    
    if [ -f "$log_file" ]; then
        lines=$(wc -l < "$log_file")
        size=$(du -h "$log_file" | cut -f1)
        check_passed "$log_name ($size, $lines 行)"
    else
        check_warning "$log_name (不存在)"
    fi
done

echo ""
echo -e "${YELLOW}=== 磁盘使用${NC}"
echo ""

# 检查磁盘
if [ -d "$INSTALL_PATH" ]; then
    usage=$(du -sh "$INSTALL_PATH" 2>/dev/null | cut -f1)
    echo "项目目录: $usage"
fi

if [ -d "$WEB_ROOT" ]; then
    usage=$(du -sh "$WEB_ROOT" 2>/dev/null | cut -f1)
    echo "Web 目录: $usage"
fi

df -h "$INSTALL_PATH" 2>/dev/null | tail -1

echo ""
echo -e "${YELLOW}=== 常用命令${NC}"
echo ""

echo "手动触发更新:"
echo "  sudo systemctl start sub-manager-update.service"
echo ""

echo "查看最近日志:"
echo "  sudo journalctl -u sub-manager-update.service -n 20 -f"
echo ""

echo "查看输出文件:"
echo "  curl http://localhost/merged.yaml | head -20"
echo ""

echo "检查节点数:"
echo "  grep -c '^  - name:' /var/www/sub-manager/merged.yaml"
echo ""

echo "重新启动 Nginx:"
echo "  sudo systemctl restart nginx"
echo ""

echo "编辑配置:"
echo "  sudo nano /opt/sub-manager/config/config.yaml"
echo ""

echo "=========================================="
echo "  检查完成"
echo "=========================================="
