#!/bin/bash
# 索引和快速启动脚本

clear

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       CentOS 节点订阅自动化管理系统 - 项目索引              ║"
echo "║                   Version 1.0.0 (2026-01-19)                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 色彩定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_menu() {
    echo -e "${CYAN}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}快速导航${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}📖 文档和指南${NC}"
    echo "  1. README.md          - 完整功能说明（600+ 行）"
    echo "  2. INSTALL.md         - 安装部署指南（450+ 行）"
    echo "  3. QUICKSTART.md      - 快速参考（200+ 行）"
    echo "  4. PROJECT_SUMMARY.md - 项目完成总结"
    echo "  5. CHANGELOG.md       - 版本变更日志"
    echo ""
    
    echo -e "${YELLOW}🚀 快速开始${NC}"
    echo "  6. 本地测试           - bash test.sh"
    echo "  7. 系统诊断           - bash healthcheck.sh"
    echo "  8. 部署到 VPS         - bash deploy.sh（需 root）"
    echo "  9. 设置 HTTPS/SSL     - bash setup-ssl.sh（需 root）"
    echo ""
    
    echo -e "${YELLOW}📂 项目文件${NC}"
    echo " 10. 打开脚本目录       - scripts/"
    echo " 11. 打开配置目录       - config/"
    echo " 12. 打开规则集目录     - rules/"
    echo " 13. 打开本地节点目录   - local-nodes/"
    echo " 14. 打开输出目录       - output/"
    echo ""
    
    echo -e "${YELLOW}⚙️  常用命令${NC}"
    echo " 15. 查看文件结构"
    echo " 16. 查看核心脚本"
    echo " 17. 查看配置示例"
    echo " 18. 手动运行合并"
    echo ""
    
    echo -e "${YELLOW}🔧 工具${NC}"
    echo " 19. 显示帮助信息"
    echo "  0. 退出菜单"
    echo ""
}

