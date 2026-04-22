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

# 2. Docker 配置
read -p "请输入 Docker MTU 值 (默认: 1460): " INPUT_MTU
DOCKER_MTU=${INPUT_MTU:-1460}

read -p "请输入 Docker 单个日志最大限制 (默认: 50m): " INPUT_LOG_SIZE
LOG_SIZE=${INPUT_LOG_SIZE:-50m}

read -p "请输入 Docker 日志保留文件数 (默认: 3): " INPUT_LOG_FILE
LOG_FILE=${INPUT_LOG_FILE:-3}

echo -e "\n--- 当前配置确认 ---"
echo "Swap: $SWAP_SIZE (Swappiness: $SWAPPINESS, VFS Pressure: $VFS_PRESSURE)"
echo "Docker: MTU=$DOCKER_MTU, Log=$LOG_SIZE/$LOG_FILE"
read -p "确认开始执行? (Y/n): " CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "脚本已终止。"
    exit 1
fi
# --------------------

echo "[1/6] Install Docker via official script..."
apt-get update
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | bash
else
    echo "Docker is already installed."
fi

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

echo "[3/6] Configure Docker Daemon..."
DAEMON_CONFIG="/etc/docker/daemon.json"
mkdir -p /etc/docker
cat > $DAEMON_CONFIG <<EOF
{
  "mtu": $DOCKER_MTU,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "$LOG_SIZE",
    "max-file": "$LOG_FILE"
  }
}
EOF

echo "[4/6] Restarting Docker..."
systemctl restart docker

echo "[5/6] Configuring User Permissions..."
CURRENT_USER="${SUDO_USER:-$(whoami)}"
if [ "$CURRENT_USER" != "root" ]; then
    usermod -aG docker "$CURRENT_USER"
    echo "User '$CURRENT_USER' added to 'docker' group."
else
    echo "Running as root, skipping user group addition."
fi

echo "[6/6] Enabling TCP BBR..."
if ! grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p
    echo "BBR enabled."
else
    echo "BBR already enabled."
fi

echo -e "\nInitialization Complete!"
echo "Docker Version: $(docker --version)"
free -h