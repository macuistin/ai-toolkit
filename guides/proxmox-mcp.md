# Proxmox MCP for a Claude Code LXC

Give Claude Code read-only access to your Proxmox VE node through the ProxmoxMCP-Plus MCP server, from the Claude LXC set up in [claude-remote-control-proxmox.md](claude-remote-control-proxmox.md).

Reviewed 30 October 2026 against Proxmox VE 9 and ProxmoxMCP-Plus 0.6.8. Check the project pages on the day you install.

## What you get

- Claude can list nodes, guests, storage, snapshots, logs and tasks, and answer questions about them.
- It cannot change anything. The API token is read-only, and the server only offers inspection tools.
- Nothing listens on a network port. Claude Code starts the server as a subprocess and talks to it over stdio.

## Where each command runs

There are two places, and every command block below says which one:

| Place | What runs there |
| --- | --- |
| **Proxmox node** (root shell on the host) | `tools/proxmox-mcp-host-setup.sh`, and anything that uses `pveum` or `pct` |
| **Claude LXC** (shell of the user that runs Claude Code) | `tools/proxmox-mcp-lxc-install.sh`, the MCP server itself, and Claude Code |

The only thing that moves between the two is the API token secret. It is shown once on the node and pasted into the installer prompt in the LXC.

```text
Claude Code  ->  MCP server (stdio, in the LXC)  ->  Proxmox API  https://<pve-host>:8006
                                                     (token: read-only role)
```

The LXC holds the token. The Proxmox node decides what the token may do. If the LXC or the server misbehaves, the token's role still limits the damage.

## Which server

Checked on 30 October 2026. Stars change daily.

