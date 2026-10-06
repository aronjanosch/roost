#!/usr/bin/env bash
# Runs as root. Remaps the agent uid/gid to PUID/PGID to match the host volume,
# seeds the persistent home, bootstraps tools, then idles as the agent user.
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

AGENT_USER=agent
AGENT_HOME=/home/agent

# ---------------------------------------------------------------------------
# 1. Remap uid/gid and (re)own the home volume.
# ---------------------------------------------------------------------------
current_uid="$(id -u "$AGENT_USER")"
current_gid="$(id -g "$AGENT_USER")"
if [ "$current_gid" != "$PGID" ]; then
  groupmod -o -g "$PGID" "$AGENT_USER"
fi
if [ "$current_uid" != "$PUID" ]; then
  usermod -o -u "$PUID" "$AGENT_USER"
fi
chown -R "$PUID:$PGID" "$AGENT_HOME" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 2. Seed an empty home from /etc/skel once, and make the standard dirs.
# ---------------------------------------------------------------------------
if [ ! -f "$AGENT_HOME/.bashrc" ]; then
  cp -r --update=none /etc/skel/. "$AGENT_HOME"/
fi
mkdir -p "$AGENT_HOME/projects" "$AGENT_HOME/.claude" "$AGENT_HOME/.codex" \
         "$AGENT_HOME/.config/opencode" "$AGENT_HOME/.local/bin"
chown -R "$PUID:$PGID" "$AGENT_HOME" 2>/dev/null || true

# Global agent instructions, managed by the image: overwritten on every start.
for f in .claude/CLAUDE.md .codex/AGENTS.md .config/opencode/AGENTS.md; do
  mkdir -p "$AGENT_HOME/$(dirname "$f")"
  cp /etc/agent-dev/AGENTS.md "$AGENT_HOME/$f"
done
chown -R "$PUID:$PGID" "$AGENT_HOME/.claude" "$AGENT_HOME/.codex" "$AGENT_HOME/.config" 2>/dev/null || true

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

  # No claude CLI here: `claude mcp add` hangs before the first login.
  # --no-sandbox because the container has no user namespaces for Chromium's sandbox.
  f="$AGENT_HOME/.claude.json"
  [ -f "$f" ] || { [ "$PUID" = "0" ] && echo '{}' > "$f" || gosu "$AGENT_USER" bash -c 'echo "{}" > "$HOME/.claude.json"'; }
  run bash -c "jq -S '.mcpServers.playwright = {\"type\":\"stdio\",\"command\":\"playwright-mcp\",\"args\":[\"--headless\",\"--browser\",\"chromium\",\"--no-sandbox\"],\"env\":{}}' '$f' > '$f.tmp' && mv '$f.tmp' '$f'" \
    || echo "WARN: playwright MCP config failed"

  # Pre-accept Claude's trust dialog per repo (it has no wildcard, so every
  # ~/projects/<name> gets an entry; repos cloned later are picked up on the
  # next container start or `agent-dev trust`).
  if [ "$TRUST_PROJECTS" = "1" ]; then
    run bash -c 'dirs=("$HOME/projects"); for d in "$HOME"/projects/*/; do [ -d "$d" ] && dirs+=("${d%/}"); done
      printf "%s\n" "${dirs[@]}" | jq -R . | jq -s . > "$HOME/.trust.json"
      jq -S --slurpfile d "$HOME/.trust.json" "reduce \$d[0][] as \$p (.; .projects[\$p].hasTrustDialogAccepted = true)" "$HOME/.claude.json" > "$HOME/.claude.json.tmp" \
        && mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"; rm -f "$HOME/.trust.json"' \
      || echo "WARN: trust pre-accept failed"
  fi

  echo "agent-dev bootstrap done"
}

bootstrap &

exec gosu "$AGENT_USER" sleep infinity
