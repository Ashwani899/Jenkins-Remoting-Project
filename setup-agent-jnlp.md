# Setting up a JNLP (inbound) agent

Applies to `agent-pi-arm` (Raspberry Pi 4, Raspberry Pi OS 64-bit) and `agent-win-01` (an old Windows 10 laptop). Both sit somewhere the controller can't initiate a connection to — the Pi is on a VLAN with client isolation, the laptop is just on wifi with a DHCP lease that changes.

## Why inbound instead of SSH here

The agent reaches out to the controller instead of the other way round, so none of that matters — as long as the agent can hit `192.168.1.50:8080` (or `:50000` if you're not using WebSocket), it'll connect.

## 1. Raspberry Pi (ARM64)

Java first:

```bash
sudo apt update
sudo apt install -y openjdk-17-jre-headless
```

Create the working dir and pull the agent jar (grab this from the node's own page on the controller — `agent-pi-arm` in this repo's lab — it's always version-matched to your controller, don't cache an old copy):

```bash
mkdir -p ~/jenkins-agent && cd ~/jenkins-agent
curl -O http://192.168.1.50:8080/jnlpJars/agent.jar
```

Run it (secret comes from the node's config page, `-webSocket` because I routed this over HTTP instead of opening 50000 on that VLAN):

```bash
java -jar agent.jar -url http://192.168.1.50:8080/ \
  -secret <secret-from-node-page> \
  -name agent-pi-arm \
  -webSocket \
  -workDir "/home/pi/jenkins-agent"
```

I turned this into a systemd service (`scripts/install-agent-ubuntu.sh` has the equivalent for Debian-based systems, same idea applies to Raspberry Pi OS) so it survives reboots — the Pi lives on a shelf and I am not walking over to SSH into it every time it restarts.

Executor count: set to **1**. I tried 2 first and two concurrent `docker build`-style steps basically froze it — 4GB of RAM and an SD card are not enough for parallel builds, learned that the hard way.

## 2. Windows laptop

Downloaded `agent.jar` from the same node page via browser instead of curl (no curl on this box by default). Ran it from PowerShell:

```powershell
java -jar agent.jar -url http://192.168.1.50:8080/ `
  -secret <secret-from-node-page> `
  -name agent-win-01 `
  -webSocket `
  -workDir "C:\jenkins-agent"
```

For it to actually survive a reboot / not require someone logged in, I installed it as a Windows service using the **Agent as a Windows service** option that shows up when you visit the node's page directly from a browser *on that machine* (`http://192.168.1.50:8080/computer/agent-win-01/`) — it offers a native `.msi`-style installer at that point rather than the raw jar. Much less fiddly than trying to wrap it in NSSM myself.

## Common gotcha across both

If the controller is behind a reverse proxy (mine is, nginx terminating TLS for `:8080`), make sure `X-Forwarded-*` headers and WebSocket upgrade headers are actually passed through, or the `-webSocket` connection will look like it hangs with no useful error. This one took me the longest to figure out — see `troubleshooting.md`.
