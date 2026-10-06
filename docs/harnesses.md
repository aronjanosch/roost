# Harnesses (coding agents)

`roost` installs harnesses with **mise**, so anything mise knows is one id
away. Inside the container you can always check what is available:

```bash
mise search <name>          # find a tool
mise registry | grep -i code
```

`herdr` recognises most of these natively (status + `herdr integration install
<name>` to restore sessions). See <https://herdr.dev/docs/agents/>.

## Verified mise ids

| Harness | Setting | mise id | Notes |
|---|---|---|---|
| Claude Code | `HARNESSES` | `claude` | |
| Codex | `HARNESSES` | `codex` | |
| opencode | `HARNESSES` | `opencode` | reports state to herdr |
| Gemini CLI | `HARNESSES` | `gemini` | npm backend |
| GitHub Copilot CLI | `HARNESSES` | `copilot` | |
| Cursor Agent CLI | `CURSOR=1` | `cursor-agent` | |
| Pi | `HARNESSES` | `pi` | reports state |
| Oh My Pi | `HARNESSES` | `oh-my-pi` | herdr calls it `omp` |
| Amp | `HARNESSES` | `amp` | |
| Grok CLI | `HARNESSES` | `grok` | |
| Qwen Code | `HARNESSES` | `qwen` | |
| Crush | `HARNESSES` | `crush` | reports state itself |
| Meta Muse Code | `HARNESSES` | `muse` | |
| Antigravity CLI | `HARNESSES` | `antigravity-cli` | |

## Install-on-demand

Some harnesses are not in mise by name; add their npm/other backend spec to
`HARNESSES`. Confirm the package name with `mise search` first.

```bash
HARNESSES="claude codex opencode npm:<package>"
```

Aider, for example, is a Python tool: `pipx:aider-chat`.

## DeepSeek

There is no separate DeepSeek harness binary in mise. DeepSeek is a *model*:
use it through opencode, Crush, or another harness that supports an
OpenAI-compatible provider, and point that provider at DeepSeek's API. The
harness is what you install here; the model lives in the harness config.

## Adding your own

1. Find the id: `mise search <name>` or `mise registry | grep -i <name>`.
2. Add it to `HARNESSES` in `.env` (or `CURSOR=1` for Cursor).
3. `./bin/roost up` — the entrypoint installs anything missing on the next
   start, into the persistent home volume.