| Server | Licence | Stars | Notes |
| --- | --- | --- | --- |
| [ProxmoxMCP-Plus](https://github.com/RekklesNA/ProxmoxMCP-Plus) | MIT | about 409 | Best maintained. Tool allowlist and denylist, command policy, approval tokens. Install with `uvx`, pip or Docker. |
| [GethosTheWalrus/proxmox-mcp](https://github.com/GethosTheWalrus/proxmox-mcp) | Apache-2.0 | about 212 | About 205 tools. Read-only mode is off by default, so set `PROXMOX_READ_ONLY=true`. |
| [Samik081/mcp-pve](https://github.com/Samik081/mcp-pve) | MIT | about 24 | Three access tiers. Tested on Proxmox VE 9.2.4. The default tier is `full`. |

This guide uses ProxmoxMCP-Plus. Avoid servers that need root SSH to the host or `root@pam` with privilege separation off: a prompt injection in a log line or guest note could then do anything.

All three are free and open source. There is no paid tier.

## Step 1: create the token (Proxmox node)

Copy `tools/proxmox-mcp-host-setup.sh` to the node and run it as root. Replace `<ctid>` with the container ID of the Claude LXC.

```bash
CLAUDE_CTID=<ctid> bash proxmox-mcp-host-setup.sh
```

The script:

- creates the user `mcp@pve`
- creates a privilege-separated token called `claude`, so its rights are the intersection of the user's and the token's
- grants both the built-in read-only `PVEAuditor` role on `/`
- sets the protection flag on the Claude LXC, so it cannot be deleted or rolled back from under the session

The token secret is printed once. Copy it now. It cannot be shown again. To get a new one, remove the token with `pveum user token remove mcp@pve claude` and run the script again.

## Step 2: copy the Proxmox CA into the LXC (Proxmox node)

The installer verifies TLS against the node's own certificate authority. Run this on the node:

```bash
pct exec <ctid> -- mkdir -p /usr/local/share/ca-certificates
pct push <ctid> /etc/pve/pve-root-ca.pem /usr/local/share/ca-certificates/pve-root-ca.crt
```

The hostname or IP you give the installer must be covered by the node's certificate. If it is not, the API test fails with a TLS error.

If you cannot supply the CA, run the installer with `INSECURE_TLS=1`. That turns off verification, so use it only on a trusted LAN.

## Step 3: run the installer (Claude LXC)

Find out which user runs Claude Code in the LXC. If Claude is started by a service or a tmux loop, it is usually a dedicated user, not root. Check with:

```bash
ps aux | grep -i '[c]laude'
```

Run the installer as that user, from its home folder. Claude Code reads its MCP servers from the home folder of the user running it, so an install made as another user is invisible to Claude.

```bash
bash ~/proxmox-mcp-lxc-install.sh
```

Send this as a single command, not pasted together with others. The installer reads the host and the token secret from the terminal, and extra pasted lines become the answers.

The installer:

- tests the API with your token before installing anything
- installs `uv` if it is missing
- pins the latest `proxmox-mcp-plus` release from PyPI
- writes the connection settings to `~/.config/proxmox-mcp/env` with mode 600
- creates a small wrapper script, so the secret stays out of Claude's own configuration
- registers the server with `claude mcp add --scope user`

## Step 4: check it works (Claude LXC)

```bash
claude mcp list
```

`proxmox` should show as connected.

Sessions that were already running do not see the new server. Start a fresh session and ask:

> List my Proxmox nodes and guests

If you run Claude through Remote Control, each session is a separate process started by the loop, so a new session picks the server up. If `proxmox` is missing there, check that the sessions run as the same user you installed for.

## Widen access later

Start read-only and use it for a while. When you want more, change both sides:

1. On the node, grant the token extra privileges, ideally on a resource pool of guests you choose, not on `/`. On Proxmox VE 9, `VM.Monitor` no longer exists. Use `Sys.Audit` and the `VM.GuestAgent.*` privileges.
2. In the LXC, add the matching tools to `MCP_TOOL_ALLOWLIST` in `~/.config/proxmox-mcp/env`, for example `create_snapshot,start_vm,stop_vm`.

Keep the DNS server, the home automation guest and the Claude LXC itself out of any pool Claude can change. Restarting your DNS server in the middle of a session cuts off everything, including the MCP connection.

Keep Claude Code's per-tool approval prompts on for every tool that changes something.

## Security notes

- The token is the real safety boundary. Allowlists and tiers reduce mistakes, but they will not stop a prompt injection if the token is over-privileged.
- Keep the token in a mode 600 file under `~/.config`, outside any Git repository. Never paste it into a chat. If you do, delete the token and create a new one.
- Do not add the optional `ssh` section to the server configuration unless you want in-guest command execution.
- Pin the server version. The project releases several times a week, and the installer pins the version that was current when you ran it. To upgrade, run it again with `PMP_VERSION=<version>`.
- No independent security audit of any Proxmox MCP server was found. Read the project's security guide before exposing anything beyond stdio.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `claude: command not found` in the LXC | Claude Code is not installed for the user you are logged in as. Find the user that runs it with `ps aux`, and use that user's shell. |
| `proxmox` is not in `claude mcp list` after the installer | The installer did not finish. A common cause is pasting several commands at once. Run it again on its own. |
| `proxmox` shows in `claude mcp list` but not in a running session | Start a new session. Running sessions do not reload MCP servers. |
| API test fails with a TLS error | The CA file is missing, or the hostname you entered is not in the node's certificate. |
| API test returns 401 or 403 | Wrong token ID or secret, or the ACLs were not applied. Run the node script again. |
| Server fails to start with an unknown tool name | `MCP_TOOL_ALLOWLIST` has a typo. The server refuses to start rather than widen access. Check the tool names in the project README. |
| `update-ca-certificates failed` note | Harmless as a non-root user. The server uses the CA file directly. |

## References

- ProxmoxMCP-Plus: https://github.com/RekklesNA/ProxmoxMCP-Plus
- Proxmox VE user management and API tokens: https://pve.proxmox.com/wiki/User_Management
- Claude Code MCP: https://code.claude.com/docs/en/mcp
