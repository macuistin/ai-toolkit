#!/usr/bin/env bash
# ==============================================================================
# pve-diag.sh
# Read-only storage and mount diagnostics for a Proxmox host. Changes nothing:
# every command only reads state. Safe to run as a restricted user through the
# sudoers file in tools/sudoers/.
#
#   bash pve-diag.sh                  Overview: block devices, mounts, recent kernel and mount messages
#   bash pve-diag.sh mount PATH       Is PATH a mount point, and what is mounted there? (findmnt)
#   bash pve-diag.sh disk DEVICE      SMART health summary for one device, e.g. /dev/sdb
#   bash pve-diag.sh ct CTID          Bind mounts configured for a container, and whether each host path is mounted
#
# Exit status of "mount" is 0 when PATH is a mount point and 1 when it is not, so a
# script can stop before a container starts against an empty folder.
# ==============================================================================
set -u

section() { printf '\n== %s ==\n' "$*"; }

usage() { sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; }

cmd_overview() {
  section "Block devices"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
  section "Mounts (excluding virtual file systems)"
  findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS
  section "Recent kernel messages about disks and mounts"
  dmesg --level=err,warn 2>/dev/null | grep -Ei 'ntfs|usb|sd[a-z]|nvme|i/o error|mount' | tail -n 30
  section "Recent journal errors for mount units"
  journalctl -p warning -b --no-pager -n 30 2>/dev/null | grep -Ei 'mount|ntfs' || echo "(none)"
}

cmd_mount() {
  local path="${1:?path required}"
  if findmnt --mountpoint "$path" -o TARGET,SOURCE,FSTYPE,OPTIONS; then
    return 0
  fi
  echo "NOT MOUNTED: $path is not a mount point on the host." >&2
  return 1
}

cmd_disk() {
  local dev="${1:?device required}"
  smartctl -H -A "$dev"
}

cmd_ct() {
  local ctid="${1:?container id required}" conf="/etc/pve/lxc/${1}.conf" line host rc=0
  [[ -r "$conf" ]] || { echo "Cannot read $conf" >&2; return 2; }
  grep -E '^mp[0-9]+:' "$conf" || { echo "No bind mounts or extra mount points in $conf."; return 0; }
  while IFS= read -r line; do
    host="${line#*: }"; host="${host%%,*}"
    # Only bind mounts have a host path; volume entries look like storage:vol and are skipped.
    [[ "$host" == /* ]] || continue
    if findmnt --mountpoint "$host" >/dev/null; then echo "OK         $host"; else echo "NOT MOUNTED $host"; rc=1; fi
  done < <(grep -E '^mp[0-9]+:' "$conf")
  return "$rc"
}

case "${1:-overview}" in
  -h|--help) usage ;;
  overview)  cmd_overview ;;
  mount)     shift; cmd_mount "$@" ;;
  disk)      shift; cmd_disk "$@" ;;
  ct)        shift; cmd_ct "$@" ;;
  *)         usage; exit 2 ;;
esac
