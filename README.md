# roost

**A long-running, headless dev box for coding agents.** Run Claude Code, Codex,
opencode and friends in one persistent container on a NAS or VM, drive them from
[herdr](https://herdr.dev), and let long tasks keep going when your laptop
sleeps.

Reached with `herdr machine add`, not `ssh somewhere`: the container has **no
inbound ports**, no sudo, and no Docker socket. SSH rides an on-demand `docker
exec` stream, so nothing is exposed to the network. Plain `ssh roost` still
works too — both paths use the same connection.

```
   your laptop                 your NAS / VM                container
  ┌──────────┐   ssh+herdr    ┌─────────────┐   docker    ┌──────────────┐
  │  herdr   │ ─────────────► │ docker exec │ ──────────► │ sshd -i      │
  │ machine  │   (no port)    │  sshd -i    │             │ herdr server │
  └──────────┘                └─────────────┘             │ agents …     │
                                                          └──────────────┘
```

## Why

- **Long tasks survive your client.** herdr keeps panes in a background server;
  detach and reattach later.
- **One place for agents.** Local and remote work in one herdr window.
- **Sealed by default.** Bypass/yolo mode is expected here, so the container is
  the boundary: no sudo, no Docker socket, read-only SSH identity, mem/pids caps.
- **Live tool installs.** mise installs into the persistent home; only system
  libraries need a rebuild.

## Quickstart

> **Run the CLI from your laptop.** It reads *your* `$HOME` for `migrate` and
> pushes the repo to `SSH_HOST` for `up`. The NAS/VM only hosts the container;
> your configs live where you do.

```bash
git clone https://github.com/aronjanosch/roost && cd roost

./bin/roost init        # wizard → writes .env, creates the SSH identity
./bin/roost up          # build + start (first boot installs tools, ~minutes)
./bin/roost logs        # wait for "roost bootstrap done"
./bin/roost ssh-config  # add the printed block to ~/.ssh/config
./bin/roost machine-add # register with herdr

./bin/roost shell       # then: gh auth login && gh auth setup-git
```

Prudentials on the host: `docker` (or an `ssh` target that can run docker),
`git`, and `herdr` (`curl -fsSL https://herdr.dev/install.sh | sh`).

## Layout and trust

Repos live in the box under `~/projects/<name>` (`/home/agent/projects/<name>`).
That path is a stable contract: tools can map "repo name → `~/projects/<name>`"
without configuration, and `migrate --repos` puts checkouts there.

Because the container is the security boundary (no sudo, no Docker socket, no
inbound ports), the entrypoint pre-accepts Claude's folder-trust dialog for
`~/projects` and every directory below it, so sessions don't block on startup.
Repos cloned later are covered after a restart or `roost trust`. Set
`TRUST_PROJECTS=0` in `.env` to keep the dialog. `rsync` is in the image for
tools that expect it.

## herdr versions

`herdr machine add` needs compatible protocol versions on laptop and box. herdr
is installed unpinned via mise, so `roost doctor` compares `herdr status`
protocols on both sides. If they differ, run `mise up herdr` on both, or pin it
with `TOOLS="herdr@<version> …"` in `.env`.

## Migrate your host setup (no new keys)

Run `migrate` **on your laptop**, not on the NAS: git-over-HTTPS works out of the
box, so copy your `gh` token and you are done — no per-environment SSH key.

```bash
./bin/roost migrate            # interactive
./bin/roost migrate --all      # git, ssh cfg, gh/glab, agent auth, dotfiles, repos
```

`~/.claude.json` is not copied wholesale: it holds host-specific project history
and trust entries. Only login keys (`oauthAccount`, `userID`, onboarding/theme)
are merged into the box's file.

| Group | Copies | Default |
|---|---|---|
| git | `~/.gitconfig`, `~/.config/git` | on |
| ssh | `~/.ssh/config`, `known_hosts` (**never** private keys) | on |
| cli | `gh` `hosts.yml`, `glab` config | on |
| agent | claude/codex/opencode login state | on |
| dots | `.bashrc`, mise config | off |
| repos | `~/projects` | off |

Everything copied is readable by any agent in the box (bypass mode). The script
refuses to copy `id_*`, `*.pem`, `*.key`.

## Adding tools

```bash
./bin/roost gap <tool>                  # how should this be added?

./bin/roost shell 'mise use -g lazygit' # live, persists in the home volume
# apt/system libs: EXTRA_PACKAGES="ffmpeg …" in .env, then
./bin/roost up                          # builds a thin overlay on the base image
```

Updates pull the published image (`./bin/roost update`); your overlay and
home volume survive. See [`docs/tools.md`](docs/tools.md) and
[`docs/harnesses.md`](docs/harnesses.md).

## Commands

| Command | Purpose |
|---|---|
| `init` | wizard: write `.env`, create SSH identity |
| `up` | pull + start (or build overlay when `EXTRA_PACKAGES` is set) |
| `update` | pull a newer image + recreate (home survives) |
| `migrate` | copy host config/credentials in |
| `ssh-config` | print the `~/.ssh/config` block |
| `machine-add` | `herdr machine add roost` |
| `gap <name>` | classify a missing tool (mise vs apt) |
| `doctor` | health checks, incl. herdr protocol match laptop ↔ box |
| `trust` | pre-accept Claude's trust dialog for `~/projects/*` |
| `shell [cmd]` | run inside the box |
| `logs` | follow container logs |
| `setup-ssh` | (re)create host key / authorized_keys |

## Layout

```
roost/
├── bin/roost        host control (all commands)
├── compose.yml          service definition (pulls the published image)
├── compose.user.yml     overlay (auto-used when EXTRA_PACKAGES is set)
├── compose.build.yml    overlay to build the base image locally (maintainers)
├── Dockerfile           base image: Ubuntu 24.04 + mise + Playwright deps
├── Dockerfile.user      end-user apt extension layer
├── entrypoint.sh        uid/gid remap, home seed, tool bootstrap
├── sshd_config          on-demand sshd (no TCP listener)
├── agent-instructions.md  global AGENTS.md/CLAUDE.md for agents in the box
├── docs/                tools.md, harnesses.md
├── skill/SKILL.md       agent skill that drives setup/migration/gap-fixes
└── .env.example         copy to .env (or let `init` write it)
```

## Host notes

- **Unraid:** `/root` is tmpfs — use an appdata path, uid/gid `99:100`.
- **Remote host:** set `SSH_HOST` to an ssh alias/`user@host` that can run
  `docker`. The ProxyCommand adds the `ssh` hop automatically.
- **Local host:** leave `SSH_HOST` blank; `docker` is used directly.
- **Firewall:** there is nothing to open. Access is pubkey-only through
  `docker exec`.

## Publish (maintainers)

Normal users pull a prebuilt image; they never build the base.
`.github/workflows/image.yml` builds and pushes `ghcr.io/<owner>/roost` on
every push to `main`, on `v*` tags, and weekly (to pick up a fresh Ubuntu base).
Forking the repo gives you the same pipeline; point your fork at its own image
with `ROOST_IMAGE=ghcr.io/<you>/roost:latest` in `.env`.

To build by hand instead: `docker build -t ghcr.io/<you>/roost:latest .`

The image is architecture-specific (the Dockerfile fetches the `linux-x64` mise
binary), so it is amd64 only for now.

## Security model

- No sudo, no Docker socket in the container.
- The SSH host key and `authorized_keys` live in a root-owned, read-only mount
  outside the agent-writable home, so agents cannot change the login set.
- Password auth is disabled; only the keys you install can log in.
- Copied host credentials (gh/glab/agent auth) are sensitive: they are readable
  by any agent in the box. Rotate them if the box is ever compromised.

## License

MIT — see [LICENSE](LICENSE).
