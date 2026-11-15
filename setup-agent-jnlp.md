# Setting up a JNLP (inbound) agent

Applies to an ARM worker and a Windows worker that initiate the connection to the Jenkins controller. Adapt node names, paths, and labels to the machines available in your lab.

## Use HTTPS by default

Set the controller URL to its HTTPS reverse-proxy endpoint with a certificate trusted by the agent host:

```bash
export CONTROLLER_URL="https://jenkins.example.internal"
```

Download the agent JAR from the controller's node page or its HTTPS JNLP endpoint. Do not disable TLS certificate validation to make a connection work.

## 1. Linux / Raspberry Pi OS (ARM64)

Install Java 17:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless curl
```

For a one-off connection, download the agent JAR and run it with the secret from that node's configuration page:

```bash
mkdir -p ~/jenkins-agent
cd ~/jenkins-agent
curl -fsSLo agent.jar "$CONTROLLER_URL/jnlpJars/agent.jar"
java -jar agent.jar -url "$CONTROLLER_URL/" \
  -secret <secret-from-node-page> \
  -name agent-pi-arm \
  -webSocket \
  -workDir "$HOME/jenkins-agent"
```

The `-secret` value is passed to the Java process as an argument. Run this only on a trusted host and avoid putting the token in shell history or shared logs.

For a systemd service, use the checked-in [install-agent-ubuntu.sh](install-agent-ubuntu.sh). It requires `CONTROLLER_URL` and `AGENT_SECRET` in the environment, validates the controller scheme, stores the secret in a root-only environment file, and installs the service for the selected local agent user. It does not create that user; create it first if needed.

Example with a prompt that avoids placing the token in the command text:

```bash
read -rsp "Jenkins agent secret: " AGENT_SECRET
echo
export AGENT_SECRET
export CONTROLLER_URL="https://jenkins.example.internal"
export AGENT_NAME="agent-pi-arm"
./install-agent-ubuntu.sh
unset AGENT_SECRET
```

The agent secret is still supplied to the Java process as a command-line argument when systemd starts it. Restrict local access to the agent host.

If a lab controller is available only over HTTP, the Linux installer refuses it by default. Set `ALLOW_INSECURE_HTTP=true` only on an isolated, trusted network; never use this exception on a shared or public network.

Set the ARM agent executor count conservatively. Small boards can become unresponsive when multiple memory-intensive builds run at once.

## 2. Windows

Install Java 17 and download the agent JAR from the controller over HTTPS. Start the script from a trusted PowerShell session:

```powershell
.\\install-agent-windows.ps1 `
  -ControllerUrl "https://jenkins.example.internal" `
  -AgentName "agent-win-01"
```

The script requires HTTPS unless `-AllowInsecureHttp` is explicitly supplied for an isolated, trusted lab network. The script prompts for the secret using a secure PowerShell input prompt, so it is not placed in the invocation history. The Java agent still receives the token as a process argument; restrict local access to the host.

For a persistent Windows service, use the supported agent service installer from the Jenkins node page and follow your controller's service-account policy.

## Network and reverse-proxy checks

If the controller is behind a reverse proxy, verify that TLS is terminated correctly and WebSocket upgrade headers are forwarded. Keep the controller URL, certificate hostname, and reverse-proxy configuration consistent. See [troubleshooting.md](troubleshooting.md) if a WebSocket connection appears to hang.
