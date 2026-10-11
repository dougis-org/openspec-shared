#!/usr/bin/env sh
# bootstrap.sh — Wire openspec-shared assets into a downstream repository.
#
# Run from the root of the downstream repository after adding the submodule:
#   git submodule add https://github.com/dougis-org/openspec-shared .github/openspec-shared
#   sh .github/openspec-shared/bootstrap.sh
#
# Options:
#   --copy    Accepted for backward compatibility; bootstrap always copies (never symlinks)
#
# Supported agent surfaces: .agents/  .codex/  .claude/  .gemini/  .github/  .agent/
#
# Assets are always copied, never symlinked: symlinks into a submodule break in git
# worktrees and on filesystems without symlink support.
#
# The script is idempotent: re-running it after a submodule bump refreshes all copies.
# Existing files, directories, or symlinks at managed paths are removed and replaced.

set -e

SUBMODULE_PATH=".github/openspec-shared"

# ── Argument parsing ────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --copy) ;; # no-op: bootstrap always copies
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

# copy_asset <path_in_shared_repo> <destination_in_downstream>
#
# Removes whatever exists at the destination (symlink, directory, or file) and copies the
# asset fresh from the submodule. Skips silently if the source does not exist.

copy_asset() {
  src_rel="$1"     # e.g. ".claude/skills"
  dest="$2"        # e.g. ".claude/skills"
  abs_src="$SUBMODULE_PATH/$src_rel"

  [ -e "$abs_src" ] || return 0

  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] || [ -f "$dest" ]; then
    rm -f "$dest"
  elif [ -d "$dest" ]; then
    rm -rf "$dest"
  fi
  echo "  copy  $dest  <-  $abs_src"
  if [ -d "$abs_src" ]; then
    cp -r "$abs_src" "$dest"
  else
    cp "$abs_src" "$dest"
  fi
}

# ── Asset wiring ────────────────────────────────────────────────────────────

echo "==> Wiring agent surfaces"

# .codex/
copy_asset "skills"                      ".codex/skills"

# .claude/ — prefer per-surface skills dir, fall back to generic skills/
copy_asset ".claude/skills"              ".claude/skills"
copy_asset ".claude/commands"            ".claude/commands"

# .gemini/ — prefer per-surface skills dir, fall back to generic skills/
copy_asset ".gemini/skills"              ".gemini/skills"
copy_asset ".gemini/commands"            ".gemini/commands"

# .agents/ — Antigravity IDE surface
copy_asset "skills"                      ".agents/skills"

# .agent/ — Antigravity CLI surface (skills + workflows)
copy_asset ".agent/skills"               ".agent/skills"
copy_asset ".agent/workflows"            ".agent/workflows"

# .github/ — agent surfaces only; workflows are downstream-repo-owned
copy_asset ".github/skills"              ".github/skills"
copy_asset ".github/prompts"             ".github/prompts"

echo "==> Wiring openspec assets"

mkdir -p openspec
copy_asset "templates"                   "openspec/templates"
copy_asset "openspec/schemas"            "openspec/schemas"
copy_asset "config.yaml"                 "openspec/config.yaml"

echo "==> Wiring scripts"

mkdir -p scripts
copy_asset "init-change.sh" "scripts/init-change.sh"

# ── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "Bootstrap complete (copied assets)."
echo "Copies do not update automatically. To refresh after bumping the submodule:"
echo "  git submodule update --remote $SUBMODULE_PATH"
echo "  sh $SUBMODULE_PATH/bootstrap.sh"
