#!/usr/bin/env bash
# The repo's checks. Exit 0 only when the branch is fit to review.
#
# The gate runs this script from the main checkout with the job's worktree as
# the working directory. Keep it fast, deterministic and non-interactive: no
# watch modes, no prompts, nothing that rewrites files.
#
# This file ships UNCONFIGURED and fails on purpose: a gate that always passes
# would let every branch through. Replace the block below with your repo's
# checks, for example:
#
#   Python:  uv sync --frozen --quiet && uv run ruff check . && uv run pytest -q
#   Node:    npm ci --silent && npm run lint && npm test --silent && npm run build
#   Go:      go vet ./... && go test ./...
#   Rust:    cargo fmt --check && cargo clippy -- -D warnings && cargo test
#
# Use read-only forms (`--check`, `--frozen`, `ci`), never `--fix`.
set -euo pipefail

echo "factory/checks.sh is not configured: edit it to run this repo's checks." >&2
exit 1
