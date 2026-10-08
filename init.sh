#!/usr/bin/env bash
# openbackbone one-command installer
#
# Installs the openbackbone workflow into the current project: OpenSpec with the
# spec-driven-with-impact schema, the living-document skeleton (ROADMAP.md,
# GLOSSARY.md, docs/architecture.md, docs/adr/), skills, and a pre-commit hook.
# Merge-based and idempotent: existing user content is never overwritten;
# rerunning upgrades managed content.
#
# Usage:
#   ./init.sh [--with openspec,docs,skills,hooks] [--tools agents,claude] [--language English]
#   curl -fsSL https://raw.githubusercontent.com/lixianweillm/openbackbone/main/init.sh | bash
#
# Environment variables:
#   OPENBACKBONE_REPO   Template repository URL (default https://github.com/lixianweillm/openbackbone)
set -euo pipefail

NAME="openbackbone"
MARKER_BEGIN="<!-- ${NAME}:begin -->"
MARKER_END="<!-- ${NAME}:end -->"
DEFAULT_REPO="${OPENBACKBONE_REPO:-https://github.com/lixianweillm/${NAME}}"
ALL_COMPONENTS="openspec docs skills hooks"
DEFAULT_COMPONENTS="openspec docs skills hooks"
MANIFEST=".${NAME}.yaml"
DEFAULT_SCHEMA="spec-driven-with-impact"

COMPONENTS="$DEFAULT_COMPONENTS"
# agents = universal target (.agents/skills/ + AGENTS.md); claude = Claude Code
# (.claude/skills/ + CLAUDE.md). Any other OpenSpec tool id is passed through
# to `openspec init`.
TOOLS="agents,claude"
LANGUAGE="English"
SRC=""
SRC_TMP=""
SRC_VERSION="unknown"
INSTALLED=""
MANAGED_EXTRA=""
TARGET="$PWD"
HAD_EXISTING_CODE=0

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$NAME" "$*"; }
warn() { printf '\033[1;33m[%s]\033[0m %s\n' "$NAME" "$*" >&2; }
die()  { printf '\033[1;31m[%s]\033[0m %s\n' "$NAME" "$*" >&2; exit 1; }

usage() {
  sed -n '2,15p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
  exit 0
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --with)     COMPONENTS="$(printf '%s' "${2:?--with requires a value}" | tr ',' ' ')"; shift 2 ;;
      --tools)    TOOLS="${2:?--tools requires a value}"; shift 2 ;;
      --language) LANGUAGE="${2:?--language requires a value}"; shift 2 ;;
      -h|--help)  usage ;;
      *) die "Unknown argument: ${1} (see --help)" ;;
    esac
  done
  for c in $COMPONENTS; do
    case " $ALL_COMPONENTS " in
      *" $c "*) ;;
      *) die "Unknown component: ${c} (available: ${ALL_COMPONENTS// /, })" ;;
    esac
  done
}

