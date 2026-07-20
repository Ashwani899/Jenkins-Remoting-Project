# Security hardening / node isolation

This is the part of the task I spent the most time on, because "just get an agent connected" is the easy 20% and "don't let a compromised agent own your controller" is the part that actually matters in a real environment.

## The default trust model is looser than people assume

Out of the box (older Jenkins especially), an agent that connects can call back into the controller with a fairly wide surface — because historically the channel was designed assuming both ends were equally trusted. If someone compromises one agent, in the worst case they can pivot to reading credentials or affecting other jobs on the controller. Modern Jenkins has walked this back a lot, but it's not automatic — you have to actually configure it.

Concrete steps I took in this lab:

### 1. Agent → Controller Security Subsystem

`Manage Jenkins → Security → Agent to Controller Access Control`. This is on by default in current Jenkins and blocks agents from reading arbitrary controller files or invoking arbitrary controller-side operations. I left it **enabled** and didn't add blanket exceptions — a couple of plugins wanted broader access and I resisted the urge to just allow-list everything to make a warning go away. Where a plugin genuinely needed an exception, I added the narrowest one it asked for, not a wildcard.

### 2. Don't run agents as root

Covered in `setup-agent-ssh.md` already, but worth repeating here: every agent in this lab runs as an unprivileged user (`jenkins` on Linux, a standard user on Windows/Pi). If a build step goes rogue or a compromised dependency tries something, it's contained to what that user can touch — not the whole box.

### 3. Separate SSH key per purpose

The key used for controller → `agent-linux-01`/`02` SSH launch (`jenkins-agent-key`, from `scripts/generate-ssh-keys.sh`) is dedicated to this and isn't reused anywhere else — not my personal key, not shared with any other automation. If it leaks, the blast radius is "someone can SSH in as an unprivileged build user on two lab VMs," not "someone has my actual SSH identity."

### 4. Fixed, firewalled inbound port

For the JNLP agents, I fixed the inbound port to `50000` specifically so I could write one precise firewall rule instead of leaving it on Jenkins' default random-port behavior (which used to make sense mainly for avoiding conflicts, not for security). In this lab the router only allows `50000` and `8080` in from the Pi's VLAN, nothing else.

### 5. WebSocket over opening more ports

For `agent-win-01` I used `-webSocket` specifically to avoid opening a second inbound port on a machine that's already on wifi with a less controlled network path than the wired VMs. One fewer port exposed anywhere is one fewer thing to worry about.

### 6. Per-node executors and labels as a soft isolation boundary

Not a hard security boundary, but I deliberately didn't create one "do everything" pool of agents. Docker-capable jobs only run on `agent-linux-02` (label `docker`), and I didn't put a `docker` label on the Pi or the Windows box at all — partly because it wouldn't work well there, but also so an accidental `docker.sock` mount in a Jenkinsfile can't happen on a machine I don't want it happening on.

### 7. Credentials scoping

Credentials that agents need (e.g. registry logins for image pushes) are scoped to the specific folder/job that uses them rather than added as global credentials visible to every pipeline. This isn't remoting-specific but it matters a lot once you have multiple agents running work with different trust levels.

### 8. What I deliberately did NOT do

I did not disable TLS/host key checking anywhere to "make it easier to connect" — every SSH launch pins a host key, and the controller itself sits behind TLS via the nginx reverse proxy even inside my own LAN. It would have been faster to skip this for a home lab. I skipped skipping it, on purpose, since the whole point was learning the secure way to do it.

## Things I'd still want before calling this production-ready

- Rotating the SSH agent key periodically (currently static)
- Moving from a Script-Console-based node registration option (`scripts/register-node-cli.groovy`) to JCasC so node definitions are versioned, not click-ops
- Secrets management via something like Vault instead of Jenkins' built-in credential store, for anything beyond a home lab
