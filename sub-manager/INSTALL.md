# 安装和使用指南

## 📦 系统要求

**CentOS 服务器：**
- CentOS 7.x / 8.x 或兼容系统（RHEL、AlmaLinux）
- 至少 1GB RAM
- 至少 500MB 存储空间
- 已安装 sudo 并具有 sudo 权限

**本地开发环境：**
- Python 3.6+
- pip3 包管理器
- 任意 Linux/macOS/Windows (WSL2)

## 🔧 安装步骤

### 步骤 1：获取代码

```bash
# 克隆或下载项目
git clone https://github.com/yourusername/sub-manager.git
cd sub-manager

# 或者直接下载
wget https://example.com/sub-manager.zip
unzip sub-manager.zip && cd sub-manager
```

### 步骤 2：本地测试（可选但推荐）

```bash
# 安装 Python 依赖
pip3 install pyyaml requests

# 运行测试脚本
chmod +x test.sh
./test.sh

# 查看输出
cat test-output/merged.yaml | head -30
```

### 步骤 3：配置文件

#### 配置 3.1 - 编辑主配置
```bash
nano config/config.yaml
```

关键配置项：
```yaml
# 添加你的远程订阅
remote_subscriptions:
  - name: "My Subscription"
    url: "https://your-subscription-url.com/sub"
    enabled: true
```

#### 配置 3.2 - 添加本地节点（可选）
```bash
nano local-nodes/private-nodes.yaml
```

示例节点格式：
```yaml
proxies:
  - name: "🇭🇰 Hong Kong"
    type: vmess
    server: hk.example.com
    port: 8080
    uuid: "your-uuid-here"
    alterId: 0
    cipher: auto
```

#### 配置 3.3 - 创建规则集（可选）
```bash
# 创建广告拦截规则
echo "DOMAIN,ads.google.com" > rules/ads.txt
echo "DOMAIN-SUFFIX,doubleclick.net" >> rules/ads.txt

# 创建自定义规则
cat > rules/custom.txt <<'EOF'
DOMAIN-KEYWORD,facebook
DOMAIN-KEYWORD,twitter
IP-CIDR,1.2.3.0/24
EOF
```

### 步骤 4：部署到 CentOS VPS

#### 方式 A：使用自动化脚本（推荐）

```bash
# 1. 上传项目到 VPS
scp -r sub-manager/ root@your-vps:/root/

# 2. 连接到 VPS
ssh root@your-vps

# 3. 执行部署
cd /root/sub-manager
chmod +x deploy.sh
sudo ./deploy.sh

# 部署脚本会自动完成以下操作：
# ✓ 安装所有系统依赖
# ✓ 创建项目目录结构
# ✓ 配置 Nginx
# ✓ 创建 Systemd 服务
# ✓ 配置 Crontab 任务
# ✓ 执行初始合并
# ✓ 配置日志轮转
```

#### 方式 B：手动部署

```bash
# 1. 安装依赖
sudo yum update -y
sudo yum install -y python3 python3-pip nginx cronie git
pip3 install pyyaml requests

# 2. 创建目录
sudo mkdir -p /opt/sub-manager
sudo mkdir -p /var/www/sub-manager
sudo chown -R nobody:nobody /opt/sub-manager
sudo chown -R nobody:nobody /var/www/sub-manager

# 3. 复制文件
sudo cp -r scripts config templates rules local-nodes /opt/sub-manager/

# 4. 更新配置路径
sudo sed -i "s|./local-nodes|/opt/sub-manager/local-nodes|g" \
    /opt/sub-manager/config/config.yaml
sudo sed -i "s|./rules|/opt/sub-manager/rules|g" \
    /opt/sub-manager/config/config.yaml
sudo sed -i "s|./templates|/opt/sub-manager/templates|g" \
    /opt/sub-manager/config/config.yaml

# 5. 配置 Nginx（见下文）
# 6. 配置定时任务（见下文）
# 7. 执行初始合并（见下文）
```

