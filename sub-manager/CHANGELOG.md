# 变更日志

## [1.0.0] - 2026-01-19

### 功能
- ✨ 核心合并脚本 - 自动合并本地和远程节点
- ✨ 去重功能 - 智能识别和移除重复节点
- ✨ 节点美化 - 规范化节点名称
- ✨ 规则集管理 - 支持灵活的规则集定制和合并
- ✨ YAML 输出 - 兼容 Clash 和 Stash
- ✨ Nginx 配置 - HTTP/HTTPS 服务
- ✨ 自动化部署 - CentOS 一键部署脚本
- ✨ 定时任务 - Systemd Timer 和 Crontab 支持
- ✨ 日志轮转 - 自动的日志管理

### 文档
- 📖 完整的 README.md
- 📖 安装和使用指南 (INSTALL.md)
- 📖 快速参考 (QUICKSTART.md)
- 📖 故障排查指南
- 📖 API 文档

### 脚本
- `merge_subscriptions.py` - 核心合并脚本
- `deploy.sh` - 自动化部署脚本
- `update.sh` - 手动更新脚本
- `test.sh` - 本地测试脚本
- `healthcheck.sh` - 系统健康检查
- `setup-ssl.sh` - SSL 证书配置

### 配置示例
- `config/config.yaml` - 主配置文件模板
- `templates/base-config.yaml` - Clash 基础配置模板
- `local-nodes/private-nodes.yaml` - 本地节点示例
- `rules/ads.txt` - 广告拦截规则示例
- `rules/china-sites.txt` - 国内网站规则示例

### 已知限制
- 仅支持 CentOS 系统（其他 Linux 发行版可能需要调整）
- Base64 编码的订阅支持有限
- 不支持二进制编码的订阅格式

## 规划的功能 (v2.0.0+)

### 功能增强
- [ ] Web UI 管理面板
- [ ] 实时订阅测试和验证
- [ ] 节点延迟测试
- [ ] 智能节点选择
- [ ] 流量统计
- [ ] 节点历史记录
- [ ] 配置版本控制
- [ ] 多用户支持

### 协议扩展
- [ ] VLESS 协议支持
- [ ] Reality 协议支持
- [ ] Tuic 协议支持
- [ ] 自定义协议转换

### 集成增强
- [ ] 数据库支持 (SQLite/PostgreSQL)
- [ ] Redis 缓存
- [ ] Webhook 通知
- [ ] 邮件报告
- [ ] Discord/Telegram 通知
- [ ] GitHub 集成

### 部署选项
- [ ] Docker 容器化
- [ ] Kubernetes 支持
- [ ] 一键 Heroku 部署
- [ ] AWS/阿里云 镜像

---

## 更新日志详情

### 初始版本 (v1.0.0) 改进点

**相比原始需求的实现：**

✅ 节点来源聚合
- 完整实现本地节点和远程订阅合并
- 支持多个远程订阅源
- 自动处理重复节点

✅ 配置兼容性
- 标准 YAML 输出格式
- Clash 完全兼容
- Stash iOS 兼容
- Surge、Quantumult X 预留支持

✅ 规则自定义
- 独立的规则集文件管理
- 支持多种规则类型
- 自动规则合并

✅ 私有化分发
- 完全自建 Nginx 服务
- 支持 HTTP/HTTPS
- 无第三方依赖

✅ 自动化运维
- Systemd Timer 自动更新
- Crontab 备选方案
- 自动备份
- 日志轮转
- 健康检查脚本

---

**项目维护：** 2026 年
**贡献者：** SubHelper Team
