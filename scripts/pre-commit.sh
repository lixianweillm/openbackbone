#!/usr/bin/env bash
# openbackbone discipline hook. Before every commit it checks that:
#   1. accepted ADRs (those on the default branch) are not modified, deleted,
#      or renamed
#   2. new ADRs record a decision, not a spec
#   3. every staged impact.md accounts for all five living documents
#   4. specs, changes that have reached their delta specs, and archived
#      changes validate
# Called by Git's effective pre-commit shim; logic is version-controlled with the
# repository, so upgrades need no hook reinstall.
set -uo pipefail

if [ "${OPENBACKBONE_SKIP_HOOKS:-}" = "1" ]; then
  echo "[openbackbone] OPENBACKBONE_SKIP_HOOKS=1, skipping discipline checks."
  exit 0
fi

fail=0
adr_pattern='^docs/adr/[0-9]{4}-[^/]+\.md$'
adr_soft_limit=40

# --- Check 1: accepted ADRs are immutable ---
# An ADR is accepted once it is on the default branch. One that exists only on
# the current branch is still a draft under review and can be revised.
adr_base=HEAD
for ref in origin/HEAD main master; do
  if git rev-parse --verify -q "${ref}^{commit}" >/dev/null 2>&1; then
    adr_base="$ref"
    break
  fi
done
adr_accepted() { git cat-file -e "${adr_base}:$1" 2>/dev/null; }

adr_violations=""
adr_added=""
while IFS=$'\t' read -r status p1 p2; do
  [ -z "${status:-}" ] && continue
  printf '%s' "$p1" | grep -Eq "$adr_pattern" || continue
  case "$status" in
    A*) adr_added="${adr_added}${p1}"$'\n' ;;
    R*) if adr_accepted "$p1"; then
          adr_violations="${adr_violations}  ${status}  ${p1} -> ${p2}"$'\n'
        else
          adr_added="${adr_added}${p2}"$'\n'
        fi ;;
    M*) if adr_accepted "$p1"; then
          adr_violations="${adr_violations}  ${status}  ${p1}"$'\n'
        else
          adr_added="${adr_added}${p1}"$'\n'
        fi ;;
    D*) if adr_accepted "$p1"; then
          adr_violations="${adr_violations}  ${status}  ${p1}"$'\n'
        fi ;;
  esac
done < <(git diff --cached --name-status -- docs/adr/ 2>/dev/null)

if [ -n "$adr_violations" ]; then
  echo "[openbackbone] Commit rejected: accepted ADRs must not be modified, deleted, or renamed."
  printf '%s' "$adr_violations"
  echo "[openbackbone] Instead: add a new docs/adr/NNNN-*.md whose 'Supersedes:' field names the old one."
  fail=1
fi

# --- Check 2: an ADR is a decision, not a spec ---
while IFS= read -r adr; do
  [ -n "$adr" ] || continue
  body="$(git show ":$adr" 2>/dev/null)" || continue
  if printf '%s\n' "$body" | grep -Eq '^#{2,4} +(Requirement|Scenario)'; then
    echo "[openbackbone] Commit rejected: ${adr} contains Requirement/Scenario sections."
    echo "[openbackbone] Behavior belongs in openspec/specs/. An ADR states one choice and why."
    fail=1
  fi
  lines="$(printf '%s\n' "$body" | wc -l | tr -d ' ')"
  if [ "$lines" -gt "$adr_soft_limit" ]; then
    echo "[openbackbone] Warning: ${adr} is ${lines} lines. An ADR is usually a paragraph; check it has not become a design document."
  fi
done <<< "$adr_added"

# --- Check 3: impact.md accounts for every living document ---
while IFS= read -r impact; do
  [ -n "$impact" ] || continue
  missing="$(git show ":$impact" 2>/dev/null | awk '
    BEGIN { n = split("Decisions Glossary Architecture Roadmap README", want, " ") }
    /^## / { section = $2; next }
    /^[-*]?[ \t]*(Updated|Planned|Not affected):[ \t]*[^ \t]/ { if (section != "") seen[section] = 1 }
    END { for (i = 1; i <= n; i++) if (!seen[want[i]]) printf "%s ", want[i] }
  ')"
  if [ -n "$missing" ]; then
    echo "[openbackbone] Commit rejected: ${impact} has no entry for: ${missing}"
    echo "[openbackbone] Each section needs 'Updated: ...', 'Planned: ...', or 'Not affected: <reason>'."
    fail=1
  fi
done < <(git diff --cached --name-only --diff-filter=AM -- openspec/changes/ 2>/dev/null \
           | grep -E '^openspec/changes/[^/]+/impact\.md$' | grep -v '^openspec/changes/archive/')

# --- Check 4: OpenSpec artifact validation ---
if [ -d openspec ]; then
  if command -v openspec >/dev/null 2>&1; then
    if ! out="$(openspec validate --specs --strict --no-interactive 2>&1)"; then
      printf '%s\n' "$out"
      echo "[openbackbone] Commit rejected: a spec in openspec/specs/ is invalid."
      fail=1
    fi
    # A change may be committed artifact by artifact; it is validated from the
    # moment it has delta specs.
    for change_dir in openspec/changes/*/; do
      change="$(basename "$change_dir")"
      [ "$change" != archive ] || continue
      [ -d "$change_dir/specs" ] || continue
      find "$change_dir/specs" -name '*.md' -print -quit | grep -q . || continue
      if ! out="$(openspec validate "$change" --type change --strict --no-interactive 2>&1)"; then
        printf '%s\n' "$out"
        echo "[openbackbone] Commit rejected: change '${change}' is invalid."
        fail=1
      fi
    done
    # Archiving with open tasks leaves a living document stale.
    if ! out="$(openspec validate --archived --no-interactive 2>&1)"; then
      printf '%s\n' "$out"
      echo "[openbackbone] Commit rejected: an archived change still has open tasks."
      fail=1
    fi
  else
    echo "[openbackbone] Note: openspec CLI not found, skipping spec validation (npm install -g @fission-ai/openspec@latest)."
  fi
fi

exit "$fail"
