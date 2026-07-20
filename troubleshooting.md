# Troubleshooting log

Things that actually went wrong while building this, roughly in the order I hit them, kept here mostly so future-me doesn't repeat them.

## "This agent is being disconnected because unencrypted/insecure protocol"

Hit this on `agent-pi-arm` the first time I tried connecting. The Pi's `agent.jar` was an old cached copy left over from a different Jenkins version I'd fiddled with months ago, and it was negotiating an old JNLP protocol version the controller now refuses (JNLP1/2 are disabled by default on recent Jenkins for exactly this reason). Fix: always pull `agent.jar` fresh from `http://<controller>/jnlpJars/agent.jar` right before connecting, don't reuse a cached one.

## `sshd`: "Authentication refused: bad ownership or modes for file /home/jenkins/.ssh/authorized_keys"

Classic. `authorized_keys` was `644` because I'd created it with a text editor as a different user first. `sshd` silently rejects loose permissions on that file (and on `~/.ssh` itself if it's not `700`). Fixed with:

```bash
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh
```

## WebSocket agent "hangs" on connect, no error

`agent-win-01` would just sit there printing nothing after `Connecting to http://192.168.1.50:8080/...`. Turned out my nginx reverse proxy in front of Jenkins wasn't passing through the `Upgrade`/`Connection` headers needed for the WebSocket handshake, so the request degraded to a plain HTTP request that Jenkins' websocket endpoint didn't know what to do with. Added to the nginx `location /` block:

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_http_version 1.1;
proxy_read_timeout 86400;
```

That last timeout line matters too — default nginx proxy timeouts are way shorter than how long you want a persistent agent connection to sit idle.

## Pi freezing under 2 executors

Not really a "bug," just underpowered hardware. Two concurrent build steps (one doing an `apt install` inside a container-ish step, one compiling something small) pushed the Pi 4 into swap and it became unresponsive over SSH too. Dropped executors on that node to 1 and it's been fine since. Worth remembering that executor count isn't just "how many jobs can I cram on here" — it's a real resource constraint per machine, and Jenkins won't stop you from over-committing a Pi.

## Java version mismatch causing weird plugin failures

Described in more detail in `setup-agent-ssh.md`. Symptom was specific pipeline steps (ones from a plugin using newer bytecode) failing with `UnsupportedClassVersionError` while basic shell steps worked fine — misleading because most of the pipeline "worked," so I initially looked everywhere except the Java version.

## Node showed "connected" but jobs never scheduled to it

Forgot to actually add the label to the Jenkinsfile's `agent { label '...' }` block and had `agent any` instead, which on a mixed-architecture setup just meant everything kept landing on whichever Linux VM had a free executor first, never the Pi. Not a bug, just me not reading my own pipeline carefully — leaving this here because it's an easy one to lose an hour to.

## SSH launch worked from my terminal but not from Jenkins

I could `ssh jenkins@192.168.1.51` fine by hand but the controller's launch kept failing. Turned out I'd tested manually using my own user's SSH agent/keys without realizing it, while the credential stored in Jenkins pointed at a key with a passphrase — and Jenkins' SSH launcher doesn't have any way to prompt for a passphrase. Regenerated the key pair without a passphrase specifically for this purpose (see the note in `security-hardening.md` about keeping this key scoped only to agent launch).
