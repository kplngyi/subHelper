#!/bin/bash
# 本地快速测试脚本

set -e

echo "=========================================="
echo "  订阅管理系统 - 本地测试"
echo "=========================================="
echo ""

# 检查 Python
echo "✓ 检查 Python 环境..."
python3 --version

# 检查依赖
echo "✓ 检查依赖..."
pip3 list | grep -E "pyyaml|requests" || {
    echo "⚠️  缺少依赖，正在安装..."
    pip3 install pyyaml requests
}

echo ""
echo "=========================================="
echo "  运行测试合并"
echo "=========================================="
echo ""

# 确定脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 创建本地测试输出目录
mkdir -p "${SCRIPT_DIR}/test-output"

# 运行合并脚本
echo "执行脚本..."
python3 "${SCRIPT_DIR}/scripts/merge_subscriptions.py" \
    "${SCRIPT_DIR}/config/config.yaml" \
    "${SCRIPT_DIR}/test-output/merged.yaml"

echo ""
echo "=========================================="
echo "  测试结果"
echo "=========================================="
echo ""

OUTPUT_FILE="${SCRIPT_DIR}/test-output/merged.yaml"

if [ -f "$OUTPUT_FILE" ]; then
    echo "✓ 输出文件已创建"
    echo "  路径: $OUTPUT_FILE"
    echo "  大小: $(du -h "$OUTPUT_FILE" | cut -f1)"
    
    echo ""
    echo "节点统计:"
    node_count=$(grep -c "^  - name:" "$OUTPUT_FILE" || echo "0")
    echo "  总节点数: $node_count"
    
    echo ""
    echo "配置验证:"
    # 尝试解析 YAML
    python3 -c "
import yaml
try:
    with open('$OUTPUT_FILE', 'r') as f:
        data = yaml.safe_load(f)
    print('  ✓ YAML 格式正确')
    print(f'  ✓ 代理组数: {len(data.get(\"proxy-groups\", []))}')
    print(f'  ✓ 节点数: {len(data.get(\"proxies\", []))}')
    print(f'  ✓ 规则数: {len(data.get(\"rules\", []))}')
except Exception as e:
    print(f'  ✗ YAML 格式错误: {e}')
" || true
    
    echo ""
    echo "前 5 个节点样本:"
    grep -A2 "^  - name:" "$OUTPUT_FILE" | head -15 || true
    
else
    echo "✗ 输出文件创建失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "  测试完成"
echo "=========================================="
echo ""
echo "💡 提示："
echo "1. 查看完整输出: cat ${SCRIPT_DIR}/test-output/merged.yaml"
echo "2. 配置订阅 URL: http://your-vps-ip/merged.yaml"
echo "3. 查看日志: tail -f ${SCRIPT_DIR}/scripts/merge_subscriptions.log"
echo ""
