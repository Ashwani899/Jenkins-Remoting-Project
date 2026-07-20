# Architecture notes

This is the stuff I wish someone had explained to me before I started clicking around in "Manage Nodes."

## What "remoting" actually is

Jenkins remoting is not some magic distributed-systems protocol — it's a Java library (`remoting.jar`, sometimes called the "agent jar") that opens a channel between the controller JVM and an agent JVM and lets them serialize commands/objects back and forth over it. Once the channel is up, the controller can basically tell the agent "run this shell step" and get the output streamed back.

Two things establish that channel, and picking the wrong one for your network topology is where most people (me included) waste the first hour:

### 1. SSH launch (controller → agent)

The controller SSHes into the agent machine, drops the `remoting.jar` on disk (or reuses a cached copy), and starts it as a subprocess over that SSH session. This means:

- The controller needs outbound SSH access to the agent.
- The agent needs an SSH server and a user Jenkins can log in as.
- No inbound port needs to be opened on the agent for Jenkins traffic — SSH is the only thing exposed.

This is what I used for `agent-linux-01` and `agent-linux-02` since both sit on the same LAN segment as the controller and I could just add a static route / DHCP reservation for them.

### 2. Inbound / JNLP launch (agent → controller)

The agent runs `agent.jar` (downloaded from `http://<controller>/jnlpJars/agent.jar`) and initiates the connection *to* the controller, using a per-agent secret. This is the one you want when:

- The agent is behind NAT and you can't reach it from the controller (my case for `agent-pi-arm`, which is on a different VLAN with client isolation on, and `agent-win-01`, which I genuinely could not be bothered to enable inbound RDP/WinRM for).
- You don't want to store SSH credentials to the agent on the controller at all.

The controller needs a TCP port open for inbound agent connections (`Configure Global Security → Agents → Fixed port`, I used `50000`) **or** you route it over the existing HTTP(S) port using WebSocket, which is what I ended up doing for `agent-win-01` — one less port to firewall, and it works cleanly through the reverse proxy I've got in front of the controller.

## Why I mixed both in one lab

Honestly, on purpose. Real orgs end up with mixed topologies — some agents on trusted internal networks, some on VPCs you can't reach directly, maybe a build box in someone's office. Setting up both launch methods side by side made the tradeoffs click in a way that just reading the docs didn't.

## Executors and labels

Each node has an executor count (I set 2 on the VMs, 1 on the Pi because it chokes on more than one concurrent build) and a set of labels. Labels are just strings — `linux`, `docker`, `arm`, `windows`, `raspberrypi` — and pipelines pin `agent { label '...' }` to route work. There's no automatic "best fit" scheduling beyond label matching and executor availability; Jenkins isn't doing anything clever here, which surprised me a little.

## What actually flows over the channel

Once connected, the controller sends serialized `Callable` objects to the agent to execute, and the agent streams stdout/stderr back as it happens (that's why `Console Output` updates live instead of appearing all at once at the end). Build artifacts, workspace files, etc. get copied back over the same channel when a job finishes, unless you're using something like the `Copy Artifact` plugin or an external artifact store.

## Diagram reference

See the topology diagram in the main [README](../README.md) — that's the exact shape of this lab, not a generic example.
