#!/bin/bash
# 快速更新脚本 - 可直接调用或由 Cron 调用

INSTALL_PATH="/opt/sub-manager"
WEB_ROOT="/var/www/sub-manager"

# 日志文件
LOG_FILE="${INSTALL_PATH}/logs/update.log"

# 记录时间戳
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}

log_message "========== 开始更新 =========="

try_update() {
    cd "${INSTALL_PATH}" || exit 1
    
    log_message "执行合并..."
    python3 "${INSTALL_PATH}/scripts/merge_subscriptions.py" \
        "${INSTALL_PATH}/config/config.yaml" \
        "${WEB_ROOT}/merged.yaml" >> "${LOG_FILE}" 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "✓ 合并成功"
        
        # 创建备份
        BACKUP_DIR="${INSTALL_PATH}/backups"
        TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
        cp "${WEB_ROOT}/merged.yaml" "${BACKUP_DIR}/merged_${TIMESTAMP}.yaml"
        
        # 保留最近 10 个备份
        ls -t "${BACKUP_DIR}"/merged_*.yaml | tail -n +11 | xargs rm -f 2>/dev/null || true
        
        log_message "备份已保存"
        return 0
    else
        log_message "✗ 合并失败，请检查日志"
        return 1
    fi
}

try_update
log_message "========== 更新结束 =========="
