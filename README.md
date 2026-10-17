<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
  <img src="assets/logo.svg" alt="" width="96">
</picture>

# roost

**A home for your remote coding agents.**<br>
Built for [herdr](https://herdr.dev).

[install](#install) · [connect](#connect) · [set up](#set-up-inside) · [docs](docs/reference.md)

[![image](https://img.shields.io/github/actions/workflow/status/aronjanosch/roost/image.yml?label=image)](https://github.com/aronjanosch/roost/actions/workflows/image.yml)
[![license](https://img.shields.io/github/license/aronjanosch/roost)](LICENSE)
[![stars](https://img.shields.io/github/stars/aronjanosch/roost)](https://github.com/aronjanosch/roost/stargazers)

</div>

roost is one Docker container for your NAS, homelab or VM. Claude Code, Codex,
opencode and friends live in it, and you drive them from
[herdr](https://herdr.dev). Close the laptop, and the agents keep working.
Open herdr on another machine or your phone, and you are back in the same
sessions.

- **A normal container:** one compose file, one port, your public key. No
  scripts to run on the docker host.
- **Plain SSH in:** pubkey-only, one user (`agent`). Works with `ssh`, herdr,
  VS Code Remote, SFTP, Termius, [Heeler](https://github.com/ZingerLittleBee/Heeler).
- **Agents ready on first start:** harnesses, herdr, `gh`/`glab`, headless
  Chromium + Playwright MCP, all via [mise](https://mise.jdx.dev).
- **Contained:** no sudo, no Docker socket. Agents cannot add logins.
- **Persistent:** logins, repos and tools live in one volume and survive
  updates.

## Install

On the docker host, in an empty folder:

```bash
curl -fsSLO https://raw.githubusercontent.com/aronjanosch/roost/main/compose.yml
cat > .env <<'EOF'
PUBLIC_KEYS="ssh-ed25519 AAAA... laptop,ssh-ed25519 AAAA... phone"
GIT_USER_NAME="Ada Lovelace"
GIT_USER_EMAIL="ada@example.com"
EOF
docker compose up -d
docker logs -f roost      # first start installs tools; wait for "roost bootstrap done"
```

Only `PUBLIC_KEYS` is required. Everything else (port, paths, uid, harnesses,
extra packages) is in [.env.example](.env.example). Change a value, then
`docker compose up -d` again. On Unraid, use uid/gid `99:100` and paths under
`/mnt/user/appdata`.

## Connect

```sshconfig
# ~/.ssh/config: pick any alias
Host roost
  HostName <docker-host>
  Port 2222
  User agent
```

```bash
ssh roost                              # shell in the box
herdr machine add roost --label roost  # sessions show up next to your local ones
```

**From your phone:** any SSH app works (Termius, [Heeler](https://github.com/ZingerLittleBee/Heeler), …).
Same host, port `2222`, user `agent`, the app's key in `PUBLIC_KEYS`. Run
`herdr` to attach. Your phone needs to reach the host: same LAN, or a VPN
such as Tailscale.

## Set up inside

Start an agent in the box and ask it to **set up roost**. The built-in
`roost-setup` skill walks you through what is still missing: git identity, `gh`
login, agent logins, cloning your repos into `~/projects`, tools your projects
need, and how to connect more devices.

Already logged in on your laptop? Copy those logins across instead (never
private keys):

```bash
git clone https://github.com/aronjanosch/roost
roost/bin/roost-migrate roost        # your ssh alias for the box; asks per group
```

## Update

```bash
docker compose pull && docker compose up -d   # logins, repos and tools stay
```

Running agent sessions stop during the recreate.

## Docs

- [reference](docs/reference.md): migrate, `~/projects` and trust, herdr
  versions, host notes, security model
- [tools](docs/tools.md) · [harnesses](docs/harnesses.md)
- [maintainers](docs/maintainers.md): image build, file layout
- [roost-setup skill](skills/roost-setup/SKILL.md): the guided setup agents run in the box

## Security

The box runs agents in bypass mode, so treat it as one trust zone. Don't expose
port 2222 to the internet. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
