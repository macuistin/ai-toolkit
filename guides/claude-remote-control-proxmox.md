PROXMOX HOMELAB  |  CLAUDE CODE REMOTE CONTROL

**Claude Code Remote Control**

Installation plan for a dedicated, always-on Proxmox VM

Purpose: run Claude Code on a dedicated machine in the home network, then control that local session from the Claude mobile app or claude.ai/code. The goal is to let Claude use local files and configured MCP servers to inspect and, with carefully limited permissions, administer selected homelab services.

# 1. What this plan does — and does not do

Uses your existing Claude Pro subscription. Claude Code Remote Control is documented as available on Pro, Max, Team and Enterprise plans.

Runs the Claude Code process and tool execution locally on the Proxmox guest. The phone/browser is a remote interface to that session.

Uses outbound HTTPS to Anthropic; do not port-forward Proxmox, SSH, or a web terminal from the internet.

Keeps local MCP configuration and local network access on the guest, subject to the permissions you configure.

Is not Anthropic's separate Team/Enterprise 'self-hosted environments' feature. Remote Control sessions stop responding if the local Claude Code process stops; this is not a managed job queue or guaranteed autonomous service.

Official references: https://code.claude.com/docs/en/remote-control  |  https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan

# 2. Recommended design

| **Component** | **Starting configuration** |
| --- | --- |
| Proxmox guest | Dedicated Debian 12 or supported Ubuntu LTS VM; use a VM for straightforward isolation and compatibility. |
| VM name | claude-runner |
| CPU / memory | 4 vCPU / 8 GB RAM |
| Disk | 64 GB virtual disk; thin provisioned if appropriate for your storage |
| Network | Bridged LAN with DHCP reservation/static lease; outbound internet access |
| Access | SSH from LAN only; no router port forwards |
| Claude session | Claude Code Remote Control, launched as a non-root user in a trusted working directory |
| MCP access | Start with read-only Proxmox information; add Home Assistant and other services only after testing |

These are practical initial allocations, not Anthropic's official minimums. A lighter VM may work, but 4 vCPU / 8 GB / 64 GB leaves room for MCP clients, logs and future tooling.

# 3. Phase A — Create the VM in Proxmox

Download a current Debian 12 or supported Ubuntu LTS ISO from the official distribution site.

In Proxmox, select Create VM. Name it claude-runner and attach the ISO.

Allocate 4 vCPU, 8 GB RAM and a 64 GB disk. Use the normal LAN bridge (commonly vmbr0).

Install Linux with a minimal server profile. Create a normal user for Claude Code and a separate admin account or sudo access for maintenance.

Apply a DHCP reservation in your router, or configure a static address appropriate to your LAN.

Enable the VM's Start at boot option in Proxmox.

After installation, update packages and reboot.

sudo apt update

sudo apt full-upgrade -y

sudo apt install -y curl ca-certificates git tmux

sudo reboot

Do not install Claude Code as root. Do not expose SSH or the Proxmox UI directly to the internet.

# 4. Phase B — Install and authenticate Claude Code

Log in over the VM console or SSH as the dedicated non-root user. Install Claude Code using Anthropic's official installer:

curl -fsSL https://claude.ai/install.sh | bash

If the installer says the claude command is not on PATH, follow its printed instructions or start a new shell. Verify:

claude --version

claude doctor

Start Claude Code and authenticate with the same Claude account used for your Pro subscription. Use the claude.ai subscription login, not an API key, because Remote Control does not support API-key authentication.

claude

# At the Claude Code prompt, use:

/login

If an ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN is set in the environment, shell profile, or Claude settings, it may override subscription authentication. Check and remove it if you intend to use Pro-plan usage.

printenv | grep -E '^ANTHROPIC_(API_KEY|AUTH_TOKEN|BASE_URL)=' || true

# 5. Phase C — Start a Remote Control session

Remote Control should be started from a working directory that you intend Claude to access. Do not start it from /, the Proxmox host filesystem, or a directory containing unrelated secrets.

mkdir -p ~/homelab-work

cd ~/homelab-work

git init

claude remote-control --name "Home Server" 

On first use, accept the Remote Control confirmation and the workspace trust prompt. The command should display a session URL. Press Space if the terminal offers a QR code. On your phone, open the URL or the Claude app, then find the 'Home Server' session. You can also use https://claude.ai/code.

Test with low-risk commands first: ask Claude to report the guest hostname, uptime and current directory. Confirm the command is running on the VM, not on the phone.

