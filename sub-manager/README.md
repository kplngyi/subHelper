# 📦 CentOS 节点订阅自动化管理系统

一套完整的基于 CentOS 的节点订阅自动化管理方案，支持本地私有节点与远程订阅的自动合并、去重、美化，并通过自建 HTTP 服务实现私有化分发。

## ✨ 核心功能

- **节点聚合** - 自动合并本地私有节点和远程订阅节点
- **去重美化** - 智能去重和节点名称规范化
- **规则自定义** - 支持灵活的规则集管理和拼接
- **私有分发** - Nginx HTTP 服务，完全自建独立
- **自动更新** - Crontab/Systemd 定时任务，无需人工干预
- **标准输出** - YAML 格式，兼容 Clash 和 Stash (iOS)

## 📋 项目结构

```
sub-manager/
├── scripts/                    # 执行脚本
│   ├── merge_subscriptions.py  # 核心合并脚本
│   └── update.sh              # 快速更新脚本
├── config/                     # 配置文件
│   └── config.yaml            # 主配置
├── templates/                  # 配置模板
│   └── base-config.yaml       # Clash 基础配置
├── local-nodes/               # 本地私有节点目录
│   └── private-nodes.yaml     # 示例私有节点
├── rules/                      # 规则集目录
│   ├── ads.txt                # 广告拦截规则
│   └── china-sites.txt        # 国内网站规则
├── output/                     # 输出目录（合并结果）
├── deploy.sh                  # 自动化部署脚本
└── README.md                  # 本文档
```

## 🚀 快速开始

### 第一步：本地测试

```bash
# 1. 进入项目目录
cd sub-manager

# 2. 确保安装了 Python 3.6+ 和必要依赖
pip3 install pyyaml requests python-dotenv

# 3. 配置本地节点（可选）
# 编辑 local-nodes/private-nodes.yaml，添加你的私有节点

# 4. 配置远程订阅
# 编辑 config/config.yaml，添加远程订阅 URL

# 5. 运行合并脚本
python3 scripts/merge_subscriptions.py config/config.yaml output/merged.yaml

# 6. 检查输出
cat output/merged.yaml
```

### 第二步：部署到 CentOS VPS

#### 方式一：自动化部署（推荐）

```bash
# 1. 将项目复制到 VPS
scp -r sub-manager/ root@your-vps:/root/

# 2. 连接到 VPS
ssh root@your-vps

# 3. 执行部署脚本
cd /root/sub-manager
chmod +x deploy.sh
sudo ./deploy.sh

# 部署脚本会自动：
# - 安装所有依赖
# - 创建项目目录
# - 配置 Nginx
# - 设置 Systemd Service
# - 配置 Crontab
# - 执行初始合并
```

#### 方式二：手动部署

```bash
# 1. 安装依赖
sudo yum update -y
sudo yum install -y python3 python3-pip nginx cronie
pip3 install pyyaml requests

# 2. 创建项目目录
sudo mkdir -p /opt/sub-manager
sudo mkdir -p /var/www/sub-manager
sudo cp -r sub-manager/* /opt/sub-manager/

# 3. 配置 Nginx (见下文)
# 4. 配置 Crontab 或 Systemd (见下文)
# 5. 手动执行合并测试
sudo python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml
```

## ⚙️ 配置说明

### 1️⃣ 主配置文件 (config/config.yaml)

```yaml
# 本地私有节点目录
local_nodes_path: /opt/sub-manager/local-nodes

# 远程订阅列表
remote_subscriptions:
  - name: "Free Subscription"
    url: "https://example.com/sub"
    enabled: true
  - name: "Premium Subscription"
    url: "https://premium.example.com/sub"
    enabled: true

# 规则集目录
rules_path: /opt/sub-manager/rules

# 配置模板路径
template_path: /opt/sub-manager/templates/base-config.yaml

# 输出配置
output:
  path: /var/www/sub-manager
  filename: merged.yaml
  backup: true
  backup_count: 10
```

