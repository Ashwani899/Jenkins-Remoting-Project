# Controller setup

Assuming Jenkins is already installed and reachable at `http://192.168.1.50:8080`. This isn't a "how to install Jenkins" doc — plenty of those exist. This is specifically the config I touched to make remoting work well.

## 1. Global security prep

`Manage Jenkins → Security`:

- **Agents → TCP port for inbound agents**: set to a fixed port (`50000`) rather than random, because I needed to open exactly that port on the router and nothing else. Random port assignment is fine on a stable internal network but a pain the moment you have a firewall rule to write.
- Left **Agent → Master Access Control** on the default ("Fully connected" isn't a real option anymore in recent Jenkins — it's now driven by the `Agent to Controller Security Subsystem`, more on that in `security-hardening.md`).

## 2. Creating the SSH-launched nodes (linux-01, linux-02)

`Manage Jenkins → Nodes → New Node`:

- Name: `agent-linux-01`
- Type: Permanent Agent
- Remote root directory: `/home/jenkins/agent` (matches the user created in `create-agent-user.sh`)
- Labels: `linux`
- Launch method: **Launch agents via SSH**
  - Host: `192.168.1.51`
  - Credentials: added an SSH username/private key credential (`jenkins-agent-key`), generated with `generate-ssh-keys.sh` — do NOT reuse your personal SSH key here, I made that mistake on the first pass and had to regenerate everything
  - Host Key Verification Strategy: **Manually trusted key verification** — I actually SSH'd in once from the controller's shell first to accept the host key, then set this to "known hosts file" so it stays pinned. "Non verifying" is the lazy option and it's how you get MITM'd on a network you don't fully trust.

Repeat for `agent-linux-02`, labels `linux,docker` (this one has Docker installed for containerized build steps).

## 3. Creating the JNLP-launched nodes (pi-arm, win-01)

Same New Node flow, except:

- Launch method: **Launch agent by connecting it to the controller** (this is the "inbound" / JNLP option, name changed a few times across Jenkins versions so don't panic if your UI says something slightly different)
- Jenkins generates a per-node secret here — grab it, you'll need it when starting `agent.jar` on the remote machine.

Details for actually starting the agent process live in `setup-agent-jnlp.md`.

## 4. A note on the built-in node

I set the built-in node (the controller itself) executor count to **0** once the agents were up. There's an ongoing debate about whether this is best practice, but for a "learn remoting properly" lab, forcing every job onto a real remote agent meant I couldn't accidentally cheat by letting something silently run on the controller.

## 5. Verifying

`Manage Jenkins → Nodes` should show all four agents with a green icon. If one's grey with an X, click into it — the log tab on the node page is usually more useful than the general Jenkins log for figuring out why a specific agent won't connect.
