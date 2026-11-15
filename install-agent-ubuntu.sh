#!/usr/bin/env bash
# Bootstraps a JNLP (inbound) agent on a Debian/Ubuntu-family host.
# See setup-agent-jnlp.md for the supported workflow and security notes.
#
# Required environment:
#   CONTROLLER_URL=https://jenkins.example.internal
#   AGENT_SECRET=<secret copied from the node's Jenkins page>
# Optional environment:
#   AGENT_NAME=agent-pi-arm
#   AGENT_USER=jenkins
#   ALLOW_INSECURE_HTTP=true  # isolated, trusted lab networks only
#
# Do not put AGENT_SECRET in shell history or the installer command line.
# The Java agent CLI still receives the secret as a process argument; restrict
# local access to the agent host and use HTTPS for the controller connection.

set -euo pipefail

CONTROLLER_URL="${CONTROLLER_URL:?Set CONTROLLER_URL to the Jenkins controller URL}"
AGENT_NAME="${AGENT_NAME:-agent-pi-arm}"
AGENT_SECRET="${AGENT_SECRET:?Set AGENT_SECRET from the Jenkins node page}"
AGENT_USER="${AGENT_USER:-$(id -un)}"
ALLOW_INSECURE_HTTP="${ALLOW_INSECURE_HTTP:-false}"

CONTROLLER_URL="${CONTROLLER_URL%/}"

if [[ "$CONTROLLER_URL" == http://* ]]; then
  if [[ "$ALLOW_INSECURE_HTTP" != "true" ]]; then
    echo "Refusing an HTTP controller URL. Use HTTPS, or set ALLOW_INSECURE_HTTP=true only on an isolated trusted lab network." >&2
    exit 2
  fi
  CURL_PROTOCOL_ARGS=(--proto '=http,https' --proto-redir '=http,https')
elif [[ "$CONTROLLER_URL" == https://* ]]; then
  CURL_PROTOCOL_ARGS=(--proto '=https' --proto-redir '=https' --tlsv1.2)
else
  echo "CONTROLLER_URL must be an absolute https:// URL." >&2
  exit 2
fi

if [[ ! "$AGENT_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "AGENT_NAME may contain only letters, digits, dot, underscore, and hyphen." >&2
  exit 2
fi

# Jenkins inbound-agent secrets are hexadecimal tokens. Restricting this value
# keeps the systemd EnvironmentFile syntax unambiguous.
if [[ ! "$AGENT_SECRET" =~ ^[[:xdigit:]]+$ ]]; then
  echo "AGENT_SECRET must be the hexadecimal secret shown on the Jenkins node page." >&2
  exit 2
fi

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  echo "Agent user '$AGENT_USER' does not exist. Create it before installing the service." >&2
  exit 2
fi

if [[ "$AGENT_USER" == "root" ]]; then
  echo "Refusing to run the Jenkins agent as root. Set AGENT_USER to an unprivileged account." >&2
  exit 2
fi
AGENT_GROUP="$(id -gn "$AGENT_USER")"

AGENT_HOME="$(getent passwd "$AGENT_USER" | cut -d: -f6)"
if [[ -z "$AGENT_HOME" ]]; then
  echo "Could not determine the home directory for '$AGENT_USER'." >&2
  exit 2
fi

WORK_DIR="${AGENT_HOME%/}/jenkins-agent"
SERVICE_FILE="/etc/systemd/system/jenkins-${AGENT_NAME}.service"
SECRET_DIR="/etc/jenkins-agent"
ENV_FILE="${SECRET_DIR}/${AGENT_NAME}.env"

PACKAGES=()
command -v java >/dev/null 2>&1 || PACKAGES+=(openjdk-17-jre-headless)
command -v curl >/dev/null 2>&1 || PACKAGES+=(curl)
if (( ${#PACKAGES[@]} > 0 )); then
  sudo apt-get update
  sudo apt-get install -y "${PACKAGES[@]}"
fi

echo "Preparing the agent work directory..."
sudo install -d -o "$AGENT_USER" -g "$AGENT_GROUP" -m 0750 "$WORK_DIR"

echo "Downloading agent.jar from the configured controller..."
sudo -u "$AGENT_USER" curl -fsSL "${CURL_PROTOCOL_ARGS[@]}" \
  -o "${WORK_DIR}/agent.jar" "${CONTROLLER_URL}/jnlpJars/agent.jar"

echo "Writing the agent secret to a root-only environment file..."
sudo install -d -o root -g root -m 0700 "$SECRET_DIR"
sudo install -o root -g root -m 0600 /dev/null "$ENV_FILE"
printf 'AGENT_SECRET=%s\n' "$AGENT_SECRET" | sudo tee "$ENV_FILE" >/dev/null
sudo chown root:root "$ENV_FILE"
sudo chmod 0600 "$ENV_FILE"

echo "Writing the systemd unit..."
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Jenkins Remoting Agent ($AGENT_NAME)
After=network-online.target
Wants=network-online.target

[Service]
User=$AGENT_USER
WorkingDirectory=$WORK_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/java -jar $WORK_DIR/agent.jar -url $CONTROLLER_URL/ -secret \${AGENT_SECRET} -name $AGENT_NAME -webSocket -workDir $WORK_DIR
Restart=on-failure
RestartSec=10
UMask=0077

[Install]
WantedBy=multi-user.target
EOF
sudo chmod 0644 "$SERVICE_FILE"

unset AGENT_SECRET
sudo systemctl daemon-reload
sudo systemctl enable --now "jenkins-$AGENT_NAME.service"

echo
echo "Service status:"
sudo systemctl status "jenkins-$AGENT_NAME.service" --no-pager || true
echo
echo "Tail logs with: journalctl -u jenkins-$AGENT_NAME.service -f"
