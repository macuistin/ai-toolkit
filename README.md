# ai-toolkit

Claude Code and Cowork plugins, skills, setup guides and scripts for AI-assisted work.

## Install a plugin

```bash
claude plugin marketplace add <owner>/ai-toolkit
claude plugin install second-brain@ai-toolkit
```

## What's in the repo

| Path | What it is |
|------|------------|
| `plugins/second-brain/` | Second brain plugin for an Obsidian vault: capture, tag-first search, calendar and email sync, daily briefs, distillation |
| `guides/` | Step-by-step setup guides, such as running Claude Code Remote Control on a Proxmox LXC |
| `tools/claude-rc-lxc.sh` | Proxmox host script that builds a Debian LXC running Claude Code Remote Control as a background service |
| `tools/check-public.sh` | Public-safety scan used before every push |

## Requirements

- Claude Code, or Claude Desktop with Cowork
- A Claude plan that includes Claude Code. Check the current plan rules before you start.
- For the second brain: an Obsidian vault on the machine running the plugin, and calendar and mail connectors if you want those skills

## Privacy

- Plugins read and write only the folders you point them at.
- Email and calendar skills are read-only. Drafts are created only after you approve the text, and nothing is sent.
- Message bodies and attendee addresses are not stored in the vault.
- Your own config (for example `config/sources.json`) is git-ignored and must never be committed.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report security issues as described in [SECURITY.md](SECURITY.md).

## Licence

MIT. See [LICENSE](LICENSE).
