#!/usr/bin/env bash
# Bootstraps a JNLP (inbound) agent on a Debian/Ubuntu-family box and
# installs it as a systemd service so it survives reboots.
#
# I used this on agent-pi-arm (Raspberry Pi OS 64-bit, which is Debian-based,
# so this script works there too) - see docs/setup-agent-jnlp.md.
#
# Fill in CONTROLLER_URL / AGENT_NAME / AGENT_SECRET before running, or pass
# them as environment variables:
#   CONTROLLER_URL=http://192.168.1.50:8080 AGENT_NAME=agent-pi-arm \
#   AGENT_SECRET=xxxx ./install-agent-ubuntu.sh

set -euo pipefail

CONTROLLER_URL="${CONTROLLER_URL:-http://192.168.1.50:8080}"
AGENT_NAME="${AGENT_NAME:-agent-pi-arm}"
AGENT_SECRET="${AGENT_SECRET:?Set AGENT_SECRET - grab it from the node's page on the controller}"
AGENT_USER="${AGENT_USER:-$(whoami)}"
WORK_DIR="/home/${AGENT_USER}/jenkins-agent"

echo "Installing Java (skips if already present)..."
if ! command -v java &>/dev/null; then
  sudo apt update
  sudo apt install -y openjdk-17-jre-headless
fi

echo "Setting up ${WORK_DIR}..."
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

echo "Downloading fresh agent.jar from controller (don't reuse old copies - see troubleshooting.md)..."
curl -fsSL -O "${CONTROLLER_URL}/jnlpJars/agent.jar"

SERVICE_FILE="/etc/systemd/system/jenkins-${AGENT_NAME}.service"

echo "Writing systemd unit to ${SERVICE_FILE}..."
sudo tee "${SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=Jenkins Remoting Agent (${AGENT_NAME})
After=network-online.target
Wants=network-online.target

[Service]
User=${AGENT_USER}
WorkingDirectory=${WORK_DIR}
ExecStart=/usr/bin/java -jar ${WORK_DIR}/agent.jar \\
  -url ${CONTROLLER_URL}/ \\
  -secret ${AGENT_SECRET} \\
  -name ${AGENT_NAME} \\
  -webSocket \\
  -workDir ${WORK_DIR}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "jenkins-${AGENT_NAME}.service"

echo ""
echo "Service status:"
sudo systemctl status "jenkins-${AGENT_NAME}.service" --no-pager || true
echo ""
echo "Tail logs with: journalctl -u jenkins-${AGENT_NAME}.service -f"
