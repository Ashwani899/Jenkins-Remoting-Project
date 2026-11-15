# Setting up an SSH-launched agent

Applies to `agent-linux-01` and `agent-linux-02` in this lab. Both are Ubuntu 22.04 VMs on the same LAN as the controller.

## 1. Create a dedicated user

Don't launch agents as `root` and don't reuse a personal account. I created a locked-down `jenkins` user with `create-agent-user.sh`:

```bash
sudo useradd -m -s /bin/bash jenkins
sudo mkdir -p /home/jenkins/agent
sudo chown -R jenkins:jenkins /home/jenkins/agent
```

## 2. Java

Remoting needs a JVM on the agent matching (or close to) what the controller runs. I used Temurin 17:

```bash
sudo apt update
sudo apt install -y openjdk-17-jre-headless
java -version
```

Mismatch note: I initially had Java 11 on `agent-linux-02` while the controller was on 17. It connected but threw intermittent `UnsupportedClassVersionError` on some pipeline steps that used newer plugin code. Not immediately obvious what was wrong — worth checking `java -version` on both ends first if something's flaky.

## 3. Generate and register the controller key

Run `./generate-ssh-keys.sh` on the controller. It prompts for a passphrase; use a strong passphrase where your lab workflow allows it. When creating the Jenkins **SSH Username with private key** credential, enter the same value in the credential's **Passphrase** field. If you intentionally leave the passphrase blank, treat the private key as unencrypted and keep its filesystem permissions and Jenkins credential scope tightly restricted. The public half belongs in the agent user's `authorized_keys`; never copy the private half to the agent.

## 4. Authorize the controller's key

On the agent, as the `jenkins` user:

```bash
mkdir -p /home/jenkins/.ssh
chmod 700 /home/jenkins/.ssh
# paste the PUBLIC half of the key generated in generate-ssh-keys.sh
echo "ssh-ed25519 AAAA... jenkins-agent-key" >> /home/jenkins/.ssh/authorized_keys
chmod 600 /home/jenkins/.ssh/authorized_keys
```

`chmod` matters more than people expect — `sshd` will silently refuse to use `authorized_keys` if permissions are too open. Cost me twenty minutes the first time.

## 5. Docker (agent-linux-02 only)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker jenkins
```

Log the `jenkins` user out/in (or reboot) for the group membership to take effect — `newgrp docker` works for a quick test but doesn't persist across the SSH sessions Jenkins opens.

## 6. Firewall

Only port 22 needs to be open from the controller's IP:

```bash
sudo ufw allow from 192.168.1.50 to any port 22 proto tcp
```

Nothing else. This is the whole point of SSH-launched agents — no inbound Jenkins-specific ports on the agent at all.

## 7. Register the node

Back on the controller, follow `setup-master.md` section 2. Once saved, Jenkins should SSH in, drop `remoting.jar` into `/home/jenkins/agent/remoting/`, and bring the node online. Watch the node's log page during first connect — it tells you exactly what command it ran.
