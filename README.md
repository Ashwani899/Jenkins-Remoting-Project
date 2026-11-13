# Jenkins Remoting & Distributed Build Lab

A hands-on Jenkins home-lab project exploring how a controller coordinates heterogeneous build agents across Linux, Windows, and ARM environments. The repository focuses on agent connectivity, label-based scheduling, parallel execution, multi-architecture builds, and practical controller/agent security boundaries.

> **Scope:** This is a learning lab and configuration reference, not a production Jenkins deployment. Hostnames, network topology, credentials, and firewall rules must be adapted to the environment where it is reproduced.

## What the lab explores

- **Mixed agent launch strategies:** SSH-launched Linux agents, inbound/JNLP connectivity for an isolated ARM agent, and WebSocket connectivity for a Windows agent.
- **Label-based workload placement:** Pipeline stages target labels such as `linux`, `docker`, `arm`, and `windows`.
- **Parallel distributed execution:** Independent stages run across eligible agents instead of being serialized on a single worker.
- **Multi-architecture build flow:** Separate x86_64 and ARM-labelled agents build binaries; artifacts are then collected and archived.
- **Security and isolation:** Unprivileged agent accounts, scoped credentials, agent-to-controller access control, dedicated SSH keys, and constrained inbound connectivity.

## Repository map

| Path | Purpose |
|---|---|
| `Jenkinsfile.label-based` | Demonstrates routing work to agents through labels |
| `Jenkinsfile.multiarch` | Parallel x86_64 / ARM build and artifact collection |
| `Jenkinsfile.parallel-distributed` | Example of parallel work distributed across agent labels |
| `architecture.md` | Controller/agent topology and SSH, inbound, and WebSocket trade-offs |
| `security-hardening.md` | Agent isolation, credential scope, keys, and network controls |
| `setup-master.md` | Controller setup notes |
| `setup-agent-ssh.md` | SSH-launched agent setup |
| `setup-agent-jnlp.md` | Inbound agent setup |
| `troubleshooting.md` | Operational debugging notes |
| `scripts/` | Helper scripts for agent users, keys, installation, and registration |

## Architecture at a glance

```text
                         Jenkins controller
                         /       |        \
                       SSH    WebSocket   Inbound
                       /         |          \
                Linux agents  Windows agent  ARM agent
                      \          |          /
                       Label-based pipelines
                                |
                    Parallel build / test stages
                                |
                    Stashed and archived artifacts
```

The lab deliberately mixes connection modes because real environments can include workers on the same LAN, hosts behind NAT, and machines on segmented networks. See [architecture.md](architecture.md) for the detailed topology and assumptions.

## Security practices documented

The accompanying security notes describe the controls used in this lab:

- Agents run under unprivileged operating-system accounts.
- SSH agent access uses a dedicated key rather than a personal key.
- Agent-to-controller access control remains enabled; broad exceptions are avoided.
- The inbound agent port is fixed and restricted by network rules in the lab.
- Windows connectivity uses WebSocket to avoid exposing another inbound port.
- Credentials are scoped to the folders or jobs that need them.
- SSH host-key checking and HTTPS at the controller reverse proxy are retained.

These are lab configuration notes, not a security certification. Review the Jenkins version, plugins, network design, secrets handling, and threat model before reusing any configuration.

## Reproducing the lab

1. Set up a Jenkins controller and install the required agent and pipeline plugins.
2. Prepare separate Linux, Windows, and ARM workers, or adapt the labels to the machines available.
3. Configure the selected launch method for each worker.
4. Create matching node labels and executor settings.
5. Review the sample Jenkinsfiles and substitute your own build commands.
6. Apply the security controls described in [security-hardening.md](security-hardening.md).
7. Run a pipeline and inspect the console output and archived artifacts.

The repository includes configuration and helper scripts, but it does not include a portable, preconfigured Jenkins controller or reusable credentials. Do not commit agent secrets, private keys, real hostnames, or home-network details.

## Current limitations and next improvements

- Replace manual node registration with Jenkins Configuration as Code (JCasC).
- Define a repeatable controller bootstrap and plugin-version strategy.
- Add sanitized screenshots or build logs only after capturing them from a real run.
- Add a reproducible test plan for agent reconnection, offline workers, and failed parallel stages.
- Rotate lab SSH keys and use an external secrets manager for deployments beyond a personal lab.

## License

See [LICENSE](LICENSE).
