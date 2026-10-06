# roost container

- Private, long-running dev box for coding agents. Sessions keep running in herdr even when the client is closed, so long tasks survive your laptop sleeping.
- `/home/agent` is persistent (logins, repos under `~/projects`, mise tools). One git worktree per task.
- Tools come from mise. Update with `mise up`, not the tools' own updaters. System packages and the image are changed in the roost repo (Dockerfile / `EXTRA_PACKAGES`), then rebuilt -- not by hand in the container.
- No sudo, no Docker socket. To test a service, add a compose file in the repo; a human deploys it.
- Bypass / yolo mode is intended here. Still: no production credentials in the container (vault passphrases, hypervisor tokens, server SSH keys).
- Chromium runs headless with `--no-sandbox` (Playwright MCP is preconfigured).
