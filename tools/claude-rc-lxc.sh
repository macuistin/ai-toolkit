#!/usr/bin/env bash
# ==============================================================================
# claude-rc-lxc.sh
# Builds a Debian 12 LXC on Proxmox VE that runs Claude Code Remote Control as a
# background service, with a Home Assistant MCP server registered for Claude.
#
# Run on the Proxmox HOST as root.
#
#   bash claude-rc-lxc.sh                    Interactive install (recommended first run)
#   bash claude-rc-lxc.sh --default          Unattended install; values from env vars
#   bash claude-rc-lxc.sh enable  <CTID>     Start the background service (after first-run prompts)
#   bash claude-rc-lxc.sh update  <CTID>     Update OS packages, Claude Code, restart service
#   bash claude-rc-lxc.sh status  <CTID>     Show service and MCP status
#   bash claude-rc-lxc.sh --help
#
# Options:
#   --token-file PATH   Read the Home Assistant token from a file (must be chmod 600/400)
#
# Environment variables (all optional; defaults shown in brackets):
#   CTID [next free]          CT_HOSTNAME [claude-runner]   CT_CORES [2]
#   CT_RAM_MB [4096]          CT_DISK_GB [16]               CT_BRIDGE [vmbr0]
#   CT_ROOTFS_STORE [local-lvm]   CT_TMPL_STORE [local]
#   HA_URL [http://homeassistant.local:8123/mcp_server/sse] HA_TRANSPORT [sse]
#   HA_TOKEN (required for --default unless --token-file is given)
#   RC_NAME [Home Server]
#   GIT_NAME, GIT_EMAIL (optional; set both to configure git commits for the claude user)
#
# Log: /var/log/claude-rc-lxc.log
#
# Community-scripts conventions (prompts with defaults, status lines, re-run safety).
# Not affiliated with the community-scripts project.
# ==============================================================================
set -Eeuo pipefail

# ------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------
RD='\e[31m'; GN='\e[32m'; YW='\e[33m'; BL='\e[34m'; CL='\e[0m'
msg_info()  { echo -e "${BL}[INFO]${CL}  $*"; }
msg_ok()    { echo -e "${GN}[ OK ]${CL}  $*"; }
msg_warn()  { echo -e "${YW}[WARN]${CL}  $*"; }
msg_error() { echo -e "${RD}[FAIL]${CL}  $*" >&2; }
die()       { msg_error "$*"; exit 1; }

LOG_FILE=/var/log/claude-rc-lxc.log
SCRIPT_URL=https://raw.githubusercontent.com/macuistin/ai-toolkit/main/tools/claude-rc-lxc.sh
# How to re-run this script in a message: a local file when run as a file, otherwise the URL.
if [[ -f "$0" ]]; then RUN="bash $0"; else RUN="wget -qO - $SCRIPT_URL | bash -s --"; fi
exec > >(tee -a "$LOG_FILE") 2>&1
echo "---- $(date '+%F %T') claude-rc-lxc.sh $* ----"

TMP="$(mktemp -d)"
CREATED=0
on_exit() { rm -rf "$TMP"; }
on_err() {
  msg_error "Stopped at line $1: $2"
  if ((CREATED)); then
    msg_warn "Container $CTID was created but setup did not finish."
    msg_warn "Retry with: $RUN enable $CTID   (or destroy it: pct stop $CTID; pct destroy $CTID)"
  fi
}
trap on_exit EXIT
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR

# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------
usage() { sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; }

MODE="install"
TARGET_CTID=""
UNATTENDED=0
TOKEN_FILE=""

while (($#)); do
  case "$1" in
    -h|--help)     usage; exit 0 ;;
    --default)     UNATTENDED=1 ;;
    --token-file)  TOKEN_FILE="${2:-}"; [[ -n "$TOKEN_FILE" ]] || die "--token-file needs a path"; shift ;;
    install)       MODE="install" ;;
    enable|update|status) MODE="$1" ;;
    ''|*[!0-9]*)   [[ -z "$TARGET_CTID" && "$MODE" != "install" ]] && { TARGET_CTID="$1"; } || die "Unknown argument: $1" ;;
    *)             [[ "$MODE" != "install" && -z "$TARGET_CTID" ]] && TARGET_CTID="$1" || die "Unknown argument: $1" ;;
  esac
  shift
