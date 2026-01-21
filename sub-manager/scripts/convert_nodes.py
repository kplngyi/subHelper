#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将local-nodes目录下的txt文件转换为yaml格式
"""

import os
import sys
import re
import base64
import yaml
from urllib.parse import urlparse, parse_qs, unquote

def parse_ss_url(url):
    """解析Shadowsocks URL"""
    try:
        # ss://base64编码@服务器:端口#备注
        match = re.match(r'ss://([^@]+)@([^:]+):(\d+)(?:\?([^#]+))?#(.+)', url)
        if not match:
            return None
        
        encoded_part = match.group(1)
        server = match.group(2)
        port = int(match.group(3))
        query_string = match.group(4) or ''
        name = unquote(match.group(5))
        
        # 解码method:password
        decoded = base64.urlsafe_b64decode(encoded_part + '==').decode('utf-8')
        method, password = decoded.split(':', 1)
        
        # 解析查询参数
        query_params = {}
        if query_string:
            query_params = dict(param.split('=') for param in query_string.split('&'))
        
        node = {
            'name': name,
            'type': 'ss',
            'server': server,
            'port': port,
            'cipher': method,
            'password': password,
            'udp': True
        }
        
        return node
    except Exception as e:
        print(f"解析SS节点失败: {url[:50]}... 错误: {e}", file=sys.stderr)
        return None

def parse_vless_url(url):
    """解析VLESS URL"""
    try:
        # vless://uuid@服务器:端口?参数#备注
        match = re.match(r'vless://([^@]+)@([^:]+):(\d+)\?([^#]+)#(.+)', url)
        if not match:
            return None
        
        uuid = match.group(1)
        server = match.group(2)
        port = int(match.group(3))
        query_string = match.group(4)
        name = unquote(match.group(5))
        
        # 解析查询参数
        params = {}
        for param in query_string.split('&'):
            if '=' in param:
                key, value = param.split('=', 1)
                params[key] = unquote(value)
        
        node = {
            'name': name,
            'type': 'vless',
            'server': server,
            'port': port,
            'uuid': uuid,
            'udp': True,
        }
        
        # 处理network
        if params.get('type'):
            node['network'] = params['type']
        
        # 处理encryption
        if params.get('encryption') and params['encryption'] != 'none':
            node['cipher'] = params['encryption']
        
        # 处理TLS/Reality
        if params.get('security'):
            security = params['security']
            if security == 'reality':
                node['tls'] = True
                node['servername'] = params.get('sni', '')
                
                reality_opts = {}
                if params.get('pbk'):
                    reality_opts['public-key'] = params['pbk']
                if params.get('sid'):
                    reality_opts['short-id'] = params['sid']
                # 处理spx (path)
                if params.get('spx'):
                    reality_opts['spider-x'] = params['spx']    
                if reality_opts:
                    node['reality-opts'] = reality_opts
                
                if params.get('fp'):
                    node['client-fingerprint'] = params['fp']
            elif security == 'tls':
                node['tls'] = True
                if params.get('sni'):
                    node['servername'] = params['sni']
        
        # 处理flow
        if params.get('flow'):
            node['flow'] = params['flow']
        
        
        return node
    except Exception as e:
        print(f"解析VLESS节点失败: {url[:50]}... 错误: {e}", file=sys.stderr)
        return None

def parse_vmess_url(url):
    """解析VMess URL"""
    try:
        # vmess://base64编码的JSON
        encoded = url.replace('vmess://', '')
        decoded = base64.urlsafe_b64decode(encoded + '==').decode('utf-8')
        config = eval(decoded)  # 或使用json.loads
        
        node = {
            'name': config.get('ps', 'VMess Node'),
            'type': 'vmess',
            'server': config.get('add'),
            'port': int(config.get('port', 443)),
            'uuid': config.get('id'),
            'alterId': int(config.get('aid', 0)),
            'cipher': config.get('scy', 'auto'),
            'udp': True,
        }
        
        if config.get('tls') == 'tls':
            node['tls'] = True
        
        if config.get('net'):
            node['network'] = config['net']
        
        return node
    except Exception as e:
        print(f"解析VMess节点失败: {url[:50]}... 错误: {e}", file=sys.stderr)
        return None

def convert_txt_to_yaml(txt_file, yaml_file):
    """将txt文件转换为yaml文件"""
    if not os.path.exists(txt_file):
        print(f"错误: 文件不存在 {txt_file}", file=sys.stderr)
        return False
    
    # 读取txt文件
    with open(txt_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 解析节点
    proxies = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        
        node = None
        if line.startswith('ss://'):
            node = parse_ss_url(line)
        elif line.startswith('vless://'):
            node = parse_vless_url(line)
        elif line.startswith('vmess://'):
            node = parse_vmess_url(line)
        
        if node:
            proxies.append(node)
    
    if not proxies:
        print("警告: 没有解析到任何节点", file=sys.stderr)
        return False
    
    # 构建yaml数据
    yaml_data = {
        '# 本地节点配置': None,
        'proxies': proxies
    }
    
    # 写入yaml文件
    with open(yaml_file, 'w', encoding='utf-8') as f:
        f.write("# 本地节点配置\n\n")
        yaml.dump({'proxies': proxies}, f, 
                  allow_unicode=True, 
                  default_flow_style=False,
                  sort_keys=False,
                  indent=2)
    
    print(f"成功转换 {len(proxies)} 个节点")
    print(f"输出文件: {yaml_file}")
    return True

def main():
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_dir = os.path.dirname(script_dir)
    
    # 设置文件路径
    local_nodes_dir = os.path.join(base_dir, 'local-nodes')
    txt_file = os.path.join(local_nodes_dir, 'private-nodes.txt')
    yaml_file = os.path.join(local_nodes_dir, 'private-nodes.yaml')
    
    print(f"输入文件: {txt_file}")
    print(f"输出文件: {yaml_file}")
    print("-" * 50)
    
    # 转换
    success = convert_txt_to_yaml(txt_file, yaml_file)
    
    if success:
        print("-" * 50)
        print("转换完成！")
        return 0
    else:
        print("转换失败！")
        return 1

if __name__ == '__main__':
    sys.exit(main())
