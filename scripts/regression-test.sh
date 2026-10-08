#!/usr/bin/env bash
# Focused regressions for installation, managed updates, repair, and the discipline hook.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openbackbone-regressions.XXXXXX")"
# Isolate from the developer's own git configuration (a global core.hooksPath
# would redirect every hook installed below)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# Never prompt, even when the tests are started from a terminal
export CI=true
# A startup file named by BASH_ENV runs in every child shell and can put the
# developer's real npm and openspec back on PATH
unset BASH_ENV ENV
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

# Permission string of a file, e.g. -rw-r--r--
mode_of() {
  # shellcheck disable=SC2012  # stat differs between GNU and BSD; ls -l does not
  ls -ld "$1" | cut -c1-10
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
  [ -x "$target/scripts/openbackbone-pre-commit.sh" ] || fail "missing hook checks"
  grep -qx '  - scripts/openbackbone-pre-commit.sh' "$target/.openbackbone.yaml" || fail "hook checks not in the manifest"
  grep -qx '  - .claude/skills/domain-modeling/' "$target/.openbackbone.yaml" || fail "skill not in the manifest"
  grep -qx '  - openspec/schemas/minimalist/' "$target/.openbackbone.yaml" || fail "schema not in the manifest"
  printf 'ok: default installation covers both agent targets and the document skeleton\n'
}

test_tool_selection() {
  local target="$TEST_ROOT/agents-only"
  mkdir -p "$target"
  run_install "$target" --with skills --tools agents
  [ -f "$target/.agents/skills/domain-modeling/SKILL.md" ] || fail "agents skills missing"
  [ ! -e "$target/.claude" ] || fail "claude skills installed without the claude tool"
  [ ! -e "$target/CLAUDE.md" ] || fail "CLAUDE.md created without the claude tool"
  mkdir -p "$TEST_ROOT/claude-only"
  run_install "$TEST_ROOT/claude-only" --with skills --tools ' claude '
  [ -f "$TEST_ROOT/claude-only/.claude/skills/domain-modeling/SKILL.md" ] || fail "claude skills missing"
  [ ! -e "$TEST_ROOT/claude-only/.agents" ] || fail ".agents created for the claude target alone"
  grep -qx '@AGENTS.md' "$TEST_ROOT/claude-only/CLAUDE.md" || fail "claude target did not get the import"
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
  chmod 644 "$target/AGENTS.md" "$target/CLAUDE.md"
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
  cp "$target/.openbackbone.yaml" "$TEST_ROOT/expected-manifest"
  run_install "$target"
  cmp "$target/.openbackbone.yaml" "$TEST_ROOT/expected-manifest" || fail "rerun changed the manifest"
  cmp "$target/AGENTS.md" "$TEST_ROOT/expected-agents" || fail "rerun changed AGENTS.md"
  cmp "$target/CLAUDE.md" "$TEST_ROOT/expected-claude" || fail "rerun changed CLAUDE.md"
  cmp "$target/ROADMAP.md" "$TEST_ROOT/expected-roadmap" || fail "existing roadmap overwritten"
  cmp "$target/GLOSSARY.md" "$TEST_ROOT/expected-glossary" || fail "edited glossary overwritten on rerun"
  [ "$(head -n 1 "$target/AGENTS.md")" = 'User prefix.' ] || fail "prefix changed"
  [ "$(tail -n 1 "$target/AGENTS.md")" = 'User suffix.' ] || fail "suffix changed"
  ! grep -q 'Outdated managed instructions' "$target/AGENTS.md" || fail "managed block not refreshed"
  [ "$(head -n 1 "$target/CLAUDE.md")" = 'My Claude notes.' ] || fail "CLAUDE.md user content changed"
  [ "$(mode_of "$target/AGENTS.md")" = '-rw-r--r--' ] || fail "AGENTS.md permissions changed"
  [ "$(mode_of "$target/CLAUDE.md")" = '-rw-r--r--' ] || fail "CLAUDE.md permissions changed"
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
  [ "$(mode_of "$target/openspec/config.yaml")" = "$(mode_of "$TEST_ROOT/expected-config")" ] \
    || fail "OpenSpec configuration permissions changed"

  printf 'schema: minimalist  # ours\ncontext: keep\n' > "$target/openspec/config.yaml"
  cp "$target/openspec/config.yaml" "$TEST_ROOT/expected-config"
  run_install "$target" --with openspec
  cmp "$target/openspec/config.yaml" "$TEST_ROOT/expected-config" || fail "the project's default schema was reset"
  grep -q "left as 'minimalist'" "$TEST_ROOT/output" || fail "kept default schema not reported"

  printf 'schema: "spec-driven"\ncontext: keep\n' > "$target/openspec/config.yaml"
  run_install "$target" --with openspec
  grep -qx 'schema: spec-driven-with-impact' "$target/openspec/config.yaml" || fail "stock default schema not replaced"
  grep -qx 'context: keep' "$target/openspec/config.yaml" || fail "configuration lost content"
  printf 'ok: OpenSpec configuration keeps its context; the default schema is set once\n'
}