done

# ------------------------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run this as root on the Proxmox host."
for cmd in pct pveam pvesm pvesh ip; do
  command -v "$cmd" >/dev/null || die "$cmd not found. This script must run on a Proxmox VE host."
done

# Defaults, overridable by environment variables.
: "${CTID:=}"
: "${CT_HOSTNAME:=claude-runner}"
: "${CT_CORES:=2}"
: "${CT_RAM_MB:=4096}"
: "${CT_DISK_GB:=16}"
: "${CT_BRIDGE:=vmbr0}"
: "${CT_ROOTFS_STORE:=local-lvm}"
: "${CT_TMPL_STORE:=local}"
: "${HA_URL:=http://homeassistant.local:8123/mcp_server/sse}"
: "${HA_TRANSPORT:=sse}"
: "${RC_NAME:=Home Server}"
: "${HA_TOKEN:=}"
: "${GIT_NAME:=}"
: "${GIT_EMAIL:=}"

# ------------------------------------------------------------------------------
# Prompt helpers
# ------------------------------------------------------------------------------
# pick VAR "Question": uses the current value of VAR as the default, prompts unless --default.
pick() {
  local var="$1" question="$2" current answer
  current="${!var}"
  if ((UNATTENDED)); then return 0; fi
  read -r -p "$(echo -e "${YW}?${CL} ${question} [${current}]: ")" answer
  printf -v "$var" '%s' "${answer:-$current}"
}

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------
is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

storage_exists() { pvesm status | awk -v s="$1" 'NR>1 && $1==s {found=1} END {exit !found}'; }

container_exists() { pct status "$1" &>/dev/null; }

