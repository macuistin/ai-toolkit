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

Two ways to build the guest. Sections 2 to 8 describe a manual VM. The script `tools/claude-rc-lxc.sh` builds a lighter Debian 12 LXC (2 cores, 4 GB RAM, 16 GB disk by default) and does the install, MCP registration and background service for you. Sections 9 to 12 (GitHub, connecting from the Claude cloud, scheduled tasks, lessons learned) apply to both.

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

# 9. Phase F — GitHub from the guest

Do this as the Claude user, not root. Claude can then clone, branch, push and open draft pull requests from the guest.

Install the tools (the LXC script installs git; `gh` is in the Debian 12 repositories):

sudo apt install -y git gh

Set the identity used for commits. Use a name and the no-reply address GitHub shows under Settings > Emails if you do not want your real address in history.

git config --global user.name "Your Name"

git config --global user.email "ID+username@users.noreply.github.com"

Authenticate with a fine-grained personal access token, limited to the repositories Claude should touch, with Contents and Pull requests set to read and write. Save the token in a file only the Claude user can read, log in from it, then delete the file.

install -m 600 /dev/null ~/gh-token && nano ~/gh-token

gh auth login --with-token < ~/gh-token

shred -u ~/gh-token

gh auth status

Rules that save trouble:

Work on a branch and open a draft pull request. Never push to the default branch.

Before pushing from a shallow clone (git clone --depth 1), fetch the default branch first. Pushing from a stale shallow clone re-uploads the whole tree and can be rejected with HTTP 413.

Run any public-safety scan the repository provides before every push. Keep the term list outside the repository.

Cloud sessions on claude.ai get their own GitHub access through the GitHub connection in your claude.ai settings. That is separate from the token on the guest.

# 10. Connecting to the guest from the Claude cloud

A running Remote Control session shows in the Claude app and at claude.ai/code under the name you gave it (for example Home Server). Behind it is an environment of kind bridge, which is your guest. Sessions in that environment run on the guest, with its files, its network and its local MCP configuration.

Check from any Claude session that has the Claude Code Remote tools: list environments, find the one whose sessions run on the guest, and note its environment ID. Sessions that start from the web or the phone app in other environments run in Anthropic's cloud and cannot see the guest's files.

What the guest must have for cloud-driven work to succeed:

The Remote Control process running and connected (section 6, or the LXC service).

Any scripts and data the task needs, stored under the Claude user's home folder, with secrets in files readable only by that user.

Python 3.9 or later if a script uses it. On Debian, install python3 (the time zone data comes from the tzdata package, which is normally already present; if a script asks for the Python tzdata package, install it with pip in a virtual environment).

A session that is idle is fine. A session that has exited is not: a new Remote Control session is needed.

# 11. Scheduled cloud tasks that run on the guest

Use a scheduled task (called a routine or trigger in some tools) that starts a fresh session on each run in the guest's environment. The fired session is a normal Claude session on the guest, so it can run scripts, read and write files in the Claude user's home, and call read-only tools.

Settings that worked:

New session on each fire, in the bridge environment of the guest. This does not depend on any particular session staying open.

A prompt that is complete on its own. A fresh session has no memory of earlier chats, so name every file path, say what to read first, what it may write, and what to report.

A cron expression with an explicit time zone prefix, for example CRON_TZ=Europe/Dublin 30 8 * * * for 08:30 local time every day. Without the prefix, times are UTC. The service may start a run a few minutes after the stated time.

A manual test run straight after creating it. Then confirm the result on the guest (file modification time, report contents), not only in the chat summary.

Limits seen:

A scheduled task cannot wake or resume one of your other live sessions. The service refuses it unless the target session sets it up itself or you do. A fresh session per run avoids this.

Messages sent from one session to another are treated as data by the receiving session, which will not act on them as instructions. Give the instruction in the session you want to act, or use a scheduled task instead.

Some organisations cannot attach connectors to a scheduled task, so the fired session may have no connector tools. Test what a fired session can reach. If local MCP servers do not load, make the task script-based: let a script on the guest read the data and have Claude analyse the output.

