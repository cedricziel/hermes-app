#!/usr/bin/env bash
# Sourced by dev-backend.sh and verify.sh: which names a throwaway launch or
# sticky profile may have. The same rules as Hermes' own
# (hermes_cli/profiles.py at openapi/HERMES_REF: _PROFILE_ID_RE, _RESERVED_NAMES
# and _HERMES_SUBCOMMANDS), so a name that passes here is one `hermes profile
# create` accepts, and `default` is refused because it is not a named profile.

# Prints why $1 is not usable and returns 1, or returns 0.
profile_name_problem() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9_-]{0,63}$ ]]; then
    echo "'$name' is not a profile name (lowercase letters, numbers, - and _; at most 64)"
    return 1
  fi
  case "$name" in
    default) echo "'default' is not a named profile" ;;
    hermes | test | tmp | root | sudo) echo "'$name' is a name Hermes reserves" ;;
    chat | model | gateway | setup | whatsapp | login | logout | status | cron | doctor | dump | config | pairing | skills | tools | mcp | connectors | sessions | insights | version | update | uninstall | profile | plugins | honcho | acp)
      echo "'$name' is the name of a hermes subcommand"
      ;;
    *) return 0 ;;
  esac
  return 1
}
