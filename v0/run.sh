#!/usr/bin/env bash
set -euo pipefail

# One fresh session to implement a grilled Linear item, then another to review it.
# Usage: ./v0/run.sh <repo>

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <repo>" >&2
  exit 1
fi

repo="$(realpath "$1")"
label="${LINEAR_LABEL:-grilled}"
tmpfiles=()

cleanup() {
  rm -f "${tmpfiles[@]}"
}
trap cleanup EXIT

for cmd in grok jq curl git; do
  command -v "$cmd" >/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

[[ -n "${LINEAR_API_KEY:-}" ]] || {
  echo "Error: LINEAR_API_KEY is not set" >&2
  exit 1
}

git -C "$repo" rev-parse --show-toplevel >/dev/null

query=$(cat <<'EOF'
query($label: String!) {
  issues(
    first: 50
    filter: {
      labels: { name: { eq: $label } }
      state: { type: { nin: [completed, canceled] } }
    }
  ) {
    nodes { identifier title url }
  }
}
EOF
)

payload="$(
  curl -fsS https://api.linear.app/graphql \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data "$(jq -n --arg query "$query" --arg label "$label" \
      '{query: $query, variables: {label: $label}}')"
)"

if jq -e '.errors' >/dev/null <<<"$payload"; then
  jq '.errors' <<<"$payload" >&2
  exit 1
fi

jq -e '.data.issues.nodes' >/dev/null <<<"$payload" || {
  echo "Error: unexpected Linear response" >&2
  printf '%s\n' "$payload" >&2
  exit 1
}

mapfile -t items < <(jq -c '.data.issues.nodes[]' <<<"$payload")

if [[ ${#items[@]} -eq 0 ]]; then
  echo "No grilled items."
  exit 0
fi

echo "Repo: $repo"
echo "Label: $label"
echo "Items: ${#items[@]}"
echo

run_session() {
  grok --cwd "$repo" \
    --no-alt-screen \
    --always-approve \
    --prompt-file "$1"
}

for item in "${items[@]}"; do
  id="$(jq -r '.identifier' <<<"$item")"
  title="$(jq -r '.title' <<<"$item")"
  url="$(jq -r '.url' <<<"$item")"

  echo "===== $id implement ====="
  implement="$(mktemp)"
  tmpfiles+=("$implement")
  {
    printf '%s\n' "Use /implement skill on this one Linear issue."
    printf '%s\n' "Work only on this issue."
    printf '%s\n' "Build it on a branch and commit the work."
    printf '%s\n' "Stop when the build is ready to hand over."
    printf '%s\n' "Leave code review for a later session."
    printf '\n'
    printf '%s\n' "Issue: $id"
    printf '%s\n' "Title: $title"
    printf '%s\n' "URL: $url"
  } >"$implement"
  run_session "$implement"

  echo "===== $id review ====="
  review="$(mktemp)"
  tmpfiles+=("$review")
  {
    printf '%s\n' "Use /code-review skill."
    printf '%s\n' "This is a new session."
    printf '%s\n' "Review only what was built for this Linear issue."
    printf '%s\n' "The issue is the spec. Review the branch diff against the base branch."
    printf '%s\n' "Stop when the review is written."
    printf '\n'
    printf '%s\n' "Issue: $id"
    printf '%s\n' "Title: $title"
    printf '%s\n' "URL: $url"
  } >"$review"
  run_session "$review"
done
