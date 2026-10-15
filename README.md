<div align="center">

# roost

**A home for your coding agents that never sleeps.**

[install](#install) · [connect](#connect) · [phone](#from-your-phone) · [docs](docs/reference.md)

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
echo 'PUBLIC_KEYS="ssh-ed25519 AAAA... my-laptop"' > .env   # your public key(s)
docker compose up -d
docker logs -f roost      # first start installs tools; wait for "roost bootstrap done"
```

That's it. More keys: comma-separated in `PUBLIC_KEYS` (`"key1,key2"`), then
`docker compose up -d`. Everything else is optional; see
[.env.example](.env.example) (port, paths, uid, harnesses, extra packages).

On Unraid, use uid/gid `99:100` and paths under `/mnt/user/appdata`.

## Connect

```sshconfig
# ~/.ssh/config
Host roost
  HostName <docker-host>
  Port 2222
  User agent
```

```bash
ssh roost                              # shell in the box
herdr machine add roost --label roost  # sessions show up next to your local ones
```

Log in once inside the box (`claude`, `codex login`, `gh auth login`, …), or
bring your laptop's logins across with [`roost migrate`](#helper-cli).

## From your phone

Any SSH app works: host = your docker host, port `2222`, user `agent`, and the
app's key in `PUBLIC_KEYS`. Run `herdr` to attach to the running sessions.
Your phone needs to reach the host: same LAN, or a VPN such as Tailscale.

## Helper CLI

Optional. `bin/roost` runs on your laptop and talks to the docker host over
your existing SSH login.

```bash
git clone https://github.com/aronjanosch/roost && cd roost
./bin/roost join <docker-host>   # authorise this laptop, write ~/.ssh/config, add herdr machine
./bin/roost add-key phone.pub    # authorise another key, no restart
./bin/roost migrate              # copy git/gh/agent logins into the box (never private keys)
./bin/roost gap <tool>           # how to install something missing
./bin/roost doctor               # health checks
./bin/roost help                 # all commands
```

`./bin/roost init` + `up` set up the box from your laptop instead of copying
`compose.yml` by hand.

## Docs

- [reference](docs/reference.md): migrate, `~/projects` and trust, herdr
  versions, host notes, security model
- [tools](docs/tools.md) · [harnesses](docs/harnesses.md)
- [maintainers](docs/maintainers.md): image build, file layout
- [skill/SKILL.md](skill/SKILL.md): agent skill that walks through all of this

## Security

The box runs agents in bypass mode, so treat it as one trust zone. Don't expose
port 2222 to the internet. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
