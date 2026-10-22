#!/usr/bin/env bash
# Runs as root. Remaps the agent uid/gid to PUID/PGID to match the host volume,
# seeds the persistent home, bootstraps tools, starts sshd, then idles as the
# agent user.
# Idempotent: safe to run on every container start.
set -uo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
HARNESSES="${HARNESSES:-claude codex opencode}"
TOOLS="${TOOLS:-herdr uv gh glab npm:ccusage npm:playwright npm:@playwright/mcp}"
CURSOR="${CURSOR:-0}"
# The box is the security boundary, so Claude's per-folder trust dialog is
# pre-accepted for ~/projects/*. Set TRUST_PROJECTS=0 to keep the dialog.
TRUST_PROJECTS="${TRUST_PROJECTS:-1}"
GH_TOKEN="${GH_TOKEN:-}"
# Heeler QR pairing (roost-pair). Off by default: it lets ~/.ssh/authorized_keys
# grant logins, which every agent in the box can write.
HEELER_PAIRING="${HEELER_PAIRING:-0}"

AGENT_USER=agent
AGENT_HOME=/home/agent

# ---------------------------------------------------------------------------
# 1. Remap uid/gid and (re)own the home volume. Edits /etc/passwd directly:
#    usermod -u would walk the whole home on every new container, and a
#    grown home (tools, repos) makes that minutes. chown -R runs only when
#    the home's owner is off, e.g. a fresh, root-created directory.
# ---------------------------------------------------------------------------
if [ "$(id -g "$AGENT_USER")" != "$PGID" ]; then
  groupmod -o -g "$PGID" "$AGENT_USER"
fi
if [ "$(id -u "$AGENT_USER")" != "$PUID" ] || [ "$(id -g "$AGENT_USER")" != "$PGID" ]; then
  sed -i "s/^$AGENT_USER:\([^:]*\):[0-9]*:[0-9]*:/$AGENT_USER:\1:$PUID:$PGID:/" /etc/passwd
fi
if [ "$(stat -c %u:%g "$AGENT_HOME")" != "$PUID:$PGID" ]; then
  echo "roost: owning $AGENT_HOME as $PUID:$PGID (one-time, may take a while)"
  chown -R "$PUID:$PGID" "$AGENT_HOME" 2>/dev/null || true
fi
as_agent() { gosu "$AGENT_USER" env HOME="$AGENT_HOME" "$@"; }

# ---------------------------------------------------------------------------
# 2. Seed an empty home from /etc/skel once, and make the standard dirs.
# ---------------------------------------------------------------------------
if [ ! -f "$AGENT_HOME/.bashrc" ]; then
  as_agent cp -r --update=none /etc/skel/. "$AGENT_HOME"/
fi
as_agent mkdir -p "$AGENT_HOME/projects" "$AGENT_HOME/.claude" "$AGENT_HOME/.codex" \
         "$AGENT_HOME/.config/opencode" "$AGENT_HOME/.local/bin"

# Global agent instructions and roost's skills (guided setup), managed by the
# image: overwritten on every start. ~/.agents/skills is Codex's (and
# opencode's) user skill folder, ~/.claude/skills Claude Code's.
for f in .claude/CLAUDE.md .codex/AGENTS.md .config/opencode/AGENTS.md; do
  as_agent mkdir -p "$AGENT_HOME/$(dirname "$f")"
  as_agent cp /etc/roost/AGENTS.md "$AGENT_HOME/$f"
done
for d in .claude/skills .agents/skills; do
  as_agent mkdir -p "$AGENT_HOME/$d"
  as_agent cp -r /etc/roost/skills/. "$AGENT_HOME/$d"/
done

# ---------------------------------------------------------------------------
# 3. Git identity (as the agent user).
# ---------------------------------------------------------------------------
git_cfg() { gosu "$AGENT_USER" git config --global "$@"; }
if [ -n "${GIT_USER_NAME:-}" ]; then  git_cfg user.name "$GIT_USER_NAME"; fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then git_cfg user.email "$GIT_USER_EMAIL"; fi
git_cfg init.defaultBranch main
git_cfg pull.rebase true