**如何添加远程订阅：**

1. 找到你的订阅 URL（通常是 .yaml 或 base64 编码的文本）
2. 在 `remote_subscriptions` 中添加新条目
3. 设置 `enabled: true`
4. 保存配置并触发更新

### 2️⃣ 本地私有节点 (local-nodes/private-nodes.yaml)

```yaml
proxies:
  # Vmess 节点
  - name: "🇭🇰 Hong Kong 01"
    type: vmess
    server: example.com
    port: 8080
    uuid: "your-uuid"
    alterId: 0
    cipher: auto

  # VLESS 节点
  - name: "🇯🇵 Japan 01"
    type: vless
    server: example.com
    port: 443
    uuid: "your-uuid"
    tls: true
    servername: "example.com"

  # Shadowsocks 节点
  - name: "🇸🇬 Singapore 01"
    type: ss
    server: example.com
    port: 8388
    cipher: chacha20-ietf-poly1305
    password: "your-password"

  # Trojan 节点
  - name: "🇺🇸 USA 01"
    type: trojan
    server: example.com
    port: 443
    password: "your-password"
    sni: example.com
```

**支持的协议：**
- Vmess
- VLESS
- Shadowsocks (SS)
- Shadowsocksr (SSR)
- Trojan
- Hysteria
- Wireguard
- HTTP/HTTPS
- SOCKS

### 3️⃣ 规则集 (rules/*.txt)

每个规则文件包含一行一条的域名或 IP 规则：

```
# 广告拦截规则 (rules/ads.txt)
DOMAIN,ads.google.com
DOMAIN-SUFFIX,doubleclick.net
DOMAIN-KEYWORD,tracking
IP-CIDR,192.168.1.0/24
```

**规则类型：**
- `DOMAIN` - 完全匹配域名
- `DOMAIN-SUFFIX` - 域名后缀匹配
- `DOMAIN-KEYWORD` - 域名关键字
- `IP-CIDR` - IP CIDR 匹配
- `IP-CIDR6` - IPv6 CIDR 匹配
- `GEOIP` - 地理位置匹配

**快速创建规则：**

```bash
# 从订阅规则列表导入
curl https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/chn.yaml \
    | grep -E '^  - ' | sed "s/  - //" > rules/china-domains.txt
```

### 4️⃣ 配置模板 (templates/base-config.yaml)

定义 Clash/Stash 的基础配置（端口、DNS、代理组等）。
脚本会自动合并节点和规则到此模板。

```yaml
proxies: []  # 自动填充节点

proxy-groups:
  - name: "🚀 Proxy"
    type: select
    proxies: ["♻️ Auto", "DIRECT"]
  
  - name: "♻️ Auto"
    type: url-test
    url: http://www.google.com/generate_204
    interval: 300

rule-providers: {}  # 自动填充规则集

rules:
  - DOMAIN-SUFFIX,google.com,🚀 Proxy
  - GEOIP,CN,DIRECT
  - MATCH,🚀 Proxy
```

## 🔄 自动化运维

### 方案一：Systemd Timer（推荐）

```bash
# 查看定时任务状态
sudo systemctl status sub-manager-update.timer

# 查看最近的执行日志
sudo journalctl -u sub-manager-update.service -n 50 -f

# 手动触发更新
sudo systemctl start sub-manager-update.service

# 修改定时时间（编辑 /etc/systemd/system/sub-manager-update.timer）
# OnCalendar=*-*-* 09:00:00  # 每天 9 点
# OnCalendar=*-*-* 09,18:00:00  # 每天 9 点和 18 点

# 重新加载配置
sudo systemctl daemon-reload
sudo systemctl restart sub-manager-update.timer
```

### 方案二：Crontab

