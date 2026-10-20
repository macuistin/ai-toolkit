#!/usr/bin/env bash
# ==============================================================================
# claude-rc-watchdog.sh
# Restarts the Claude Code Remote Control service when its tmux session is missing
# or stuck (for example on a trust prompt or a login error). systemd only restarts
# a service when its process exits, so it cannot see these hangs.
#
# Install as a systemd user timer (run as the user that owns the service):
#
#   install -m 0755 tools/claude-rc-watchdog.sh ~/.local/bin/claude-rc-watchdog.sh
#   cp tools/systemd/claude-rc-watchdog.{service,timer} ~/.config/systemd/user/
#   systemctl --user daemon-reload
#   systemctl --user enable --now claude-rc-watchdog.timer
#
# Environment variables (all optional):
#   RC_SESSION [claude-rc]        tmux session the service runs in
#   RC_UNIT [claude-rc.service]   systemd user unit to restart
#   MAX_FAILS [2]                 consecutive unhealthy checks before a restart
#
# Log: $XDG_STATE_HOME/claude-rc-watchdog/watchdog.log (default ~/.local/state)
# ==============================================================================
set -u

SESSION=${RC_SESSION:-claude-rc}
UNIT=${RC_UNIT:-claude-rc.service}
MAX_FAILS=${MAX_FAILS:-2}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/claude-rc-watchdog
LOG=$STATE_DIR/watchdog.log
FAIL_FILE=$STATE_DIR/consecutive_failures

mkdir -p "$STATE_DIR"
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# Healthy means the pane shows the connected line for Remote Control.
healthy() {
  tmux has-session -t "$SESSION" 2>/dev/null || return 1
  tmux capture-pane -p -t "$SESSION" -S -60 | grep -q 'Connected ·'
}

if healthy; then
  rm -f "$FAIL_FILE"
  exit 0
fi

fails=$(( $(cat "$FAIL_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$fails" > "$FAIL_FILE"
log "unhealthy check $fails/$MAX_FAILS"

if [ "$fails" -ge "$MAX_FAILS" ]; then
  log "restarting $UNIT"
  if systemctl --user restart "$UNIT"; then
    log "restart issued"
  else
    log "restart failed"
  fi
  rm -f "$FAIL_FILE"
fi
