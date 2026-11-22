#!/usr/bin/env bash
# Install the software factory into a git repository.
#
#   ./install.sh <target-repo>              copy the factory in; never overwrite a file that differs
#   ./install.sh <target-repo> --upgrade    refresh the engine (bin/, agents, skill, dashboard);
#                                           never touches config.json, checks.sh, lenses or AGENTS.md
#   ./install.sh <target-repo> --force      overwrite every factory file, including your config
#   ./install.sh <target-repo> --no-labels  don't create the GitHub labels
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/template"

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

TARGET=""; MODE="safe"; LABELS=1
for arg in "$@"; do
  case "$arg" in
    --upgrade) MODE="upgrade" ;;
    --force) MODE="force" ;;
    --no-labels) LABELS=0 ;;
    -h|--help) usage 0 ;;
    -*) echo "unknown option: $arg" >&2; usage ;;
    *) [ -z "$TARGET" ] && TARGET="$arg" || { echo "one target only" >&2; usage; } ;;
  esac
done
[ -n "$TARGET" ] || usage
[ -d "$TARGET/.git" ] || { echo "error: $TARGET is not the root of a git repository" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

for tool in git python3; do
  command -v "$tool" >/dev/null || { echo "error: $tool is required" >&2; exit 1; }
done
command -v gh >/dev/null || echo "warning: gh (GitHub CLI) not found: the factory needs it to read issues and open PRs" >&2

# Files that are yours once installed: --upgrade never touches them.
is_user_file() {
  case "$1" in
    factory/config.json|factory/checks.sh|factory/lenses/*) return 0 ;;
  esac
  return 1
}

copied=0; skipped=0; kept=0
while IFS= read -r -d '' file; do
  rel="${file#"$SRC"/}"
  dest="$TARGET/$rel"
  mkdir -p "$(dirname "$dest")"
  if [ ! -e "$dest" ]; then
    cp -p "$file" "$dest"; echo "  add      $rel"; copied=$((copied + 1)); continue
  fi
  if cmp -s "$file" "$dest"; then continue; fi
  case "$MODE" in
    force) cp -p "$file" "$dest"; echo "  replace  $rel"; copied=$((copied + 1)) ;;
    upgrade)
      if is_user_file "$rel"; then echo "  keep     $rel (yours)"; kept=$((kept + 1))
      else cp -p "$file" "$dest"; echo "  update   $rel"; copied=$((copied + 1)); fi ;;
    *) echo "  skip     $rel (exists and differs; use --upgrade or --force)"; skipped=$((skipped + 1)) ;;
  esac
done < <(find "$SRC" -type f ! -name '*.pyc' ! -path '*/__pycache__/*' -print0)

chmod +x "$TARGET/factory/bin/"* "$TARGET/factory/checks.sh" 2>/dev/null || true

# Runtime state must never be committed.
GI="$TARGET/.gitignore"; touch "$GI"
for line in "/factory/jobs/" "/.worktrees/"; do
  grep -qxF "$line" "$GI" || { printf '%s\n' "$line" >> "$GI"; echo "  ignore   $line"; }
done

# AGENTS.md: the agents read it first. Start one only if the repo has none.
if [ ! -e "$TARGET/AGENTS.md" ] && [ ! -e "$TARGET/CLAUDE.md" ]; then
  cp "$HERE/templates/AGENTS.example.md" "$TARGET/AGENTS.md"; echo "  add      AGENTS.md (a starter: fill it in)"
fi

if [ "$LABELS" = 1 ] && command -v gh >/dev/null; then
  echo "Creating GitHub labels in the repo at $TARGET (skipped if they exist):"
  ( cd "$TARGET"
    gh label create factory --color 0E8A16 --description "Build this issue with the software factory" 2>/dev/null && echo "  label    factory" || echo "  label    factory (exists or no access)"
    gh label create factory:needs-info --color FBCA04 --description "Factory is waiting for the author" 2>/dev/null && echo "  label    factory:needs-info" || echo "  label    factory:needs-info (exists or no access)"
    gh label create factory:needs-human --color D93F0B --description "Factory needs a person's decision" 2>/dev/null && echo "  label    factory:needs-human" || echo "  label    factory:needs-human (exists or no access)" )
fi

echo
echo "Done: $copied written, $kept kept, $skipped skipped."
cat <<NEXT

Next steps in $TARGET:
  1. Edit factory/checks.sh: it ships unconfigured and fails on purpose.
  2. Review factory/config.json (base_branch, concurrency, auto_merge, models).
  3. Fill in AGENTS.md; add factory/lenses/*.md for repo-specific review guidance.
  4. Commit the factory files and merge them to your base branch: jobs branch from it.
  5. Label an issue 'factory' and run /factory run in Claude Code.
NEXT
