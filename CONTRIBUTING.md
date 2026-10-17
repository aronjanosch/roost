# Contributing

Thanks for looking. roost is small on purpose: one container, one port, one
compose file. Changes that keep it that way are the easiest to merge.

- **Bugs:** open an issue with the bug template. `docker logs roost` helps a
  lot.
- **Small fixes** (docs, typos, an obvious bug): send a PR directly.
- **Anything bigger** (new commands, new defaults, more image weight): open an
  issue first so we can agree on the shape before you build it.
- **A tool you miss:** check [docs/tools.md](docs/tools.md) first. Most tools
  belong in mise inside the box, not in the image.

## Local checks

```bash
shellcheck entrypoint.sh roost-trust bin/roost-migrate
docker build -t roost:dev .
ROOST_IMAGE=roost:dev docker compose up -d
```

Commits: short imperative subject, body explains why.
