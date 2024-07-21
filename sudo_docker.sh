#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '
	')

# Docker, Nala, timezone
sudo apt install sudo -y
sudo apt install nala -y
sudo timedatectl set-timezone America/New_York
curl -sSL https://get.docker.com | sudo sh
printf '
Docker installed successfully

'

printf 'Waiting for Docker to start...

'
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
sudo docker run -d   -p 8000:8000   -p 9000:9000   --name=portainer   --restart=always   -v /var/run/docker.sock:/var/run/docker.sock   -v portainer_data:/data   portainer/portainer-ce:latest

printf 'Waiting for Portainer to start...

'
until [ "$(sudo docker inspect -f '{{.State.Status}}' portainer)" = "running" ]; do
    sleep 1
done

printf '
Portainer started successfully

'
