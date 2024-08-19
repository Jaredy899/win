#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Function to install packages based on distribution
install_packages() {
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu-based system
        sudo apt update
        sudo apt install -y sudo
        sudo apt install -y curl
        sudo timedatectl set-timezone America/New_York
        curl -sSL https://get.docker.com | sh
    elif [ -f /etc/arch-release ]; then
        # Arch-based system
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm sudo
        sudo pacman -S --noconfirm docker
        sudo timedatectl set-timezone America/New_York
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "Unsupported distribution"
        exit 1
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -sSL https://github.com/docker/compose/releases/download/$LATEST/docker-compose-$(uname -s)-$(uname -m) -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    docker compose version
}

# Function to install and start Portainer
install_portainer() {
    docker volume create portainer_data
    docker run -d \
      -p 8000:8000 \
      -p 9000:9000 \
      --name=portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest

    printf 'Waiting for Portainer to start...\n\n'
    until [ "$(docker inspect -f '{{.State.Status}}' portainer)" = "running" ]; do
        sleep 1
    done

    printf '\nPortainer started successfully\n\n'
}

# Install packages and Docker
install_packages

# Wait for Docker to start
printf 'Waiting for Docker to start...\n\n'
while ! systemctl is-active --quiet docker; do
    sleep 1
done

printf '\nDocker installed successfully\n\n'

# Install Docker Compose
install_docker_compose

# Install and start Portainer
install_portainer
