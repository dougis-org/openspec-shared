#!/usr/bin/env sh
# bootstrap.sh — Wire openspec-shared assets into a downstream repository.
#
# Run from the root of the downstream repository after adding the submodule:
#   git submodule add https://github.com/dougis-org/openspec-shared .github/openspec-shared
#   sh .github/openspec-shared/bootstrap.sh
#
# Options:
#   --copy    Copy assets instead of creating symlinks (useful when symlinks are unavailable)
#
# Supported agent surfaces (default): .agents/  .codex/  .claude/  .gemini/  .github/
# Experimental surface (.agent/) is NOT wired by default.
#
# The script is idempotent: re-running it after a submodule bump refreshes all links.
# Existing symlinks at managed paths are replaced. Plain files or directories that the
# script did not create will trigger an automatic fallback to copy mode with a warning.

set -e

SUBMODULE_PATH=".github/openspec-shared"
COPY_MODE=false

# ── Argument parsing ────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --copy) COPY_MODE=true ;;
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
  echo "  Add the submodule first:" >&2
  echo "  git submodule add https://github.com/dougis-org/openspec-shared $SUBMODULE_PATH" >&2
  exit 1
fi

# ── Submodule initialisation / update ──────────────────────────────────────

echo "==> Initialising / updating submodule $SUBMODULE_PATH"
git submodule update --init "$SUBMODULE_PATH"

# ── Helper functions ────────────────────────────────────────────────────────

# link_or_copy <target_in_repo> <destination_in_downstream>
#
# <target_in_repo>        — path inside openspec-shared, relative to the shared repo root
# <destination_in_downstream> — path in the downstream repo where the link / copy lands
#
# Symlink target is computed relative to the destination's parent directory.

link_or_copy() {
  src_rel="$1"     # e.g. ".codex/skills"
  dest="$2"        # e.g. ".codex/skills"

  dest_dir=$(dirname "$dest")
  mkdir -p "$dest_dir"

  # Compute depth of dest_dir to build the relative path back to repo root.
  # e.g. dest_dir=".codex" → depth=1 → prefix="../"
  #      dest_dir="openspec" → depth=1 → prefix="../"
  #      dest_dir="scripts"  → depth=1 → prefix="../"
  if [ "$dest_dir" = "." ]; then
    depth=0
  else
    # Count slashes in dest_dir + 1
    depth=$(printf '%s' "$dest_dir" | tr -cd '/' | wc -c)
    depth=$((depth + 1))
  fi

  # Build relative prefix (../../ etc.)
  prefix=""
  i=0
  while [ $i -lt $depth ]; do
    prefix="../$prefix"
    i=$((i + 1))
  done

  abs_src="$SUBMODULE_PATH/$src_rel"
  rel_target="${prefix}${SUBMODULE_PATH}/${src_rel}"

  # Skip silently if the source does not exist in the submodule
  if [ ! -e "$abs_src" ]; then
    return 0
  fi

  if $COPY_MODE; then
    # Copy mode: remove existing content (symlink, directory, or file) then copy fresh.
    # Re-running bootstrap in copy mode is an explicit refresh; all managed paths are replaced.
    if [ -L "$dest" ] || [ -d "$dest" ]; then
      rm -rf "$dest"
    elif [ -e "$dest" ]; then
      rm "$dest"
    fi
    echo "  copy  $dest  ←  $abs_src"
    if [ -d "$abs_src" ]; then
      cp -r "$abs_src" "$dest"
    else
      cp "$abs_src" "$dest"
    fi
  else
    # Symlink mode
    if [ -L "$dest" ]; then
      # Existing symlink — replace (idempotent refresh)
      rm "$dest"
    elif [ -e "$dest" ]; then
      # Destination is a real file or directory (not a symlink).
      # Fall back to copy mode automatically rather than aborting.
      echo "  warn  '$dest' exists and is not a symlink — falling back to copy mode for this path" >&2
      rm -rf "$dest"
      echo "  copy  $dest  ←  $abs_src (fallback)"
      if [ -d "$abs_src" ]; then
        cp -r "$abs_src" "$dest"
      else
        cp "$abs_src" "$dest"
      fi
      return 0
    fi
    echo "  link  $dest  ->  $rel_target"
    ln -s "$rel_target" "$dest"
  fi
}

# ── Asset wiring ────────────────────────────────────────────────────────────

echo "==> Wiring agent surfaces"

# .codex/
link_or_copy "skills"            ".codex/skills"

# .claude/
link_or_copy "skills"            ".claude/skills"
link_or_copy ".claude/commands"  ".claude/commands"

# .gemini/
link_or_copy "skills"            ".gemini/skills"
link_or_copy ".gemini/commands"  ".gemini/commands"

# .agents/ — Antigravity IDE surface
link_or_copy "skills"            ".agents/skills"

# .github/ — agent surfaces only; workflows are downstream-repo-owned
link_or_copy "skills"            ".github/skills"
link_or_copy ".github/prompts"   ".github/prompts"

echo "==> Wiring openspec assets"

mkdir -p openspec
link_or_copy "templates"   "openspec/templates"
link_or_copy "config.yaml" "openspec/config.yaml"

echo "==> Wiring scripts"

mkdir -p scripts
link_or_copy "init-change.sh" "scripts/init-change.sh"

# ── Done ────────────────────────────────────────────────────────────────────

if $COPY_MODE; then
  echo ""
  echo "Bootstrap complete (copy mode)."
  echo "Note: copied assets will not receive updates automatically."
  echo "Re-run bootstrap after 'git submodule update --remote $SUBMODULE_PATH' to refresh copies."
else
  echo ""
  echo "Bootstrap complete (symlink mode)."
  echo "To refresh after bumping the submodule:"
  echo "  git submodule update --remote $SUBMODULE_PATH"
  echo "  sh $SUBMODULE_PATH/bootstrap.sh"
fi
