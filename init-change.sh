#!/bin/sh
# init-change.sh — initialize a new OpenSpec change with starter templates.
# Usage: ./scripts/init-change.sh <change-name> [capability-name]
#
# Runs `openspec new change` then copies all templates into the new change
# directory. Language-agnostic: requires only POSIX sh, openspec CLI, and
# standard UNIX tools (cp, mkdir, grep).

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
# Works correctly whether called directly or through a symlink, because $0
# refers to the symlink path (e.g. scripts/init-change.sh) whose parent is
# the scripts/ folder, one level below the repo root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Run the openspec CLI from the repo root.
(cd "$REPO_ROOT" && openspec new change "$CHANGE_NAME")

TEMPLATES_DIR="$REPO_ROOT/openspec/templates"
CHANGE_DIR="$REPO_ROOT/openspec/changes/$CHANGE_NAME"
CAPABILITY_DIR="$CHANGE_DIR/specs/$CAPABILITY_NAME"

# Verify all expected templates are present before touching anything.
for tmpl in proposal.template.md design.template.md tasks.template.md spec.template.md; do
  if [ ! -f "$TEMPLATES_DIR/$tmpl" ]; then
    echo "Missing template: $TEMPLATES_DIR/$tmpl" >&2
    exit 1
  fi
done

mkdir -p "$CAPABILITY_DIR"

copy_template() {
  src="$1"
  dst="$2"
  if [ -f "$dst" ]; then
    echo "Refusing to overwrite existing file: $dst" >&2
    exit 1
  fi
  cp "$src" "$dst"
}

copy_template "$TEMPLATES_DIR/proposal.template.md" "$CHANGE_DIR/proposal.md"
copy_template "$TEMPLATES_DIR/design.template.md"   "$CHANGE_DIR/design.md"
copy_template "$TEMPLATES_DIR/tasks.template.md"    "$CHANGE_DIR/tasks.md"
copy_template "$TEMPLATES_DIR/spec.template.md"     "$CAPABILITY_DIR/spec.md"

echo "OpenSpec change initialized with starter templates:"
echo "  Change:     $CHANGE_NAME"
echo "  Capability: $CAPABILITY_NAME"
echo "  Proposal:   openspec/changes/$CHANGE_NAME/proposal.md"
echo "  Design:     openspec/changes/$CHANGE_NAME/design.md"
echo "  Tasks:      openspec/changes/$CHANGE_NAME/tasks.md"
echo "  Spec:       openspec/changes/$CHANGE_NAME/specs/$CAPABILITY_NAME/spec.md"