# ---------------------------------------------------------------------------
# 4. Bootstrap tools into the persistent home, in the background, then idle.
#    Logins (claude / codex / opencode / gh / glab) stay manual.
# ---------------------------------------------------------------------------
bootstrap() {
  export HOME="$AGENT_HOME"
  export PATH="$AGENT_HOME/.local/share/mise/shims:$AGENT_HOME/.local/bin:/usr/local/bin:$PATH"
  MISE=/usr/local/bin/mise
  run() { gosu "$AGENT_USER" env HOME="$AGENT_HOME" PATH="$PATH" "$@"; }

  # node first: the npm: / npx tools need it.
  extra=""
  [ "$CURSOR" = "1" ] && extra="cursor-agent"
  for t in node@lts $TOOLS $HARNESSES $extra; do
    name="${t%@*}"
    case "$name" in
      npm:*) bare="${name#npm:}";;
      *)     bare="$name";;
    esac
    run "$MISE" where "$bare" >/dev/null 2>&1 \
      || run "$MISE" use -g "$t" 2>/dev/null \
      || run "$MISE" use -g "$name@latest" 2>/dev/null \
      || echo "WARN: could not install $t"
  done

  run bash -c 'ls "$HOME"/.cache/ms-playwright/chromium-* >/dev/null 2>&1 || playwright install chromium' \
    || echo "WARN: chromium download failed"

  # GH_TOKEN: log gh in with it and let git use gh for HTTPS. ssh sessions do
  # not see the container env, so the token goes into gh's own config.
  # (gh refuses --with-token while GH_TOKEN is set, hence env -u.)
  if [ -n "${GH_TOKEN:-}" ]; then
    printf '%s\n' "$GH_TOKEN" | run env -u GH_TOKEN gh auth login --with-token \
      && run env -u GH_TOKEN gh auth setup-git \
      && echo "roost: gh logged in from GH_TOKEN" \
      || echo "WARN: gh login from GH_TOKEN failed"
  fi

  # No claude CLI here: `claude mcp add` hangs before the first login.
  # --no-sandbox because the container has no user namespaces for Chromium's sandbox.
  f="$AGENT_HOME/.claude.json"
  [ -f "$f" ] || { [ "$PUID" = "0" ] && echo '{}' > "$f" || gosu "$AGENT_USER" bash -c 'echo "{}" > "$HOME/.claude.json"'; }
  run bash -c "jq -S '.mcpServers.playwright = {\"type\":\"stdio\",\"command\":\"playwright-mcp\",\"args\":[\"--headless\",\"--browser\",\"chromium\",\"--no-sandbox\"],\"env\":{}}' '$f' > '$f.tmp' && mv '$f.tmp' '$f'" \
    || echo "WARN: playwright MCP config failed"

  # Pre-accept Claude's trust dialog for ~/projects/*; later clones: roost-trust.
  if [ "$TRUST_PROJECTS" = "1" ]; then
    run roost-trust || echo "WARN: trust pre-accept failed"
  fi

  echo "roost bootstrap done"
}

bootstrap &

# ---------------------------------------------------------------------------
# 5. SSH, the only way in. Host key: generated once into the identity volume,
#    so the fingerprint survives updates. Logins: PUBLIC_KEYS (rebuilt on every
#    start, so removing a key there revokes it) plus the volume's
#    authorized_keys file. Both are root-owned and outside the
#    agent's home, so agents cannot add logins. sshd stays root to drop
#    privileges per login; only `agent` may log in.
# ---------------------------------------------------------------------------
SSH_DIR=/etc/roost/ssh
key="$SSH_DIR/ssh_host_ed25519_key"
if [ ! -s "$key" ]; then
  install -d -o root -g root -m 0755 "$SSH_DIR" 2>/dev/null
  ssh-keygen -q -t ed25519 -N "" -C roost -f "$key" \
    && echo "roost: generated SSH host key $(ssh-keygen -lf "$key.pub" | cut -d' ' -f2)" \
    || echo "WARN: cannot write $SSH_DIR (read-only mount?) — no host key, sshd not started"
fi
install -d -o root -g root -m 0755 /run/roost
# Separated by newlines or commas (single-line UIs such as Unraid templates).
printf '%s\n' "${PUBLIC_KEYS:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -E '^(ssh-|ecdsa-|sk-)' > /run/roost/authorized_keys
chmod 0644 /run/roost/authorized_keys
if [ ! -s /run/roost/authorized_keys ] && [ ! -s "$SSH_DIR/authorized_keys" ]; then
  echo "WARN: no public keys — set PUBLIC_KEYS (newline- or comma-separated) or add $SSH_DIR/authorized_keys; nobody can log in yet"
fi
# The Heeler plugin pins the host key it finds under /etc/ssh.
ln -sf "$key.pub" /etc/ssh/ssh_host_ed25519_key.pub

# Heeler pairing: the plugin enrolls the phone's key into ~/.ssh/authorized_keys,
# so sshd reads that file too (StrictModes wants the home not group/world
# writable). Address and port for the Pairing Code go to roost-pair via
# /run/roost/heeler-pair.json.
sshd_config=/etc/roost/sshd_config
rm -f /run/roost/heeler-pair.json
if [ "$HEELER_PAIRING" = "1" ]; then
  sshd_config=/run/roost/sshd_config
  sed 's|^AuthorizedKeysFile .*|& .ssh/authorized_keys|' /etc/roost/sshd_config > "$sshd_config"
  chmod go-w "$AGENT_HOME"
  printf '%s\n' "${HEELER_ADDRESSES:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | { grep -v '^$' || true; } \
    | jq -R . | jq -s --argjson port "${HEELER_PORT:-2222}" '{ssh_port: $port, addresses: .}' > /run/roost/heeler-pair.json \
    || echo "WARN: HEELER_PORT must be a number — roost-pair will not work"
  chmod 0644 /run/roost/heeler-pair.json
  echo "roost: Heeler pairing on — agents in the box can add logins via ~/.ssh/authorized_keys"
fi
[ -s "$key" ] && /usr/sbin/sshd -D -e -f "$sshd_config" &

exec gosu "$AGENT_USER" sleep infinity
