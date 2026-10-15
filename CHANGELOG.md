# Changelog

## Unreleased

- The box now runs its own sshd on one published port (`SSH_PORT`, default
  2222). Phones and every SSH client connect directly as `agent`; the
  `docker exec` ProxyCommand and `roost mobile-key` are gone.
- `PUBLIC_KEYS` in the compose env authorises keys; the container generates
  its SSH host key on first start. No setup on the docker host is needed, and
  `roost setup-ssh` is gone.
- `roost add-key` writes through the container (no root on the docker host),
  accepts a file or a pasted key, and works without a restart.

Upgrading an existing box: add the `ports:` entry from `compose.yml` and
recreate. The SSH volume can stay as it is (also read-only); existing keys and
the host key keep working. Replace a ProxyCommand `Host roost` block with the
output of `roost ssh-config`.

## 2026-10-06

- First public version (renamed from agent-dev).
