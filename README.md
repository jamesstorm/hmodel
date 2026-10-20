# hmodel

Switch the Hermes Agent default model safely, bypassing the broken desktop model picker.

## Why

The Hermes desktop model picker has a config-clobbering bug: selecting a model (even within the same provider) rewrites `config.yaml`, replacing the literal `api_key` with a synthesized `key_env: HERMES_CUSTOM_<SLUG>_API_KEY` that is never resolved. This kills every open chat with `launch_credentials_unavailable` and breaks new chats. See [NousResearch/hermes-agent#141063](https://github.com/NousResearch/hermes-agent/issues/141063).

`hmodel` edits `config.yaml` directly, bypassing the picker entirely.

## Usage

```
hmodel                          # show current provider + model
hmodel --listproviders          # list configured providers (slug, name, base_url)
hmodel --list                   # list models for ALL providers, grouped
hmodel --set <model>            # change model only (keep current provider)
hmodel --set <provider> <model> # switch provider AND model
hmodel --set ... --no-restart   # edit only, don't restart the gateway
```

### Examples

```bash
# switch to a local Ollama model on provider "mini-ollama"
hmodel --set mini-ollama qwen3:4b

# switch back to a cloud model on provider "nous-api"
hmodel --set nous-api deepseek/deepseek-v4.1-flash-1017

# change model only, keep current provider
hmodel --set deepseek/deepseek-v4-flash-0731
```

## How it works

- Backs up `$HERMES_HOME/config.yaml` (default `~/.hermes/config.yaml`) to `config.yaml.bak-<timestamp>` before editing.
- With a provider: rewrites the whole `model:` block (provider, default, base_url, api_key, api_mode) from the matching `providers.<slug>` entry, and strips any stale `key_env`.
- Without a provider: changes only the `default:` line.
- Asserts after the edit that the model stuck and the credential survived.
- Restarts the gateway (unless `--no-restart`).

## Safety rules (while #141063 is open)

- **Never use the desktop model picker** — any selection rewrites `api_key` → `key_env` and breaks the config.
- Keep `api_key` **literal** in `config.yaml` (or an actual exported var like `${NOUS_API_KEY}`), never `key_env`.
- After a switch, open a **new** chat in the desktop app — don't `/retry` an old one (sessions freeze their credential fingerprint at launch).

## Install

```bash
install -m 0755 hmodel ~/.local/bin/hmodel
```

## Requirements

- `$HERMES_HOME/config.yaml` (default `~/.hermes/config.yaml`) with a `providers:` section
- `python3` with `yaml` (PyYAML). The script resolves the first interpreter that can
  `import yaml` (vendor venvs included); pin one explicitly with `HMODEL_PY=/path/to/python3`.
- `hermes` CLI on PATH (for the gateway restart)

## Tab completion

Completes the switches, provider slugs, and models per provider (from the provider's
static `models:` list, or live from its endpoint). It needs a `python3` with PyYAML,
same as the script.

### bash

Source it from `~/.bashrc` (completion only exists in interactive shells):

```bash
[[ -r "$HOME/.local/bin/hmodel-completion.bash" ]] && source "$HOME/.local/bin/hmodel-completion.bash"
```

Then open a new shell, or `source ~/.bashrc`. Two things look like a failure but are not:

- `hmodel<TAB>` with no space lists files named `hmodel*`. Bash completes the *command
  word* that way for every command — type the space first: `hmodel <TAB>`.
- With `set -o vi`, Tab in vi **command** mode does nothing; completion is bound in
  insert mode. (Some distributions bind `TAB: menu-complete` in `inputrc`, which cycles
  candidates instead of listing them.)

### zsh

`_hmodel` must be in a directory on `$fpath`, and that directory must be added to
`$fpath` **before `compinit` runs** — a file that is merely present on disk, or a
`.zshrc` edit placed after `compinit`, will not be picked up.

```bash
mkdir -p ~/.local/share/zsh/site-functions
cp _hmodel ~/.local/share/zsh/site-functions/
```

In `~/.zshrc`, *above* the `compinit` lines:

```zsh
fpath=("$HOME/.local/share/zsh/site-functions" $fpath)
autoload -Uz compinit
compinit
```

Then `rm -f ~/.zcompdump*` to force the completion cache to rebuild, and open a new shell.

Gotchas that silently disable it:

- `ZDOTDIR`: if it is set, zsh reads `$ZDOTDIR/.zshrc`, not `~/.zshrc` (`echo $ZDOTDIR`).
- Your login shell is whatever `getent passwd $USER` says — a bash-only setup does
  nothing for a zsh login shell.
- Completion functions are autoloaded, never `source`d.
