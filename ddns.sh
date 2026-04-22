#!/bin/bash
set -euo pipefail

# 变量定义
CONFIG_DIR="/etc/cloudflare-ddns"
CONFIG_FILE="$CONFIG_DIR/config.ini"

echo "========= Cloudflare DDNS 交互配置 ========="

# 1. 检查并安装依赖
echo "[1/4] 检查 cloudflare-ddns 安装状态..."
if ! command -v cloudflare-ddns &> /dev/null; then
    echo "未检测到 cloudflare-ddns，正在安装..."
    apt-get update
    apt-get install cloudflare-ddns -y
else
    echo "cloudflare-ddns 已安装。"
fi

# 2. 交互式输入配置
read -p "请输入 Cloudflare API Token: " CF_API_TOKEN
if [ -z "$CF_API_TOKEN" ]; then echo "错误: API Token 不能为空"; exit 1; fi

read -p "请输入 DNS 记录名称 (例如 sub.example.com): " CF_RECORD_NAME
if [ -z "$CF_RECORD_NAME" ]; then echo "错误: 记录名称不能为空"; exit 1; fi

echo -e "\n--- 配置确认 ---"
echo "Token: ${CF_API_TOKEN:0:4}****${CF_API_TOKEN: -4}"
echo "域名: $CF_RECORD_NAME"
read -p "确认写入配置并即刻同步? (Y/n): " CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "操作已取消。"
    exit 1
fi

# 3. 写入配置文件
echo -e "\n[2/4] 正在写入配置文件..."
mkdir -p "$CONFIG_DIR"
cat <<EOF > "$CONFIG_FILE"
# SPDX-FileCopyrightText: 2021 Andrea Pappacoda
# SPDX-License-Identifier: FSFAP

[ddns]
api_token = $CF_API_TOKEN
record_name = $CF_RECORD_NAME
EOF

chmod 600 "$CONFIG_FILE"

# 4. 核心：手动运行一次以同步
echo "[3/4] 正在执行首次同步 (sudo cloudflare-ddns)..."
if sudo cloudflare-ddns; then
    echo "同步成功！域名已指向当前 IP。"
else
    echo "错误：首次同步失败，请检查 Token 权限或域名拼写。"
    exit 1
fi

echo -e "\n[4/4] 检查运行状态:"
echo "------------------------------------------------"
systemctl status cloudflare-ddns --no-pager | grep "Active:" || true
echo "------------------------------------------------"

echo -e "\nDDNS 配置完成！"