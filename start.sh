#!/bin/sh
# Start px0 (review workbench, loopback only) behind Caddy basic auth on $PORT.
# Exits non-zero as soon as either process stops, so Railway restarts the service.
set -eu

export PORT="${PORT:-8080}"
export PX0_INTERNAL_PORT="${PX0_INTERNAL_PORT:-7777}"
export PX0_USERNAME="${PX0_USERNAME:-admin}"
export HOME="${HOME:-/data}"
WORKSPACE="${PX0_WORKSPACE:-/data/workspace}"

fail() { echo "px0-railway: $*" >&2; exit 1; }

[ -n "${PX0_PASSWORD:-}" ] || fail "PX0_PASSWORD is empty: set it (the template generates one) so the UI is not open to anyone."
[ "${#PX0_PASSWORD}" -ge 12 ] || fail "PX0_PASSWORD must be at least 12 characters."
case "$PX0_USERNAME" in *[!A-Za-z0-9._@-]*|"") fail "PX0_USERNAME may use only letters, digits and . _ @ -";; esac

mkdir -p "$HOME" "$WORKSPACE"

# Size Go's heap to the service's memory limit (cgroup v2), leaving room for git.
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  lim=$(cat /sys/fs/cgroup/memory.max)
  if [ "$lim" != "max" ]; then
    export GOMEMLIMIT="$(( lim * 6 / 10 / 1048576 ))MiB"
  fi
fi
# Railway shows the host's CPUs inside a small service: cap Go threads to the quota.
if [ -z "${GOMAXPROCS:-}" ] && [ -r /sys/fs/cgroup/cpu.max ]; then
  set -- $(cat /sys/fs/cgroup/cpu.max)
  if [ "$1" != "max" ]; then
    n=$(( ($1 + $2 - 1) / $2 )); [ "$n" -ge 1 ] || n=1
    export GOMAXPROCS="$n"
  fi
fi

# A GitHub/GitLab/Gitea/Bitbucket token, if given, is read by px0 from the
# environment (GITHUB_TOKEN, GITLAB_TOKEN, ...). Empty values are dropped so
# px0 falls back to its read-only mode instead of sending an empty token.
for v in GITHUB_TOKEN GH_TOKEN GITLAB_TOKEN GITLAB_HOST GITEA_TOKEN GITEA_HOST BITBUCKET_TOKEN BITBUCKET_EMAIL; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || unset "$v"
done

# Caddy wants a bcrypt hash; make it from the password at every start.
PX0_PASSWORD_HASH=$(caddy hash-password --plaintext "$PX0_PASSWORD") || fail "could not hash PX0_PASSWORD"
export PX0_PASSWORD_HASH
unset PX0_PASSWORD
caddy validate --config /etc/px0/Caddyfile --adapter caddyfile >/dev/null 2>&1 || {
  caddy validate --config /etc/px0/Caddyfile --adapter caddyfile; fail "Caddyfile is invalid"; }

# A workbench lock from the last container would point at a dead process;
# px0 checks it with a ping, but drop it anyway so start-up never waits on it.
[ ! -e "$HOME/.px0/workbench.lock" ] || rm "$HOME/.px0/workbench.lock"

cd "$WORKSPACE"
px0 -host 127.0.0.1 -port "$PX0_INTERNAL_PORT" -no-open -no-update -no-telemetry -no-color &
PX0_PID=$!
caddy run --config /etc/px0/Caddyfile --adapter caddyfile &
CADDY_PID=$!

term() { kill -TERM "$PX0_PID" "$CADDY_PID" 2>/dev/null || true; wait 2>/dev/null || true; exit 143; }
trap term TERM INT

# BusyBox `wait -n` doesn't return on the first child exit, so poll.
while kill -0 "$PX0_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 2
done
kill -0 "$PX0_PID" 2>/dev/null || echo "px0-railway: px0 stopped" >&2
kill -0 "$CADDY_PID" 2>/dev/null || echo "px0-railway: caddy stopped" >&2
kill -TERM "$PX0_PID" "$CADDY_PID" 2>/dev/null || true
exit 1