### 步骤 5：配置 Nginx

```bash
# 创建 Nginx 配置
sudo tee /etc/nginx/conf.d/sub-manager.conf <<'EOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/sub-manager;
    client_max_body_size 100M;
    
    location / {
        try_files $uri =404;
        add_header Content-Type text/yaml;
    }
    
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    access_log /var/log/nginx/sub-manager-access.log combined;
    error_log /var/log/nginx/sub-manager-error.log warn;
}
EOF

# 测试配置
sudo nginx -t

# 启动 Nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 步骤 6：配置定时更新

#### 方式 A：Systemd Timer（推荐）

```bash
# 创建 service 文件
sudo tee /etc/systemd/system/sub-manager-update.service <<'EOF'
[Unit]
Description=Subscription Manager Update Service
After=network.target

[Service]
Type=oneshot
User=nobody
WorkingDirectory=/opt/sub-manager
ExecStart=/usr/bin/python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml /var/www/sub-manager/merged.yaml

[Install]
WantedBy=multi-user.target
EOF

# 创建 timer 文件
sudo tee /etc/systemd/system/sub-manager-update.timer <<'EOF'
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

# 启用和启动
sudo systemctl daemon-reload
sudo systemctl enable sub-manager-update.timer
sudo systemctl start sub-manager-update.timer

# 检查状态
sudo systemctl status sub-manager-update.timer
```

#### 方式 B：Crontab

```bash
# 编辑 crontab
sudo crontab -e

# 添加定时任务（每天 9:00 运行）
0 9 * * * /opt/sub-manager/scripts/update.sh >> /opt/sub-manager/logs/cron.log 2>&1

# 或者使用脚本
sudo tee /opt/sub-manager/cron-update.sh <<'EOF'
#!/bin/bash
cd /opt/sub-manager
python3 scripts/merge_subscriptions.py config/config.yaml /var/www/sub-manager/merged.yaml
EOF

sudo chmod +x /opt/sub-manager/cron-update.sh

# 添加到 crontab
(sudo crontab -l 2>/dev/null || true; echo "0 9 * * * /opt/sub-manager/cron-update.sh") | \
    sudo crontab -
```

### 步骤 7：执行初始合并

```bash
# 手动运行一次
sudo python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml

# 验证输出
ls -lh /var/www/sub-manager/merged.yaml
curl http://localhost/merged.yaml | head -30
```

### 步骤 8：SSL 配置（可选但推荐）

```bash
# 使用提供的脚本
chmod +x setup-ssl.sh
sudo ./setup-ssl.sh

# 或手动配置
sudo yum install certbot certbot-nginx -y
sudo certbot certonly --standalone -d your-domain.com

# 更新 Nginx 配置
# （脚本会自动完成）
```

## 🎯 验证安装

```bash
# 检查项目目录
ls -la /opt/sub-manager/

# 查看配置
sudo cat /opt/sub-manager/config/config.yaml

# 查看输出
curl http://localhost/health

# 查看节点
curl http://localhost/merged.yaml | grep "name:" | head -10

# 检查日志
tail -f /opt/sub-manager/logs/merge_subscriptions.log

# 检查定时任务
sudo systemctl status sub-manager-update.timer
```

## 📱 客户端配置

### Clash

在 Clash 客户端中：
1. 打开 Profile / Subscriptions
2. 点击 + 或 Add
3. 输入 URL：`http://your-vps-ip/merged.yaml` 或 `https://your-domain.com/merged.yaml`
4. 点击 Download
5. 选择使用

### Stash (iOS)

在 Stash 中：
1. 底部菜单 → Subscriptions
2. 点击 + 添加
3. URL：`https://your-domain.com/merged.yaml`
4. 选择更新频率
5. 等待同步

### Surge (iOS/macOS)

1. 主菜单 → 配置 → 新建
2. 从 URL 导入
3. 粘贴 URL
4. 完成

## 🔄 日常使用

### 手动更新