validate_inputs() {
  is_int "$CTID" && ((CTID >= 100)) || die "Container ID must be a number of at least 100."
  container_exists "$CTID" && die "Container $CTID already exists. Use: $RUN status $CTID"
  [[ "$CT_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]{0,62})$ ]] || die "Hostname must be lowercase letters, digits and hyphens."
  is_int "$CT_CORES" && ((CT_CORES >= 1)) || die "CPU cores must be a positive number."
  is_int "$CT_RAM_MB" && ((CT_RAM_MB >= 4096)) || die "RAM must be at least 4096 MB (Claude Code needs about 4 GB)."
  is_int "$CT_DISK_GB" && ((CT_DISK_GB >= 8)) || die "Disk must be at least 8 GB."
  ip link show "$CT_BRIDGE" &>/dev/null || die "Network bridge '$CT_BRIDGE' does not exist."
  storage_exists "$CT_ROOTFS_STORE" || die "Storage '$CT_ROOTFS_STORE' does not exist (see: pvesm status)."
  storage_exists "$CT_TMPL_STORE"   || die "Storage '$CT_TMPL_STORE' does not exist (see: pvesm status)."
  [[ "$HA_URL" =~ ^https?:// ]] || die "Home Assistant MCP URL must start with http:// or https://."
  [[ "$HA_TRANSPORT" == "sse" || "$HA_TRANSPORT" == "http" ]] || die "HA_TRANSPORT must be 'sse' or 'http'."
  [[ "$RC_NAME" =~ ^[A-Za-z0-9._\ -]{1,64}$ ]] || die "Remote Control name may use letters, digits, spaces, '.', '_' and '-' (max 64)."
  [[ -n "$HA_TOKEN" ]] || die "No Home Assistant token. Set HA_TOKEN or pass --token-file."
}

load_token() {
  if [[ -n "$TOKEN_FILE" ]]; then
    [[ -r "$TOKEN_FILE" ]] || die "Cannot read token file: $TOKEN_FILE"
    local perms; perms="$(stat -c %a "$TOKEN_FILE")"
    [[ "$perms" == "600" || "$perms" == "400" ]] || die "Token file must be chmod 600 or 400 (currently $perms)."
    HA_TOKEN="$(head -n1 "$TOKEN_FILE" | tr -d '\r\n')"
  fi
  if [[ -z "$HA_TOKEN" ]] && ((!UNATTENDED)); then
    msg_warn "Create a token: Home Assistant > your profile > Security > Long-lived access tokens."
    read -r -s -p "$(echo -e "${YW}?${CL} Home Assistant token (input hidden): ")" HA_TOKEN
    echo
  fi
}

# ------------------------------------------------------------------------------
# Container-side setup script (pushed into the LXC; quoted heredoc = no host expansion)
# ------------------------------------------------------------------------------
write_container_script() {
cat > "$TMP/setup.sh" <<'CTSCRIPT'
#!/usr/bin/env bash
# Runs inside the container.  Usage: setup.sh install | enable | update | status
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
PHASE="${1:?phase required}"
U=claude
H=/home/claude
ENV_FILE=/root/rc.env

trap 'echo "setup.sh failed at line $LINENO" >&2' ERR
log() { echo "==> $*"; }

as_claude() {
  runuser -u "$U" -- env HOME="$H" PATH="$H/.local/bin:/usr/local/bin:/usr/bin:/bin" "$@"
}
sysd() {
  runuser -u "$U" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "$U")" systemctl --user "$@"
}

case "$PHASE" in
install)
  log "Updating OS packages"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  apt-get update -qq
  apt-get -y -qq full-upgrade
  apt-get install -y -qq --no-install-recommends curl ca-certificates git tmux python3 tzdata >/dev/null
  # GitHub CLI is optional: a missing package must not stop the install.
  apt-get install -y -qq --no-install-recommends gh >/dev/null 2>&1 \
    || echo "gh (GitHub CLI) is not available from the package list; skipping." >&2

  log "Creating the claude user (no sudo)"
  id "$U" >/dev/null 2>&1 || useradd -m -s /bin/bash "$U"
  chmod 750 "$H"
  # Private folder for secrets such as API URLs. Files inside should be chmod 600.
  install -d -m 700 -o "$U" -g "$U" "$H/.config"

  if [[ -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
    log "Setting the git identity"
    as_claude git config --global user.name "$GIT_NAME"
    as_claude git config --global user.email "$GIT_EMAIL"
  fi

  log "Installing Claude Code"
  as_claude bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

  log "Creating project folder"
  install -d -m 700 -o "$U" -g "$U" "$H/homeserver"

  log "Registering Home Assistant MCP server"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  as_claude env HA_URL="$HA_URL" HA_TRANSPORT="$HA_TRANSPORT" HA_TOKEN="$HA_TOKEN" \
    bash -c 'cd "$HOME/homeserver"
             claude mcp remove homeassistant --scope user >/dev/null 2>&1 || true
             claude mcp add --transport "$HA_TRANSPORT" --scope user homeassistant "$HA_URL" \
               --header "Authorization: Bearer $HA_TOKEN"'
  mcp_list="$(as_claude bash -c 'cd "$HOME/homeserver" && claude mcp list' || true)"
  if [[ "$mcp_list" != *homeassistant* ]]; then
    echo "Home Assistant MCP server was not registered." >&2
    exit 1
  fi

  log "Writing the Remote Control service"
  install -d -m 700 -o "$U" -g "$U" "$H/.config" "$H/.config/systemd" "$H/.config/systemd/user"
  cat > "$H/.config/systemd/user/claude-rc.service" <<UNIT
[Unit]
Description=Claude Code Remote Control
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
WorkingDirectory=%h/homeserver
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/tmux new-session -d -s claude-rc 'while true; do claude remote-control --name "${RC_NAME}"; sleep 15; done'
ExecStop=/usr/bin/tmux kill-session -t claude-rc
Restart=on-failure

[Install]
WantedBy=default.target
UNIT
  chown "$U:$U" "$H/.config/systemd/user/claude-rc.service"
  chmod 600 "$H/.config/systemd/user/claude-rc.service"

  # The token now lives only in the Claude MCP config. Remove the staging copy.
  shred -u "$ENV_FILE" 2>/dev/null || rm -f "$ENV_FILE"

  if env | grep -q '^ANTHROPIC_'; then
    echo "WARNING: ANTHROPIC_* variables are set in the container environment. Remove them or Remote Control will not start." >&2
  fi
  log "Install complete"
  ;;

enable)
  log "Enabling background service"
  loginctl enable-linger "$U"
  for _ in $(seq 20); do [[ -d "/run/user/$(id -u "$U")" ]] && break; sleep 1; done
  sysd daemon-reload
  sysd enable --now claude-rc.service
  sleep 15
  if sysd is-active --quiet claude-rc.service; then
    log "claude-rc is running"
  else
    echo "claude-rc is not active. Check logs: pct exec <CTID> -- runuser -u claude -- journalctl --user -u claude-rc -n 50" >&2
    exit 1
  fi
  ;;

update)
  log "Updating OS packages"
  apt-get update -qq
  apt-get -y -qq full-upgrade
  apt-get -y -qq autoremove
  log "Updating Claude Code"
  as_claude claude update || echo "Claude Code update reported a problem; the current version is still installed." >&2
  log "Restarting Remote Control"
  sysd restart claude-rc.service
  log "Update complete"
  ;;

status)
  echo "Service:";  sysd is-active claude-rc.service || true
  echo "Version:";  as_claude claude --version || true
  echo "MCP:";      as_claude bash -c 'cd "$HOME/homeserver" && claude mcp list' || true
  echo "GitHub:";   as_claude gh auth status 2>&1 | head -3 || true
  echo "Python:";   python3 --version || true
  ;;

*)
  echo "Unknown phase: $PHASE" >&2
  exit 1
  ;;
esac
CTSCRIPT
}

