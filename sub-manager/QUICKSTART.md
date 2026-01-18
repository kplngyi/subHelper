# 快速参考指南

## 🚀 5 分钟快速开始

### 本地环境
```bash
cd sub-manager

# 安装依赖
pip3 install pyyaml requests

# 测试运行
bash test.sh

# 查看输出
cat test-output/merged.yaml | head -20
```

### CentOS VPS 部署
```bash
# 上传文件
scp -r sub-manager/ root@YOUR_VPS:/root/

# 部署
ssh root@YOUR_VPS "cd /root/sub-manager && chmod +x deploy.sh && sudo ./deploy.sh"

# 访问
curl http://YOUR_VPS_IP/merged.yaml
```

## 📝 配置检查清单

- [ ] `config/config.yaml` - 已设置本地节点路径
- [ ] `config/config.yaml` - 已添加远程订阅 URL
- [ ] `local-nodes/private-nodes.yaml` - 已添加本地节点
- [ ] `rules/*.txt` - 已配置规则集
- [ ] `templates/base-config.yaml` - 已自定义基础配置

## 🔧 常见操作

### 添加远程订阅
```yaml
# 编辑 config/config.yaml
remote_subscriptions:
  - name: "My Subscription"
    url: "https://example.com/sub"
    enabled: true
```

### 添加本地节点
```yaml
# 编辑或创建 local-nodes/your-nodes.yaml
proxies:
  - name: "🇭🇰 HK 01"
    type: vmess
    server: example.com
    port: 8080
    uuid: "your-uuid"
    alterId: 0
```

### 创建新规则
```bash
# 新建规则文件
echo "DOMAIN,example.com" > rules/custom-rules.txt

# 下次合并时自动包含
```

### 手动运行合并
```bash
# CentOS VPS 上
python3 /opt/sub-manager/scripts/merge_subscriptions.py \
    /opt/sub-manager/config/config.yaml \
    /var/www/sub-manager/merged.yaml

# 或使用更新脚本
/opt/sub-manager/scripts/update.sh
```

### 查看定时任务
```bash
# Systemd
sudo systemctl status sub-manager-update.timer
sudo journalctl -u sub-manager-update.service -f

# Crontab
sudo crontab -l
tail -f /var/log/cron
```

## 📊 文件说明

| 文件 | 用途 |
|------|------|
| `merge_subscriptions.py` | 核心合并脚本 |
| `config/config.yaml` | 主配置文件 |
| `local-nodes/*.yaml` | 本地私有节点 |
| `rules/*.txt` | 规则集 |
| `templates/base-config.yaml` | Clash 配置模板 |
| `deploy.sh` | CentOS 自动化部署 |
| `update.sh` | 手动更新脚本 |
| `test.sh` | 本地测试脚本 |

## 🌍 订阅 URL 示例

```
# 本地 (macOS/Linux)
file:///Users/you/sub-manager/test-output/merged.yaml

# VPS HTTP
http://your-vps-ip/merged.yaml

# VPS HTTPS (需配置 SSL)
https://your-domain.com/merged.yaml

# 代理 (Cloudflare)
https://cdn.example.com/merged.yaml
```

## 🔐 安全清单

- [ ] 设置限制 IP 访问（如需要）
- [ ] 配置 HTTPS/SSL 证书
- [ ] 定期查看访问日志
- [ ] 备份重要配置
- [ ] 设置强密码登录 VPS
- [ ] 禁用 root 登录（可选）

## 📞 故障排查快速表

| 问题 | 解决方案 |
|------|---------|
| 合并失败 | `python3 script.py config.yaml output.yaml` 查看错误 |
| 无法访问订阅 | `sudo nginx -t` && `curl http://localhost/health` |
| 定时任务未运行 | `sudo systemctl status sub-manager-update.timer` |
| 节点无法连接 | 验证 YAML 格式：`python3 -c "import yaml; yaml.safe_load(open('merged.yaml'))"` |
| 权限问题 | `sudo chown -R nobody:nobody /opt/sub-manager` |

## 💡 进阶提示

### 备份和恢复
```bash
# 列出备份
ls -lh /opt/sub-manager/backups/

# 恢复旧版本
cp /opt/sub-manager/backups/merged_20260119_090000.yaml \
   /var/www/sub-manager/merged.yaml
```

### 性能优化
```bash
# 限制节点数量（编辑 merge_subscriptions.py）
all_nodes = all_nodes[:500]  # 仅保留前 500 个

# 开启 Gzip 压缩（Nginx）
gzip on;
gzip_types text/yaml application/x-yaml;
```

### 监控面板
```bash
# 简单的实时监控
watch -n 60 "tail -5 /opt/sub-manager/logs/merge_subscriptions.log"

# 或定期检查
sudo /root/sub-manager/healthcheck.sh
```

## 📚 更多资源

- Clash 文档: https://clash.verge.dev/
- Stash 使用: https://www.stashapp.com/
- YAML 规范: https://yaml.org/
- 规则集: https://github.com/ACL4SSR/ACL4SSR

---

**需要帮助？运行 `bash healthcheck.sh` 诊断问题**