has_component() { case " $COMPONENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
has_tool() { case ",$TOOLS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
mark_installed() { INSTALLED="$INSTALLED $1"; }

# Progressive installation: when a component is skipped, record the exact
# remediation command and print a summary at the end
SKIPPED=""
note_skip() { SKIPPED="${SKIPPED}  - $1"$'\n'"    Fix: $2"$'\n'; }

resolve_source() {
  local script_path script_dir link
  # Follow symlinks so the installer still finds its sources when linked onto PATH
  script_path="${BASH_SOURCE[0]:-$0}"
  while [ -L "$script_path" ]; do
    link="$(readlink "$script_path")"
    case "$link" in
      /*) script_path="$link" ;;
      *)  script_path="$(dirname "$script_path")/$link" ;;
    esac
  done
  script_dir="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd || true)"
  if [ -n "$script_dir" ] && [ -f "$script_dir/openspec/schemas/$DEFAULT_SCHEMA/schema.yaml" ]; then
    SRC="$script_dir"
    SRC_VERSION="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null \
      || sed -n 's/^  "version": "\(.*\)",$/\1/p' "$SRC/package.json" 2>/dev/null | grep . \
      || echo local)"
    log "Install source: local template repository ${SRC} (version ${SRC_VERSION})"
  else
    SRC_TMP="$(mktemp -d)"
    log "Install source: cloning $DEFAULT_REPO ..."
    git clone --quiet --depth 1 "$DEFAULT_REPO" "$SRC_TMP/$NAME" \
      || die "Cannot clone template repository ${DEFAULT_REPO} (override with OPENBACKBONE_REPO)"
    SRC="$SRC_TMP/$NAME"
    SRC_VERSION="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi
  [ -f "$SRC/AGENTS.md" ] || die "Install source is missing template content: $SRC"
}

cleanup() { if [ -n "$SRC_TMP" ]; then rm -rf "$SRC_TMP"; fi; }
trap cleanup EXIT

detect_existing_code() {
  if find "$TARGET" -mindepth 1 -maxdepth 2 \
      -not -path "$TARGET/.git" -not -path "$TARGET/.git/*" \
      -type f -print -quit 2>/dev/null | grep -q .; then
    HAD_EXISTING_CODE=1
  fi
}

# Managed directories are replaced wholesale (rerun = upgrade); when source and
# target paths coincide (template repo self-install), leave them alone
sync_dir() {
  local from="$1" to="$2"
  [ "$from" = "$to" ] && return 0
  mkdir -p "$(dirname "$to")"
  rm -rf "$to"
  cp -R "$from" "$to"
}

# User-owned living documents: seeded once, never overwritten
seed_file() {
  local from="$1" to="$2"
  [ -e "$to" ] && return 0
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
  log "Created ${to#"$TARGET"/}"
}

# Insert or refresh the managed marker block in an instruction file. Content
# outside the block belongs to the user and is left untouched.
merge_block() {
  local block_src="$1" target_md="$2" label tmp b e
  label="${target_md#"$TARGET"/}"
  if [ ! -f "$target_md" ]; then
    { echo "$MARKER_BEGIN"; cat "$block_src"; echo "$MARKER_END"; } > "$target_md"
    log "Created ${label} (managed marker block)"
    return
  fi
  b="$(grep -cF "$MARKER_BEGIN" "$target_md" || true)"
  e="$(grep -cF "$MARKER_END" "$target_md" || true)"
  tmp="$(mktemp)"
  if [ "$b" = "0" ] && [ "$e" = "0" ]; then
    { cat "$target_md"; echo; echo "$MARKER_BEGIN"; cat "$block_src"; echo "$MARKER_END"; } > "$tmp"
    mv "$tmp" "$target_md"
    log "Appended managed marker block to existing ${label} (original content untouched)"
  elif [ "$b" = "1" ] && [ "$e" = "1" ]; then
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v src="$block_src" '
      $0 == begin { if (seen || skip) exit 1; seen=1; print begin; while ((getline line < src) > 0) print line; close(src); skip=1; next }
      $0 == end   { if (!skip) exit 1; skip=0; closed=1; print end; next }
      !skip { print }
      END { if (!seen || !closed || skip) exit 1 }
    ' "$target_md" > "$tmp" || { rm -f "$tmp"; die "Invalid managed ${label} marker order"; }
    mv "$tmp" "$target_md"
    log "Updated the managed marker block in ${label} (content outside the block untouched)"
  else
    rm -f "$tmp"
    die "Unpaired ${NAME} markers in ${label} (begin=${b}, end=${e}); repair manually and rerun"
  fi
}

# Fail on malformed markers before anything is written
check_markers() {
  local f b e
  for f in "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md"; do
    [ -f "$f" ] || continue
    b="$(grep -cF "$MARKER_BEGIN" "$f" || true)"
    e="$(grep -cF "$MARKER_END" "$f" || true)"
    { [ "$b" = "$e" ] && [ "$b" -le 1 ]; } \
      || die "Unpaired ${NAME} markers in ${f#"$TARGET"/} (begin=${b}, end=${e}); repair manually and rerun"
  done
}

merge_instructions() {
  if [ "$SRC" = "$TARGET" ]; then
    log "Instruction merge skipped: target is the template repository itself"
    return
  fi
  merge_block "$SRC/AGENTS.md" "$TARGET/AGENTS.md"
  MANAGED_EXTRA="  - AGENTS.md  # marker block only"
  if has_tool claude; then
    # Claude Code reads CLAUDE.md, not AGENTS.md: import one from the other
    local import
    import="$(mktemp)"
    echo '@AGENTS.md' > "$import"
    merge_block "$import" "$TARGET/CLAUDE.md"
    rm -f "$import"
    MANAGED_EXTRA="${MANAGED_EXTRA}"$'\n'"  - CLAUDE.md  # marker block only"
  fi
}

install_openspec() {
  if ! command -v openspec >/dev/null 2>&1; then
    local fix="npm install -g @fission-ai/openspec@latest"
    if ! command -v npm >/dev/null 2>&1; then
      fix="install Node.js first, then ${fix}"
    fi
    warn "Component openspec skipped: openspec CLI not found"
    note_skip "openspec (workspace + schemas + workflow skills)" "${fix}; then rerun this script"
    return
  fi
  # openspec init is idempotent and refreshes its generated workflow skills.
  # Always run it: a previous attempt may have created openspec/ before failing
  # to finish the skills, and directory existence alone is not proof of a
  # complete installation.
  # OpenSpec accepts --language only when creating a new config. Existing
  # projects keep their context (including language) during an upgrade.
  local init_args=(--tools "$TOOLS" --no-animation)
  if [ ! -f "$TARGET/openspec/config.yaml" ]; then
    init_args+=(--language "$LANGUAGE")
  fi
  (cd "$TARGET" && openspec init "${init_args[@]}" >/dev/null) \
    || { warn "openspec init failed; component openspec skipped"
         note_skip "openspec (init failed)" "investigate, then rerun: cd ${TARGET} && openspec init --tools ${TOOLS}"
         return; }
  sync_dir "$SRC/openspec/schemas/$DEFAULT_SCHEMA" "$TARGET/openspec/schemas/$DEFAULT_SCHEMA"
  sync_dir "$SRC/openspec/schemas/minimalist" "$TARGET/openspec/schemas/minimalist"
  # Set the default schema (preserve the rest of the config)
  local cfg="$TARGET/openspec/config.yaml" tmp
  tmp="$(mktemp)"
  if [ -f "$cfg" ] && grep -q '^schema:' "$cfg"; then
    sed "s/^schema:.*/schema: $DEFAULT_SCHEMA/" "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  else
    { echo "schema: $DEFAULT_SCHEMA"; [ -f "$cfg" ] && cat "$cfg"; } > "$tmp" && mv "$tmp" "$cfg"
  fi
  mark_installed openspec
  log "Component openspec: workspace + both schemas installed (default ${DEFAULT_SCHEMA}; minimalist for spikes)"
}

install_docs() {
  mkdir -p "$TARGET/docs/adr"
  [ "$SRC" = "$TARGET" ] || cp "$SRC/docs/adr/README.md" "$TARGET/docs/adr/README.md"
  if [ "$SRC" != "$TARGET" ]; then
    seed_file "$SRC/templates/ROADMAP.md" "$TARGET/ROADMAP.md"
    seed_file "$SRC/templates/GLOSSARY.md" "$TARGET/GLOSSARY.md"
    seed_file "$SRC/templates/architecture.md" "$TARGET/docs/architecture.md"
  fi
  mark_installed docs
  log "Component docs: living-document skeleton ready (existing files kept; the template's own ADRs are not copied)"
}

SKILL_NAMES=""
SKILL_DIRS=""

install_skills() {
  local f s d names=""
  # Every agent that follows the AGENTS.md convention reads .agents/skills/
  SKILL_DIRS=".agents/skills"
  if has_tool claude; then SKILL_DIRS="$SKILL_DIRS .claude/skills"; fi
  for f in "$SRC"/openspec/schemas/*/skills.txt "$SRC/skills.txt"; do
    [ -f "$f" ] || continue
    while IFS= read -r s || [ -n "$s" ]; do
      s="${s%%#*}"
      s="$(printf '%s' "$s" | tr -d '[:space:]')"
      [ -n "$s" ] || continue
      case " $names " in *" $s "*) continue ;; esac
      [ -d "$SRC/skills/$s" ] || { warn "Declared skill missing from the template repository: $s"; continue; }
      for d in $SKILL_DIRS; do
        sync_dir "$SRC/skills/$s" "$TARGET/$d/$s"
      done
      names="$names $s"
    done < "$f"
  done
  [ -n "$names" ] || { warn "Component skills skipped: no skills declared in any manifest"; return; }
  SKILL_NAMES="$names"
  mark_installed skills
  log "Component skills: installed${names} into ${SKILL_DIRS// /, }"
}

install_hooks() {
  if ! git -C "$TARGET" rev-parse --show-toplevel >/dev/null 2>&1; then
    warn "Component hooks skipped: current directory is not a git repository"
    note_skip "hooks (pre-commit discipline hook)" "run git init, then rerun this script"
    return
  fi
  local project_root
  project_root="$(git -C "$TARGET" rev-parse --show-toplevel)"
  if [ "$(cd "$project_root" && pwd -P)" != "$(cd "$TARGET" && pwd -P)" ]; then
    warn "Component hooks skipped: run the installer from the Git project root"
    note_skip "hooks (target is a project subdirectory)" "rerun the installer from ${project_root}"
    return
  fi
  # A core.hooksPath outside this repository (typically set globally) is shared
  # by every repository on the machine. Never write there.
  local hook_dir hook common_dir
  hook_dir="$(git -C "$TARGET" rev-parse --path-format=absolute --git-path hooks)"
  common_dir="$(git -C "$TARGET" rev-parse --path-format=absolute --git-common-dir)"
  case "$hook_dir/" in
    "$common_dir"/*|"$project_root"/*) ;;
    *)
      warn "Component hooks skipped: core.hooksPath points outside this repository (${hook_dir})"
      note_skip "hooks (shared hook directory ${hook_dir})" \
        "to use repository-local hooks here: git config --local core.hooksPath .git/hooks (this bypasses the shared hooks for this repository), then rerun this script"
      return ;;
  esac

  # Hook logic is versioned with the project so collaborators get upgrades by
  # pulling; the shim is generated by this script
  mkdir -p "$TARGET/scripts"
  [ "$SRC" = "$TARGET" ] || cp "$SRC/scripts/pre-commit.sh" "$TARGET/scripts/pre-commit.sh"
  chmod +x "$TARGET/scripts/pre-commit.sh"

  mkdir -p "$hook_dir"
  hook="$hook_dir/pre-commit"
  if [ -f "$hook" ] && ! grep -qF "$NAME hook shim" "$hook"; then
    local backup
    backup="$hook.backup.$(date +%Y%m%d%H%M%S)"
    mv "$hook" "$backup"
    chmod +x "$backup" 2>/dev/null || true
    log "Existing pre-commit hook backed up as $(basename "$backup"); it will be chain-called"
  fi
  cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# openbackbone hook shim (managed file, do not edit; logic lives in scripts/pre-commit.sh)
set -uo pipefail
repo_root="$(git rev-parse --show-toplevel)"
hook_dir="$(git rev-parse --path-format=absolute --git-path hooks)"
for prev in "$hook_dir"/pre-commit.backup.*; do
  if [ -x "$prev" ] && ! grep -qF 'openbackbone hook shim' "$prev"; then
    "$prev" "$@" || exit $?
  fi
done
if [ -x "$repo_root/scripts/pre-commit.sh" ]; then
  exec "$repo_root/scripts/pre-commit.sh" "$@"
fi
HOOK
  chmod +x "$hook"
  mark_installed hooks
  log "Component hooks: pre-commit hook ready (spec validation, ADR immutability, impact review)"
}

write_manifest() {
  local c s d
  {
    echo "# $NAME install manifest (managed file, maintained by init.sh)"
    echo "template: $NAME"
    echo "source: $DEFAULT_REPO"
    echo "version: $SRC_VERSION"
    echo "installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "tools: $TOOLS"
    echo "components:"
    for c in $INSTALLED; do echo "  - $c"; done
    echo "managed_paths:"
    [ -z "$MANAGED_EXTRA" ] || echo "$MANAGED_EXTRA"
    for c in $INSTALLED; do
      case "$c" in
        openspec) echo "  - openspec/schemas/" ;;
        docs)     echo "  - docs/adr/README.md" ;;
        skills)   for d in $SKILL_DIRS; do for s in $SKILL_NAMES; do echo "  - $d/$s/"; done; done ;;
        hooks)    echo "  - scripts/pre-commit.sh"; echo "  - $(git -C "$TARGET" rev-parse --git-path hooks)/pre-commit" ;;
      esac
    done
  } > "$TARGET/$MANIFEST"
  log "Manifest written to ${MANIFEST} (rerun this script to upgrade managed content)"
}

print_guidance() {
  if [ -n "$SKIPPED" ]; then
    echo
    log "The following components were skipped this run (the script is idempotent: fix the environment and rerun to fill the gap; installed content is unaffected):"
    printf '%s' "$SKIPPED"
  fi
  echo
  log "Installation complete. Next steps:"
  echo "  1. Restart your agent session so the instructions and skills take effect"
  echo "  2. Put what you intend to build in ROADMAP.md"
  echo "  3. Describe a change to the agent; large ones run proposal → specs → design → impact → tasks"
  echo "  Note: git hooks are local to each machine; rerun init.sh after cloning to restore them"
  if [ "$HAD_EXISTING_CODE" = "1" ]; then
    echo
    log "Existing code detected. Suggested cold start (send this to your agent verbatim):"
    echo "  \"Onboard this codebase from the code as it is today: 1) settle its core domain terms"
    echo "   into GLOSSARY.md; 2) write the current capabilities as specs in"
    echo "   openspec/specs/<capability>/spec.md; 3) describe the current structure in"
    echo "   docs/architecture.md; 4) record only the established decisions that are hard to"
    echo "   reverse and would surprise a newcomer as ADRs in docs/adr/, one paragraph each.\""
  fi
}

main() {
  parse_args "$@"
  command -v git >/dev/null 2>&1 \
    || die "Missing required dependency: git (install it, then rerun this script)"
  detect_existing_code
  resolve_source
  log "Target project: $TARGET"
  log "Components: $COMPONENTS"
  log "Tools: $TOOLS"

  check_markers
  merge_instructions
  if has_component openspec; then install_openspec; fi
  if has_component docs;     then install_docs; fi
  if has_component skills;   then install_skills; fi
  if has_component hooks;    then install_hooks; fi

  [ -n "$INSTALLED" ] || die "No component was installed successfully"
  write_manifest
  print_guidance
}

main "$@"
