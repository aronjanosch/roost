# Maintainers

## Publish

Normal users pull a prebuilt image; they never build the base.
`.github/workflows/image.yml` builds and pushes `ghcr.io/<owner>/roost` on
every push to `main`, on `v*` tags, and weekly (to pick up a fresh Ubuntu base).
Forking the repo gives you the same pipeline; point your fork at its own image
with `ROOST_IMAGE=ghcr.io/<you>/roost:latest` in `.env`.

To build by hand instead: `docker build -t ghcr.io/<you>/roost:latest .`

The image is built for `linux/amd64` and `linux/arm64` (Raspberry Pi 4/5, ARM
NAS, Apple-silicon VMs); arm64 runs under QEMU in CI, so a build takes longer.

## Files

```
roost/
├── bin/roost-migrate    laptop → box: copy config and logins over ssh
├── compose.yml          service definition (pulls the published image)
├── compose.user.yml     overlay for EXTRA_PACKAGES (apt)
├── Dockerfile           base image: Ubuntu 24.04 + mise + Playwright deps
├── Dockerfile.user      end-user apt extension layer
├── entrypoint.sh        uid/gid remap, home seed, tool bootstrap, sshd
├── roost-trust          in the image: pre-accept Claude trust for ~/projects/*
├── roost-pair           in the image: Heeler QR pairing (HEELER_PAIRING=1)
├── sshd_config          the box's sshd (pubkey-only, user agent)
├── agent-instructions.md  global AGENTS.md/CLAUDE.md for agents in the box
├── docs/                reference, tools, harnesses, maintainers
├── skills/roost-setup/  guided setup skill, installed for every agent in the box
├── assets/             logo (light/dark), icon.png (Unraid), og-card.png (social preview)
│   └── demo/           README GIF: record.sh + roost.tape (VHS)
├── templates/roost.xml  Unraid Community Apps template (+ ca_profile.xml)
├── .github/             image workflow, issue templates
├── CHANGELOG.md · CONTRIBUTING.md · SECURITY.md
└── .env.example         copy to .env next to compose.yml
```

## Demo GIF

`assets/demo/record.sh` deploys a throwaway box (container `roost-demo`, port
2299) on a docker host next to any real roost, then records
`assets/demo/roost.tape` with VHS:

```bash
DEMO_HOST=nas DEMO_DIR=/mnt/user/appdata/roost-demo assets/demo/record.sh
```

The first run bootstraps the demo home once (a few minutes, kept for later
recordings; `DEMO_CLEAN=1` removes it). The recording uses a throwaway SSH
key and none of your ssh config, so nothing personal ends up in the GIF.
