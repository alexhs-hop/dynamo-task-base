#!/usr/bin/env bash
# Post the read-only eval verdict to the PR and gate the check.
# Runs inside the fellow's own repo CI.
#
#   report.sh <verdict-file>
#
# Env (provided by the workflow):
#   GH_TOKEN     ${{ github.token }} (pull-requests: write)
#   REPO         owner/name (GITHUB_REPOSITORY)
#   PR_NUMBER    the pull request number
set -euo pipefail

VERDICT_FILE="${1:?usage: report.sh <verdict-file>}"
REPO="${REPO:-$GITHUB_REPOSITORY}"
MARKER="<!-- halo-eval -->"

post_comment() {
  local body="$1" existing
  existing="$(gh api "repos/$REPO/issues/$PR_NUMBER/comments" --paginate \
    --jq "map(select(.body | startswith(\"$MARKER\"))) | .[0].id // empty" 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    gh api -X PATCH "repos/$REPO/issues/comments/$existing" -f body="$body" >/dev/null
  else
    gh api -X POST "repos/$REPO/issues/$PR_NUMBER/comments" -f body="$body" >/dev/null
  fi
}

set_label() { # add $1, remove $2
  gh label create "$1" --repo "$REPO" --color "$3" --description "$4" 2>/dev/null || true
  gh pr edit "$PR_NUMBER" --repo "$REPO" --add-label "$1" 2>/dev/null || true
  gh pr edit "$PR_NUMBER" --repo "$REPO" --remove-label "$2" 2>/dev/null || true
}

# --- Did the eval produce a verdict? --------------------------------------
if [ ! -s "$VERDICT_FILE" ] || ! grep -qE '^Verdict:' "$VERDICT_FILE"; then
  post_comment "$MARKER
### Halo eval — could not complete

The automated review did not produce a verdict (usually a transient error or an
API budget issue). Push a new commit to re-run."
  echo "no verdict produced" >&2
  exit 1
fi

# Trim any model preamble: keep from the first "# Halo Eval" heading onward.
VERDICT_BODY="$(awk 'f || /^# Halo Eval/ {f=1; print}' "$VERDICT_FILE")"
[ -n "$VERDICT_BODY" ] || VERDICT_BODY="$(cat "$VERDICT_FILE")"

if grep -m1 -qE '^Verdict:[[:space:]]*PASS' "$VERDICT_FILE"; then
  HEADER="### Halo eval — ✅ PASS"
  set_label "accepted" "needs-revision" "0e8a16" "Halo eval passed all criteria"
  RESULT=pass
else
  HEADER="### Halo eval — 🔧 needs revision"
  set_label "needs-revision" "accepted" "d93f0b" "Halo eval found failing criteria"
  RESULT=fail
fi

post_comment "$MARKER
$HEADER

$VERDICT_BODY

---
*Automated read-only review against \`.halo/halo-rubric.toml\`. Address the
failing criteria above, then \`git commit\` and \`git push\` to re-run. All
criteria must pass to be accepted.*"

[ "$RESULT" = pass ] || { echo "eval verdict: FAIL" >&2; exit 1; }
echo "eval verdict: PASS"
