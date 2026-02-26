#!/usr/bin/env bash

set -euo pipefail

echo "[+] Installing Yggdrasil on Debian-based system..."

# Ensure running as root
if [[ "$EUID" -ne 0 ]]; then
  echo "[!] Please run as root (use sudo)."
  exit 1
fi

# Install required packages
echo "[+] Installing required dependencies..."
apt-get update
apt-get install -y curl gnupg dirmngr apt-transport-https ca-certificates

# Create key directory
echo "[+] Creating apt key directory..."
mkdir -p /usr/local/apt-keys

# Fetch and install repository key (new key as of 2025-11-11)
echo "[+] Importing Yggdrasil repository key..."
curl -fsSL https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/key.txt \
  | gpg --dearmor \
  | tee /usr/local/apt-keys/yggdrasil-keyring.gpg > /dev/null

chmod 644 /usr/local/apt-keys/yggdrasil-keyring.gpg

# Add repository
echo "[+] Adding Yggdrasil repository..."
echo "deb [signed-by=/usr/local/apt-keys/yggdrasil-keyring.gpg] https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/ debian yggdrasil" \
  | tee /etc/apt/sources.list.d/yggdrasil.list

# Update package list
echo "[+] Updating apt..."
apt-get update

# Install Yggdrasil
echo "[+] Installing Yggdrasil..."
apt-get install -y yggdrasil

# Enable and start service
echo "[+] Enabling Yggdrasil service..."
systemctl enable yggdrasil
systemctl restart yggdrasil

echo "[✓] Installation complete."
echo
echo "Check status with:"
echo "  systemctl status yggdrasil"
echo
echo "Config file located at:"
echo "  /etc/yggdrasil.conf"