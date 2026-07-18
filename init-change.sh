#!/bin/sh
# init-change.sh — Initialize a new OpenSpec change in an isolated git worktree.
# Usage: ./scripts/init-change.sh <change-name> [capability-name]
#
# Creates a dedicated worktree at .worktrees/<change-name>/ on branch opsx/<change-name>,
# then runs `openspec new change` inside it and copies schema templates into place.
#
# Language-agnostic: requires only POSIX sh, git, openspec CLI, and standard UNIX tools.

set -e

CHANGE_NAME="$1"
CAPABILITY_NAME="${2:-new-capability}"

if [ -z "$CHANGE_NAME" ]; then
  echo "Usage: $0 <change-name> [capability-name]" >&2
  exit 1
fi

# Validate kebab-case: lowercase letters, digits, and hyphens only;
# no leading/trailing/consecutive hyphens.
validate_kebab() {
  echo "$1" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'
}

if ! validate_kebab "$CHANGE_NAME"; then
  echo "Invalid change name: \"$CHANGE_NAME\". Use kebab-case (e.g. my-change)." >&2
  exit 1
fi

if ! validate_kebab "$CAPABILITY_NAME"; then
  echo "Invalid capability name: \"$CAPABILITY_NAME\". Use kebab-case (e.g. my-capability)." >&2
  exit 1
fi

# Resolve repo root as the parent of the directory containing this script.
# Works correctly whether called directly or through a symlink.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BRANCH_NAME="opsx/$CHANGE_NAME"
WORKTREE_PATH="$REPO_ROOT/.worktrees/$CHANGE_NAME"

# ── Worktree setup ──────────────────────────────────────────────────────────

# Check if a worktree for this change already exists
if git -C "$REPO_ROOT" worktree list | grep -q "$WORKTREE_PATH"; then
  echo "Worktree already exists at $WORKTREE_PATH — skipping creation"
elif git -C "$REPO_ROOT" branch --list "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  # Branch exists (e.g. after a crash or manual cleanup) — re-attach worktree
  echo "Branch $BRANCH_NAME exists — re-attaching worktree at $WORKTREE_PATH"
  git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
  # Fresh start: create branch + worktree
  echo "Creating worktree at $WORKTREE_PATH on branch $BRANCH_NAME"
  git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
fi

echo "Working in worktree: $WORKTREE_PATH (branch: $BRANCH_NAME)"

# ── Initialize the change inside the worktree ───────────────────────────────

(cd "$WORKTREE_PATH" && openspec new change "$CHANGE_NAME")

CHANGE_DIR="$WORKTREE_PATH/openspec/changes/$CHANGE_NAME"
CAPABILITY_DIR="$CHANGE_DIR/specs/$CAPABILITY_NAME"

# ── Resolve schema templates dir ────────────────────────────────────────────
# Prefer the active project schema's templates; fall back to the shared templates/ dir.

SCHEMA_NAME=$(grep '^schema:' "$WORKTREE_PATH/openspec/config.yaml" 2>/dev/null | awk '{print $2}')
SCHEMA_TEMPLATES=""

if [ -n "$SCHEMA_NAME" ]; then
  candidate="$WORKTREE_PATH/openspec/schemas/$SCHEMA_NAME/templates"
  if [ -d "$candidate" ]; then
    SCHEMA_TEMPLATES="$candidate"
  fi
fi

# Fallback to the shared templates/ directory
if [ -z "$SCHEMA_TEMPLATES" ]; then
  SCHEMA_TEMPLATES="$REPO_ROOT/templates"
fi

echo "Using templates from: $SCHEMA_TEMPLATES"

# ── Verify templates are present ─────────────────────────────────────────────
# Check for all artifacts defined in the sdd-with-feedback-loop schema.
# If a template is missing it means the schema templates dir is incomplete.

for tmpl in proposal.md design.md tasks.md spec.md tests.md; do
  if [ ! -f "$SCHEMA_TEMPLATES/$tmpl" ]; then
    # tests.md is optional (not all schemas define it) — warn rather than abort
    if [ "$tmpl" = "tests.md" ]; then
      echo "  warn: template $tmpl not found in $SCHEMA_TEMPLATES — skipping tests artifact"
    else
      echo "Missing required template: $SCHEMA_TEMPLATES/$tmpl" >&2
      exit 1
    fi
  fi
done

# ── Copy templates into the change directory ─────────────────────────────────

mkdir -p "$CAPABILITY_DIR"

copy_template() {
  src="$1"
  dst="$2"
  if [ ! -f "$src" ]; then
    return 0  # Optional templates silently skipped
  fi
  if [ -f "$dst" ]; then
    echo "Refusing to overwrite existing file: $dst" >&2
    exit 1
  fi
  cp "$src" "$dst"
}

copy_template "$SCHEMA_TEMPLATES/proposal.md"  "$CHANGE_DIR/proposal.md"
copy_template "$SCHEMA_TEMPLATES/design.md"    "$CHANGE_DIR/design.md"
copy_template "$SCHEMA_TEMPLATES/tasks.md"     "$CHANGE_DIR/tasks.md"
copy_template "$SCHEMA_TEMPLATES/tests.md"     "$CHANGE_DIR/tests.md"
copy_template "$SCHEMA_TEMPLATES/spec.md"      "$CAPABILITY_DIR/spec.md"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "OpenSpec change initialized:"
echo "  Change:     $CHANGE_NAME"
echo "  Branch:     $BRANCH_NAME"
echo "  Worktree:   $WORKTREE_PATH"
echo "  Capability: $CAPABILITY_NAME"
echo ""
echo "Artifacts:"
echo "  $WORKTREE_PATH/openspec/changes/$CHANGE_NAME/proposal.md"
echo "  $WORKTREE_PATH/openspec/changes/$CHANGE_NAME/design.md"
echo "  $WORKTREE_PATH/openspec/changes/$CHANGE_NAME/tasks.md"
echo "  $WORKTREE_PATH/openspec/changes/$CHANGE_NAME/tests.md"
echo "  $WORKTREE_PATH/openspec/changes/$CHANGE_NAME/specs/$CAPABILITY_NAME/spec.md"
echo ""
echo "All work on this change should happen inside the worktree:"
echo "  cd $WORKTREE_PATH"
