# claude-mode

Interactive installer + mode switcher for Claude Code billing/auth modes.

`claude-mode` gives you a reliable way to switch between:

- `subscription` (Claude Code OAuth/subscription)
- `api` (direct Anthropic API billing)
- `local` (local-compatible endpoints such as Ollama/LiteLLM)

This repo packages the full setup into one Linux/macOS installer so you can recreate the same configuration on any machine.

## Why this is useful

- Prevents accidental billing mode confusion (for example, landing in API billing when you expected subscription).
- Makes switching explicit and fast with one command.
- Provides a simple built-in workflow to set/update/clear Anthropic API keys.
- Persists mode settings across terminal sessions.
- Installs a global Claude reminder hook so future sessions nudge you with the exact commands.
- Adds a global `/claude-mode` command in Claude Code for quick help.

## What the installer sets up

Running `install.sh` can configure all of the following:

1. Installs `claude-mode` executable (default: `~/.local/bin/claude-mode`).
2. Adds shell startup integration in `~/.bashrc`, `~/.zshrc`, both, or custom file:
   - Loads `~/.config/claude-code/mode.env` automatically.
   - Uses safe unsets when no mode file exists.
   - Optionally ensures install directory is on `PATH`.
3. Installs global Claude assets under `~/.claude`:
   - SessionStart reminder hook script.
   - `/claude-mode` slash command markdown.
   - Merges `hooks.SessionStart` entry into `~/.claude/settings.json` (idempotent).
4. Walks you through selecting a default mode (`subscription`, `api`, or `local`).

## Quick start

One-line installer (Linux/macOS):

```bash
tmpdir="$(mktemp -d)" && curl -fsSL https://github.com/trezero/claude-mode/archive/refs/tags/v1.0.0.tar.gz | tar -xz -C "$tmpdir" && bash "$tmpdir/claude-mode-1.0.0/install.sh"
```

Local clone/install:

```bash
cd /home/winadmin/projects/claude-mode
./install.sh
```

Then either open a new terminal or run:

```bash
source ~/.config/claude-code/mode.env
```

Check/help:

```bash
claude-mode
```

Configure Anthropic API key (hidden prompt):

```bash
claude-mode api-key
```

## How `claude-mode` works

`claude-mode` manages two files:

- `~/.config/claude-code/mode`
- `~/.config/claude-code/mode.env`

Your shell startup file sources `mode.env`, which exports/unsets the Anthropic-related environment variables needed for the selected mode.

### Mode behavior

- `subscription`
  - Unsets `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, `LITELLM_MASTER_KEY`.
  - Lets Claude Code use account OAuth/subscription credentials.

- `api`
  - Exports `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` (default `https://api.anthropic.com`).
  - Unsets `ANTHROPIC_AUTH_TOKEN`.
  - Caches API key in `~/.config/claude-code/api.key` with mode `600`.

- `local`
  - Exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` for local-compatible providers.
  - Defaults to `http://localhost:11434`, auth token `ollama`, api key `unused`.

### API key management

Use these commands to manage Anthropic API keys:

```bash
claude-mode api-key              # prompt and save key (input hidden)
claude-mode api-key set <KEY>    # set key directly
claude-mode api-key show         # show masked key + path
claude-mode api-key clear        # remove stored key
claude-mode api                  # enable api mode using stored key
```

## Global reminder integration

The installer can add a Claude SessionStart hook that injects reminder context each session, prompting a short reminder in first responses with the key commands:

- `claude-mode`
- `claude-mode api-key`
- `claude-mode subscription`
- `claude-mode api`
- `claude-mode local`
- `source ~/.config/claude-code/mode.env`

It also installs a global `/claude-mode` slash command under `~/.claude/commands`.

## Idempotency and safety

- Re-running the installer is safe.
- Existing target files are backed up with timestamp suffixes (`.bak-YYYYMMDD-HHMMSS`) before overwrite/merge.
- Shell config insertion uses marker blocks:
  - `# >>> claude-mode >>>`
  - `# <<< claude-mode <<<`
- Claude settings merge preserves existing config and appends only missing hook entries.

## Files in this repo

```text
.
├── install.sh
├── assets
│   ├── bin/claude-mode
│   └── claude
│       ├── hooks/claude-mode-reminder-session-start.sh
│       └── commands/claude-mode.md
├── README.md
└── LICENSE
```

## Uninstall

Manual uninstall steps:

1. Remove executable:
   - `rm -f ~/.local/bin/claude-mode` (or your custom install path)
2. Remove shell marker blocks from your shell startup file(s):
   - `# >>> claude-mode >>> ... # <<< claude-mode <<<`
   - `# >>> claude-mode-path >>> ... # <<< claude-mode-path <<<`
3. Remove mode files:
   - `rm -rf ~/.config/claude-code`
4. Remove Claude global helper files (if installed):
   - `rm -f ~/.claude/hooks/claude-mode-reminder-session-start.sh`
   - `rm -f ~/.claude/commands/claude-mode.md`
5. Remove hook entry from `~/.claude/settings.json` if desired.

## Requirements

- Linux or macOS
- `bash`
- `python3`

## License

MIT License. See [LICENSE](LICENSE).
