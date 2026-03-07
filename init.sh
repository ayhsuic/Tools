#!/bin/bash
set -euo pipefail

# --- 交互式配置部分 ---
echo "========= 环境配置交互初始化 ========="

# 1. Swap 配置
read -p "请输入 Swap 大小 (默认: 2G): " INPUT_SWAP_SIZE
SWAP_SIZE=${INPUT_SWAP_SIZE:-2G}

read -p "请输入 Swappiness (0-100, 默认: 60): " INPUT_SWAPPINESS
SWAPPINESS=${INPUT_SWAPPINESS:-60}

read -p "请输入 VFS Cache Pressure (默认: 50): " INPUT_VFS_PRESSURE
VFS_PRESSURE=${INPUT_VFS_PRESSURE:-50}


echo -e "\n--- 当前配置确认 ---"
echo "Swap: $SWAP_SIZE (Swappiness: $SWAPPINESS, VFS Pressure: $VFS_PRESSURE)"
read -p "确认开始执行? (Y/n): " CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "脚本已终止。"
    exit 1
fi
# --------------------

SWAP_FILE="/swapfile"
echo "[2/6] Configure Swap ($SWAP_SIZE)..."
if [ ! -f "$SWAP_FILE" ]; then
    fallocate -l $SWAP_SIZE $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1M count=2048
    chmod 600 $SWAP_FILE
    mkswap $SWAP_FILE
    swapon $SWAP_FILE

    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi
    echo "Swap created successfully."
else
    echo "Swap file already exists. Skipping."
fi

# 应用交互式内存优化参数
sudo touch /etc/sysctl.conf 

sudo sysctl vm.swappiness=${SWAPPINESS:-10}
sudo sysctl vm.vfs_cache_pressure=${VFS_PRESSURE:-50}

echo "正在写入 /etc/sysctl.conf..."
sudo sed -i '/vm.swappiness/d' /etc/sysctl.conf
sudo sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf

sudo bash -c "echo 'vm.swappiness=${SWAPPINESS:-10}' >> /etc/sysctl.conf"
sudo bash -c "echo 'vm.vfs_cache_pressure=${VFS_PRESSURE:-50}' >> /etc/sysctl.conf"


sudo sysctl -p

echo "内存优化完成。"

echo -e "\nInitialization Complete!"
free -h