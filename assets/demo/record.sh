#!/usr/bin/env bash
# Record assets/demo/roost.gif: a real deploy on a docker host, then the
# connection from this laptop. Uses a throwaway box (container roost-demo,
# its own port and folders), so it runs next to a real roost.
#
#   DEMO_HOST=nas DEMO_DIR=/mnt/user/appdata/roost-demo assets/demo/record.sh
#
# DEMO_HOST    ssh alias of the docker host (its user may run docker)
# DEMO_DIR     folder on that host for the demo box; the home inside it is
#              bootstrapped once (a few minutes, ~2 GB) and reused
# DEMO_PORT    port for the demo box (default 2299)
# DEMO_CLEAN=1 removes the demo box and its folder afterwards
set -euo pipefail

: "${DEMO_HOST:?set DEMO_HOST to the ssh alias of the docker host}"
: "${DEMO_DIR:?set DEMO_DIR to a folder on the docker host (not tmpfs)}"
DEMO_PORT="${DEMO_PORT:-2299}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
# The recording terminal gets no ssh agent and none of your ssh config:
# the docker host is reached through a master connection opened here, the
# demo box with a throwaway key that is also the one shown in .env.
work="$(mktemp -d /tmp/roost-demo.XXXXXX)"
ctl="$work/nas.sock"
cleanup() { ssh -S "$ctl" -O exit "$DEMO_HOST" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
ssh -M -S "$ctl" -fN "$DEMO_HOST"
host="$(ssh -G "$DEMO_HOST" 2>/dev/null | awk '/^hostname /{print $2; exit}')"
ssh-keygen -q -t ed25519 -N "" -C laptop -f "$work/laptop"

cat > "$work/ssh_config" <<EOF
Host nas
  HostName $host
  ControlPath $ctl
  ControlMaster no
  LogLevel ERROR
Host roost
  HostName $host
  Port $DEMO_PORT
  User agent
  IdentityFile $work/laptop
  IdentitiesOnly yes
  IdentityAgent none
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOF

remote() { ssh -S "$ctl" "$DEMO_HOST" "$@"; }
# Everything the visible `docker compose` needs, set out of frame.
denv="SSH_PORT=$DEMO_PORT ROOST_HOME=$DEMO_DIR/home ROOST_SSH=$DEMO_DIR/ssh COMPOSE_PROGRESS=plain"

echo "==> preparing $DEMO_HOST:$DEMO_DIR"
remote "docker rm -f roost-demo >/dev/null 2>&1; rm -rf '$DEMO_DIR/roost' '$DEMO_DIR/ssh'; mkdir -p '$DEMO_DIR/roost' '$DEMO_DIR/home'
  printf 'services:\n  roost:\n    container_name: roost-demo\n' > '$DEMO_DIR/roost/compose.override.yml'"
remote "cat > '$DEMO_DIR/roost/laptop.pub'" < "$work/laptop.pub"
remote "cat > '$DEMO_DIR/roost/compose.yml'" < "$repo/compose.yml"

if ! remote "test -d '$DEMO_DIR/home/.local/share/mise/installs/herdr'"; then
  echo "==> first bootstrap of the demo home (a few minutes, not recorded)"
  remote "cd '$DEMO_DIR/roost' && $denv docker compose up -d >/dev/null 2>&1
    for i in \$(seq 1 180); do docker logs roost-demo 2>&1 | grep -q 'roost bootstrap done' && break; sleep 5; done
    docker logs roost-demo 2>&1 | grep -q 'roost bootstrap done' || { echo 'bootstrap did not finish' >&2; exit 1; }
    docker compose down >/dev/null 2>&1; rm -rf '$DEMO_DIR/ssh'"
fi
# The recording downloads compose.yml itself.
remote "rm -f '$DEMO_DIR/roost/compose.yml'"

echo "==> recording"
export DEMO_SSHCFG="$work/ssh_config" DEMO_DIR DEMO_ENV="$denv"
(cd "$repo" && mise exec vhs@latest ttyd@latest -- vhs assets/demo/roost.tape)

remote "cd '$DEMO_DIR/roost' && $denv docker compose down >/dev/null 2>&1 || true"
[ "${DEMO_CLEAN:-}" = 1 ] && remote "rm -rf '$DEMO_DIR'"
echo "==> wrote assets/demo/roost.gif"