# Push the container script and run one phase of it.
run_phase() {
  local phase="$1"
  pct push "$CTID" "$TMP/setup.sh" /root/setup.sh --perms 700
  pct exec "$CTID" -- bash /root/setup.sh "$phase"
  pct exec "$CTID" -- rm -f /root/setup.sh
}

ensure_running() {
  if [[ "$(pct status "$CTID")" != *running* ]]; then
    msg_info "Starting container $CTID"
    pct start "$CTID"
    pct exec "$CTID" -- bash -c 'for i in $(seq 60); do getent hosts claude.ai >/dev/null 2>&1 && exit 0; sleep 2; done; exit 1' \
      || die "Container $CTID has no network access."
  fi
}

require_existing() {
  is_int "$TARGET_CTID" || die "Give a container ID, e.g. $RUN $MODE 200"
  container_exists "$TARGET_CTID" || die "Container $TARGET_CTID does not exist."
  CTID="$TARGET_CTID"
}

# ------------------------------------------------------------------------------
# Modes
# ------------------------------------------------------------------------------
do_install() {
  echo
  echo -e "${GN}Claude Code Remote Control + Home Assistant MCP${CL}"
  if ((!UNATTENDED)); then
    echo "Press Enter to accept the default shown in [brackets]."
    echo
  fi

  if [[ -z "$CTID" ]]; then
    CTID="$(pvesh get /cluster/nextid 2>/dev/null || echo 200)"
  fi
  pick CTID          "Container ID"
  pick CT_HOSTNAME   "Container hostname"
  pick CT_CORES      "CPU cores"
  pick CT_RAM_MB     "RAM (MB)"
  pick CT_DISK_GB    "Disk size (GB)"
  pick CT_BRIDGE     "Network bridge"
  pick CT_ROOTFS_STORE "Storage for the container disk"
  pick CT_TMPL_STORE "Storage for templates"
  pick HA_URL        "Home Assistant MCP URL"
  pick HA_TRANSPORT  "Transport (sse or http)"
  pick RC_NAME       "Name shown in the Claude app"
  load_token

  validate_inputs

  echo
  msg_info "Plan"
  echo "  Container   : $CTID ($CT_HOSTNAME), Debian 12, ${CT_CORES} cores, ${CT_RAM_MB} MB RAM, ${CT_DISK_GB} GB disk"
  echo "  Network     : $CT_BRIDGE (DHCP)"
  echo "  HA MCP      : $HA_URL ($HA_TRANSPORT)"
  echo "  Remote name : $RC_NAME"
  if ((!UNATTENDED)); then
    read -r -p "$(echo -e "${YW}?${CL} Continue? [y/N]: ")" go
    [[ "$go" =~ ^[Yy]$ ]] || { msg_info "Cancelled. Nothing was changed."; exit 0; }
  fi

  # Template
  msg_info "Locating the Debian 12 template"
  pveam update >/dev/null 2>&1 || msg_warn "Could not refresh the template list; using the cached copy."
  TEMPLATE="$(pveam available -section system | awk '$2 ~ /^debian-12-standard_.*_amd64\.tar\.zst$/ {print $2}' | sort -V | tail -1)"
  [[ -n "$TEMPLATE" ]] || die "No Debian 12 template found."
  local present
  present="$(pveam list "$CT_TMPL_STORE" || true)"
  if [[ "$present" != *"$TEMPLATE"* ]]; then
    msg_info "Downloading $TEMPLATE"
    pveam download "$CT_TMPL_STORE" "$TEMPLATE"
  fi
  msg_ok "Template ready: $TEMPLATE"

  # Container
  msg_info "Creating container $CTID"
  pct create "$CTID" "${CT_TMPL_STORE}:vztmpl/${TEMPLATE}" \
    --hostname "$CT_HOSTNAME" \
    --cores "$CT_CORES" \
    --memory "$CT_RAM_MB" \
    --swap 512 \
    --rootfs "${CT_ROOTFS_STORE}:${CT_DISK_GB}" \
    --net0 "name=eth0,bridge=${CT_BRIDGE},ip=dhcp" \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1 \
    --tags claude-rc \
    --ostype debian
  CREATED=1
  msg_ok "Container $CTID created"

  # Stage the token and run the install phase.
  {
    printf 'HA_URL=%q\n' "$HA_URL"
    printf 'HA_TRANSPORT=%q\n' "$HA_TRANSPORT"
    printf 'HA_TOKEN=%q\n' "$HA_TOKEN"
    printf 'RC_NAME=%q\n' "$RC_NAME"
    printf 'GIT_NAME=%q\n' "$GIT_NAME"
    printf 'GIT_EMAIL=%q\n' "$GIT_EMAIL"
  } > "$TMP/rc.env"
  chmod 600 "$TMP/rc.env"
  unset HA_TOKEN

  msg_info "Starting container and waiting for network"
  pct start "$CTID"
  pct push "$CTID" "$TMP/rc.env" /root/rc.env --perms 600
  pct exec "$CTID" -- bash -c 'for i in $(seq 60); do getent hosts claude.ai >/dev/null 2>&1 && exit 0; sleep 2; done; exit 1' \
    || die "Container has no network access. Check the bridge and DHCP, then run: $RUN enable $CTID"
  msg_ok "Network is up"

  msg_info "Installing packages, Claude Code and the Home Assistant MCP server (a few minutes)"
  run_phase install
  msg_ok "Install complete"

  echo
  msg_warn "One manual step: Claude asks two first-run questions that need a terminal."
  echo "  1. pct enter $CTID"
  echo "  2. su - claude"
  echo "  3. cd ~/homeserver && claude remote-control --name \"$RC_NAME\""
  echo "  4. Answer  y  to 'Trust <directory>?' and  y  to 'Enable Remote Control?'."
  echo "  5. Confirm '$RC_NAME' appears in the Claude app (Code tab), press Ctrl+C, then type exit twice."
  echo "  Optional: log in to GitHub as the claude user (gh auth login --with-token < token-file); see the guide, section 9."
  echo

  # Do not wait here: the first-run steps need a second terminal, so finish now
  # and start the background service once they are done.
  msg_warn "Finish the steps above, then start the background service with:"
  echo "  $RUN enable $CTID"
  echo
  msg_info "The service is set to start whenever the container starts."
  exit 0
}

finish_message() {
  local ip
  ip="$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}' || true)"
  echo
  msg_ok "Container $CTID ($CT_HOSTNAME) is ready."
  echo "  Claude app > Code tab > '$RC_NAME'"
  echo "  Container IP : ${ip:-unknown}"
  echo "  Shell        : pct enter $CTID"
  echo "  Status       : $RUN status $CTID"
  echo "  Update       : $RUN update $CTID"
}

do_enable() {
  require_existing
  ensure_running
  pct set "$CTID" --onboot 1 >/dev/null
  msg_info "Enabling background service on $CTID"
  run_phase enable
  msg_ok "Remote Control is running in the background"
}

do_update() {
  require_existing
  ensure_running
  msg_info "Updating container $CTID"
  run_phase update
  msg_ok "Update finished"
}

do_status() {
  require_existing
  ensure_running
  run_phase status
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
write_container_script

case "$MODE" in
  install) do_install ;;
  enable)  do_enable ;;
  update)  do_update ;;
  status)  do_status ;;
  *)       die "Unknown mode: $MODE" ;;
esac
