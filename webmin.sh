#!/bin/bash

# Update system packages
echo "Updating system packages..."
apt update -y
apt upgrade -y

# Install required dependencies
echo "Installing required dependencies..."
apt install -y wget curl software-properties-common

# Add Webmin repository
echo "Adding Webmin repository..."
wget -qO - https://download.webmin.com/jcameron-key.asc | apt-key add -
echo "deb http://download.webmin.com/download/repository sarge contrib" | tee /etc/apt/sources.list.d/webmin.list

# Update package lists
echo "Updating package lists..."
apt update -y

# Install Webmin
echo "Installing Webmin..."
apt install -y webmin

# Download and install Virtualmin
echo "Installing Virtualmin..."
wget -O install.sh https://software.virtualmin.com/gpl/scripts/install.sh
chmod +x install.sh
./install.sh

# Notify the user
echo "Webmin and Virtualmin installation is complete."
echo "You can access Webmin at: https://your_server_ip:10000"
echo "You can access Virtualmin at: https://your_server_ip:10000/virtualmin"
