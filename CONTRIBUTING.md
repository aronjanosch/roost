# Contributing

Thanks for looking. roost is small on purpose: one container, one port, one
compose file. Changes that keep it that way are the easiest to merge.

- **Bugs:** open an issue with the bug template. `./bin/roost doctor` output
  and `docker logs roost` help a lot.
- **Small fixes** (docs, typos, an obvious bug): send a PR directly.
- **Anything bigger** (new commands, new defaults, more image weight): open an
  issue first so we can agree on the shape before you build it.
- **A tool you miss:** check [docs/tools.md](docs/tools.md) first. Most tools
  belong in mise inside the box, not in the image.

## Local checks

```bash
bash -n bin/roost entrypoint.sh
shellcheck bin/roost entrypoint.sh       # if installed
docker build -t roost:dev .              # or: ROOST_BUILD=1 ./bin/roost up
```

Commits: short imperative subject, body explains why.
