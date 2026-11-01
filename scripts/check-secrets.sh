#!/bin/bash
# DRAFT. Local secrets scan that needs no extra tool. Prints file:line and the rule name only, never the matched text.
# Usage: bash gates/check-secrets.sh [folder]   Exit 0 = clean, 1 = possible secret found, 2 = bad usage.
#        bash gates/check-secrets.sh --env-example <file>   Checks only that file. The agent guard calls this.
# A line containing the words "nexysguard:allow" is skipped by the token rules (for documented test values).
# Bytes, not characters, so a stray byte can't make sed fail and a line count as blank.
export LC_ALL=C
found=0
rule() { # name, regex
  local hits
  # -H so a single file's name is always printed, and only the name and line number survive the cut.
  hits="$(grep -HrInE --exclude-dir=.git --exclude-dir=node_modules -e "$2" "$dir" 2>/dev/null | grep -v 'nexysguard:allow' | cut -d: -f1,2)"
  if [ -n "$hits" ]; then echo "$hits" | sed "s|\$| [$1]|"; found=1; fi
}
token_rules() {
  rule "github-token"      'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'
  rule "aws-access-key"    '(AKIA|ASIA)[0-9A-Z]{16}'
  rule "anthropic-key"     'sk-ant-[A-Za-z0-9_-]{20,}'
  rule "slack-token"       'xox[baprs]-[A-Za-z0-9-]{10,}'
  rule "private-key"       '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  rule "generic-assignment" "(secret|token|passw(or)?d|api[_-]?key)[A-Za-z_]*[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9+/_=.-]{20,}[\"']"
}
# .env.example is the one exception, by Alexander's yes on 1 Nov 2026: every value must be empty or a placeholder.
# Anything else fails, including a line that isn't KEY=VALUE. Line numbers only, never the value.
# Placeholders are words: <letters, spaces, hyphens> and your-words-here, so generated secrets don't fit.
placeholder='^(<[a-z][a-z _-]{0,29}>|your([-_][a-z]+)*|change[-_]?me|replace[-_]?me|placeholder|example|todo|x{3,}|\.\.\.)$'
assignment='^(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*='
check_env_example() { # file
  local example="$1" content n=0 line trimmed value
  # A file that can't be read fails, so it can never count as clean.
  if ! content="$(cat "$example" 2>/dev/null)"; then echo "$example [env-example-unreadable]"; found=1; return; fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n+1))
    trimmed="$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$line")" || { echo "$example:$n [env-example-unreadable]"; found=1; continue; }
    case "$trimmed" in
      '') continue ;;
      # A comment in words is fine. A commented-out setting's value counts, and so does a long unbroken run.
      '#'*)
        if grep -Eq '[A-Za-z0-9+/_=.-]{20,}' <<<"$trimmed"; then echo "$example:$n [env-example-comment]"; found=1; continue; fi
        trimmed="$(sed -E 's/^#+[[:space:]]*//; s/^((export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*/\1=/' <<<"$trimmed")" || { echo "$example:$n [env-example-unreadable]"; found=1; continue; }
        grep -Eq "$assignment" <<<"$trimmed" || continue ;;
      *)
        grep -Eq "$assignment" <<<"$trimmed" || { echo "$example:$n [env-example-format]"; found=1; continue; } ;;
    esac
    value="${trimmed#*=}"
    value="$(sed -E "s/^[\"'](.*)[\"']\$/\1/" <<<"$value")" || { echo "$example:$n [env-example-unreadable]"; found=1; continue; }
    value="$(tr '[:upper:]' '[:lower:]' <<<"$value")" || { echo "$example:$n [env-example-unreadable]"; found=1; continue; }
    [ -z "$value" ] || { [ "${#value}" -le 40 ] && grep -Eq "$placeholder" <<<"$value"; } || { echo "$example:$n [env-example-value]"; found=1; }
  done <<<"$content"
}
if [ "${1:-}" = "--env-example" ]; then
  [ "$#" = 2 ] || { echo "usage: check-secrets.sh --env-example <file>"; exit 2; }
  dir="$2"
  token_rules
  check_env_example "$2"
  exit "$found"
fi
dir="${1:-.}"; [ -d "$dir" ] || { echo "no such folder: $dir"; exit 2; }
token_rules
# committed environment files, in any spelling, and any shortcut with such a name
envs="$(find "$dir" \( -name .git -o -name node_modules \) -prune -o \( -type f -o -type l \) \( -iname '.env' -o -iname '.env.*' \) ! \( -type f -name '.env.example' \) -print 2>/dev/null)"
if [ -n "$envs" ]; then echo "$envs" | sed 's|$| [env-file]|'; found=1; fi
while IFS= read -r example; do
  [ -n "$example" ] || continue
  check_env_example "$example"
done < <(find "$dir" \( -name .git -o -name node_modules \) -prune -o -type f -name '.env.example' -print 2>/dev/null)
if [ "$found" = 0 ]; then echo "secrets: clean"; exit 0; fi
echo "secrets: POSSIBLE SECRET FOUND (values not shown)"; exit 1