A desktop-app scheduled task (the Claude desktop app's own scheduler) is a different thing. It runs only while the desktop app is open on that machine. If you move a task from one machine to another, disable or delete it on the old one so reports do not run twice.

Read-only tasks: say so at the top of the prompt, list the tools that must never be called, and keep the guest's credentials read-only where the service allows it.

# 12. Lessons learned

Secrets: never paste a URL or token into a chat. If one is pasted, rotate it. Keep secrets in files under ~/.config with mode 600, and have scripts read them from there. Do not print them in logs or reports.

A Home Assistant MCP can be reached two ways: the built-in MCP server integration (a URL plus a bearer token, as the LXC script registers) or an add-on that serves a secret URL path. If a script needs the URL, make it look in environment variables first, then a mode 600 file, then the Claude MCP configuration, and fail with a message that names the file, never the URL.

Check that a script is read-only in code, not only in the prompt. For example, an allow-list of tool names that start with a read prefix.

Run the data collection script first and let Claude read its summary. This keeps token use small and gives a fallback when MCP tools are missing.

One report file per day, named by date, so each run can compare with the last one and a repeat run on the same day is visibly an overwrite. Ask before overwriting a report you did not generate.

Container time zone is usually UTC. Use explicit time zones in scripts and cron.

Do not move files between machines by pasting their contents. Use a zip or scp, then check ownership and modes.

Keep a copy of every prompt used by a scheduled task in a file under version control, with no secrets, so you can review and re-create it.

# 13. Acceptance tests

☐  VM starts automatically after a Proxmox reboot.

☐  Claude Code is authenticated using the Claude Pro subscription, not API-key billing.

☐  A Remote Control session can be opened from the phone app and a browser.

☐  A harmless command confirms execution occurs inside the VM.

☐  The session can be used when the phone is off the home Wi-Fi.

☐  A local MCP can list permitted resources without changing anything.

☐  No inbound router port forwards are required.

☐  After a VM reboot, the documented recovery procedure successfully starts a new Remote Control session.

☐  gh auth status succeeds as the Claude user, and a test branch can be pushed and a draft pull request opened.

☐  A scheduled task with a new session per run, fired manually, writes its output file on the guest.

☐  The task's time zone prefix is set and the next run time shown matches your local time.

# 14. Troubleshooting

| **Symptom** | **Check** |
| --- | --- |
| Remote Control requires a Claude subscription | Run /login in Claude Code and choose claude.ai account authentication. Ensure API-key variables are not overriding it. |
| Remote Control command fails to connect | Check outbound HTTPS/443, DNS, system time, subscription status, and run claude remote-control --verbose. |
| Workspace not trusted | Run Claude Code interactively in the intended project directory and accept the trust prompt. |
| Session disappears | Check whether the local Claude process stopped, the VM rebooted, or the network dropped. Start a new session if needed. |
| MCP tools do not appear | Validate MCP configuration and server logs; restart Claude Code after changing MCP settings. |
| Scheduled task refused with a message about resuming another session | Create the task to start a new session on each run instead of targeting an existing session. |
| Message sent to another session was ignored | Sessions treat messages from other sessions as data. Give the instruction in the target session, or use a scheduled task. |
| Scheduled task ran but cannot see local files | It started in a cloud environment. Pick the bridge environment of the guest. |
| Script says the MCP URL is not found | Put it in a mode 600 file under ~/.config, or set the environment variable the script names. Do not paste it into chat. |
| Push rejected with HTTP 413 | Fetch the default branch into the shallow clone and rebase, then push again. |
| Run time is an hour out | The cron has no CRON_TZ prefix, or the guest and cron disagree about summer time. Set an explicit zone. |

# 15. Official references

**Claude Code Remote Control: **https://code.claude.com/docs/en/remote-control

**Use Claude Code with Pro or Max: **https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan

**Claude Code installation: **https://code.claude.com/docs/en/quickstart

**Claude Code MCP: **https://code.claude.com/docs/en/mcp

**Anthropic self-hosted environments announcement (Team/Enterprise feature, distinct from Remote Control): **https://claude.com/resources/articles/run-claude-code-sessions-on-your-own-compute

Version note: Anthropic's documentation and CLI behaviour change over time. Check the official Remote Control and installation pages on the day you install. Commands in this plan are a starting procedure; follow any newer prompts printed by the installer or CLI.

Installation plan • Reviewed 20 October 2026