# 获取项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 显示选择菜单
while true; do
    show_menu
    
    echo -n "请选择 (0-19): "
    read choice
    
    case $choice in
        1)
            echo ""
            echo -e "${CYAN}打开 README.md...${NC}"
            less "$PROJECT_DIR/README.md"
            ;;
        2)
            echo ""
            echo -e "${CYAN}打开 INSTALL.md...${NC}"
            less "$PROJECT_DIR/INSTALL.md"
            ;;
        3)
            echo ""
            echo -e "${CYAN}打开 QUICKSTART.md...${NC}"
            less "$PROJECT_DIR/QUICKSTART.md"
            ;;
        4)
            echo ""
            echo -e "${CYAN}打开 PROJECT_SUMMARY.md...${NC}"
            less "$PROJECT_DIR/PROJECT_SUMMARY.md"
            ;;
        5)
            echo ""
            echo -e "${CYAN}打开 CHANGELOG.md...${NC}"
            less "$PROJECT_DIR/CHANGELOG.md"
            ;;
        6)
            echo ""
            echo -e "${GREEN}运行本地测试...${NC}"
            bash "$PROJECT_DIR/test.sh"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        7)
            echo ""
            echo -e "${GREEN}运行系统诊断...${NC}"
            bash "$PROJECT_DIR/healthcheck.sh"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        8)
            echo ""
            echo -e "${YELLOW}注意：部署脚本需要 root 权限${NC}"
            echo -e "${YELLOW}请在 CentOS VPS 上运行以下命令：${NC}"
            echo "  sudo bash $PROJECT_DIR/deploy.sh"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        9)
            echo ""
            echo -e "${YELLOW}注意：SSL 设置脚本需要 root 权限${NC}"
            echo -e "${YELLOW}请在 CentOS VPS 上运行以下命令：${NC}"
            echo "  sudo bash $PROJECT_DIR/setup-ssl.sh"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        10)
            echo ""
            echo -e "${CYAN}脚本文件列表：${NC}"
            ls -lah "$PROJECT_DIR/scripts/"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        11)
            echo ""
            echo -e "${CYAN}配置文件列表：${NC}"
            ls -lah "$PROJECT_DIR/config/"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        12)
            echo ""
            echo -e "${CYAN}规则集文件列表：${NC}"
            ls -lah "$PROJECT_DIR/rules/"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        13)
            echo ""
            echo -e "${CYAN}本地节点文件列表：${NC}"
            ls -lah "$PROJECT_DIR/local-nodes/"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        14)
            echo ""
            echo -e "${CYAN}输出目录列表：${NC}"
            ls -lah "$PROJECT_DIR/output/"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        15)
            echo ""
            echo -e "${CYAN}项目文件结构：${NC}"
            tree "$PROJECT_DIR" -L 2 -I '__pycache__|*.pyc' 2>/dev/null || \
            find "$PROJECT_DIR" -maxdepth 2 -type f | sort
            echo ""
            read -p "按 Enter 继续..."
            ;;
        16)
            echo ""
            echo -e "${CYAN}核心脚本：merge_subscriptions.py${NC}"
            echo "位置：scripts/merge_subscriptions.py"
            echo ""
            echo -e "${GREEN}主要函数和类：${NC}"
            grep -E "^class|^def " "$PROJECT_DIR/scripts/merge_subscriptions.py" | head -20
            echo ""
            echo "查看完整代码? (y/n): "
            read view_full
            if [ "$view_full" = "y" ]; then
                less "$PROJECT_DIR/scripts/merge_subscriptions.py"
            fi
            ;;
        17)
            echo ""
            echo -e "${CYAN}配置示例：${NC}"
            echo ""
            echo "1. config/config.yaml"
            echo "─────────────────────"
            head -15 "$PROJECT_DIR/config/config.yaml"
            echo ""
            echo "2. templates/base-config.yaml (前 20 行)"
            echo "──────────────────────────────────"
            head -20 "$PROJECT_DIR/templates/base-config.yaml"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        18)
            echo ""
            echo -e "${CYAN}运行合并脚本...${NC}"
            echo "命令: python3 scripts/merge_subscriptions.py config/config.yaml output/merged.yaml"
            echo ""
            python3 "$PROJECT_DIR/scripts/merge_subscriptions.py" \
                "$PROJECT_DIR/config/config.yaml" \
                "$PROJECT_DIR/output/merged.yaml"
            echo ""
            echo "输出文件: $PROJECT_DIR/output/merged.yaml"
            ls -lh "$PROJECT_DIR/output/merged.yaml" 2>/dev/null && echo "✓ 合并成功"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        19)
            echo ""
            echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
            echo -e "${BLUE}║            项目快速帮助                              ║${NC}"
            echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${CYAN}本项目目录：${NC}"
            echo "  $PROJECT_DIR"
            echo ""
            echo -e "${CYAN}关键文件：${NC}"
            echo "  • merge_subscriptions.py - 核心合并脚本"
            echo "  • config/config.yaml     - 主配置文件"
            echo "  • README.md              - 完整文档"
            echo "  • INSTALL.md             - 安装指南"
            echo "  • test.sh                - 本地测试"
            echo "  • healthcheck.sh         - 系统诊断"
            echo "  • deploy.sh              - VPS 部署"
            echo ""
            echo -e "${CYAN}快速命令：${NC}"
            echo "  本地测试：              bash test.sh"
            echo "  系统检查：              bash healthcheck.sh"
            echo "  手动合并：              python3 scripts/merge_subscriptions.py config/config.yaml output/merged.yaml"
            echo "  查看配置：              cat config/config.yaml"
            echo "  查看输出：              cat output/merged.yaml"
            echo ""
            echo -e "${CYAN}CentOS 部署：${NC}"
            echo "  1. 上传文件到 VPS"
            echo "  2. ssh 连接到 VPS"
            echo "  3. 运行：sudo bash deploy.sh"
            echo ""
            echo -e "${CYAN}官方文档：${NC}"
            echo "  README.md    - 超过 600 行的完整文档"
            echo "  INSTALL.md   - 详细的安装和部署步骤"
            echo "  QUICKSTART.md - 快速参考和常见操作"
            echo ""
            read -p "按 Enter 继续..."
            ;;
        0)
            echo ""
            echo -e "${GREEN}感谢使用，再见！ 👋${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重试${NC}"
            read -p "按 Enter 继续..."
            ;;
    esac
    
    clear
done
