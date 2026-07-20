#!/usr/bin/env bash
# Generates a dedicated ed25519 keypair to be used ONLY for controller -> agent
# SSH-launch connections. Do not reuse this key for anything else - see the
# note in docs/security-hardening.md about key scoping.
#
# Run this ON THE CONTROLLER, then:
#   - upload the PRIVATE key as an "SSH Username with private key" credential
#     in Jenkins (Manage Jenkins -> Credentials)
#   - append the PUBLIC key to each agent's ~/.ssh/authorized_keys
#
# Usage: ./generate-ssh-keys.sh

set -euo pipefail

KEY_NAME="jenkins-agent-key"
KEY_DIR="${HOME}/.ssh/jenkins-remoting"
KEY_PATH="${KEY_DIR}/${KEY_NAME}"

mkdir -p "${KEY_DIR}"
chmod 700 "${KEY_DIR}"

if [[ -f "${KEY_PATH}" ]]; then
  echo "Key already exists at ${KEY_PATH}, not overwriting."
  exit 1
fi

# No passphrase on purpose - Jenkins' SSH launcher can't prompt for one.
# Learned this the hard way, see docs/troubleshooting.md.
ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "${KEY_NAME}"

echo ""
echo "Private key: ${KEY_PATH}"
echo "Public key:  ${KEY_PATH}.pub"
echo ""
echo "Public key contents (append this to each agent's authorized_keys):"
echo "-----------------------------------------------------------------"
cat "${KEY_PATH}.pub"
