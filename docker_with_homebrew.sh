#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Variables
USER="jared"  # Replace with your username

# Docker, Nala, timezone
sudo apt install sudo -y
sudo apt install nala -y
sudo timedatectl set-timezone America/New_York
curl -sSL https://get.docker.com | sudo sh
printf '\nDocker installed successfully\n\n'

printf 'Waiting for Docker to start...\n\n'
while ! sudo systemctl is-active --quiet docker; do
    sleep 1
done

# Docker Compose
LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
sudo docker compose version

# Portainer
sudo docker volume create portainer_data
sudo docker run -d \
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

# Homebrew
sudo -u $USER curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/install_homebrew.sh"
sudo -u $USER bash -c "yes '' | bash /tmp/install_homebrew.sh

# Configure Homebrew
sudo -u $USER bash -c '(echo; echo "eval \$($(/home/linuxbrew/.linuxbrew/bin/brew shellenv))") >> /home/$USER/.bashrc'
sudo -u $USER bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

# Install build-essential
sudo apt-get install build-essential -y

# Install gcc using Homebrew
sudo -u $USER bash -c "brew install gcc"
