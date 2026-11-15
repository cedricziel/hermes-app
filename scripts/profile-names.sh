#!/usr/bin/env bash
# Sourced by dev-backend.sh and verify.sh: what a throwaway Hermes home, launch
# profile or sticky profile may be called, and the rules that keep a run away
# from the real Hermes home.
#
# Profile names follow Hermes' own (hermes_cli/profiles.py at openapi/HERMES_REF:
# _PROFILE_ID_RE, _RESERVED_NAMES and _HERMES_SUBCOMMANDS), so a name that
# passes here is one `hermes profile create` accepts; `default` is refused
# because it is not a named profile.
#
# Paths are an allowlist, not a list of known bad spellings: Hermes runs
# expanduser(expandvars(...)) on HERMES_HOME and takes `~/.hermes<suffix>` as
# its default, and bash keeps a leading `//`, so only a canonical absolute path
# is taken at face value (canonical_abs_path) and the resolved result is then
# compared with the real home (inside_real_hermes_home).

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

# The passwd entry's home of the current user.
real_passwd_home() {
  getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6
}

# The home Hermes (Python's Path.home()) would use: $HOME when set, else the
# passwd entry. Prints nothing when neither is known.
real_user_home() {
  if [[ -n "${HOME:-}" ]]; then
    echo "$HOME"
  else
    real_passwd_home
  fi
}

# Whether path $1 has a `.` or `..` segment.
has_dot_segment() {
  case "/$1/" in
    */./* | */../*) return 0 ;;
  esac
  return 1
}

# Whether $1 is a canonical absolute path: one leading slash, no `//`, no `.`
# or `..` segment, no `~`, `$` or backtick (Hermes expands them, a shell does
# not), no control character such as a newline.
canonical_abs_path() {
  local p="$1"
  [[ "$p" == /* ]] || return 1 # absolute
  [[ "$p" != *//* ]] || return 1 # no // (which covers a leading //, the one bash keeps)
  [[ "$p" == / || "$p" != */ ]] || return 1 # no trailing slash
  ! has_dot_segment "$p" || return 1 # no . or .. segment
  [[ "$p" != *[\~\$\`]* ]] || return 1 # no ~ $ or backtick
  [[ ! "$p" =~ [[:cntrl:]] ]] || return 1 # no control character
  return 0
}

# The physical path of $1 even when it, or part of it, does not exist yet:
# nothing is created to find out. Always one leading slash (bash's `pwd -P`
# keeps a leading `//`).
resolve_path() {
  local path="$1" rest="" physical
  while [[ ! -d "$path" ]]; do
    rest="/$(basename "$path")$rest"
    path="$(dirname "$path")"
  done
  physical="$(cd "$path" && pwd -P)"
  physical="/${physical#"${physical%%[!/]*}"}" # one leading slash
  [[ "$physical" == / ]] && physical=""
  echo "$physical$rest"
}

# Returns 0, printing the real Hermes home it is at or under, when the resolved
# path $1 is at or under a real home's `.hermes` or `.hermes<anything>` (the
# data-dir suffix moves the default there) or an ambient HERMES_HOME. Checks
# $HOME's and the passwd entry's home.
inside_real_hermes_home() {
  local resolved="$1" home dir candidate
  for home in "$(real_user_home || true)" "$(real_passwd_home || true)"; do
    [[ -n "$home" ]] || continue
    dir="$(resolve_path "$home")"
    [[ "$dir" == / ]] && dir=""
    case "$resolved" in
      "$dir"/.hermes | "$dir"/.hermes/* | "$dir"/.hermes[!/]* )
        echo "$dir/.hermes*"
        return 0
        ;;
    esac
  done
  if [[ -n "${HERMES_HOME:-}" ]]; then
    candidate="$(resolve_path "$HERMES_HOME")"
    if [[ "$resolved" == "$candidate" || "$resolved" == "$candidate"/* ]]; then
      echo "$candidate"
      return 0
    fi
  fi
  return 1
}