```bash
# 编辑 crontab
sudo crontab -e

# 添加定时任务（每天 9:00 执行）
0 9 * * * /opt/sub-manager/cron-update.sh

# 常用时间表达式：
# 0 9 * * *        每天 9:00
# 0 */6 * * *      每 6 小时
# 0 0 * * 0        每周日 0:00
# 0 0 1 * *        每月 1 号 0:00
```

### 方案三：手动更新

```bash
# 随时触发更新
/opt/sub-manager/scripts/update.sh

# 或
python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml
```

## 🌐 Nginx 配置

部署脚本会自动创建配置，或手动创建：

```bash
sudo tee /etc/nginx/conf.d/sub-manager.conf <<'EOF'
server {
    listen 80;
    server_name your-domain.com;
    
    root /var/www/sub-manager;
    
    # 订阅文件访问
    location / {
        try_files $uri =404;
        add_header Content-Type text/yaml;
        add_header Content-Disposition "attachment; filename=merged.yaml";
    }
    
    # 健康检查
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    # 日志
    access_log /var/log/nginx/sub-manager-access.log combined;
    error_log /var/log/nginx/sub-manager-error.log warn;
}
EOF

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

**带 HTTPS 的配置（使用 Let's Encrypt）：**

```bash
# 安装 Certbot
sudo yum install certbot certbot-nginx -y

# 获取证书
sudo certbot certonly --standalone -d your-domain.com

# Nginx 配置中添加
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # ... 其他配置
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## 📲 客户端使用

### Clash (Windows/macOS/Linux)

1. 打开 Clash，进入 "Profile" 标签
2. 点击 "Edit" 或直接输入订阅 URL
3. 订阅链接：`http://your-vps-ip/merged.yaml` 或 `https://your-domain.com/merged.yaml`
4. 点击 "Download" 更新配置
5. 选择所需的代理组，开始使用

### Stash (iOS)

1. 打开 Stash 应用
2. 进入 "Subscriptions" 标签
3. 点击 "+" 添加新订阅
4. URL: `http://your-vps-ip/merged.yaml` 或 `https://your-domain.com/merged.yaml`
5. 选择更新频率（推荐每 6 小时）
6. 等待下载完成，选择配置应用

### Surge (iOS)

1. 打开 Surge 应用
2. 主菜单 → 配置 → 新建配置
3. 选择 "从URL导入"
4. 输入订阅链接
5. 选择更新间隔

### Quantumult X (iOS)

1. 打开 Quantumult X
2. 首页 → 右下角 ⚙️ → 订阅管理
3. 点击 "+" 添加
4. 输入订阅链接
5. 保存并更新

## 📊 监控和日志

### 查看日志

```bash
# 应用日志
tail -f /opt/sub-manager/logs/merge_subscriptions.log

# Cron 日志
tail -f /opt/sub-manager/logs/cron.log

# Nginx 访问日志
tail -f /var/log/nginx/sub-manager-access.log

# Nginx 错误日志
tail -f /var/log/nginx/sub-manager-error.log

# Systemd 日志（实时）
sudo journalctl -u sub-manager-update.service -f

# Systemd 日志（最后 50 行）
sudo journalctl -u sub-manager-update.service -n 50
```

### 监控脚本执行

```bash
# 检查备份文件
ls -lh /opt/sub-manager/backups/

# 查看最后的合并时间
stat /var/www/sub-manager/merged.yaml

# 检查输出文件大小
du -h /var/www/sub-manager/merged.yaml

# 统计节点数
grep "name:" /var/www/sub-manager/merged.yaml | wc -l
```

## 🔒 安全建议

### 1. 访问控制

```bash
# 限制 IP 访问
sudo nano /etc/nginx/conf.d/sub-manager.conf

# 添加到 server 块
location / {
    # 仅允许本地网络访问
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;
}
```

### 2. 隐藏真实 IP

如使用 Cloudflare 等 CDN，DNS 解析指向 CDN，真实 IP 隐藏。

### 3. 定期备份