# 6. Phase D — Keep the session available

Remote Control is a local process, not a cloud-hosted always-on worker. The VM must remain powered on and the Claude Code process must remain running. If the process exits, the remote session stops responding. Start with tmux for a simple, observable setup:

sudo apt install -y tmux

tmux new -s claude-remote

cd ~/homelab-work

claude remote-control --name "Home Server"

# Detach from tmux with Ctrl+B, then D

# Reattach later with:

tmux attach -t claude-remote

Important: tmux helps the process survive an SSH disconnect; it does not automatically restart the process after a crash or reboot. First prove that login, trust prompts and Remote Control work reliably. Then decide whether to create a systemd user service. Do not assume a blind systemd service will work: interactive authentication, workspace trust and session lifecycle need testing. After configuring any supervisor, reboot the VM and verify that a fresh Remote Control session is available.

# 7. Phase E — Configure local MCP access safely

Add MCP servers only after the phone-to-VM session works. Claude Code's MCP configuration is documented at https://code.claude.com/docs/en/mcp.

Start with one read-only Proxmox MCP server. Create a dedicated Proxmox API user and token with the minimum permissions required; never use root@pam credentials.

Keep API secrets in a protected configuration or environment file readable only by the Claude user. Do not commit secrets to Git.

Register the MCP server using its own documented installation/configuration instructions. Verify its tool list and test read-only queries first.

Add Home Assistant only after Proxmox read-only access works. Prefer a restricted token and a small set of allowed actions.

For Docker, media services, or shell administration, expose narrowly scoped commands or APIs rather than unrestricted root SSH.

Keep write operations disabled or require approval until the read-only setup has been tested thoroughly.

The exact MCP package and command should be selected after checking its current maintenance status and documentation. Do not blindly copy a community MCP command into a privileged host shell.

# 8. Security baseline

Use a dedicated VM and a non-root Claude user.

Do not expose Proxmox's web UI, SSH, or a browser terminal to the public internet.

Allow only required outbound traffic; Remote Control needs outbound HTTPS access to Anthropic.

Do not provide Proxmox root credentials, broad SSH keys, or unrestricted access to the whole LAN.

Use read-only MCP permissions first; separate read and write credentials if the tool supports it.

Require explicit approval for deleting resources, changing network/storage, upgrading hosts, or running destructive commands.

Keep the OS and Claude Code updated, and review logs after testing.

Take a Proxmox backup/snapshot before changing the VM's authentication, service supervision, or MCP configuration.

# 9. Acceptance tests

☐  VM starts automatically after a Proxmox reboot.

☐  Claude Code is authenticated using the Claude Pro subscription, not API-key billing.

☐  A Remote Control session can be opened from the phone app and a browser.

☐  A harmless command confirms execution occurs inside the VM.

☐  The session can be used when the phone is off the home Wi-Fi.

☐  A local MCP can list permitted resources without changing anything.

☐  No inbound router port forwards are required.

☐  After a VM reboot, the documented recovery procedure successfully starts a new Remote Control session.

# 10. Troubleshooting

| **Symptom** | **Check** |
| --- | --- |
| Remote Control requires a Claude subscription | Run /login in Claude Code and choose claude.ai account authentication. Ensure API-key variables are not overriding it. |
| Remote Control command fails to connect | Check outbound HTTPS/443, DNS, system time, subscription status, and run claude remote-control --verbose. |
| Workspace not trusted | Run Claude Code interactively in the intended project directory and accept the trust prompt. |
| Session disappears | Check whether the local Claude process stopped, the VM rebooted, or the network dropped. Start a new session if needed. |
| MCP tools do not appear | Validate MCP configuration and server logs; restart Claude Code after changing MCP settings. |

# 11. Official references

**Claude Code Remote Control: **https://code.claude.com/docs/en/remote-control

**Use Claude Code with Pro or Max: **https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan

**Claude Code installation: **https://code.claude.com/docs/en/quickstart

**Claude Code MCP: **https://code.claude.com/docs/en/mcp

**Anthropic self-hosted environments announcement (Team/Enterprise feature, distinct from Remote Control): **https://claude.com/resources/articles/run-claude-code-sessions-on-your-own-compute

Version note: Anthropic's documentation and CLI behaviour change over time. Check the official Remote Control and installation pages on the day you install. Commands in this plan are a starting procedure; follow any newer prompts printed by the installer or CLI.

Installation plan • Reviewed 20 October 2026