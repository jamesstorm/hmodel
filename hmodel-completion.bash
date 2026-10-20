# bash completion for hmodel
# install: source this file from ~/.bashrc (completion only applies to interactive
# shells), or drop it into /etc/bash_completion.d/ or ~/.bash_completion
#
# note: like every bash completion spec, this applies to arguments — `hmodel <TAB>`.
# Tab on the bare command word itself always lists matching files/commands.
_hmodel() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local CFG="${HERMES_HOME:-$HOME/.hermes}/config.yaml"

  # the first python3 that can import yaml; resolved once per shell, override with HMODEL_PY
  if [ -z "${_HMODEL_PY:-}" ]; then
    local c
    for c in "${HMODEL_PY:-}" /usr/bin/python3 /usr/local/bin/python3 \
             "$(command -v python3 2>/dev/null || true)" \
             "$HOME"/.hermes/*/bin/python3 "$HOME"/.local/share/uv/python/*/bin/python3; do
      [ -n "$c" ] && [ -x "$c" ] || continue
      "$c" -c 'import yaml' >/dev/null 2>&1 && { _HMODEL_PY="$c"; break; }
    done
  fi
  local PY="${_HMODEL_PY:-/usr/bin/python3}"

  # provider slugs from config
  _hmodel_providers() {
    "$PY" - "$CFG" <<'PY' 2>/dev/null
import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1]))
    for k in (d.get('providers') or {}):
        print(k)
except Exception:
    pass
PY
  }

  # models for a provider slug: its static models: list if present, else query the endpoint
  _hmodel_models() {
    local slug="$1"
    "$PY" - "$CFG" "$slug" <<'PY' 2>/dev/null
import sys, yaml, json, urllib.request
cfg, slug = sys.argv[1], sys.argv[2]
try:
    d = yaml.safe_load(open(cfg))
    p = (d.get('providers') or {}).get(slug)
    if not p:
        sys.exit()
    ms = p.get('models')
    if isinstance(ms, dict):
        for k in ms: print(k)
        sys.exit()
    if isinstance(ms, list):
        for k in ms: print(k)
        sys.exit()
    base = (p.get('base_url') or '').rstrip('/')
    key = p.get('api_key') or ''
    req = urllib.request.Request(base + '/models', headers={'Authorization': 'Bearer ' + key})
    data = json.load(urllib.request.urlopen(req, timeout=10))
    for x in data.get('data', []):
        print(x['id'])
except Exception:
    pass
PY
  }

  # first argument: the switches
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "--listproviders --list --set" -- "$cur") )
    return 0
  fi

  # after --set: provider slug, then a model for that provider
  if [ "${COMP_WORDS[1]}" = "--set" ]; then
    if [ "$COMP_CWORD" -eq 2 ]; then
      COMPREPLY=( $(compgen -W "$(_hmodel_providers)" -- "$cur") )
      return 0
    elif [ "$COMP_CWORD" -eq 3 ]; then
      COMPREPLY=( $(compgen -W "$(_hmodel_models "${COMP_WORDS[2]}")" -- "$cur") )
      return 0
    fi
  fi

  # --no-restart is valid anywhere after --set
  if [ "${cur#-}" != "$cur" ]; then
    COMPREPLY=( $(compgen -W "--no-restart" -- "$cur") )
    return 0
  fi

  COMPREPLY=()
  return 0
}

complete -F _hmodel hmodel