# A directory holding every system tool except Node.js, npm, and the OpenSpec
# CLI, so a test can run the installer where neither exists and can never
# reach the real npm.
make_bare_path() {
  local dirs i
  BARE_PATH="$TEST_ROOT/bare-bin"
  mkdir -p "$BARE_PATH"
  # Mirror the caller's PATH. Walking it backwards and overwriting leaves the
  # first match on PATH as the winner, as it is outside the sandbox.
  IFS=: read -r -a dirs <<< "$PATH"
  for (( i = ${#dirs[@]} - 1; i >= 0; i-- )); do
    case "${dirs[i]}" in /*) ;; *) continue ;; esac
    [ -d "${dirs[i]}" ] || continue
    ln -sf "${dirs[i]}"/* "$BARE_PATH"/ 2>/dev/null || true
  done
  (cd "$BARE_PATH" && rm -f node nodejs npm npx corepack openspec)
  if PATH="$BARE_PATH" command -v npm > /dev/null 2>&1 || PATH="$BARE_PATH" command -v openspec > /dev/null 2>&1; then
    fail "the bare PATH still reaches npm or openspec"
  fi
}

test_openspec_required() {
  local target="$TEST_ROOT/no-cli" npm_bin="$TEST_ROOT/fake-npm" calls="$TEST_ROOT/npm-calls"
  mkdir -p "$target" "$npm_bin"
  cat > "$npm_bin/npm" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_NPM_CALLS"
cp "$FAKE_OPENSPEC" "$(dirname "$0")/openspec"
FAKE
  chmod +x "$npm_bin/npm"

  if (cd "$target" && PATH="$npm_bin:$BARE_PATH" FAKE_NPM_CALLS="$calls" "$REPO_ROOT/init.sh") > "$TEST_ROOT/output" 2>&1; then
    fail "installation succeeded without the OpenSpec CLI"
  fi
  grep -q 'OpenSpec CLI is required' "$TEST_ROOT/output" || fail "missing CLI not explained"
  grep -q 'npm install -g @fission-ai/openspec' "$TEST_ROOT/output" || fail "install command not shown"
  [ -z "$(ls -A "$target")" ] || fail "a refused installation changed the project"
  [ ! -e "$calls" ] || fail "npm ran without consent"

  (cd "$target" && PATH="$npm_bin:$BARE_PATH" FAKE_NPM_CALLS="$calls" "$REPO_ROOT/init.sh" --with docs) \
    > "$TEST_ROOT/output" 2>&1 || { cat "$TEST_ROOT/output"; fail "a subset without openspec required the CLI"; }
  rm -rf "$target" && mkdir -p "$target"

  (cd "$target" && PATH="$npm_bin:$BARE_PATH" FAKE_NPM_CALLS="$calls" FAKE_OPENSPEC="$TEST_ROOT/bin/openspec" \
    "$REPO_ROOT/init.sh" --yes) > "$TEST_ROOT/output" 2>&1 || { cat "$TEST_ROOT/output"; fail "--yes did not install the CLI and continue"; }
  grep -qx 'install -g @fission-ai/openspec@latest' "$calls" || fail "npm was not asked to install the CLI"
  grep -qx '  - openspec' "$target/.openbackbone.yaml" || fail "openspec component missing after --yes"
  rm "$npm_bin/openspec"

  rm -rf "$target" && mkdir -p "$target"
  if (cd "$target" && PATH="$BARE_PATH" "$REPO_ROOT/init.sh" --yes) > "$TEST_ROOT/output" 2>&1; then
    fail "installation succeeded without the CLI or npm"
  fi
  [ -z "$(ls -A "$target")" ] || fail "a failed prerequisite changed the project"
  printf 'ok: the OpenSpec CLI is required; it is installed only with consent\n'
}

test_openspec_recovery() {
  local target="$TEST_ROOT/recovery-target" fake_bin="$TEST_ROOT/recovery-bin"
  local state="$TEST_ROOT/openspec-state"
  mkdir -p "$target" "$fake_bin"
  cat > "$fake_bin/openspec" <<'FAKE'
#!/usr/bin/env bash
set -eu
mkdir -p "$PWD/openspec"
[ -z "${FAKE_ALWAYS_FAIL:-}" ] || exit 1
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
  mkdir -p "$TEST_ROOT/recovery-multi"
  if (cd "$TEST_ROOT/recovery-multi" && PATH="$fake_bin:$PATH" FAKE_OPEN_SPEC_STATE="$TEST_ROOT/never" FAKE_ALWAYS_FAIL=1 "$REPO_ROOT/init.sh") \
      > "$TEST_ROOT/output" 2>&1; then
    fail "a failed OpenSpec initialization was reported as success"
  fi
  (cd "$target" && PATH="$fake_bin:$PATH" FAKE_OPEN_SPEC_STATE="$state" "$REPO_ROOT/init.sh" --with openspec) \
    > "$TEST_ROOT/output" 2>&1 || fail "rerun did not repair the incomplete OpenSpec initialization"
  [ -f "$target/openspec/schemas/spec-driven-with-impact/schema.yaml" ] || fail "rerun did not install the default schema"
  grep -qx '  - openspec' "$target/.openbackbone.yaml" || fail "manifest did not record the repaired component"
  [ ! -e "$TEST_ROOT/recovery-multi/.openbackbone.yaml" ] || fail "a failed initialization wrote a manifest"
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
  printf 'ok: a symlinked installer resolves to its own sources\n'
}

test_piped_upgrade() {
  local source="$TEST_ROOT/published" target="$TEST_ROOT/piped"
  mkdir -p "$source" "$target"
  (cd "$REPO_ROOT" && tar cf - --exclude=.git --exclude=node_modules .) | (cd "$source" && tar xf -)
  new_repo "$source"
  git -C "$source" add -A
  git -C "$source" commit -q -m published
  # A project that is already installed must still be upgraded from the
  # published source, not mistaken for the source itself
  run_install "$target" --with openspec,skills --tools agents
  printf '# managed-by: openbackbone\nstale\n' > "$target/openspec/schemas/spec-driven-with-impact/schema.yaml"
  (cd "$target" && PATH="$TEST_ROOT/bin:$PATH" OPENBACKBONE_REPO="$source" bash -s -- --tools agents < "$REPO_ROOT/init.sh") \
    > "$TEST_ROOT/output" 2>&1 || { cat "$TEST_ROOT/output"; fail "piped installation failed"; }
  grep -q 'cloning' "$TEST_ROOT/output" || fail "piped installer did not fetch the published source"
  cmp -s "$target/openspec/schemas/spec-driven-with-impact/schema.yaml" \
    "$REPO_ROOT/openspec/schemas/spec-driven-with-impact/schema.yaml" || fail "piped rerun did not upgrade the schema"
  grep -q 'Engineering workflow' "$target/AGENTS.md" || fail "piped rerun skipped the instructions"
  printf 'ok: a piped rerun upgrades an installed project from the published source\n'
}

test_claude_instructions() {
  local target="$TEST_ROOT/claude-symlink" imported="$TEST_ROOT/claude-imported"
  mkdir -p "$target" "$imported"
  printf 'Project rules.\n' > "$target/AGENTS.md"
  ln -s AGENTS.md "$target/CLAUDE.md"
  run_install "$target" --with docs
  [ -L "$target/CLAUDE.md" ] || fail "CLAUDE.md symlink was replaced"
  [ "$(grep -cF "$BEGIN" "$target/AGENTS.md")" = 1 ] || fail "symlinked CLAUDE.md duplicated the managed block"
  ! grep -qx '@AGENTS.md' "$target/AGENTS.md" || fail "AGENTS.md imports itself"
  printf 'Notes.\n@AGENTS.md\n' > "$imported/CLAUDE.md"
  cp "$imported/CLAUDE.md" "$TEST_ROOT/expected-claude-import"
  run_install "$imported" --with docs
  cmp "$imported/CLAUDE.md" "$TEST_ROOT/expected-claude-import" || fail "an existing AGENTS.md import was duplicated"

  local reversed="$TEST_ROOT/agents-symlink" elsewhere="$TEST_ROOT/claude-elsewhere"
  mkdir -p "$reversed" "$elsewhere/notes"
  printf 'Project rules.\n' > "$reversed/CLAUDE.md"
  ln -s CLAUDE.md "$reversed/AGENTS.md"
  run_install "$reversed" --with docs
  [ -L "$reversed/AGENTS.md" ] || fail "AGENTS.md symlink was replaced"
  [ "$(head -n 1 "$reversed/CLAUDE.md")" = 'Project rules.' ] || fail "content behind the AGENTS.md symlink was lost"
  [ "$(grep -cF "$BEGIN" "$reversed/CLAUDE.md")" = 1 ] || fail "managed block not written through the AGENTS.md symlink"
  ! grep -qx '@AGENTS.md' "$reversed/CLAUDE.md" || fail "CLAUDE.md imports itself through the symlink"
  run_install "$reversed" --with docs
  [ "$(grep -cF "$BEGIN" "$reversed/CLAUDE.md")" = 1 ] || fail "rerun duplicated the block behind the symlink"

  printf 'Claude notes.\n' > "$elsewhere/notes/claude.md"
  ln -s notes/claude.md "$elsewhere/CLAUDE.md"
  run_install "$elsewhere" --with docs
  [ -L "$elsewhere/CLAUDE.md" ] || fail "CLAUDE.md symlink to another file was replaced"
  grep -qx '@AGENTS.md' "$elsewhere/notes/claude.md" || fail "import not written through the CLAUDE.md symlink"
  printf 'ok: instruction files that are symlinks stay symlinks; nothing imports itself\n'
}

test_ownership() {
  local target="$TEST_ROOT/ownership" kept
  new_repo "$target"
  mkdir -p "$target/.claude/skills/domain-modeling" "$target/docs/adr" "$target/scripts" "$target/openspec/schemas/minimalist"
  for kept in .claude/skills/domain-modeling/SKILL.md docs/adr/README.md scripts/pre-commit.sh openspec/schemas/minimalist/schema.yaml; do
    printf 'MINE\n' > "$target/$kept"
  done
  run_install "$target"
  for kept in .claude/skills/domain-modeling/SKILL.md docs/adr/README.md scripts/pre-commit.sh openspec/schemas/minimalist/schema.yaml; do
    [ "$(cat "$target/$kept")" = MINE ] || fail "the project's own $kept was overwritten"
  done
  grep -q 'Kept as they are' "$TEST_ROOT/output" || fail "kept files not reported"
  for kept in .claude/skills/domain-modeling/ docs/adr/README.md openspec/schemas/minimalist/; do
    grep -qF "  - $kept" "$TEST_ROOT/output" || fail "$kept not named as kept"
    ! grep -qxF "  - $kept" "$target/.openbackbone.yaml" || fail "$kept listed as managed"
  done
  [ -f "$target/.agents/skills/domain-modeling/ADR-FORMAT.md" ] || fail "the other agent target did not get the skill"
  grep -qx '  - .agents/skills/domain-modeling/' "$target/.openbackbone.yaml" || fail "installed skill not in the manifest"

  # Managed and still marked: an upgrade replaces local edits
  printf 'local edit\n' >> "$target/.agents/skills/tech-doc/SKILL.md"
  # Taken over by removing the marker: an upgrade keeps it
  grep -v 'managed-by: openbackbone' "$target/.agents/skills/openspec-git-discipline/SKILL.md" > "$TEST_ROOT/taken-over"
  printf 'our own rule\n' >> "$TEST_ROOT/taken-over"
  cat "$TEST_ROOT/taken-over" > "$target/.agents/skills/openspec-git-discipline/SKILL.md"
  grep -v 'managed-by: openbackbone' "$target/openspec/schemas/spec-driven-with-impact/schema.yaml" > "$TEST_ROOT/own-schema"
  cat "$TEST_ROOT/own-schema" > "$target/openspec/schemas/spec-driven-with-impact/schema.yaml"
  run_install "$target"
  cmp -s "$target/.agents/skills/tech-doc/SKILL.md" "$REPO_ROOT/skills/tech-doc/SKILL.md" || fail "a marked skill was not upgraded"
  cmp -s "$target/.agents/skills/openspec-git-discipline/SKILL.md" "$TEST_ROOT/taken-over" || fail "a skill the project took over was replaced"
  cmp -s "$target/openspec/schemas/spec-driven-with-impact/schema.yaml" "$TEST_ROOT/own-schema" || fail "a schema the project took over was replaced"
  grep -qF '  - .agents/skills/openspec-git-discipline/' "$TEST_ROOT/output" || fail "taken-over skill not reported as kept"
  printf 'ok: same-named and taken-over files are kept; marked files are upgraded\n'
}

test_disabled_user_hook() {
  local target="$TEST_ROOT/disabled-hook" backup
  new_repo "$target"
  printf '#!/bin/sh\necho ran >> disabled-hook.log\n' > "$target/.git/hooks/pre-commit"
  chmod 644 "$target/.git/hooks/pre-commit"
  run_install "$target" --with docs,hooks
  backup="$(find "$target/.git/hooks" -name 'pre-commit.backup.*')"
  [ -n "$backup" ] || fail "disabled hook was not kept"
  [ ! -x "$backup" ] || fail "a disabled hook was made executable"
  git -C "$target" add -A
  git -C "$target" commit -q -m install > "$TEST_ROOT/output" 2>&1 || { cat "$TEST_ROOT/output"; fail "commit failed"; }
  [ ! -e "$target/disabled-hook.log" ] || fail "a disabled hook ran"
  printf 'ok: a disabled pre-commit hook stays disabled\n'
}

test_spec_validation_scope() {
  local target="$TEST_ROOT/validation" calls="$TEST_ROOT/validate-calls" bin="$TEST_ROOT/validate-bin"
  new_repo "$target"
  run_install "$target" --with docs,hooks
  mkdir -p "$bin" "$target/openspec/changes/drafting" "$target/openspec/changes/specified/specs/export" \
    "$target/openspec/specs/billing"
  cat > "$bin/openspec" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$VALIDATE_CALLS"
case "$*" in *"${VALIDATE_REJECT:-none}"*) exit 1 ;; esac
FAKE
  chmod +x "$bin/openspec"
  git -C "$target" add -A
  git -C "$target" commit -q -m install > "$TEST_ROOT/output" 2>&1 || fail "installation commit failed"

  # The commit's own specs and changes are validated, one by one
  : > "$calls"
  printf '## Why\n' > "$target/openspec/changes/drafting/proposal.md"
  printf '## ADDED Requirements\n' > "$target/openspec/changes/specified/specs/export/spec.md"
  printf '# billing\n' > "$target/openspec/specs/billing/spec.md"
  git -C "$target" add -A
  PATH="$bin:$PATH" VALIDATE_CALLS="$calls" git -C "$target" commit -q -m 'work in progress' > "$TEST_ROOT/output" 2>&1 \
    || { cat "$TEST_ROOT/output"; fail "a proposal-only change blocked the commit"; }
  grep -qx 'validate billing --type spec --strict --no-interactive' "$calls" || fail "a staged spec was not validated"
  grep -qx 'validate specified --type change --strict --no-interactive' "$calls" || fail "a change with delta specs was not validated"
  ! grep -q '^validate drafting ' "$calls" || fail "a change without delta specs was validated"
  [ "$(wc -l < "$calls" | tr -d ' ')" = 2 ] || { cat "$calls"; fail "the hook validated more than the commit touched"; }

  # A commit that touches nothing under openspec/ runs no validation
  : > "$calls"
  printf 'code\n' > "$target/main.c"
  git -C "$target" add -A
  PATH="$bin:$PATH" VALIDATE_CALLS="$calls" VALIDATE_REJECT=validate git -C "$target" commit -q -m 'unrelated' > "$TEST_ROOT/output" 2>&1 \
    || { cat "$TEST_ROOT/output"; fail "an unrelated commit was rejected"; }
  [ ! -s "$calls" ] || fail "an unrelated commit ran the OpenSpec CLI"

  # A touched spec that fails validation blocks the commit
  printf 'more\n' >> "$target/openspec/specs/billing/spec.md"
  git -C "$target" add -A
  if PATH="$bin:$PATH" VALIDATE_CALLS="$calls" VALIDATE_REJECT='billing --type spec' \
      git -C "$target" commit -q -m 'invalid spec' > "$TEST_ROOT/output" 2>&1; then
    fail "an invalid staged spec was committed"
  fi
  grep -q "spec 'billing' is invalid" "$TEST_ROOT/output" || fail "invalid spec not explained"
  git -C "$target" reset -q
  git -C "$target" checkout -q -- openspec/specs

  # Without the CLI, validation is skipped with a notice and the commit goes through
  printf 'more\n' >> "$target/openspec/specs/billing/spec.md"
  git -C "$target" add -A
  PATH="$BARE_PATH" git -C "$target" commit -q -m 'spec edit without the CLI' > "$TEST_ROOT/output" 2>&1 \
    || { cat "$TEST_ROOT/output"; fail "a missing CLI blocked the commit"; }
  grep -q 'openspec CLI not found, skipping spec validation' "$TEST_ROOT/output" || fail "skipped validation not reported"

  # An archive from before the installation never blocks a commit
  mkdir -p "$target/openspec/changes/archive/2020-01-01-old"
  printf '## 1. Old\n\n- [ ] 1.1 never finished\n' > "$target/openspec/changes/archive/2020-01-01-old/tasks.md"
  git -C "$target" add -A
  OPENBACKBONE_SKIP_HOOKS=1 git -C "$target" commit -q -m 'history from before the installation' > "$TEST_ROOT/output" 2>&1
  printf 'more code\n' >> "$target/main.c"
  git -C "$target" add -A
  git -C "$target" commit -q -m 'unrelated, after an old archive' > "$TEST_ROOT/output" 2>&1 \
    || { cat "$TEST_ROOT/output"; fail "an old archive with open tasks blocked an unrelated commit"; }

  # Archiving in this commit with an open task is rejected; no CLI is needed
  mkdir -p "$target/openspec/changes/archive/2026-01-01-new"
  printf '## 1. New\n\n- [x] 1.1 done\n- [ ] 1.2 README.md: document it\n' > "$target/openspec/changes/archive/2026-01-01-new/tasks.md"
  git -C "$target" add -A
  if PATH="$BARE_PATH" git -C "$target" commit -q -m 'archive with an open task' > "$TEST_ROOT/output" 2>&1; then
    fail "a change was archived with an open task"
  fi
  grep -q 'archived with 1 open task' "$TEST_ROOT/output" || { cat "$TEST_ROOT/output"; fail "open archived task not explained"; }
  git -C "$target" reset -q
  printf '## 1. New\n\n- [x] 1.1 done\n- [x] 1.2 README.md: document it\n' > "$target/openspec/changes/archive/2026-01-01-new/tasks.md"
  git -C "$target" add -A
  git -C "$target" commit -q -m 'archive' > "$TEST_ROOT/output" 2>&1 || { cat "$TEST_ROOT/output"; fail "a finished archive was rejected"; }
  printf 'ok: the hook validates what a commit touches, and nothing that was already there\n'
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
  local target="$TEST_ROOT/discipline" change default_branch
  new_repo "$target"
  default_branch="$(git -C "$target" symbolic-ref --short HEAD)"
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

  # A draft that exists only on a feature branch can still be revised
  git -C "$target" checkout -q -b feat/draft
  printf '# Cache reads\n\n- Date: 2026-01-02\n- Supersedes: —\n\nFirst wording.\n' > "$target/docs/adr/0002-cache-reads.md"
  git -C "$target" add -A
  expect_commit pass "$target" 'a draft decision'
  printf '# Cache reads\n\n- Date: 2026-01-02\n- Supersedes: —\n\nBetter wording after review.\n' > "$target/docs/adr/0002-cache-reads.md"
  git -C "$target" add -A
  expect_commit pass "$target" 'revise the draft'
  printf '\nSecond thoughts.\n' >> "$target/docs/adr/0001-use-files-for-state.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'edit an accepted ADR from a feature branch'
  git -C "$target" checkout -q -- docs/adr

  printf '# Storage\n\n## Requirement: persist state\n\nThe system SHALL persist state.\n' \
    > "$target/docs/adr/0003-storage.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'an ADR that is really a spec'
  grep -q 'Requirement/Scenario' "$TEST_ROOT/output" || fail "spec-in-ADR message missing"
  rm "$target/docs/adr/0003-storage.md"

  printf '# Pick a queue\n\n- Date: 2026-01-03\n- Supersedes: —\n\nWe chose the simpler one.\n\n## Requirements we weighed\n\nThroughput mattered most.\n' \
    > "$target/docs/adr/0003-pick-a-queue.md"
  git -C "$target" add -A
  expect_commit pass "$target" 'an ADR whose heading only mentions requirements'

  # File names that are not ASCII are checked like any other
  git -C "$target" checkout -q "$default_branch"
  printf '# 使用消息队列\n\n- Date: 2026-01-04\n- Supersedes: —\n\n因为简单。\n' > "$target/docs/adr/0009-使用消息队列.md"
  git -C "$target" add -A
  expect_commit pass "$target" 'a decision with a Chinese file name'
  printf '\n改主意了。\n' >> "$target/docs/adr/0009-使用消息队列.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'edit an accepted ADR with a Chinese file name'
  grep -q 'must not be modified' "$TEST_ROOT/output" || fail "immutability missed a file name that is not ASCII"
  git -C "$target" checkout -q -- docs/adr

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

  # Markers may be bold, bulleted either way, or use a full-width colon
  mkdir -p "$target/openspec/changes/formatted"
  cat > "$target/openspec/changes/formatted/impact.md" <<'IMPACT'
## Decisions (docs/adr/)
- **Not affected:** nothing durable was decided
## Glossary (GLOSSARY.md)
- **Updated**: GLOSSARY.md - added Export
## Architecture (docs/architecture.md)
* Planned：补充导出组件
## Roadmap (ROADMAP.md)
Not affected：计划外的工作
## README (README.md)
  - Planned: document the export command
IMPACT
  git -C "$target" add -A
  expect_commit pass "$target" 'an impact review with formatted markers'
  printf '## Decisions (docs/adr/)\n- Not affected:\n' > "$target/openspec/changes/formatted/impact.md"
  git -C "$target" add -A
  expect_commit reject "$target" 'a marker without a reason'
  grep -q 'no entry for: Decisions' "$TEST_ROOT/output" || fail "a marker without a reason was accepted"
  printf 'ok: the hook guards ADR immutability, ADR scope, and impact reviews\n'
}

setup_openspec
make_bare_path
test_default_installation
test_tool_selection
test_user_content_preserved
test_bad_markers
test_existing_openspec_config
test_openspec_required
test_openspec_recovery
test_worktree_hooks
test_symlinked_entry_point
test_piped_upgrade
test_claude_instructions
test_ownership
test_disabled_user_hook
test_shared_hook_directory
test_spec_validation_scope
test_discipline_hook
printf 'All regression tests passed.\n'
