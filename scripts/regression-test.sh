#!/usr/bin/env bash
# Focused regressions for installation, managed updates, repair, and the discipline hook.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openbackbone-regressions.XXXXXX")"
# Isolate from the developer's own git configuration (a global core.hooksPath
# would redirect every hook installed below)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
BEGIN='<!-- openbackbone:begin -->'
END='<!-- openbackbone:end -->'

cleanup() {
  [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

setup_openspec() {
  mkdir -p "$TEST_ROOT/bin"
  cat > "$TEST_ROOT/bin/openspec" <<'FAKE'
#!/usr/bin/env bash
set -eu
[ "${1:-}" = init ] || exit 0
language_seen=0
for argument in "$@"; do
  [ "$argument" != '--language' ] || language_seen=1
done
if [ -f openspec/config.yaml ] && [ "$language_seen" = 1 ]; then
  echo '--language does not overwrite an existing OpenSpec config' >&2
  exit 1
fi
if [ ! -f openspec/config.yaml ] && [ "$language_seen" = 0 ]; then
  echo 'fresh initialization must receive the requested language' >&2
  exit 1
fi
mkdir -p openspec
[ -f openspec/config.yaml ] || printf 'schema: spec-driven\n' > openspec/config.yaml
FAKE
  chmod +x "$TEST_ROOT/bin/openspec"
}

run_install() {
  local target="$1"; shift
  (cd "$target" && PATH="$TEST_ROOT/bin:$PATH" "$REPO_ROOT/init.sh" "$@") > "$TEST_ROOT/output" 2>&1 \
    || { cat "$TEST_ROOT/output"; fail "installation failed"; }
}

new_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.name Test
  git -C "$1" config user.email test@example.com
}

test_default_installation() {
  local target="$TEST_ROOT/default-target" dir skill
  new_repo "$target"
  run_install "$target"
  for component in openspec docs skills hooks; do
    grep -qx "  - $component" "$target/.openbackbone.yaml" || fail "missing component $component"
  done
  grep -qx 'schema: spec-driven-with-impact' "$target/openspec/config.yaml" || fail "default schema not set"
  [ -f "$target/openspec/schemas/spec-driven-with-impact/templates/impact.md" ] || fail "impact template missing"
  [ -f "$target/openspec/schemas/minimalist/schema.yaml" ] || fail "minimalist schema missing"
  for dir in .agents/skills .claude/skills; do
    for skill in domain-modeling openspec-git-discipline tech-doc; do
      [ -f "$target/$dir/$skill/SKILL.md" ] || fail "missing $dir/$skill"
    done
  done
  grep -q 'Engineering workflow' "$target/AGENTS.md" || fail "AGENTS.md managed block missing"
  grep -qx '@AGENTS.md' "$target/CLAUDE.md" || fail "CLAUDE.md does not import AGENTS.md"
  for doc in ROADMAP.md GLOSSARY.md docs/architecture.md docs/adr/README.md; do
    [ -f "$target/$doc" ] || fail "missing $doc"
  done
  [ -z "$(find "$target/docs/adr" -name '[0-9]*.md')" ] || fail "template ADRs leaked into the target"
  [ ! -e "$target/README.md" ] || fail "installer created a README"
  [ -x "$target/.git/hooks/pre-commit" ] || fail "missing hook"
  printf 'ok: default installation covers both agent targets and the document skeleton\n'
}

test_tool_selection() {
  local target="$TEST_ROOT/agents-only"
  mkdir -p "$target"
  run_install "$target" --with skills --tools agents
  [ -f "$target/.agents/skills/domain-modeling/SKILL.md" ] || fail "agents skills missing"
  [ ! -e "$target/.claude" ] || fail "claude skills installed without the claude tool"
  [ ! -e "$target/CLAUDE.md" ] || fail "CLAUDE.md created without the claude tool"
  mkdir -p "$TEST_ROOT/rejected"
  if (cd "$TEST_ROOT/rejected" && "$REPO_ROOT/init.sh" --with adr) > "$TEST_ROOT/output" 2>&1; then
    fail "unknown component was accepted"
  fi
  [ ! -e "$TEST_ROOT/rejected/AGENTS.md" ] || fail "invalid selection changed target"
  printf 'ok: tool selection limits targets; unknown components are rejected\n'
}

test_user_content_preserved() {
  local target="$TEST_ROOT/user-content"
  new_repo "$target"
  printf 'User prefix.\n%s\nOutdated managed instructions.\n%s\nUser suffix.\n' "$BEGIN" "$END" > "$target/AGENTS.md"
  printf 'My Claude notes.\n' > "$target/CLAUDE.md"
  printf '# Roadmap\n\n- Ship the thing\n' > "$target/ROADMAP.md"
  cp "$target/ROADMAP.md" "$TEST_ROOT/expected-roadmap"
  cat > "$target/.git/hooks/pre-commit" <<'HOOK'
#!/usr/bin/env bash
printf 'user-hook\n' >> user-hook.log
HOOK
  chmod +x "$target/.git/hooks/pre-commit"
  run_install "$target"
  printf 'A settled term.\n' >> "$target/GLOSSARY.md"
  cp "$target/GLOSSARY.md" "$TEST_ROOT/expected-glossary"
  cp "$target/AGENTS.md" "$TEST_ROOT/expected-agents"
  cp "$target/CLAUDE.md" "$TEST_ROOT/expected-claude"
  run_install "$target"
  cmp "$target/AGENTS.md" "$TEST_ROOT/expected-agents" || fail "rerun changed AGENTS.md"
  cmp "$target/CLAUDE.md" "$TEST_ROOT/expected-claude" || fail "rerun changed CLAUDE.md"
  cmp "$target/ROADMAP.md" "$TEST_ROOT/expected-roadmap" || fail "existing roadmap overwritten"
  cmp "$target/GLOSSARY.md" "$TEST_ROOT/expected-glossary" || fail "edited glossary overwritten on rerun"
  [ "$(head -n 1 "$target/AGENTS.md")" = 'User prefix.' ] || fail "prefix changed"
  [ "$(tail -n 1 "$target/AGENTS.md")" = 'User suffix.' ] || fail "suffix changed"
  ! grep -q 'Outdated managed instructions' "$target/AGENTS.md" || fail "managed block not refreshed"
  [ "$(head -n 1 "$target/CLAUDE.md")" = 'My Claude notes.' ] || fail "CLAUDE.md user content changed"
  [ "$(grep -cF "$BEGIN" "$target/CLAUDE.md")" = 1 ] || fail "duplicate CLAUDE.md blocks"
  [ "$(find "$target/.git/hooks" -name 'pre-commit.backup.*' | wc -l | tr -d ' ')" = 1 ] || fail "managed hook was backed up"
  (cd "$target" && OPENBACKBONE_SKIP_HOOKS=1 .git/hooks/pre-commit) > "$TEST_ROOT/output" 2>&1 || fail "hook failed"
  [ "$(cat "$target/user-hook.log")" = 'user-hook' ] || fail "user hook did not run exactly once"
  grep -q 'OPENBACKBONE_SKIP_HOOKS=1, skipping discipline checks' "$TEST_ROOT/output" || fail "maintenance bypass not reported"
  printf 'ok: reruns preserve user instructions, living documents, and chained hooks\n'
}

test_bad_markers() {
  local target="$TEST_ROOT/bad-markers"
  mkdir -p "$target"
  printf '%s\nUser data\n%s\n' "$END" "$BEGIN" > "$target/AGENTS.md"
  cp "$target/AGENTS.md" "$TEST_ROOT/bad-original"
  if (cd "$target" && "$REPO_ROOT/init.sh" --with docs) > "$TEST_ROOT/output" 2>&1; then fail "reversed markers accepted"; fi
  cmp "$target/AGENTS.md" "$TEST_ROOT/bad-original" || fail "invalid block was overwritten"
  printf '%s\n%s\n%s\n%s\n' "$BEGIN" "$END" "$BEGIN" "$END" > "$target/AGENTS.md"
  cp "$target/AGENTS.md" "$TEST_ROOT/bad-original"
  if (cd "$target" && "$REPO_ROOT/init.sh" --with docs) > "$TEST_ROOT/output" 2>&1; then fail "duplicate blocks accepted"; fi
  cmp "$target/AGENTS.md" "$TEST_ROOT/bad-original" || fail "duplicate blocks were overwritten"
  rm "$target/AGENTS.md"
  printf '%s\nunclosed\n' "$BEGIN" > "$target/CLAUDE.md"
  if (cd "$target" && "$REPO_ROOT/init.sh" --with docs) > "$TEST_ROOT/output" 2>&1; then fail "unclosed CLAUDE.md block accepted"; fi
  [ ! -e "$target/AGENTS.md" ] || fail "AGENTS.md written before CLAUDE.md markers were checked"
  printf 'ok: malformed managed blocks fail before anything is written\n'
}

test_existing_openspec_config() {
  local target="$TEST_ROOT/existing-config"
  mkdir -p "$target/openspec"
  cat > "$target/openspec/config.yaml" <<'CONFIG'
schema: spec-driven-with-impact
context: |
  Language: Japanese
  Preserve project-specific instructions.
CONFIG
  cp "$target/openspec/config.yaml" "$TEST_ROOT/expected-config"
  run_install "$target" --with openspec --language 'Simplified Chinese'
  cmp "$target/openspec/config.yaml" "$TEST_ROOT/expected-config" || fail "existing OpenSpec context changed"
  printf 'ok: OpenSpec reinitialization preserves existing language and context\n'
}

test_openspec_recovery() {
  local target="$TEST_ROOT/recovery-target" fake_bin="$TEST_ROOT/recovery-bin"
  local state="$TEST_ROOT/openspec-state"
  mkdir -p "$target" "$fake_bin"
  cat > "$fake_bin/openspec" <<'FAKE'
#!/usr/bin/env bash
set -eu
mkdir -p "$PWD/openspec"
if [ ! -f "$FAKE_OPEN_SPEC_STATE" ]; then
  : > "$FAKE_OPEN_SPEC_STATE"
  exit 1
fi
printf 'schema: spec-driven\n' > "$PWD/openspec/config.yaml"
FAKE
  chmod +x "$fake_bin/openspec"
  if (cd "$target" && PATH="$fake_bin:$PATH" FAKE_OPEN_SPEC_STATE="$state" "$REPO_ROOT/init.sh" --with openspec) \
      > "$TEST_ROOT/output" 2>&1; then
    fail "incomplete OpenSpec initialization unexpectedly succeeded"
  fi
  (cd "$target" && PATH="$fake_bin:$PATH" FAKE_OPEN_SPEC_STATE="$state" "$REPO_ROOT/init.sh" --with openspec) \
    > "$TEST_ROOT/output" 2>&1 || fail "rerun did not repair the incomplete OpenSpec initialization"
  [ -f "$target/openspec/schemas/spec-driven-with-impact/LICENSE" ] || fail "rerun did not install the default schema"
  grep -qx '  - openspec' "$target/.openbackbone.yaml" || fail "manifest did not record the repaired component"
  printf 'ok: incomplete OpenSpec initialization self-heals on rerun\n'
}

test_worktree_hooks() {
  local target="$TEST_ROOT/hooks-main" worktree="$TEST_ROOT/hooks-worktree"
  new_repo "$target"
  git -C "$target" commit -q --allow-empty -m initial
  mkdir -p "$target/nested"
  run_install "$target/nested" --with docs,hooks
  [ ! -e "$target/.git/hooks/pre-commit" ] || fail "nested installation changed repository hooks"
  if grep -qx '  - hooks' "$target/nested/.openbackbone.yaml"; then fail "nested installation reported hooks installed"; fi
  git -C "$target" worktree add -q -b linked "$worktree"
  printf '#!/bin/sh\necho chained >> hook.log\n' > "$target/.git/hooks/pre-commit"
  chmod +x "$target/.git/hooks/pre-commit"
  run_install "$worktree" --with hooks
  (cd "$worktree" && OPENBACKBONE_SKIP_HOOKS=1 "$target/.git/hooks/pre-commit") > "$TEST_ROOT/output" 2>&1 || fail "worktree hook failed"
  [ "$(cat "$worktree/hook.log")" = chained ] || fail "worktree user hook did not run"
  (cd "$target" && .git/hooks/pre-commit) > "$TEST_ROOT/output" 2>&1 || fail "uninitialized sibling worktree hook failed"
  git -C "$worktree" config core.hooksPath .custom-hooks
  run_install "$worktree" --with hooks
  [ -x "$worktree/.custom-hooks/pre-commit" ] || fail "custom hook path ignored"
  printf 'ok: linked worktrees and custom hook paths preserve chained hooks\n'
}

test_symlinked_entry_point() {
  local target="$TEST_ROOT/symlinked" bin="$TEST_ROOT/npm-bin"
  mkdir -p "$target" "$bin"
  ln -s "$REPO_ROOT/init.sh" "$bin/openbackbone"
  (cd "$target" && "$bin/openbackbone" --with docs --tools agents) > "$TEST_ROOT/output" 2>&1 \
    || { cat "$TEST_ROOT/output"; fail "symlinked entry point failed"; }
  grep -q 'local template repository' "$TEST_ROOT/output" || fail "symlinked entry point fell back to cloning"
  [ -f "$target/docs/adr/README.md" ] || fail "symlinked entry point did not install"
  printf 'ok: the npm bin symlink resolves to the packaged sources\n'
}

test_shared_hook_directory() {
  local target="$TEST_ROOT/shared-hooks" shared="$TEST_ROOT/shared-hook-dir"
  new_repo "$target"
  mkdir -p "$shared"
  git -C "$target" config core.hooksPath "$shared"
  run_install "$target" --with docs,hooks
  [ -z "$(ls -A "$shared")" ] || fail "installer wrote into a hook directory outside the repository"
  if grep -qx '  - hooks' "$target/.openbackbone.yaml"; then fail "shared hook directory reported as installed"; fi
  grep -q 'points outside this repository' "$TEST_ROOT/output" || fail "shared hook directory skip not explained"
  printf 'ok: a hook directory outside the repository is never written to\n'
}

expect_commit() {
  local outcome="$1" target="$2" message="$3"
  if git -C "$target" commit -q -m "$message" > "$TEST_ROOT/output" 2>&1; then
    [ "$outcome" = pass ] || { cat "$TEST_ROOT/output"; fail "commit should have been rejected: $message"; }
  else
    [ "$outcome" = reject ] || { cat "$TEST_ROOT/output"; fail "commit should have passed: $message"; }
    git -C "$target" reset -q
  fi
}

test_discipline_hook() {
  local target="$TEST_ROOT/discipline" change
  new_repo "$target"
  # No openspec component: the hook's spec validation stays out of this test
  run_install "$target" --with docs,hooks
  git -C "$target" add -A
  expect_commit pass "$target" 'install'

  printf '# Use files for state\n\n- Date: 2026-01-01\n- Supersedes: —\n\nWe store state in files because a database is one more thing to run.\n' \
    > "$target/docs/adr/0001-use-files-for-state.md"
  git -C "$target" add -A
  expect_commit pass "$target" 'a decision'

  printf '\nSecond thoughts.\n' >> "$target/docs/adr/0001-use-files-for-state.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'edit an accepted ADR'
  grep -q 'must not be modified' "$TEST_ROOT/output" || fail "immutability message missing"
  git -C "$target" checkout -q -- docs/adr

  printf '# Storage\n\n## Requirement: persist state\n\nThe system SHALL persist state.\n' \
    > "$target/docs/adr/0002-storage.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'an ADR that is really a spec'
  grep -q 'Requirement/Scenario' "$TEST_ROOT/output" || fail "spec-in-ADR message missing"
  rm "$target/docs/adr/0002-storage.md"

  change="$target/openspec/changes/add-export"
  mkdir -p "$change"
  cp "$REPO_ROOT/openspec/schemas/spec-driven-with-impact/templates/impact.md" "$change/impact.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'an unfilled impact review'
  grep -q 'Decisions Glossary Architecture Roadmap README' "$TEST_ROOT/output" || fail "template impact.md not fully flagged"

  cat > "$change/impact.md" <<'IMPACT'
## Decisions (docs/adr/)
- Not affected: no decision here is hard to reverse
## Glossary (GLOSSARY.md)
- Updated: GLOSSARY.md - added Export
## Architecture (docs/architecture.md)
Planned: add the export worker
## Roadmap (ROADMAP.md)
- Planned: remove "CSV export"
## README (README.md)
IMPACT
  git -C "$target" add -A
  expect_commit reject "$target" 'an impact review missing README'
  grep -q 'no entry for: README' "$TEST_ROOT/output" || fail "missing section not named"

  printf -- '- Planned: document the export command\n' >> "$change/impact.md"
  git -C "$target" add -A
  expect_commit pass "$target" 'a complete impact review'
  printf 'ok: the hook guards ADR immutability, ADR scope, and impact reviews\n'
}

setup_openspec
test_default_installation
test_tool_selection
test_user_content_preserved
test_bad_markers
test_existing_openspec_config
test_openspec_recovery
test_worktree_hooks
test_symlinked_entry_point
test_shared_hook_directory
test_discipline_hook
printf 'All regression tests passed.\n'
