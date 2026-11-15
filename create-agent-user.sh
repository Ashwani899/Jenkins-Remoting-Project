#!/usr/bin/env bash
# Creates a dedicated, unprivileged user for a Jenkins SSH-launched agent.
# Ran this on agent-linux-01 and agent-linux-02 (Ubuntu 22.04) in my lab.
#
# Usage: sudo ./create-agent-user.sh

set -euo pipefail

AGENT_USER="jenkins"
AGENT_HOME="/home/${AGENT_USER}"
AGENT_WORKDIR="${AGENT_HOME}/agent"

if id "${AGENT_USER}" &>/dev/null; then
  echo "User ${AGENT_USER} already exists, skipping useradd."
else
  echo "Creating user ${AGENT_USER}..."
  useradd -m -s /bin/bash "${AGENT_USER}"
fi

echo "Setting up remoting work directory at ${AGENT_WORKDIR}..."
mkdir -p "${AGENT_WORKDIR}"
chown -R "${AGENT_USER}:${AGENT_USER}" "${AGENT_HOME}"

echo "Setting up .ssh directory..."
mkdir -p "${AGENT_HOME}/.ssh"
touch "${AGENT_HOME}/.ssh/authorized_keys"
chmod 700 "${AGENT_HOME}/.ssh"
chmod 600 "${AGENT_HOME}/.ssh/authorized_keys"
chown -R "${AGENT_USER}:${AGENT_USER}" "${AGENT_HOME}/.ssh"

echo ""
echo "Done. Next steps:"
echo "  1. Append the controller's PUBLIC key to ${AGENT_HOME}/.ssh/authorized_keys"
echo "  2. Install Java: sudo apt install -y openjdk-17-jre-headless"
echo "  3. Register this node from the controller (see setup-master.md)"
