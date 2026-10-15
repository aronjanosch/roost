---
name: roost-setup
description: Set up and operate roost, a long-running headless container for coding agents (herdr + Claude Code/Codex/opencode) on a NAS/VM, reached over its own SSH port. Use when the user wants to set up the box, connect another laptop or a phone/Termius to it, migrate logins/config into it, log in gh/glab or a harness inside it, add a missing tool or package, or update it.
---

# roost

One container on a docker host (NAS/VM) holds the agents. Devices reach it as
`ssh roost` / `herdr machine add roost`: the box's own sshd, published on
`SSH_BIND:SSH_PORT` (default all interfaces, 2222), pubkey-only, user `agent`.
No sudo, no Docker socket. Management commands (`up`, `join`, `add-key`,
`migrate`) go through `ssh <docker-host> docker …`. Sessions keep running
while laptops sleep.

All host-side actions go through `./bin/roost` (`./bin/roost help` lists them).
When a step has no command, say so instead of improvising one.

## Where state lives

- **The box is the source of truth.** Paths and the uid come from
  `docker inspect roost` on the docker host.
- **`.env`** sits only on the *deploy device*, the one that ran `init` and runs
  `up`/`update`. It is gitignored, so another clone has none.
- **`~/.config/roost/host`** on every other device holds just `SSH_HOST`;
  `roost join` writes it.
- The SSH login user is always `agent`. Allowed keys: `PUBLIC_KEYS` in the
  compose env (rebuilt on every start) plus `authorized_keys` in the root-owned
  volume at `/etc/roost/ssh` (`roost add-key`). The container generates its
  host key there on first start.

Run the CLI on the user's own laptop: `migrate` copies the *local* `$HOME`.

## Pick the branch

| The user wants to … | Branch |
|---|---|
| create the box for the first time | A — set up |
| use an existing box from this (or another) laptop | B — join |
| use it from Termius / a phone / an iPad | C — mobile |
| bring logins, git identity, repos across | D — migrate |
| install a missing tool or package | E — tools |
| update the image, or runs the box from their own compose file | F — operate |

## A — set up the box (deploy device, once)

Two ways, same result. Without the CLI (user works on the docker host): copy
`compose.yml`, put the laptop's public key in `.env` as `PUBLIC_KEYS="…"`,
`docker compose up -d`, then continue at step 4. With the CLI:

1. Prerequisites: `ssh <docker-host> docker ps` works (the ssh user can run
   docker), and `herdr` is on the laptop
   (`curl -fsSL https://herdr.dev/install.sh | sh`).
2. `./bin/roost init`: the wizard writes `.env` including `PUBLIC_KEYS`. With
   several keys in `~/.ssh` (or an agent like 1Password), confirm the one the
   user's ssh actually offers to that host (`ssh -v <docker-host>`).
3. `./bin/roost up`, then `./bin/roost logs` until `roost bootstrap done`.
4. `./bin/roost ssh-config` → into `~/.ssh/config`; test `ssh roost id`.
5. `./bin/roost machine-add`, then continue with step 6 of branch B.

Done when `./bin/roost doctor` is all `ok`.

## B — join a device

On the new laptop, from a clone of the repo:

1. `ssh <docker-host> docker ps` must work from *this* laptop first. A failure
   here is the docker host's own ssh/key setup, outside roost.
2. `./bin/roost join <docker-host>`: finds the container, saves the host,
   appends this laptop's key, adds `Host roost` to `~/.ssh/config`, tests it
   and offers `herdr machine add`.
3. If it printed "could not write the box's authorized_keys" (identity volume
   mounted read-only), add the printed key to `PUBLIC_KEYS`, recreate, re-run
   `join`.
4. Logins already in the box are shared; this laptop needs none of its own.

Done when `ssh roost id` prints `agent` and `herdr machine status roost` is
connected. A herdr protocol mismatch (`roost doctor`) means
`mise up herdr` on both sides.

## C — mobile (Termius, Heeler and other phone apps)

A phone is just another key on the box's sshd:

1. User exports the app's public key to a file (or pastes the line).
2. `./bin/roost add-key <file.pub | 'ssh-ed25519 …'>` appends it to the box's
   `authorized_keys`, live. Without the CLI: add it to `PUBLIC_KEYS`, recreate.
3. In the app: host = the `HostName`, port = the `Port` from
   `./bin/roost ssh-config`, user `agent`, that key. The phone must reach that
   address (same LAN, or VPN/Tailscale). `herdr` attaches to the running
   sessions; SFTP works.

## D — migrate this laptop's setup

1. Explain the groups before running (table in `docs/reference.md`): git, ssh config +
   known_hosts, gh/glab tokens, agent logins on; dotfiles, `~/projects` off.
   Private keys (`id_*`, `*.pem`, `*.key`) are always stripped.
2. `./bin/roost migrate` (interactive) or with `--git --ssh --cli --agent
   --dotfiles --repos --all`.
3. Verify: `./bin/roost shell 'gh auth status && git config --global user.email'`
   and a clone of a private repo. `migrate` runs `gh auth setup-git` in the box
   (the copied `.gitconfig` points at the laptop's gh path); if it warned, run
   it there by hand. glab: `glab auth login` with a token, then
   `glab config set git_protocol https`; the box has no SSH key.
4. Remind the user that copied tokens are readable by every agent in the box.

Logins not migrated stay **interactive**: print the command and let the user run
it in `./bin/roost shell` (`gh auth login && gh auth setup-git`, `claude`,
`codex login`, `opencode auth login`).

## E — a tool is missing

`./bin/roost gap <name>` names the tier:

- **mise** (by name, or `npm:`/`pipx:`/`cargo:`/`ubi:` backend):
  `./bin/roost shell 'mise use -g <spec>'`. Live, persists in the home volume.
- **apt / system library**: add to `EXTRA_PACKAGES` in `.env` on the deploy
  device, then `./bin/roost up` (builds a thin overlay and recreates the box).
- **harness**: add to `HARNESSES` (or `CURSOR=1`), then `up`.
  `docs/harnesses.md` lists what is verified.

## F — operate

- `./bin/roost update` pulls a newer image and recreates; the home volume and
  overlay survive.
- Box run from the user's own compose project: `docker compose pull && docker
  compose up -d` there. Every other branch works unchanged, because the CLI reads
  the box via `docker inspect` and needs no `.env`.

## Guardrails

- `up`, `update` and compose recreates **stop running sessions**: warn and get a
  yes first.
- The home volume holds logins, repos and mise tools. Recover through `update`;
  keep the volume and image in place.
- Fix tools via mise or `EXTRA_PACKAGES`; the box has no sudo by design.
- Only public keys go into the box or `authorized_keys`.
