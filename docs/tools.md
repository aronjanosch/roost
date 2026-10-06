# Tools

Two levers, and it matters which one you use:

| Lever | Installs | Persists | Rebuild? |
|---|---|---|---|
| **mise** | CLIs, runtimes, language toolchains | yes (in the home volume) | no |
| **apt** (`EXTRA_PACKAGES`) | system libraries, `ffmpeg`, `-dev` headers | only in the image | **yes** |

Rule of thumb: if `mise use -g <tool>` works, it is live. If it needs shared
libraries or is an `apt` package, it goes in `EXTRA_PACKAGES` and gets built as
a thin overlay on top of the published image.

## Three tiers, not two

1. **mise by name** — `mise use -g lazygit`, `mise use -g python@3.12`.
2. **mise by backend** — when there is no plain name:
   `mise use -g npm:<pkg>`, `pipx:<pkg>`, `cargo:<pkg>`, `ubi:<owner>/<repo>`,
   `aqua:<owner>/<repo>`. Tiers 1 and 2 are both live and persistent.
3. **apt** — `EXTRA_PACKAGES` in `.env` + `./bin/roost up`. This builds
   `Dockerfile.user` (`FROM` the published image) as a small overlay, so it only
   re-runs that one layer on top of a new base.

## Updates

```bash
./bin/roost update     # pull a newer published image + recreate
```

The base image is pulled, never rebuilt, for normal users — so an update is
fast and reproducible. Your overlay (`EXTRA_PACKAGES`) is re-applied
automatically from `.env`; your home volume is untouched. Sessions stop while
the container is recreated.

Maintainers who want to build the base image from `Dockerfile` locally:

```bash
ROOST_BUILD=1 ./bin/roost up
```

## Inside the box, live (mise)

```bash
mise use -g lazygit            # or: aqua:owner/repo, npm:pkg, pipx:pkg, cargo:pkg, ubi:owner/repo
mise use -g python@3.12
mise use -g npm:some-cli
mise up                        # update everything
```

`./bin/roost gap <name>` prints the right command for a given tool.

## Image overlay (apt)

```bash
./bin/roost gap ffmpeg     # tells you: add to EXTRA_PACKAGES
# then edit .env:  EXTRA_PACKAGES="ffmpeg libpq-dev"
./bin/roost up             # builds Dockerfile.user overlay + recreates
```

The overlay is re-applied on every `up`/`update`; the home volume (logins,
repos, mise tools) survives. Sessions stop while the container is recreated.

## Default set

`TOOLS` in `.env` installs: `herdr uv gh glab npm:ccusage npm:playwright
npm:@playwright/mcp`, plus `node@lts`. The base image also carries git, tmux,
ripgrep, fd, jq, btop, build-essential, python3-venv, vim, less, openssh.

## Why not sudo?

There is deliberately **no sudo and no Docker socket**. Agents run in bypass
mode, so root in the container would be root on the host. Keep new dependencies
flowing through mise or a reviewed `EXTRA_PACKAGES` change. If a task truly
needs to deploy a service, write a compose file in the repo and have a human
deploy it.
