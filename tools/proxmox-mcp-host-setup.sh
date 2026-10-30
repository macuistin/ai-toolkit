#!/usr/bin/env bash
# Run on the Proxmox host as root.
# Creates a read-only API token for ProxmoxMCP-Plus and protects the Claude LXC.
# Usage: CLAUDE_CTID=<id of the Claude LXC> bash proxmox-mcp-host-setup.sh
set -euo pipefail

CLAUDE_CTID="${CLAUDE_CTID:-}"
PVE_USER="mcp@pve"
TOKEN_NAME="claude"

[[ $EUID -eq 0 ]] || { echo "Run as root on the Proxmox host." >&2; exit 1; }
command -v pveum >/dev/null || { echo "pveum not found: run this on the Proxmox host." >&2; exit 1; }

if [[ -z "$CLAUDE_CTID" ]]; then
  read -r -p "Container ID of the Claude LXC (shown in the Proxmox UI): " CLAUDE_CTID
fi
[[ "$CLAUDE_CTID" =~ ^[0-9]+$ ]] || { echo "CLAUDE_CTID must be a number." >&2; exit 1; }
pct status "$CLAUDE_CTID" >/dev/null 2>&1 || { echo "No container with ID $CLAUDE_CTID on this node." >&2; exit 1; }

# 1. Dedicated user (no shell, no password)
if pveum user list | grep -q "$PVE_USER"; then
  echo "User $PVE_USER already exists, skipping."
else
  pveum user add "$PVE_USER" --comment "Claude MCP (read-only)"
fi

# 2. Privilege-separated token (effective rights = user ACL AND token ACL)
if pveum user token list "$PVE_USER" 2>/dev/null | grep -q "$TOKEN_NAME"; then
  echo "Token $PVE_USER!$TOKEN_NAME already exists. Not recreating (secret is only shown once)."
  echo "To rotate: pveum user token remove $PVE_USER $TOKEN_NAME  and re-run."
else
  echo
  echo "=== COPY THE 'value' BELOW NOW: it is shown only once ==="
  pveum user token add "$PVE_USER" "$TOKEN_NAME" --privsep 1
  echo "=========================================================="
fi

# 3. Read-only everywhere (PVEAuditor), for both the user and the token
pveum acl modify / --users "$PVE_USER" --roles PVEAuditor
pveum acl modify / --tokens "${PVE_USER}!${TOKEN_NAME}" --roles PVEAuditor

# 4. Protect the Claude LXC so it can't be deleted or rolled back from under the session
pct set "$CLAUDE_CTID" --protection 1
echo
echo "Done. Token ID to use in the LXC: ${PVE_USER}!${TOKEN_NAME}"
echo "LXC $CLAUDE_CTID protection flag set."
echo
echo "Optional: for TLS verification, copy /etc/pve/pve-root-ca.pem to the LXC at"
echo "/usr/local/share/ca-certificates/pve-root-ca.crt before running the LXC installer."
