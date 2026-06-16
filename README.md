# Dynamo Task Submission

Implement a Terminal-Bench-style task in this repository (Harbor task format). When
you open a pull request, an automated reviewer scores your task against the Dynamo
rubric and posts a **PASS / FAIL verdict** as a PR comment. **All criteria must
pass** to be accepted — iterate until the verdict is ✅ PASS.

- The review **runs on the project's API key — you do not need one.**
- The review is **read-only**: it reads your files and grades them; it never runs
  your solution or tests.

## How to submit (fork → PR)

You don't have write access to this repo. You **fork it, implement your task, and
open a pull request** (requires the [GitHub CLI](https://cli.github.com/), `gh`):

```bash
gh repo fork alexhs-hop/dynamo-task-base --clone
cd dynamo-task-base
git checkout -b submission
#  ... implement the task (see below) ...
git add -A && git commit -m "Task submission"
git push -u origin submission
gh pr create --repo alexhs-hop/dynamo-task-base --fill
```

To **iterate** after reading the verdict: edit, then `git commit` and `git push` —
the review re-runs automatically on every push.

## What to build (Harbor task format)

This repo was scaffolded with `harbor tasks init`. Fill in:

| File | What it is |
|------|------------|
| `instruction.md` | The prompt the agent receives. Absolute paths (`/app/...`), explicit output files/schema, the "what" not the "how". |
| `task.toml` | Metadata + config. **Fill in `difficulty_explanation`, `solution_explanation`, `verification_explanation`, `category`, `tags`, `expert_time_estimate_hours`, author fields** — the reviewer grades these. |
| `environment/Dockerfile` | The agent's container. Don't COPY `solution/` or `tests/` into it. |
| `solution/solve.sh` (+ helpers) | Reference solution. `solve.sh` is the entrypoint; put real logic in `solve.py`/helpers it calls (everything it invokes is reviewed). Must solve the task by genuine computation. |
| `tests/test_outputs.py`, `tests/test.sh` | Verifiers — check the agent's actual outputs (no string/source matching); 1:1 with `instruction.md`. |
| `tests/Dockerfile` | Verifier image (separate-verifier mode) — owns the test deps; keep ground truth here, never in the agent image. |

Keep the `harbor-canary` comment in each file (anti-contamination), pin dependency
versions, and reference every expected output file in `instruction.md`.

> The exact criteria the reviewer uses are in
> [`.dynamo/dynamo-rubric.toml`](.dynamo/dynamo-rubric.toml) — read it to see what "good" means.

When your task is complete, replace this README with a short description of your
task (overview, approach, environment, how verification works).
