#!/usr/bin/env bash
set -euo pipefail

# Must run as root
if [[ "${EUID}" -ne 0 ]]; then
  echo "[!] Run as root (use sudo)."
  exit 1
fi

CONF_DIR="/etc/yggdrasil"
CONF_FILE="${CONF_DIR}/yggdrasil.conf"

PEER1='tls://ygg-kcmo.incognet.io:8884'
PEER2='quic://mn.us.ygg.triplebit.org:443'

echo "[+] Installing dependencies..."
apt-get update
apt-get install -y curl gnupg dirmngr apt-transport-https ca-certificates perl

echo "[+] Installing Yggdrasil apt repo key..."
mkdir -p /usr/local/apt-keys
curl -fsSL https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/key.txt \
  | gpg --dearmor \
  | tee /usr/local/apt-keys/yggdrasil-keyring.gpg > /dev/null
chmod 644 /usr/local/apt-keys/yggdrasil-keyring.gpg

echo "[+] Adding Yggdrasil apt repo..."
echo "deb [signed-by=/usr/local/apt-keys/yggdrasil-keyring.gpg] https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/ debian yggdrasil" \
  > /etc/apt/sources.list.d/yggdrasil.list

echo "[+] Installing Yggdrasil..."
apt-get update
apt-get install -y yggdrasil

echo "[+] Regenerating config (overwriting) at ${CONF_FILE}..."
mkdir -p "${CONF_DIR}"
yggdrasil -genconf > "${CONF_FILE}"
chmod 600 "${CONF_FILE}"

echo "[+] Setting Peers to:"
echo "    - ${PEER1}"
echo "    - ${PEER2}"

# Replace the Peers block (handles common HJSON formatting from -genconf)
perl -0777 -i -pe "s/\\bPeers\\s*:\\s*\\[[^\\]]*\\]/Peers: [\\n  \\\"${PEER1}\\\"\\n  \\\"${PEER2}\\\"\\n]/m" "${CONF_FILE}"

echo "[+] Enabling + restarting service..."
systemctl enable yggdrasil
systemctl reset-failed yggdrasil || true
systemctl restart yggdrasil

echo "[✓] Done."
echo "    Check: yggdrasilctl getPeers"
echo "    Self : yggdrasilctl getSelf"
