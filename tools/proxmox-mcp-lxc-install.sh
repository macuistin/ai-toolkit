#!/usr/bin/env bash
# Run inside the Claude LXC as the user that runs Claude Code (NOT root, unless Claude
# runs as root): the config and the MCP registration live in that user's home folder.
# Run it on its own, not pasted together with other commands: it reads prompts from the terminal.
# Installs ProxmoxMCP-Plus (pinned), stores the token in a chmod-600 env file,
# and registers it with Claude Code as a READ-ONLY server (tool allowlist).
set -euo pipefail

PVE_HOST="${PVE_HOST:-}"                 # hostname or IP of the Proxmox node
PVE_PORT="${PVE_PORT:-8006}"
PVE_USER="${PVE_USER:-mcp@pve}"
PVE_TOKEN_NAME="${PVE_TOKEN_NAME:-claude}"
PMP_VERSION="${PMP_VERSION:-}"           # leave empty to pin the latest PyPI release
INSECURE_TLS="${INSECURE_TLS:-0}"        # 1 = allow verify_ssl=false if no CA is installed

CONF_DIR="$HOME/.config/proxmox-mcp"
ENV_FILE="$CONF_DIR/env"
WRAPPER="$HOME/.local/bin/proxmox-mcp-plus-run"
CA_SRC="/usr/local/share/ca-certificates/pve-root-ca.crt"

# Read-only allowlist. Widen later (see end of script).
ALLOWLIST="get_nodes,get_cluster_status,get_storage,get_vms,get_containers,list_snapshots,get_node_syslog,get_cluster_log,get_task_log,get_node_firewall_log,get_guest_firewall_log,list_jobs,get_job"

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null    || die "curl is required"
command -v python3 >/dev/null || die "python3 is required (used to read PyPI JSON)"

if [[ -z "$PVE_HOST" ]]; then
  read -r -p "Proxmox node hostname or IP: " PVE_HOST
fi
[[ -n "$PVE_HOST" ]] || die "PVE_HOST is required"

read -r -s -p "API token secret for ${PVE_USER}!${PVE_TOKEN_NAME} (input hidden): " TOKEN_VALUE
echo
[[ -n "$TOKEN_VALUE" ]] || die "token secret is required"

# --- TLS ---------------------------------------------------------------------
VERIFY_SSL="true"
CURL_TLS=()
if [[ -f "$CA_SRC" ]]; then
  say "Installing Proxmox CA into the system trust store"
  command -v update-ca-certificates >/dev/null && update-ca-certificates >/dev/null 2>&1 || \
    echo "note: update-ca-certificates failed (needs root); using the CA file directly."
  CA_BUNDLE="$CA_SRC"
  CURL_TLS=(--cacert "$CA_SRC")
elif [[ "$INSECURE_TLS" == "1" ]]; then
  say "No CA found: TLS verification DISABLED (INSECURE_TLS=1)"
  VERIFY_SSL="false"
  CA_BUNDLE=""
  CURL_TLS=(-k)
else
  die "No Proxmox CA at $CA_SRC. Copy /etc/pve/pve-root-ca.pem from the host to that path (as pve-root-ca.crt), or re-run with INSECURE_TLS=1."
fi

# --- connectivity smoke test (before installing anything) --------------------
say "Testing API access"
HTTP_CODE=$(curl -sS "${CURL_TLS[@]}" -o /tmp/pve-version.json -w '%{http_code}' \
  -H "Authorization: PVEAPIToken=${PVE_USER}!${PVE_TOKEN_NAME}=${TOKEN_VALUE}" \
  "https://${PVE_HOST}:${PVE_PORT}/api2/json/version") || die "could not reach https://${PVE_HOST}:${PVE_PORT} (network, DNS or TLS; the cert must match the host you entered)"
[[ "$HTTP_CODE" == "200" ]] || die "API returned HTTP $HTTP_CODE (check token id/secret and that the ACLs were applied)"
rm -f /tmp/pve-version.json
echo "API reachable, token accepted."

# --- uv ----------------------------------------------------------------------
if ! command -v uv >/dev/null && ! command -v uvx >/dev/null; then
  say "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
command -v uvx >/dev/null || die "uvx not found after install; open a new shell and re-run"

# --- pin version --------------------------------------------------------------
if [[ -z "$PMP_VERSION" ]]; then
  say "Resolving latest proxmox-mcp-plus on PyPI"
  PMP_VERSION=$(curl -fsS https://pypi.org/pypi/proxmox-mcp-plus/json | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')
fi
echo "Pinned version: $PMP_VERSION"

# --- secrets / config (chmod 600, outside any repo) ---------------------------
say "Writing $ENV_FILE"
mkdir -p "$CONF_DIR" "$HOME/.local/bin"
umask 077
cat > "$ENV_FILE" <<EOF
PROXMOX_HOST=${PVE_HOST}
PROXMOX_PORT=${PVE_PORT}
PROXMOX_USER=${PVE_USER}
PROXMOX_TOKEN_NAME=${PVE_TOKEN_NAME}
PROXMOX_TOKEN_VALUE=${TOKEN_VALUE}
PROXMOX_VERIFY_SSL=${VERIFY_SSL}
MCP_TOOL_ALLOWLIST=${ALLOWLIST}
EOF
[[ -n "${CA_BUNDLE:-}" ]] && echo "REQUESTS_CA_BUNDLE=${CA_BUNDLE}" >> "$ENV_FILE"
chmod 600 "$ENV_FILE"

# Wrapper keeps the secret out of Claude's own config (~/.claude.json)
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set -a
. "$ENV_FILE"
set +a
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"
exec uvx "proxmox-mcp-plus==${PMP_VERSION}"
EOF
chmod 700 "$WRAPPER"

# --- warm the uv cache so the first Claude start isn't slow --------------------
say "Pre-fetching proxmox-mcp-plus==${PMP_VERSION}"
uvx --from "proxmox-mcp-plus==${PMP_VERSION}" python -c "import proxmox_mcp; print('import ok')" || \
  echo "note: pre-fetch import check failed; the server may still start. Check with: claude mcp list"

# --- register with Claude Code -------------------------------------------------
if command -v claude >/dev/null; then
  say "Registering with Claude Code (user scope)"
  claude mcp remove proxmox --scope user >/dev/null 2>&1 || true
  claude mcp add --scope user proxmox -- "$WRAPPER"
  claude mcp list || true
else
  echo
  echo "Claude Code CLI not found on PATH. Register manually:"
  echo "  claude mcp add --scope user proxmox -- $WRAPPER"
fi

cat <<EOF

Done.
  Config:   $ENV_FILE (chmod 600)
  Wrapper:  $WRAPPER
  Version:  proxmox-mcp-plus==${PMP_VERSION}
  Mode:     read-only tool allowlist, PVEAuditor token

Try in Claude Code:  "List my Proxmox nodes and guests"

To widen access later: edit MCP_TOOL_ALLOWLIST in $ENV_FILE (e.g. add
create_snapshot,start_vm,stop_vm) AND grant the token the matching PVE privileges.
If startup fails on an unknown tool name, the allowlist has a typo: check the
tool table in the project README. To upgrade, re-run with PMP_VERSION=x.y.z.
EOF
