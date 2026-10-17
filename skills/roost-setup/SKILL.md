---
name: roost-setup
description: Guided first-run setup and upkeep of the roost box you are running in (git identity, gh/glab and agent logins, repos under ~/projects, missing tools, connecting laptops and phones). Use when the user says "set up roost", "init", asks what is still missing in the box, wants to log in somewhere, clone repos, install a tool, or connect another device.
---

# roost setup

You run inside **roost**: a long-running container for coding agents on the
user's NAS/VM. `/home/agent` is persistent; the image, `/etc` and the SSH keys
are not yours to change (no sudo, by design). The user reaches the box with
`ssh` on its published port and drives sessions with herdr.

Work through the steps in order. Check first, then ask only for what is
missing; skip a step that is already done and say so. One short status line
per step. At the end, print the checklist with what is done and what is open.

Logins need the user's hands: an interactive command (device code, browser,
pasted token) must run in **their** terminal. Give them the exact command, ask
them to run it (in Claude Code: type `! <command>`; otherwise in a second
herdr pane or `ssh` session), then verify. Never ask for a token or key in
chat.

## 1. Git identity

`git config --global user.name` / `user.email`. They come from the container
env `GIT_USER_NAME` / `GIT_USER_EMAIL` on every start. If empty: ask, set them
with `git config --global`, and tell the user to add both vars to the box's
`.env` (or compose) so they survive a recreate.

## 2. GitHub / GitLab

- `gh auth status`. If not logged in: user runs `gh auth login` (HTTPS, web
  device flow), then you run `gh auth setup-git` so git uses gh for HTTPS.
  Alternative that survives a fresh home: a fine-grained token as `GH_TOKEN`
  in the box's `.env`; the box logs gh in with it on every start.
- GitLab only if the user uses it: `glab auth status`; else user runs
  `glab auth login`, then `glab config set git_protocol https`.
- The box has no SSH key for git on purpose; HTTPS via gh/glab is the way.
  If a remote is `git@…`, switch it to HTTPS.

## 3. Agent logins

Check each harness that is installed (`command -v claude codex opencode …`):

| Harness | Check | User runs |
|---|---|---|
| Claude Code | you are running, or `claude auth status` | `claude` → `/login` |
| Codex | `codex login status` | `codex login --device-auth` |
| opencode | `opencode auth list` | `opencode auth login` |

Other harnesses: look up their login command (`<tool> --help`). Which ones
are installed is set by `HARNESSES` in the box's env.

Shortcut: if the user already has these logins on their laptop, they can run
`roost-migrate <ssh-target>` there (`bin/roost-migrate` in the roost repo)
instead of steps 1–3. It copies git config, gh/glab tokens and agent logins,
never private keys.

## 4. Repos

Ask which repos to bring in. Clone each into `~/projects/<name>`
(`gh repo clone owner/repo ~/projects/<name>`; that path is a contract other
tools rely on). Then run `roost-trust` so Claude does not ask for folder trust.
One git worktree per task later, not one clone per task.

## 5. Tools

For anything the user's projects need (`go`, `node`, `python`, linters, CLIs):

- **mise** first, live and persistent: `mise use -g <tool>` or a backend
  (`npm:`, `pipx:`, `cargo:`, `ubi:owner/repo`, `aqua:owner/repo`). Search
  with `mise search <name>`.
- **apt / system libraries** (`ffmpeg`, `-dev` headers) cannot be installed
  here. The user adds them to `EXTRA_PACKAGES` in the box's `.env` on the
  docker host and runs
  `docker compose -f compose.yml -f compose.user.yml up -d --build`.
- Update tools with `mise up`, not with a tool's own updater.

## 6. Devices

Logins into the box are only the public keys in `PUBLIC_KEYS` (compose/env
on the docker host, comma-separated) and `/etc/roost/ssh/authorized_keys`.
Neither is writable from inside, on purpose, so you cannot add a device: tell
the user what to do on the docker host.

- New key: append it to `PUBLIC_KEYS`, then `docker compose up -d`.
- Laptop: an ssh config entry with host, port (default 2222) and `User
  agent`; then `herdr machine add <alias>`. The alias name is theirs to pick.
- Phone (Heeler, Termius, …): same host, port and user, the app's key in
  `PUBLIC_KEYS`. Needs LAN or a VPN such as Tailscale to reach the host.
- herdr versions must speak the same protocol on laptop and box: compare
  `herdr status` (protocol line) on both; `mise up herdr` aligns them.

## Done

Print the checklist: git identity, gh (+ setup-git), glab if used, each
agent login, repos cloned + trusted, tools, devices. Mark open items with the
exact command the user still has to run.

## Guardrails

- Everything in this home (tokens, logins) is readable by every agent in the
  box. Say so before the user logs in to something sensitive; no production
  credentials here (server SSH keys, vault passphrases, cloud admin tokens).
- A container recreate (`docker compose up -d` after a change) stops running
  agent sessions. Say that before suggesting one.
- Don't edit files under `/etc/roost`, `~/.claude/skills/roost-setup` or the
  managed `AGENTS.md`/`CLAUDE.md`: they are overwritten on every start.
