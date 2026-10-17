# Changelog

## Unreleased

roost is now a plain container: compose file, one port, your public key.

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

Upgrading an existing box: add the `ports:` entry and `PUBLIC_KEYS` from
`compose.yml`, then recreate. The SSH volume can stay as it is (also
read-only); existing keys and the host key keep working. Point your ssh
config at the port instead of the `docker exec` ProxyCommand.

## 2026-10-06

- First public version (renamed from agent-dev).
