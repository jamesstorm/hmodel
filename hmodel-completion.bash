# bash completion for hmodel
# install: source this file, or drop into /etc/bash_completion.d/ or ~/.bash_completion
_hmodel() {
  local cur prev words cword
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  words=("${COMP_WORDS[@]}")
  cword=$COMP_CWORD

  local CFG="$HOME/.hermes/config.yaml"

  # provider slugs from config
  _hmodel_providers() {
    /usr/bin/python3 - "$CFG" <<'PY' 2>/dev/null
import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1]))
    for k in (d.get('providers') or {}):
        print(k)
except Exception:
    pass
PY
  }

  # models for a given provider slug (from its models: list in config, else its base_url)
  _hmodel_models() {
    local slug="$1"
    /usr/bin/python3 - "$CFG" "$slug" <<'PY' 2>/dev/null
import sys, yaml, json, urllib.request
cfg, slug = sys.argv[1], sys.argv[2]
try:
    d = yaml.safe_load(open(cfg))
    p = (d.get('providers') or {}).get(slug)
    if not p:
        sys.exit()
    # prefer the static models: list if present
    ms = p.get('models')
    if isinstance(ms, dict):
        for k in ms: print(k)
        sys.exit()
    if isinstance(ms, list):
        for k in ms: print(k)
        sys.exit()
    # else query the endpoint
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

  # top-level: --listproviders / --list / --set
    if [ $cword -eq 1 ]; then
      COMPREPLY=( $(compgen -W "--listproviders --list --set" -- "$cur") )
      return 0
    fi

  # after --set
  if [ "${words[1]}" = "--set" ]; then
    if [ $cword -eq 2 ]; then
      # first positional after --set: provider slug (or a model if they skip provider)
      COMPREPLY=( $(compgen -W "$(_hmodel_providers)" -- "$cur") )
      return 0
    elif [ $cword -eq 3 ]; then
      # second positional: model for the provider given in position 2
      local slug="${words[2]}"
      COMPREPLY=( $(compgen -W "$(_hmodel_models "$slug")" -- "$cur") )
      return 0
    fi
  fi

  # --no-restart anywhere
  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "--no-restart" -- "$cur") )
    return 0
  fi

  COMPREPLY=()
  return 0
}
complete -F _hmodel hmodel
