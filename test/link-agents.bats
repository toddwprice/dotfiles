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
