#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo "Usage: $0 <repo-directory>" >&2
  exit 1
fi

command -v grok >/dev/null || {
  echo "Error: grok is not installed" >&2
  exit 1
}

repo="$(cd -- "$1" && pwd -P)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# A positional prompt keeps the interview interactive and preserves its context.
exec grok --cwd "$repo" --no-alt-screen "$(cat "$script_dir/intent.md")"
