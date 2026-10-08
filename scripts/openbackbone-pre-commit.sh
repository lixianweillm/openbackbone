#!/usr/bin/env bash
# openbackbone discipline hook (installed by init.sh and replaced on upgrade).
# It judges a commit on what the commit touches, never on what was already in
# the repository:
#   1. an ADR that is on the default branch is not modified, deleted, or renamed
#   2. a new or revised ADR records a decision, not a spec
#   3. a staged impact.md accounts for all five living documents
#   4. staged specs, and staged changes that have delta specs, validate
#   5. a change archived by this commit has no open task
# Called by the pre-commit shim. The checks are version-controlled with the
# repository, so an upgrade needs no hook reinstall.
set -uo pipefail

if [ "${OPENBACKBONE_SKIP_HOOKS:-}" = "1" ]; then
  echo "[openbackbone] OPENBACKBONE_SKIP_HOOKS=1, skipping discipline checks."
  exit 0
fi

fail=0
adr_pattern='^docs/adr/[0-9]{4}-[^/]+\.md$'
adr_soft_limit=40

# Staged paths as they are. Without core.quotePath=false Git prints a name
# that is not ASCII as quoted octal escapes, which match no pattern below.
staged() { git -c core.quotePath=false diff --cached "$@" 2>/dev/null; }

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
adr_drafts=""
while IFS=$'\t' read -r status p1 p2; do
  [ -n "${status:-}" ] || continue
  printf '%s' "$p1" | grep -Eq "$adr_pattern" || continue
  case "$status" in
    A*) adr_drafts="${adr_drafts}${p1}"$'\n' ;;
    R*) if adr_accepted "$p1"; then
          adr_violations="${adr_violations}  ${status}  ${p1} -> ${p2}"$'\n'
        else
          adr_drafts="${adr_drafts}${p2}"$'\n'
        fi ;;
    M*|T*) if adr_accepted "$p1"; then
          adr_violations="${adr_violations}  ${status}  ${p1}"$'\n'
        else
          adr_drafts="${adr_drafts}${p1}"$'\n'
        fi ;;
    D*) if adr_accepted "$p1"; then
          adr_violations="${adr_violations}  ${status}  ${p1}"$'\n'
        fi ;;
  esac
done < <(staged --name-status -- docs/adr/)

if [ -n "$adr_violations" ]; then
  echo "[openbackbone] Commit rejected: accepted ADRs must not be modified, deleted, or renamed."
  printf '%s' "$adr_violations"
  echo "[openbackbone] Instead: add a new docs/adr/NNNN-*.md whose 'Supersedes:' field names the old one."
  fail=1
fi

# --- Check 2: an ADR is a decision, not a spec ---
# Only the headings OpenSpec itself uses for requirements count as spec content.
while IFS= read -r adr; do
  [ -n "$adr" ] || continue
  body="$(git show ":$adr" 2>/dev/null)" || continue
  if printf '%s\n' "$body" | grep -Eq '^#{2,4} +(Requirement|Scenario):'; then
    echo "[openbackbone] Commit rejected: ${adr} contains Requirement/Scenario sections."
    echo "[openbackbone] Behavior belongs in openspec/specs/. An ADR states one choice and why."
    fail=1
  fi
  lines="$(printf '%s\n' "$body" | wc -l | tr -d ' ')"
  if [ "$lines" -gt "$adr_soft_limit" ]; then
    echo "[openbackbone] Warning: ${adr} is ${lines} lines. An ADR is usually a paragraph; check it has not become a design document."
  fi
done <<< "$adr_drafts"

# --- Check 3: impact.md accounts for every living document ---
# An entry is "Updated:", "Planned:", or "Not affected:" followed by text. It
# may be a list item, the marker may be bold, the colon may be full-width.
while IFS= read -r impact; do
  [ -n "$impact" ] || continue
  missing="$(git show ":$impact" 2>/dev/null | awk '
    BEGIN { n = split("Decisions Glossary Architecture Roadmap README", want, " ") }
    /^## / { section = $2; next }
    /^[ \t]*[-*+]?[ \t]*\**(Updated|Planned|Not affected)\**[ \t]*(:|：)[ \t*]*[^ \t*]/ { if (section != "") seen[section] = 1 }
    END { for (i = 1; i <= n; i++) if (!seen[want[i]]) printf "%s ", want[i] }
  ')"
  if [ -n "$missing" ]; then
    echo "[openbackbone] Commit rejected: ${impact} has no entry for: ${missing}"
    echo "[openbackbone] Each section needs 'Updated: ...', 'Planned: ...', or 'Not affected: <reason>', under its original heading."
    fail=1
  fi
done < <(staged --name-only --diff-filter=AM -- openspec/changes/ \
           | grep -E '^openspec/changes/[^/]+/impact\.md$')

# --- Check 4: the specs and changes this commit touches validate ---
touched="$(staged --name-only --diff-filter=ACMR -- openspec/specs/ openspec/changes/)"
touched_specs="$(printf '%s\n' "$touched" | sed -n 's|^openspec/specs/\([^/]*\)/.*|\1|p' | sort -u)"
touched_changes="$(printf '%s\n' "$touched" | sed -n 's|^openspec/changes/\([^/]*\)/.*|\1|p' | grep -vx archive | sort -u)"

if [ -n "${touched_specs}${touched_changes}" ]; then
  if command -v openspec >/dev/null 2>&1; then
    while IFS= read -r capability; do
      [ -n "$capability" ] || continue
      [ -f "openspec/specs/$capability/spec.md" ] || continue
      if ! out="$(openspec validate "$capability" --type spec --strict --no-interactive 2>&1)"; then
        printf '%s\n' "$out"
        echo "[openbackbone] Commit rejected: spec '${capability}' is invalid."
        fail=1
      fi
    done <<< "$touched_specs"
    # A change may be committed artifact by artifact; it is validated from the
    # moment it has delta specs.
    while IFS= read -r change; do
      [ -n "$change" ] || continue
      [ -d "openspec/changes/$change/specs" ] || continue
      find "openspec/changes/$change/specs" -name '*.md' -print -quit | grep -q . || continue
      if ! out="$(openspec validate "$change" --type change --strict --no-interactive 2>&1)"; then
        printf '%s\n' "$out"
        echo "[openbackbone] Commit rejected: change '${change}' is invalid."
        fail=1
      fi
    done <<< "$touched_changes"
  else
    echo "[openbackbone] Note: openspec CLI not found, skipping spec validation (npm install -g @fission-ai/openspec@latest)."
  fi
fi

# --- Check 5: a change archived by this commit is finished ---
# Archiving with open tasks is how a "Living documents" task gets skipped.
while IFS= read -r tasks; do
  [ -n "$tasks" ] || continue
  open_tasks="$(git show ":$tasks" 2>/dev/null | grep -cE '^[[:space:]]*[-*+][[:space:]]+\[ \]')"
  if [ "${open_tasks:-0}" -gt 0 ]; then
    echo "[openbackbone] Commit rejected: ${tasks} is archived with ${open_tasks} open task(s)."
    echo "[openbackbone] Finish them, or delete the ones that no longer apply, then archive."
    fail=1
  fi
done < <(staged --name-only --diff-filter=AMR -- openspec/changes/archive/ \
           | grep -E '^openspec/changes/archive/[^/]+/tasks\.md$')

exit "$fail"
