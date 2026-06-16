#!/usr/bin/env bash
# Run the deterministic static checks against the submission, post a sticky PR
# comment, and exit non-zero if any fail. No API key needed — this is a free,
# fast pre-check that gates before the (paid) LLM review runs.
#
#   static-report.sh <submission-dir>
#
# Env: GH_TOKEN, REPO (owner/name), PR_NUMBER
set -uo pipefail

SUB="${1:?usage: static-report.sh <submission-dir>}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS="$DIR/checks"
REPO="${REPO:-$GITHUB_REPOSITORY}"
MARKER="<!-- halo-static -->"

# script | human label
ALL=(
  "check-allow-internet.sh|allow_internet is true"
  "check-task-absolute-path.sh|instruction.md uses absolute paths"
  "check-test-file-references.sh|expected output files are documented in instruction.md"
  "check-dockerfile-references.sh|Dockerfile does not COPY solution/ or tests/"
  "check-dockerfile-sanity.sh|Dockerfile apt hygiene (no pins, update + cleanup)"
  "check-dockerfile-platform.sh|Dockerfile is not pinned to a CPU platform"
  "check-nproc.sh|no bare nproc (use a fixed CPU count)"
  "check-pip-pinning.sh|pip/uv installs are version-pinned"
  "check-canary.sh|canary strings present in task files"
)

pass=""; fail=""; FAILED=0
for entry in "${ALL[@]}"; do
  script="${entry%%|*}"; label="${entry##*|}"
  out="$(bash "$CHECKS/$script" "$SUB" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    pass="${pass}| ✅ | ${label} |
"
  else
    FAILED=1
    det="$(printf '%s\n' "$out" | grep -E '^(FAIL|Warning) ' | sed 's/|/\\|/g' | paste -sd '; ' -)"
    [ -z "$det" ] && det="see workflow logs"
    fail="${fail}| ❌ | ${label} | ${det} |
"
  fi
done

if [ "$FAILED" -eq 0 ]; then
  body="${MARKER}
### Static checks ✅
All deterministic checks passed.

<details><summary>Checks</summary>

|  | Check |
|---|---|
${pass}
</details>"
else
  body="${MARKER}
### Static checks ❌ — fix these, then push (the full review runs once these pass)

|  | Check | Details |
|---|---|---|
${fail}
<details><summary>Passed checks</summary>

|  | Check |
|---|---|
${pass}
</details>"
fi

existing="$(gh api "repos/$REPO/issues/$PR_NUMBER/comments" --paginate \
  --jq "map(select(.body | startswith(\"$MARKER\"))) | .[0].id // empty" 2>/dev/null || true)"
if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$REPO/issues/comments/$existing" -f body="$body" >/dev/null
else
  gh api -X POST "repos/$REPO/issues/$PR_NUMBER/comments" -f body="$body" >/dev/null
fi

[ "$FAILED" -eq 0 ] || { echo "static checks failed" >&2; exit 1; }
echo "static checks passed"
