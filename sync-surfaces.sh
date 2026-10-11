#!/usr/bin/env sh
# sync-surfaces.sh — Regenerate every per-surface skill and command wrapper from skills/.
#
# Run from the root of the openspec-shared repo after editing anything under skills/:
#   sh sync-surfaces.sh
#
# skills/ is the single source of truth. This script:
#   1. Copies every skill in skills/ into .claude/ .gemini/ .github/ .agent/ (skills/ dirs)
#   2. Regenerates the /opsx command wrappers for each surface from the matching skill body:
#        .claude/commands/opsx/*.md   .gemini/commands/opsx/*.toml
#        .github/prompts/opsx-*.prompt.md   .agent/workflows/opsx-*.md
#
# Output is always plain copies (never symlinks) with LF line endings.

set -e

cd "$(dirname "$0")"

# body <skill-name> — skill file without its YAML frontmatter, LF line endings
body() {
  tr -d '\r' < "skills/$1/SKILL.md" | awk 'c>=2{print;next} /^---$/{c++}'
}

# gen <command> <skill> <title> <description> <claude-tags>
gen() {
  cmd="$1"; skill="$2"; title="$3"; desc="$4"; tags="$5"

  mkdir -p .claude/commands/opsx .gemini/commands/opsx .github/prompts .agent/workflows

  {
    printf -- '---\nname: "OPSX: %s"\ndescription: "%s"\ncategory: Workflow\ntags: %s\n---\n' "$title" "$desc" "$tags"
    body "$skill"
  } > ".claude/commands/opsx/$cmd.md"

  {
    printf 'description = "%s"\n\nprompt = '"'''"'\n' "$desc"
    body "$skill"
    printf "'''"'\n'
  } > ".gemini/commands/opsx/$cmd.toml"

  {
    printf -- '---\ndescription: "%s"\n---\n' "$desc"
    body "$skill"
  } > ".github/prompts/opsx-$cmd.prompt.md"

  {
    printf -- '---\ndescription: "%s"\n---\n' "$desc"
    body "$skill"
  } > ".agent/workflows/opsx-$cmd.md"

  echo "  wrapper  opsx $cmd  <-  skills/$skill"
}

echo "==> Copying skills into agent surfaces"
for surface in .claude .gemini .github .agent; do
  mkdir -p "$surface/skills"
  for dir in skills/*/; do
    name=$(basename "$dir")
    rm -rf "$surface/skills/$name"
    cp -r "$dir" "$surface/skills/$name"
    find "$surface/skills/$name" -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.sh' \) -exec sed -i 's/\r$//' {} +
  done
  echo "  skills   $surface/skills"
done

echo "==> Generating command wrappers"
gen apply   openspec-apply-change   "Apply"   "Implement tasks from an OpenSpec change (Experimental)" "[workflow, artifacts, experimental]"
gen archive openspec-archive-change "Archive" "Archive a completed change in the experimental workflow" "[workflow, archive, experimental]"
gen explore openspec-explore        "Explore" "Enter explore mode - think through ideas, investigate problems, clarify requirements" "[workflow, explore, experimental, thinking]"
gen propose openspec-propose        "Propose" "Propose a new change - create it and generate all artifacts in one step" "[workflow, artifacts, experimental]"

echo "Done."
