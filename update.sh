#!/usr/bin/env sh
# update.sh — Update openspec-shared to the latest version and refresh all wired assets.
#
# Run from the root of the downstream repository:
#   sh .github/openspec-shared/update.sh
#
# This script:
#   1. Pulls the latest openspec-shared submodule commit from the remote
#   2. Stages and commits the submodule bump (with an optional --no-commit flag to skip)
#   3. Re-runs bootstrap to refresh all symlinks / copies
#
# Options:
#   --copy        Pass through to bootstrap: copy assets instead of creating symlinks
#   --no-commit   Update the submodule and refresh links, but do NOT create a git commit
#   -h|--help     Show this help text and exit
#

set -e

SUBMODULE_PATH=".github/openspec-shared"
COPY_FLAG=""
NO_COMMIT=false

# ── Argument parsing ────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --copy)       COPY_FLAG="--copy" ;;
    --no-commit)  NO_COMMIT=true ;;
    -h|--help)
      sed -n '2,/^set -e/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# ── Pre-flight checks ───────────────────────────────────────────────────────

if [ ! -d "$SUBMODULE_PATH" ]; then
  echo "error: '$SUBMODULE_PATH' not found." >&2
  echo "  This script must be run from the root of the downstream repository." >&2
  echo "  If the submodule hasn't been added yet, follow the setup in README.md." >&2
  exit 1
fi

# ── Step 1: Pull latest submodule commit ───────────────────────────────────

echo "==> Fetching latest openspec-shared from remote"
git submodule update --remote "$SUBMODULE_PATH"

# ── Step 2: Commit the submodule bump (unless --no-commit) ─────────────────

if ! $NO_COMMIT; then
  if git diff --cached --quiet && git diff --quiet "$SUBMODULE_PATH"; then
    echo "==> Submodule already at latest — no commit needed"
  else
    echo "==> Staging submodule bump"
    git add "$SUBMODULE_PATH"
    echo "==> Committing submodule bump"
    git commit -m "chore: bump openspec-shared to latest and refresh schema symlinks"
    echo ""
    echo "    Commit created. Run 'git push' when ready to share."
  fi
else
  echo "==> Skipping commit (--no-commit)"
fi

# ── Step 3: Re-run bootstrap to refresh all wired assets ───────────────────

echo ""
echo "==> Refreshing wired assets via bootstrap"
# shellcheck disable=SC1090
sh "$SUBMODULE_PATH/bootstrap.sh" $COPY_FLAG

# ── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "Update complete."
if $NO_COMMIT; then
  echo "Submodule bump was NOT committed (--no-commit). Stage and commit manually if desired:"
  echo "  git add $SUBMODULE_PATH"
  echo "  git commit -m \"chore: bump openspec-shared to latest\""
  echo "  git push"
fi