```bash
# 方式 1：直接运行脚本
/opt/sub-manager/scripts/update.sh

# 方式 2：运行 Python 脚本
python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml

# 方式 3：触发 Systemd 服务
sudo systemctl start sub-manager-update.service
```

### 添加新节点

```bash
# 编辑本地节点文件
sudo nano /opt/sub-manager/local-nodes/private-nodes.yaml

# 添加新节点后保存，自动合并会获取最新数据
```

### 添加新远程订阅

```bash
# 编辑配置
sudo nano /opt/sub-manager/config/config.yaml

# 在 remote_subscriptions 中添加
- name: "New Subscription"
  url: "https://new-sub-url.com/sub"
  enabled: true

# 保存，下次自动合并会包含此订阅
```

### 添加新规则

```bash
# 创建规则文件
sudo tee /opt/sub-manager/rules/my-rules.txt <<'EOF'
DOMAIN,my-domain.com
DOMAIN-SUFFIX,example.com
EOF

# 自动合并时会包含此规则
```

## 🐛 故障排查

### 合并失败

```bash
# 查看详细日志
tail -100 /opt/sub-manager/logs/merge_subscriptions.log

# 手动运行并查看错误
python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml

# 检查 Python 依赖
pip3 list | grep -E "pyyaml|requests"
```

### 无法访问订阅

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 查看 Nginx 错误日志
sudo tail -50 /var/log/nginx/sub-manager-error.log

# 检查文件权限
ls -la /var/www/sub-manager/merged.yaml

# 测试本地访问
curl http://localhost/merged.yaml
```

### 定时任务未执行

```bash
# 检查 Systemd 状态
sudo systemctl status sub-manager-update.timer

# 查看执行历史
sudo systemctl list-timers sub-manager-update.timer

# 查看日志
sudo journalctl -u sub-manager-update.service -n 50

# 检查 Crontab
sudo crontab -l

# 查看系统日志
sudo tail -f /var/log/cron
```

### 节点无法连接

```bash
# 验证 YAML 格式
python3 -c "
import yaml
with open('/var/www/sub-manager/merged.yaml') as f:
    yaml.safe_load(f)
print('YAML 格式正确')
"

# 查看节点示例
head -50 /var/www/sub-manager/merged.yaml

# 检查节点数量
grep -c "name:" /var/www/sub-manager/merged.yaml
```

## 📚 后续维护

### 定期检查

```bash
# 每周检查一次日志
ls -lah /opt/sub-manager/logs/

# 清理旧备份
find /opt/sub-manager/backups -mtime +30 -delete

# 检查磁盘使用
du -sh /opt/sub-manager
du -sh /var/www/sub-manager
```

### 备份配置

```bash
# 备份整个项目
tar -czf /root/sub-manager-backup-$(date +%s).tar.gz /opt/sub-manager/

# 只备份配置
cp -r /opt/sub-manager/config /root/config-backup-$(date +%Y%m%d)/
```

### 升级脚本

```bash
# 拉取最新版本
cd /root/sub-manager
git pull origin main

# 比较差异
diff -r /opt/sub-manager/scripts scripts/

# 更新（如果有改动）
sudo cp scripts/*.py /opt/sub-manager/scripts/
```

## 📞 常见问题

**Q: 支持多少个节点？**
A: 无限制，建议不超过 1000 个以保证性能。

**Q: 多久更新一次？**
A: 默认每天 9:00，可在配置中修改。

**Q: 可以从多个源合并吗？**
A: 可以，在 `remote_subscriptions` 中添加多个 URL。

**Q: 如何隐藏真实 IP？**
A: 建议使用 CDN（如 Cloudflare）将域名指向 CDN，CDN 回源到 VPS。

**Q: 脚本支持哪些系统？**
A: CentOS 7/8, Ubuntu 18.04+, Debian 10+, RHEL 7/8。

---

**更多帮助：运行 `bash healthcheck.sh` 诊断问题**
