#!/usr/bin/env bash
# End-to-end check against the real OpenSpec CLI. The regression tests stub the
# CLI, so only this script notices when a schema or template stops matching
# what OpenSpec accepts. It installs into a fresh repository, takes a change
# through each schema, and commits through the pre-commit hook.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v openspec >/dev/null 2>&1 || { echo "FAIL: the OpenSpec CLI is required for this test" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 CI=true OPENSPEC_TELEMETRY=0
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openbackbone-e2e.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
OUT="$TEST_ROOT/output"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  [ ! -f "$OUT" ] || cat "$OUT" >&2
  exit 1
}

commit() {
  git add -A
  git commit -q -m "$1" > "$OUT" 2>&1
}

delta_spec() {
  mkdir -p "$1"
  cat > "$1/spec.md" <<'SPEC'
## Purpose

Let customers keep their own copy of their invoices.

## ADDED Requirements

### Requirement: Invoice export
The system SHALL let a customer download their invoices as one CSV file.

#### Scenario: Customer with invoices
- **WHEN** a customer with three invoices requests an export
- **THEN** the system returns a CSV file with three rows
SPEC
}

project="$TEST_ROOT/project"
mkdir -p "$project"
cd "$project"
git init -q
git config user.name Test
git config user.email test@example.com

"$REPO_ROOT/init.sh" > "$OUT" 2>&1 || fail "installation failed"
for component in openspec docs skills hooks; do
  grep -qx "  - $component" .openbackbone.yaml || fail "component $component was not installed"
done
openspec schema validate spec-driven-with-impact > "$OUT" 2>&1 || fail "default schema is invalid"
openspec schema validate minimalist > "$OUT" 2>&1 || fail "minimalist schema is invalid"
commit install || fail "the hook rejected a fresh installation"
printf 'ok: installation commits cleanly with the real CLI\n'

# --- default schema: five artifacts, impact review enforced by the hook ---
openspec new change add-export > "$OUT" 2>&1 || fail "could not create a change with the default schema"
openspec status --change add-export > "$OUT" 2>&1 || fail "status failed"
for artifact in proposal specs design impact tasks; do
  grep -q "$artifact" "$OUT" || fail "default schema is missing the $artifact artifact"
done
openspec instructions impact --change add-export > "$OUT" 2>&1 || fail "impact instructions do not render"
grep -q 'Not affected: <reason>' "$OUT" || fail "impact instructions lost their markers"

change=openspec/changes/add-export
printf '## Why\n\nCustomers ask for their invoices.\n' > "$change/proposal.md"
commit 'proposal only' || fail "a change with only a proposal could not be committed"
delta_spec "$change/specs/invoice-export"
openspec validate add-export --type change --strict --no-interactive > "$OUT" 2>&1 \
  || fail "a spec in the documented format does not validate"
printf '\n### Requirement: No scenario\nThe system SHALL do something nobody described.\n' >> "$change/specs/invoice-export/spec.md"
if commit 'a requirement without a scenario'; then fail "an invalid delta spec was committed"; fi
grep -q "change 'add-export' is invalid" "$OUT" || fail "invalid delta spec not explained"
git reset -q
delta_spec "$change/specs/invoice-export"
cp openspec/schemas/spec-driven-with-impact/templates/impact.md "$change/impact.md"
if commit 'empty impact review'; then fail "an unfilled impact review was committed"; fi
git reset -q
for section in 'Decisions (docs/adr/)' 'Glossary (GLOSSARY.md)' 'Architecture (docs/architecture.md)' \
               'Roadmap (ROADMAP.md)' 'README (README.md)'; do
  printf '## %s\n\n- Not affected: end-to-end fixture\n\n' "$section"
done > "$change/impact.md"
commit 'specs and impact review' || fail "a complete impact review was rejected"
printf 'ok: the default schema runs proposal to impact through the hook\n'

# --- minimalist schema: specs and tasks, archived into the main specs ---
openspec new change spike --schema minimalist > "$OUT" 2>&1 || fail "could not create a minimalist change"
delta_spec openspec/changes/spike/specs/spike-export
sed -i.bak 's/Invoice export/Spike export/' openspec/changes/spike/specs/spike-export/spec.md
rm openspec/changes/spike/specs/spike-export/spec.md.bak
openspec validate spike --type change --strict --no-interactive > "$OUT" 2>&1 \
  || fail "a minimalist spec in the documented format does not validate"
printf '## 1. Spike\n\n- [ ] 1.1 Try it\n' > openspec/changes/spike/tasks.md
commit 'spike' || fail "the hook rejected a minimalist change"

openspec archive spike -y > "$OUT" 2>&1 || fail "could not archive the minimalist change"
grep -q 'Requirement: Spike export' openspec/specs/spike-export/spec.md || fail "archive did not merge the delta spec"
if commit 'archive with an open task'; then fail "an archive with an open task was committed"; fi
git reset -q
archived="$(find openspec/changes/archive -maxdepth 1 -name '*-spike' -type d)"
sed -i.bak 's/- \[ \]/- [x]/' "$archived/tasks.md"
rm "$archived/tasks.md.bak"
commit 'archive' || fail "a finished archive was rejected"
printf 'ok: the minimalist schema validates, commits, and archives\n'

# --- an existing OpenSpec project: what was already there never blocks a commit ---
mkdir -p openspec/changes/archive/2020-01-01-legacy openspec/specs/legacy
printf '## 1. Legacy\n\n- [ ] 1.1 never finished\n' > openspec/changes/archive/2020-01-01-legacy/tasks.md
cat > openspec/specs/legacy/spec.md <<'SPEC'
# legacy Specification

## Purpose

TBD - created by archiving change legacy. Update Purpose after archive.

## Requirements

### Requirement: Legacy behavior
The system SHALL keep working.

#### Scenario: Still works
- **WHEN** nothing changes
- **THEN** nothing breaks
SPEC
if openspec validate legacy --type spec --strict --no-interactive > "$OUT" 2>&1; then
  fail "the legacy fixture is expected to fail strict validation"
fi
git add -A
OPENBACKBONE_SKIP_HOOKS=1 git commit -q -m 'state from before the installation' > "$OUT" 2>&1
printf 'int main(void) { return 0; }\n' > main.c
commit 'unrelated code' || fail "pre-existing specs or archives blocked an unrelated commit"
printf '\n' >> openspec/specs/legacy/spec.md
if commit 'touch the legacy spec'; then fail "a touched spec that fails validation was committed"; fi
git reset -q
git checkout -q -- openspec/specs
printf 'ok: specs and archives from before the installation do not block commits\n'

printf 'All end-to-end tests passed.\n'
