#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Determine the package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        arch)
            PKG_MANAGER="pacman -Sy --noconfirm"
            ;;
        debian | ubuntu)
            PKG_MANAGER="apt install -y"
            ;;
        fedora)
            PKG_MANAGER="dnf install -y"
            ;;
        *)
            echo "Unsupported distribution: $ID"
            exit 1
            ;;
    esac
else
    echo "Cannot determine the distribution."
    exit 1
fi

# Install sudo (if not installed), Nala (for Debian/Ubuntu), and set timezone
sudo $PKG_MANAGER sudo

if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
    sudo $PKG_MANAGER nala
fi

sudo timedatectl set-timezone America/New_York

# Install Docker
if [ "$ID" = "arch" ]; then
    sudo $PKG_MANAGER docker
    sudo systemctl enable --now docker
else
    curl -sSL https://get.docker.com | sh
fi

printf '\nDocker installed successfully\n\n'

printf 'Waiting for Docker to start...\n\n'
while ! systemctl is-active --quiet docker; do
    sleep 1
done

# Docker Compose installation
LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
docker compose version

# Portainer installation
docker volume create portainer_data
docker run -d \
  -p 8000:8000 \
  -p 9000:9000 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce
