#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing Yggdrasil on Debian-based system..."

# Ensure running as root
if [[ "${EUID}" -ne 0 ]]; then
  echo "[!] Please run as root (use sudo)."
  exit 1
fi

# ---- Settings (optional overrides) ----
CONF_DIR="/etc/yggdrasil"
CONF_FILE="${CONF_DIR}/yggdrasil.conf"

# Set FORCE_REGEN=1 to overwrite existing config
FORCE_REGEN="${FORCE_REGEN:-0}"

# Optional: seed peers by exporting YGG_PEERS as a newline-separated list of URIs.
# Example:
#   export YGG_PEERS=$'tls://ygg-kcmo.incognet.io:8884\nquic://mn.us.ygg.triplebit.org:443'
YGG_PEERS="${YGG_PEERS:-}"

# ---- Dependencies ----
echo "[+] Installing required dependencies..."
apt-get update
apt-get install -y curl gnupg dirmngr apt-transport-https ca-certificates

# ---- Repo key + repo ----
echo "[+] Creating apt key directory..."
mkdir -p /usr/local/apt-keys

echo "[+] Importing Yggdrasil repository key..."
curl -fsSL https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/key.txt \
  | gpg --dearmor \
  | tee /usr/local/apt-keys/yggdrasil-keyring.gpg > /dev/null

chmod 644 /usr/local/apt-keys/yggdrasil-keyring.gpg

echo "[+] Adding Yggdrasil repository..."
echo "deb [signed-by=/usr/local/apt-keys/yggdrasil-keyring.gpg] https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/ debian yggdrasil" \
  | tee /etc/apt/sources.list.d/yggdrasil.list > /dev/null

echo "[+] Updating apt..."
apt-get update

# ---- Install ----
echo "[+] Installing Yggdrasil..."
apt-get install -y yggdrasil

# ---- Ensure config exists where systemd expects it ----
echo "[+] Ensuring Yggdrasil config exists at ${CONF_FILE} ..."

mkdir -p "${CONF_DIR}"

if [[ -f "${CONF_FILE}" && "${FORCE_REGEN}" != "1" ]]; then
  echo "[=] Config already exists; leaving it untouched (set FORCE_REGEN=1 to overwrite)."
else
  if [[ -f "${CONF_FILE}" && "${FORCE_REGEN}" == "1" ]]; then
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    echo "[!] FORCE_REGEN=1 set; backing up existing config to ${CONF_FILE}.bak.${ts}"
    cp -a "${CONF_FILE}" "${CONF_FILE}.bak.${ts}"
  fi

  # Generate a fresh config in the expected location
  yggdrasil -genconf | tee "${CONF_FILE}" > /dev/null
  chmod 600 "${CONF_FILE}"
  echo "[+] Generated new config."

  # Optional: seed peers into the config (best-effort; only if user provided YGG_PEERS)
  if [[ -n "${YGG_PEERS}" ]]; then
    echo "[+] Seeding peers from \$YGG_PEERS ..."
    # Build an HJSON Peers array block
    peers_block="Peers: ["
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      peers_block+=$'\n  "'"${line}"'"'
    done <<< "${YGG_PEERS}"
    peers_block+=$'\n]'

    # Replace any existing Peers block (best-effort, handles common default formatting)
    # If the file doesn't contain "Peers:", append it near top.
    if grep -qE '^\s*Peers\s*:' "${CONF_FILE}"; then
      perl -0777 -i -pe 's/^\s*Peers\s*:\s*\[[^\]]*\]/'"${peers_block//\//\\/}"'/m' "${CONF_FILE}" || true
    else
      printf "\n%s\n" "${peers_block}" >> "${CONF_FILE}"
    fi
  fi
fi

# ---- Enable + start ----
echo "[+] Enabling and starting Yggdrasil service..."
systemctl enable yggdrasil
systemctl reset-failed yggdrasil || true
systemctl restart yggdrasil

echo "[✓] Installation complete."
echo
echo "Check status with:"
echo "  systemctl status yggdrasil"
echo
echo "Peers / self info:"
echo "  yggdrasilctl getPeers"
echo "  yggdrasilctl getSelf"
echo
echo "Config file:"
echo "  ${CONF_FILE}"
