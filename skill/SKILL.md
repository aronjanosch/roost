---
name: agent-dev-setup
description: Set up, migrate, and operate a long-running headless coding-agent container ("agent-dev") that runs herdr + Claude Code/Codex/opencode over a portless SSH transport and is reached with `herdr machine add`. Use when the user wants a persistent dev box for long agent tasks on a NAS/VM/homelab, wants to register it as a herdr machine rather than "ssh somewhere", wants to migrate logins/config/repos from their host into it, wants to authenticate gh/glab or a coding harness inside it, or hits a missing tool/package error in the container. Triggers: agent-dev, herdr machine add, dev container for agents, long-running agent box, migrate host into container, "install X in the box", container package missing.
---

# agent-dev setup skill

`agent-dev` is a focused recipe: one long-running container that holds your
coding agents, reached with `herdr machine add` (not a manual `ssh`), with no
inbound ports, no sudo, and no Docker socket. Sessions keep running when your
laptop sleeps. Plain `ssh agent-dev` still works — it is the same transport,
just not the everyday entry point.

All host-side actions go through `./bin/agent-dev` in the repo. Never invent
commands; if a step is missing, say so rather than improvising.

**Run the CLI on the laptop, not on the Docker host.** `migrate` reads the
local `$HOME`; `up` reads the local repo and pushes it to `REMOTE_DIR` on
`SSH_HOST`. If the user runs it on the NAS, `migrate` sees the NAS's configs,
not theirs.

## Ground rules

- **Secrets:** everything copied into the box is readable by any agent running
  there in bypass mode. Never copy SSH **private** keys, vault passphrases, or
  production credentials. Only the allowlisted files in `agent-dev migrate`.
- **Auth is manual and interactive.** Do not try to script `claude`/`codex`/
  `opencode`/`gh`/`glab` logins. Print the exact command and wait for the user.
- **Never run `sudo` or `docker.sock` inside the box.** Fix missing tools with
  mise (live) or `EXTRA_PACKAGES` + overlay build (human-gated).
- **Never delete the home volume or `docker rmi` to "fix" an update.** Use
  `./bin/agent-dev update`; the home volume holds logins, repos and mise tools.
- **Do not rebuild silently.** `up`/`update` recreate the container and stop
  sessions; warn first.

## Flow A — first-time setup

1. Confirm prerequisites on the host: `docker` (or an `ssh` target that can run
   docker), `git`, `mise` (optional but assumed), and `herdr`
   (`curl -fsSL https://herdr.dev/install.sh | sh` if absent). Check with
   `command -v docker herdr`.
2. Run `./bin/agent-dev init` and answer the wizard. It writes `.env` and
   creates the container's host key + `authorized_keys` (defaults to the user's
   first `~/.ssh/*.pub`). If the user has several keys, make sure the one they
   will authenticate with is the one installed.
3. `./bin/agent-dev up` — builds and starts. First start installs harnesses and
   tools into the home volume; watch `./bin/agent-dev logs` until
   `agent-dev bootstrap done`.
4. `./bin/agent-dev ssh-config` → have the user add the printed block to
   `~/.ssh/config` **or** `~/.ssh/config.d/<file>`.
5. Test: `ssh agent-dev 'id && command -v herdr && uname -s'`. Then
   `./bin/agent-dev machine-add` → `herdr machine status agent-dev`.
6. Authenticate inside the box, interactively, one at a time:
   `./bin/agent-dev shell` then `gh auth login`, `glab auth login`,
   `claude` (first run logs in), `codex login`, `opencode auth login` as
   applicable. The user chose **git over HTTPS via `gh`**, so `gh auth login`
   plus `gh auth setup-git` is the important one.
7. `./bin/agent-dev doctor` for a final check.

## Flow B — migrate from the host

Use when the user says "bring my setup across" / "I don't want new keys".

**Run this on the laptop**, so `$HOME` is theirs. If they are SSHed into the NAS,
stop and have them run it locally — otherwise it copies the wrong configs.

1. `./bin/agent-dev migrate` (interactive) or with flags:
   `--git --ssh --cli --agent --dotfiles --repos --all`.
2. Explain what each group is first (see `docs/tools.md` and the README table).
   Defaults: git identity **on**, SSH config + known_hosts **on** (no keys),
   gh/glab tokens **on**, agent auth **on**, dotfiles/repos **off**.
3. After it runs, verify: `./bin/agent-dev shell 'gh auth status'` and
   `git config --global user.email`. Git-over-HTTPS should just work.
4. Reminder: the copied tokens are now readable by any agent in the box.

## Flow C — "I need tool X, it isn't in the container"

This is the package-gap case. Three tiers, then act:

1. `./bin/agent-dev gap <name>` prints the correct tier.
2. **mise by name** (most CLIs/runtimes): `./bin/agent-dev shell 'mise use -g <name>'`.
   Live, persists in the home volume.
3. **mise by backend** — only if there is no plain name:
   `mise use -g npm:<pkg>` / `pipx:<pkg>` / `cargo:<pkg>` / `ubi:<owner>/<repo>`.
   Also live. `mise search <name>` to find the spec.
4. **apt / system library**: edit `EXTRA_PACKAGES` in `.env`, then
   `./bin/agent-dev up`. This builds a thin `Dockerfile.user` overlay on the
   published image and recreates the container — say that sessions stop.
5. **A harness**: add its mise id to `HARNESSES` (or `CURSOR=1`), then `up`.
   See `docs/harnesses.md`.

## Flow E — updates

To take a new base image: `./bin/agent-dev update` (pulls + recreates). The
home volume and the `EXTRA_PACKAGES` overlay are preserved. Never tell the user
to `docker rmi` or delete the volume. Maintainers build the base with
`AGENT_DEV_BUILD=1 ./bin/agent-dev up`.

## Flow D — pick / add harnesses

When the user asks "can it run X?":

- Check `docs/harnesses.md` first, then `mise search <name>` inside the box.
- For DeepSeek: it is a *model*, not a harness. Configure it as an
  OpenAI-compatible provider inside opencode/Crush/etc.
- To add: append to `HARNESSES` in `.env`, run `up`, then log in interactively.

## Guardrails

- Stop and ask before anything that recreates the container or writes outside
  the repo.
- `agent-dev migrate` must never include private keys — the script deletes
  `id_*`, `*.pem`, `*.key` from the staging tree; do not defeat that.
- If the user is on Unraid: `/root` is tmpfs, so keep `AGENT_DEV_HOME` under
  `/mnt/user/appdata`; Unraid uid/gid is `99:100`.
