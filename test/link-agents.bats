#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../bin/link-agents"
  export HOME="$BATS_TEST_TMPDIR/home"
  export DOTFILES="$HOME/.dotfiles"
  local ai="$DOTFILES/ai"
  mkdir -p "$ai/skills/demo" "$ai/commands" "$ai/claude/agents" "$ai/claude/scripts"
  echo "skill"  > "$ai/skills/demo/SKILL.md"
  echo "cmd"    > "$ai/commands/demo.md"
  echo "agents" > "$ai/AGENTS.md"
  echo "{}"     > "$ai/claude/settings.json"
  echo "line"   > "$ai/claude/statusline-command.sh"
  mkdir -p "$HOME/.claude"
}

@test "links skills into ~/.claude/skills" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/skills" ]
  [ "$(readlink "$HOME/.claude/skills")" = "$DOTFILES/ai/skills" ]
  [ -f "$HOME/.claude/skills/demo/SKILL.md" ]
}

@test "links AGENTS.md in as ~/.claude/CLAUDE.md" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$DOTFILES/ai/AGENTS.md" ]
}

@test "creates ~/.agents/skills even though ~/.agents does not exist" {
  [ ! -d "$HOME/.agents" ]
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.agents/skills")" = "$DOTFILES/ai/skills" ]
}

@test "refuses a real directory and exits non-zero" {
  rm -rf "$HOME/.claude/skills"
  mkdir -p "$HOME/.claude/skills/mine"
  echo "keep me" > "$HOME/.claude/skills/mine/SKILL.md"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REFUSE"* ]]
  [ -f "$HOME/.claude/skills/mine/SKILL.md" ]
  [ ! -L "$HOME/.claude/skills" ]
}

@test "one refusal does not stop later rows" {
  # ~/.claude/skills is row 1 and ~/.agents/skills is row 2, so refusing the
  # first proves the loop kept going rather than bailing on the first failure.
  rm -rf "$HOME/.claude/skills"
  mkdir -p "$HOME/.claude/skills/mine"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REFUSE"* ]]
  [ "$(readlink "$HOME/.agents/skills")" = "$DOTFILES/ai/skills" ]
}

@test "reports MISSING and exits non-zero when a source is absent" {
  rm -f "$DOTFILES/ai/AGENTS.md"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING"* ]]
}

@test "--dry-run creates nothing" {
  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"link"* ]]
  [ ! -e "$HOME/.claude/skills" ]
  [ ! -e "$HOME/.agents" ]
}

@test "gates codex and opencode rows when those harnesses are absent" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gate"* ]]
  [ ! -e "$HOME/.codex" ]
  [ ! -e "$HOME/.config/opencode" ]
}

@test "links codex rows once ~/.codex exists" {
  mkdir -p "$HOME/.codex"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.codex/prompts")" = "$DOTFILES/ai/commands" ]
  [ "$(readlink "$HOME/.codex/AGENTS.md")" = "$DOTFILES/ai/AGENTS.md" ]
}

@test "links opencode rows once ~/.config/opencode exists" {
  mkdir -p "$HOME/.config/opencode"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/opencode/commands")" = "$DOTFILES/ai/commands" ]
  [ "$(readlink "$HOME/.config/opencode/AGENTS.md")" = "$DOTFILES/ai/AGENTS.md" ]
}

@test "second run is a no-op and reports ok" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  [[ "$output" != *"link "* ]]
}

@test "repoints a symlink that points somewhere else" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  ln -sfn "$BATS_TEST_TMPDIR/elsewhere" "$HOME/.claude/skills"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"repoint"* ]]
  [ "$(readlink "$HOME/.claude/skills")" = "$DOTFILES/ai/skills" ]
}

@test "re-linking does not nest a link inside the target directory" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  ln -sfn "$BATS_TEST_TMPDIR/elsewhere" "$HOME/.claude/skills"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  # Without -n, ln descends into the existing symlink-to-directory and creates
  # the new link inside it instead of replacing it.
  [ ! -e "$BATS_TEST_TMPDIR/elsewhere/skills" ]
  [ "$(readlink "$HOME/.claude/skills")" = "$DOTFILES/ai/skills" ]
}

@test "rejects an unrecognized flag and creates nothing" {
  run "$SCRIPT" --dry-ru
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.claude/skills" ]
  [ ! -e "$HOME/.agents" ]
}
