#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo "Usage: $0 <repo-directory>" >&2
  exit 1
fi

for cmd in grok git curl jq; do
  command -v "$cmd" >/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

[[ -n "${LINEAR_API_KEY:-}" ]] || {
  echo "Error: LINEAR_API_KEY is not set" >&2
  exit 1
}

repo="$(cd -- "$1" && pwd -P)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
git -C "$repo" rev-parse --show-toplevel >/dev/null
git -C "$repo" rev-parse --verify HEAD >/dev/null

session_dir="$(mktemp -d)"
trap 'rm -rf -- "$session_dir"' EXIT
export LINEAR_LABEL="${LINEAR_LABEL:-ready-for-agent}"

echo "===== intent ====="
"$script_dir/intent.sh" "$repo"

echo "===== pick up Linear issues: $LINEAR_LABEL ====="
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
    --data "$(jq -n --arg query "$query" --arg label "$LINEAR_LABEL" \
      '{query: $query, variables: {label: $label}}')"
)"

if jq -e '.errors != null' >/dev/null <<<"$payload"; then
  jq '.errors' <<<"$payload" >&2
  exit 1
fi

# Validate before spawning sessions; a malformed response must not look like an empty queue.
jq -e '
  .data.issues.nodes | type == "array" and all(.[];
    (.identifier | type == "string") and
    (.title | type == "string") and
    (.url | type == "string")
  )
' >/dev/null <<<"$payload" || {
  echo "Error: unexpected Linear response" >&2
  exit 1
}
mapfile -t issues < <(jq -c '.data.issues.nodes[]' <<<"$payload")

if [[ ${#issues[@]} -eq 0 ]]; then
  echo "No open Linear issues with label $LINEAR_LABEL."
  exit 0
fi

for issue in "${issues[@]}"; do
  id="$(jq -r '.identifier' <<<"$issue")"
  title="$(jq -r '.title' <<<"$issue")"
  url="$(jq -r '.url' <<<"$issue")"
  base="$(git -C "$repo" rev-parse HEAD)"
  echo "===== implement: $url ====="
  cat >"$session_dir/implement.md" <<EOF
Use /implement on this one issue: $url
Issue: $id
Title: $title
The issue is the confirmed spec. Work only on this issue.
Build it on a branch and commit the work. Run the checks required by the spec and project.
Stop when the implementation is committed and ready for code review in a fresh session.
EOF
  grok --cwd "$repo" --no-alt-screen --always-approve \
    --prompt-file "$session_dir/implement.md"

  echo "===== review: $url ====="
  cat >"$session_dir/review.md" <<EOF
Use /code-review on the implementation of this one issue: $url
Issue: $id
Title: $title
The issue is the confirmed spec. Review the current branch diff against base commit $base.
This is a fresh session. Stop when the review is written.
EOF
  grok --cwd "$repo" --no-alt-screen --always-approve \
    --prompt-file "$session_dir/review.md"
done
