# Changelog

## Unreleased

- Heeler QR pairing: `HEELER_PAIRING=1` plus `HEELER_ADDRESSES`, then
  `roost-pair` in the box shows a Pairing Code to scan. Off by default; when
  on, `~/.ssh/authorized_keys` grants logins too. The plugin comes from a fork
  until ZingerLittleBee/Heeler#489 is merged.
- The SSH host key is linked to `/etc/ssh`, where tools such as the Heeler
  plugin look for it.

## 0.1.0 (2026-10-17)

First release. roost is a plain container: compose file, one port, your
public key.

- The box runs its own sshd on one published port (`SSH_PORT`, default 2222).
  Every SSH client connects directly as `agent`, phones included.
- `PUBLIC_KEYS` (comma-separated) authorises keys; the container generates its
  SSH host key on first start. Nothing to set up on the docker host.
- The `bin/roost` CLI is gone. Install and update with `docker compose`;
  configure with `.env`. What is left:
  - `bin/roost-migrate <ssh-target>` copies your laptop's config and logins
    over plain ssh (any alias, never private keys).
  - `roost-trust` in the image (run on every start) pre-accepts Claude trust.
  - The `roost-setup` skill is installed for Claude, Codex and opencode in the
    box: ask an agent to "set up roost" for a guided setup.
- Extra apt packages: `docker compose -f compose.yml -f compose.user.yml up -d --build`.
- `GH_TOKEN` logs gh in on start and wires git to it.
- Starts in seconds: no more walking the whole home on every new container.
- Images for linux/amd64 and linux/arm64.
- Unraid Community Apps template (`templates/roost.xml`), logo and icon.

Upgrading an existing box: add the `ports:` entry and `PUBLIC_KEYS` from
`compose.yml`, then recreate. The SSH volume can stay as it is (also
read-only); existing keys and the host key keep working. Point your ssh
config at the port instead of the `docker exec` ProxyCommand.

## 2026-10-06

- First public version (renamed from agent-dev).
