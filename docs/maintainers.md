# Maintainers

## Publish

Normal users pull a prebuilt image; they never build the base.
`.github/workflows/image.yml` builds and pushes `ghcr.io/<owner>/roost` on
every push to `main`, on `v*` tags, and weekly (to pick up a fresh Ubuntu base).
Forking the repo gives you the same pipeline; point your fork at its own image
with `ROOST_IMAGE=ghcr.io/<you>/roost:latest` in `.env`.

To build by hand instead: `docker build -t ghcr.io/<you>/roost:latest .`

The image is architecture-specific (the Dockerfile fetches the `linux-x64` mise
binary), so it is amd64 only for now.

## Files

```
roost/
├── bin/roost            device-side control (all commands)
├── compose.yml          service definition (pulls the published image)
├── compose.user.yml     overlay (auto-used when EXTRA_PACKAGES is set)
├── compose.build.yml    overlay to build the base image locally (maintainers)
├── Dockerfile           base image: Ubuntu 24.04 + mise + Playwright deps
├── Dockerfile.user      end-user apt extension layer
├── entrypoint.sh        uid/gid remap, home seed, tool bootstrap
├── sshd_config          the box's sshd (pubkey-only, user agent)
├── agent-instructions.md  global AGENTS.md/CLAUDE.md for agents in the box
├── docs/                reference, tools, harnesses, maintainers
├── skill/SKILL.md       agent skill that drives setup/migration/gap-fixes
├── unraid/roost.xml     Unraid Community Apps template
├── .github/             image workflow, issue templates
├── CHANGELOG.md · CONTRIBUTING.md · SECURITY.md
└── .env.example         copy to .env (or let `init` write it)
```
