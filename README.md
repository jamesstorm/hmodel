# hmodel

Switch the Hermes Agent default model safely, bypassing the broken desktop model picker.

## Why

The Hermes desktop model picker has a config-clobbering bug: selecting a model (even within the same provider) rewrites `config.yaml`, replacing the literal `api_key` with a synthesized `key_env: HERMES_CUSTOM_<SLUG>_API_KEY` that is never resolved. This kills every open chat with `launch_credentials_unavailable` and breaks new chats. See [NousResearch/hermes-agent#141063](https://github.com/NousResearch/hermes-agent/issues/141063).

`hmodel` edits `config.yaml` directly, bypassing the picker entirely.

## Usage

```
hmodel                          # show current provider + model
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

- Backs up `~/.hermes/config.yaml` to `config.yaml.bak-<timestamp>` before editing.
- With a provider: rewrites the whole `model:` block (provider, default, base_url, api_key, api_mode) from the matching `providers.<slug>` entry, and strips any stale `key_env`.
- Without a provider: changes only the `default:` line.
- Asserts after the edit that the model stuck and the credential survived.
- Restarts the gateway (unless `--no-restart`).

## Safety rules (while #141063 is open)

- **Never use the desktop model picker** — any selection rewrites `api_key` → `key_env` and breaks the config.
- Keep `api_key` **literal** in `config.yaml` (or an actual exported var like `${NOUS_API_KEY}`), never `key_env`.
- After a switch, open a **new** chat in the desktop app — don't `/retry` an old one (sessions freeze their credential fingerprint at launch).

## Tab completion

- **bash:** source `hmodel-completion.bash` (or drop it in `/etc/bash_completion.d/`).
- **zsh:** put `_hmodel` on your `$fpath` (e.g. `~/.zsh/completions/`) and run `compinit`.

Completes provider slugs, and models per provider (from the provider's static `models:` list, or live from its endpoint).

## Install

```bash
install -m 0755 hmodel ~/.local/bin/hmodel
```

## Requirements

- `~/.hermes/config.yaml` with a `providers:` section
- `python3` with `yaml` (PyYAML)
- `hermes` CLI on PATH (for the gateway restart)