```bash
# 备份脚本已包含，保留最近 10 个版本
# 手动备份
cp /var/www/sub-manager/merged.yaml \
   /opt/sub-manager/backups/merged_backup_$(date +%s).yaml
```

### 4. 敏感信息

- **勿在配置中硬编码密码** - 使用 `.env` 文件或环境变量
- **保护私有节点配置** - 限制文件权限
- **定期检查日志** - 发现异常访问

## 🐛 故障排查

### 问题 1：合并失败

```bash
# 检查 Python 版本
python3 --version  # 需要 3.6+

# 检查依赖
pip3 list | grep -E "pyyaml|requests"

# 运行脚本查看详细错误
python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml
```

### 问题 2：无法访问订阅

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 检查 Nginx 配置
sudo nginx -t

# 检查文件权限
ls -l /var/www/sub-manager/merged.yaml

# 测试访问
curl http://localhost/merged.yaml

# 检查防火墙
sudo firewall-cmd --list-all
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
```

### 问题 3：定时任务未执行

```bash
# 检查 Systemd 状态
sudo systemctl status sub-manager-update.timer

# 查看执行历史
sudo systemctl list-timers sub-manager-update.timer

# 检查 Crontab
sudo crontab -l

# 查看系统日志
sudo tail -f /var/log/cron
```

### 问题 4：节点无法连接

```bash
# 检查节点配置格式
yaml -c /var/www/sub-manager/merged.yaml

# 验证单个节点
grep -A5 "name:" /var/www/sub-manager/merged.yaml | head -20

# 查看远程订阅获取的节点
python3 -c "
import yaml
with open('/var/www/sub-manager/merged.yaml') as f:
    data = yaml.safe_load(f)
    for proxy in data['proxies'][:5]:
        print(f\"{proxy['name']}: {proxy['type']}\")
"
```

## 📚 高级用法

### 自定义合并逻辑

编辑 `scripts/merge_subscriptions.py` 的 `_merge_configurations` 方法：

```python
def _merge_configurations(self, ...):
    # 添加自定义过滤逻辑
    all_nodes = [n for n in all_nodes if n.get('server') not in blacklist]
    
    # 添加自定义排序
    all_nodes.sort(key=lambda x: x.get('name', ''))
    
    # 其他自定义逻辑...
```

### 多个输出配置

创建多个脚本实例，输出不同的配置：

```bash
# 仅本地节点
python3 merge_subscriptions.py config/config.yaml output/local.yaml --local-only

# 仅远程节点
python3 merge_subscriptions.py config/config.yaml output/remote.yaml --remote-only
```

### 与 Git 集成

自动提交变更到 Git：

```bash
cd /opt/sub-manager
git add -A
git commit -m "Auto update: $(date '+%Y-%m-%d %H:%M:%S')"
git push origin main
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## ❓ FAQ

**Q: 订阅文件多久更新一次？**
A: 默认每天 9:00 自动更新，可在配置中修改。

**Q: 支持多少个节点？**
A: 无限制，但建议不超过 1000 个以保证性能。

**Q: 可以从多个远程源合并吗？**
A: 可以，在 `remote_subscriptions` 中添加多个 URL 即可。

**Q: 如何防止节点泄露？**
A: 建议：
1. 使用 HTTPS
2. 限制 IP 访问
3. 定期更新远程服务
4. 监控访问日志

**Q: 脚本支持哪些操作系统？**
A: 
- ✅ CentOS 7/8
- ✅ Ubuntu 18.04+
- ✅ Debian 10+
- ✅ RHEL 7/8

**Q: 如何恢复之前的配置版本？**
A: 备份文件保存在 `/opt/sub-manager/backups/`，直接恢复即可：
```bash
cp /opt/sub-manager/backups/merged_YYYYMMDD_HHMMSS.yaml \
   /var/www/sub-manager/merged.yaml
```

---

**最后更新：2026-01-19**  
**作者：SubHelper Team**  
**支持：提交 Issue 或联系技术支持**
