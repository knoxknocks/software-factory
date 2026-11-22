#!/usr/bin/env bash
# The repo's checks. Exit 0 only when the branch is fit to review.
#
# The gate runs this script from the main checkout with the job's worktree as
# the working directory. Keep it fast, deterministic and non-interactive: no
# watch modes, no prompts, nothing that rewrites files.
set -euo pipefail

cd be
uv sync --frozen --quiet
uv run ruff check .
uv run ruff format --check .
uv run pytest -q
# Synth without AWS: lookups come from the committed cdk.context.json.
npx --yes aws-cdk@2 synth --quiet --no-lookups >/dev/null
