#!/bin/bash

# Update package lists and upgrade all packages
sudo apt-get update
sudo apt-get upgrade -y

# Install cron-apt
sudo apt-get install -y cron-apt

# Configure cron-apt
sudo bash -c 'cat <<EOL > /etc/cron-apt/config
APTCOMMAND=/usr/bin/apt-get
OPTIONS="-o quiet=1"
MAILON="always"
EOL'

# Configure cron-apt action script for upgrades
sudo bash -c 'cat <<EOL > /etc/cron-apt/action.d/5-upgrade
dist-upgrade -y -o APT::Get::Show-Upgraded=true
autoclean -y
EOL'

# Configure cron job to run daily at 1 AM
sudo bash -c 'cat <<EOL > /etc/cron.d/cron-apt
0 1 * * * root test -x /usr/sbin/cron-apt && /usr/sbin/cron-apt
EOL'

# Test the cron-apt setup
sudo cron-apt

echo "Automatic updates setup is complete."
