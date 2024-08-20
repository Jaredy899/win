#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Function to detect the distribution and install the necessary packages
install_packages() {
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu-based system
        echo "Detected Debian-based system"
        sudo apt update && sudo apt install -y curl
        curl -sSL https://get.docker.com | sh
    elif [ -f /etc/arch-release ]; then
        # Arch-based system
        echo "Detected Arch-based system"
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm docker docker-compose
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "Unsupported distribution"
        exit 1
    fi
}

# Function to install and start Portainer
install_portainer() {
    if [ "$(docker ps -q -f name=portainer)" ]; then
        echo "Portainer is already running"
    else
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
    fi
}

install_packages

# Display instructions to manually add user to Docker group
echo "To add your user to the Docker group and apply the changes, please run the following commands:"
echo
echo "  sudo usermod -aG docker $USER"
echo "  newgrp docker"
echo
echo "After running these commands, you can use Docker without sudo."
install_portainer
