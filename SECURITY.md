# Security

## Model

roost runs coding agents with broad permissions inside one container. The
container is the boundary:

- no sudo, no Docker socket, no host mounts besides the home and SSH volumes
- one sshd, pubkey-only, single user `agent`, no root login, no remote
  forwarding (local forwarding is on: Heeler reaches herdr's socket through it)
- allowed keys and the host key are root-owned, outside the agent's home
  (unless you turn on `HEELER_PAIRING`: then `~/.ssh/authorized_keys`, which
  agents can write, grants logins too)

Anything you put in the box (gh tokens, agent logins, repos) is readable by
every agent in it. Keep port 2222 on your LAN or VPN; don't forward it to the
internet.

## Reporting a vulnerability

Please use GitHub's private reporting: **Security → Report a vulnerability** on
this repository. Don't open a public issue for it. You'll get an answer within
a week.
