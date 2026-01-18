#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
订阅节点合并管理工具
支持本地私有节点和远程订阅的自动合并、去重、美化
输出标准 YAML 格式，兼容 Clash 和 Stash
"""

import os
import sys
import yaml
import json
import hashlib
import requests
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional
from urllib.parse import urlparse
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('merge_subscriptions.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class SubscriptionMerger:
    """订阅管理器：合并、去重、美化节点配置"""
    
    def __init__(self, config_path: str):
        """初始化订阅管理器"""
        self.config_path = Path(config_path)
        self.config = self._load_config()
        self.local_nodes = []
        self.remote_nodes = []
        self.merged_config = {}
        
    def _load_config(self) -> Dict[str, Any]:
        """加载配置文件"""
        if not self.config_path.exists():
            logger.error(f"配置文件不存在: {self.config_path}")
            sys.exit(1)
            
        with open(self.config_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        logger.info(f"配置文件加载成功")
        return config
    
    def _load_local_nodes(self) -> List[Dict[str, Any]]:
        """加载本地私有节点"""
        local_dir = Path(self.config['local_nodes_path'])
        if not local_dir.exists():
            logger.warning(f"本地节点目录不存在: {local_dir}")
            return []
        
        nodes = []
        for yaml_file in local_dir.glob('*.yaml'):
            try:
                with open(yaml_file, 'r', encoding='utf-8') as f:
                    data = yaml.safe_load(f)
                    if data and 'proxies' in data:
                        logger.info(f"加载本地节点: {yaml_file.name}")
                        nodes.extend(data['proxies'])
            except Exception as e:
                logger.error(f"加载本地节点失败 {yaml_file}: {e}")
        
        logger.info(f"本地节点总数: {len(nodes)}")
        return nodes
    
    def _fetch_remote_subscription(self, url: str) -> List[Dict[str, Any]]:
        """获取远程订阅节点"""
        try:
            logger.info(f"正在获取远程订阅: {url}")
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=30)
            response.raise_for_status()
            
            # 尝试解析为 YAML
            try:
                data = yaml.safe_load(response.text)
                if data and 'proxies' in data:
                    logger.info(f"成功获取远程订阅，节点数: {len(data['proxies'])}")
                    return data['proxies']
            except:
                pass
            
            # 如果不是 YAML，可能是 Base64 编码的
            import base64
            try:
                decoded = base64.b64decode(response.text).decode('utf-8')
                data = yaml.safe_load(decoded)
                if data and 'proxies' in data:
                    logger.info(f"成功解析 Base64 订阅，节点数: {len(data['proxies'])}")
                    return data['proxies']
            except:
                pass
            
            logger.warning(f"无法解析远程订阅: {url}")
            return []
            
        except requests.RequestException as e:
            logger.error(f"获取远程订阅失败 {url}: {e}")
            return []
    
    def _load_remote_subscriptions(self) -> List[Dict[str, Any]]:
        """加载所有远程订阅"""
        nodes = []
        
        for subscription in self.config.get('remote_subscriptions', []):
            remote_nodes = self._fetch_remote_subscription(subscription['url'])
            nodes.extend(remote_nodes)
        
        logger.info(f"远程节点总数: {len(nodes)}")
        return nodes
    
    def _deduplicate_nodes(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """去重节点（基于名称和服务器地址）"""
        seen = set()
        unique_nodes = []
        
        for node in nodes:
            # 使用名称和服务器地址作为唯一标识
            key = (node.get('name', ''), node.get('server', ''), node.get('port', ''))
            key_hash = hashlib.md5(str(key).encode()).hexdigest()
            
            if key_hash not in seen:
                seen.add(key_hash)
                unique_nodes.append(node)
        
        removed = len(nodes) - len(unique_nodes)
        logger.info(f"去重完成，移除 {removed} 个重复节点，保留 {len(unique_nodes)} 个")
        return unique_nodes
    
    def _beautify_node_names(self, nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """美化节点名称"""
        beautified = []
        
        for node in nodes:
            name = node.get('name', '')
            
            # 移除不必要的符号和重复信息
            name = name.strip()
            # 移除流量限制信息
            name = name.split('|')[0].strip()
            # 统一格式：地区-节点类型-编号
            
            node['name'] = name
            beautified.append(node)
        
        logger.info("节点名称美化完成")
        return beautified
    
    def _load_rules(self) -> Dict[str, List[str]]:
        """加载规则集"""
        rules = {}
        rules_dir = Path(self.config['rules_path'])
        
        if not rules_dir.exists():
            logger.warning(f"规则目录不存在: {rules_dir}")
            return rules
        
        for rule_file in rules_dir.glob('*.txt'):
            try:
                with open(rule_file, 'r', encoding='utf-8') as f:
                    rule_name = rule_file.stem
                    rules[rule_name] = [line.strip() for line in f if line.strip() and not line.startswith('#')]
                    logger.info(f"加载规则集: {rule_name} ({len(rules[rule_name])} 条)")
            except Exception as e:
                logger.error(f"加载规则文件失败 {rule_file}: {e}")
        
        return rules
    
    def _merge_configurations(self, 
                             local_nodes: List[Dict[str, Any]], 
                             remote_nodes: List[Dict[str, Any]],
                             rules: Dict[str, List[str]]) -> Dict[str, Any]:
        """合并配置"""
        # 合并所有节点
        all_nodes = local_nodes + remote_nodes
        all_nodes = self._deduplicate_nodes(all_nodes)
        all_nodes = self._beautify_node_names(all_nodes)
        
        # 加载基础配置模板
        template_path = Path(self.config['template_path'])
        with open(template_path, 'r', encoding='utf-8') as f:
            merged = yaml.safe_load(f)
        
        # 更新节点列表
        merged['proxies'] = all_nodes
        
        # 合并规则集
        if 'rule-providers' not in merged:
            merged['rule-providers'] = {}
        
        for rule_name, rule_list in rules.items():
            merged['rule-providers'][rule_name] = {
                'type': 'inline',
                'behavior': 'classical',
                'rules': rule_list
            }
        
        # 更新规则链（rule）
        if 'rules' not in merged:
            merged['rules'] = []
        
        logger.info(f"最终节点数: {len(merged['proxies'])}")
        logger.info(f"规则集数: {len(rules)}")
        
        return merged
    
    def merge(self) -> Dict[str, Any]:
        """执行合并操作"""
        try:
            logger.info("=" * 50)
            logger.info("开始合并订阅")
            logger.info("=" * 50)
            
            # 加载各种源
            self.local_nodes = self._load_local_nodes()
            self.remote_nodes = self._load_remote_subscriptions()
            rules = self._load_rules()
            
            # 执行合并
            self.merged_config = self._merge_configurations(
                self.local_nodes,
                self.remote_nodes,
                rules
            )
            
            logger.info("=" * 50)
            logger.info("合并完成")
            logger.info("=" * 50)
            
            return self.merged_config
            
        except Exception as e:
            logger.error(f"合并过程出错: {e}", exc_info=True)
            sys.exit(1)
    
    def save(self, output_path: str):
        """保存合并后的配置"""
        try:
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_file, 'w', encoding='utf-8') as f:
                yaml.dump(self.merged_config, f, 
                         default_flow_style=False,
                         allow_unicode=True,
                         sort_keys=False)
            
            logger.info(f"配置已保存: {output_file}")
            logger.info(f"文件大小: {output_file.stat().st_size / 1024:.2f} KB")
            
        except Exception as e:
            logger.error(f"保存配置失败: {e}")
            sys.exit(1)


def main():
    """主程序"""
    if len(sys.argv) < 2:
        print("使用方法: python merge_subscriptions.py <config.yaml> [output.yaml]")
        sys.exit(1)
    
    config_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else 'merged.yaml'
    
    merger = SubscriptionMerger(config_path)
    merger.merge()
    merger.save(output_path)
    
    logger.info("任务完成！")


if __name__ == '__main__':
    main()
