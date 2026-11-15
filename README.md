# Jenkins Remoting & Distributed Build Lab

A hands-on Jenkins home-lab project exploring how a controller coordinates heterogeneous build agents across Linux, Windows, and ARM environments. The repository focuses on agent connectivity, label-based scheduling, parallel execution, multi-architecture build examples, and practical controller/agent security boundaries.

> **Scope:** This is a learning lab and configuration reference, not a production Jenkins deployment. The checked-in Jenkinsfiles are examples; the repository CI does not execute them on a live Jenkins controller.

## What the lab explores

- **Mixed agent launch strategies:** SSH-launched Linux agents, inbound/WebSocket connectivity for ARM and Windows agents.
- **Label-based workload placement:** Pipeline examples target labels such as `linux`, `docker`, `arm`, and `windows`.
- **Parallel distributed execution:** Independent stages are assigned to eligible agents.
- **Multi-architecture build example:** x86_64 and ARM-labelled agents build artifacts that are collected by a packaging stage.
- **Security and isolation:** Unprivileged agent accounts, scoped credentials, agent-to-controller access control, dedicated SSH keys, and restricted inbound connectivity.

## Repository map

| Path | Purpose |
|---|---|
| `Jenkinsfile.label-based` | Demonstrates routing work to agents through labels |
| `Jenkinsfile.multiarch` | Parallel x86_64 / ARM build and artifact collection |
| `Jenkinsfile.parallel-distributed` | Example of parallel work distributed across agent labels |
| `architecture.md` | Controller/agent topology and connection-mode trade-offs |
| `security-hardening.md` | Agent isolation, credential scope, keys, and network controls |
| `setup-master.md` | Controller setup notes |
| `setup-agent-ssh.md` | SSH-launched agent setup |
| `setup-agent-jnlp.md` | Inbound agent setup |
| `troubleshooting.md` | Operational debugging notes |
| `create-agent-user.sh` | Creates an unprivileged Linux agent account |
| `generate-ssh-keys.sh` | Generates a dedicated controller-to-agent SSH key |
| `install-agent-ubuntu.sh` | Installs an inbound agent as a systemd service |
| `install-agent-windows.ps1` | Starts an inbound agent on Windows |
| `register-node-cli.groovy` | Example Script Console node registration |

All helper scripts are in the repository root; there is no `scripts/` or `docs/` subdirectory.

## Architecture at a glance

```text
                         Jenkins controller
                         /       |        \\
                       SSH    WebSocket   Inbound
                       /         |          \\
                Linux agents  Windows agent  ARM agent
                      \\          |          /
                       Label-based pipelines
                                |
                    Parallel build / test stages
                                |
                    Stashed and archived artifacts
```

See [architecture.md](architecture.md) for the detailed topology and assumptions.

## Security notes

- Run agents as unprivileged operating-system users.
- Use a dedicated SSH key and retain host-key verification. The key helper prompts for a passphrase; store the same passphrase in the Jenkins SSH credential. A blank passphrase is an explicit lab convenience, not the preferred default.
- Keep agent-to-controller access control enabled.
- Restrict inbound connectivity and scope Jenkins credentials to the jobs that need them.
- Use HTTPS with a valid certificate for inbound agent connections.

The Linux bootstrap now stores the agent token in a root-owned, mode-0600 environment file instead of writing the token into a world-readable systemd unit. The Java agent still receives the token as a command-line argument, so local process inspection remains a consideration. The Windows bootstrap also passes the token to the Java process as an argument.

Both inbound bootstrap scripts require HTTPS by default. An explicit HTTP opt-in exists only for isolated, trusted lab networks; HTTP exposes the agent token to network observers. Do not use that option on public, shared, or untrusted networks.

These are learning-lab controls, not a security certification. Review Jenkins versions, plugins, network design, secrets handling, and the threat model before reusing any configuration.

## Reproducing the lab

1. Set up a Jenkins controller and install the required agent and pipeline plugins.
2. Prepare separate Linux, Windows, and ARM workers, or adapt the labels to available machines.
3. Configure the selected launch method for each worker.
4. Create matching node labels and executor settings.
5. Review the sample Jenkinsfiles and substitute your own build commands.
6. Apply the controls described in [security-hardening.md](security-hardening.md).
7. Run a pipeline on your controller and inspect its console output and archived artifacts.

The repository does not include a portable, preconfigured Jenkins controller or reusable credentials. Do not commit agent secrets, private keys, real hostnames, or home-network details.

## Automated checks and limitations

GitHub Actions checks shell-script syntax and parses the Windows PowerShell bootstrap script. These checks do not run Jenkins, validate Jenkins plugin compatibility, or execute the Jenkinsfiles on real agents. A reproducible controller test plan for agent reconnection, offline workers, and failed parallel stages remains future work.

## Next improvements

- Replace manual node registration with Jenkins Configuration as Code (JCasC).
- Define a repeatable controller bootstrap and plugin-version strategy.
- Add a controller-backed pipeline validation job.
- Rotate lab SSH keys and use an external secrets manager for deployments beyond a personal lab.

## License

See [LICENSE](LICENSE).
