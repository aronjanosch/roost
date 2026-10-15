# Reference

Details behind the [README](../README.md). Tools and harnesses have their own
pages: [tools.md](tools.md), [harnesses.md](harnesses.md).

## Migrate

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

## Layout and trust

Repos live in the box under `~/projects/<name>` (`/home/agent/projects/<name>`).
That path is a stable contract: tools can map "repo name → `~/projects/<name>`"
without configuration, and `migrate --repos` puts checkouts there.

Because the container is the security boundary (no sudo, no Docker socket, only a
pubkey-only sshd), the entrypoint pre-accepts Claude's folder-trust dialog for
`~/projects` and every directory below it, so sessions don't block on startup.
Repos cloned later are covered after a restart or `roost trust`. Set
`TRUST_PROJECTS=0` in `.env` to keep the dialog. `rsync` is in the image for
tools that expect it.

## herdr versions

`herdr machine add` needs compatible protocol versions on laptop and box. herdr
is installed unpinned via mise, so `roost doctor` compares `herdr status`
protocols on both sides. If they differ, run `mise up herdr` on both, or pin it
with `TOOLS="herdr@<version> …"` in `.env`.

## Host notes

- **Unraid:** use paths under `/mnt/user/appdata` and uid/gid `99:100`.
- **Ports:** `SSH_PORT` (default 2222) must be free on the docker host and
  reachable from your devices. By default it listens on every host interface
  (LAN, Tailscale, …). `SSH_BIND` limits it to one IP, but the container then
  fails to start if that IP is not up yet (e.g. Tailscale after a reboot). Do
  not forward the port to the internet.
- **Keys:** `PUBLIC_KEYS` is rebuilt on every start, so deleting a key there
  and running `docker compose up -d` revokes it. Keys added with
  `roost add-key` live in `<ROOST_SSH>/authorized_keys`; edit that file to
  revoke them.
- **Helper CLI:** `SSH_HOST` is an ssh alias/`user@host` that can run `docker`;
  the CLI uses it for management only (`join`, `add-key`, `migrate`, …).
  Leave it blank (`join local`) for a local daemon. A box started from your own
  compose file works with every command except `init`/`up`/`update`.

## Security model

- No sudo, no Docker socket in the container.
- The SSH host key and `authorized_keys` live in a root-owned volume outside
  the agent-writable home, and `PUBLIC_KEYS` is written to a root-owned file
  in `/run`, so agents cannot change the login set. The host key is generated
  on first start and kept across updates.
- The sshd lets in only `agent`, by public key: no passwords, no root, no
  port forwarding. Only the keys you install can log in.
- Copied host credentials (gh/glab/agent auth) are sensitive: they are readable
  by any agent in the box. Rotate them if the box is ever compromised.
