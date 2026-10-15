#!/usr/bin/env bash
# repo-distill: the ANTI-ROT gate. Run in CI or as a pre-commit hook.
# Fails (exit 1) when:
#   (a) .distill/ source changed but adapters were not recompiled, OR
#   (b) the repo-distill block in AGENTS.md (or the Copilot copy) was hand-edited. Text OUTSIDE the block is
#       never checked: it belongs to humans and to other tools' blocks, OR
#   (c) [warn only] Tier-2 knowledge files are past their staleness_threshold.
# This is what lets a team STOP hand-maintaining markdown: drift fails the build.
#
# Usage: scripts/check-freshness.sh [repo_root]
#   exit 0 = fresh · exit 1 = stale/drifted (run: repo-distill render) · exit 2 = setup error
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || { echo "cannot cd $ROOT" >&2; exit 2; }
SRC=".distill"
MAN="$SRC/.manifest"
[ -f "$MAN" ] || { echo "✗ no $MAN : run scripts/render-adapters.sh first" >&2; exit 2; }
[ -d "$SRC/knowledge" ] || { echo "✗ no $SRC/knowledge" >&2; exit 2; }

# shellcheck disable=SC1090
get() { grep -E "^$1=" "$MAN" | head -1 | cut -d= -f2-; }
ORDER="architecture conventions workflows gotchas glossary review-culture"
list_files() {
  for n in $ORDER; do [ -f "$SRC/knowledge/$n.md" ] && echo "$SRC/knowledge/$n.md"; done
  for f in "$SRC"/knowledge/*.md; do
    case " $ORDER " in *" $(basename "$f" .md) "*) ;; *) [ -f "$f" ] && echo "$f";; esac
  done
}

FILES=$(list_files)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOW_SRC=$(printf '%s\n' "$SRC/SPINE.md" $FILES | xargs cat 2>/dev/null | shasum -a 256 | awk '{print $1}')
NOW_BLOCK=$(python3 "$HERE/agents_block.py" sha AGENTS.md repo-distill 2>/dev/null)
NOW_COPILOT=$(shasum -a 256 .github/copilot-instructions.md 2>/dev/null | awk '{print $1}')
WANT_SRC=$(get sources_sha)
WANT_BLOCK=$(get agents_block_sha)
WANT_COPILOT=$(get copilot_sha)

rc=0
if [ "$NOW_SRC" != "$WANT_SRC" ]; then
  echo "✗ DRIFT: .distill/ source changed since last render."
  echo "    expected sources_sha=$WANT_SRC"
  echo "    actual   sources_sha=$NOW_SRC"
  echo "    → run: repo-distill render  (scripts/render-adapters.sh)"
  rc=1
fi
if [ -z "$NOW_BLOCK" ]; then
  echo "✗ MISSING: AGENTS.md has no <!-- repo-distill:start --> block. Run the render script."
  rc=1
elif [ "$NOW_BLOCK" != "$WANT_BLOCK" ]; then
  echo "✗ DRIFT: the repo-distill block in AGENTS.md was hand-edited. Edit .distill/ and re-render;"
  echo "    write your own text OUTSIDE the block, where it is never checked."
  rc=1
fi
if [ -n "$WANT_COPILOT" ] && [ "$NOW_COPILOT" != "$WANT_COPILOT" ]; then
  echo "✗ DRIFT: .github/copilot-instructions.md was hand-edited. It is generated whole; re-render."
  rc=1
fi

# staleness (warn-only, never fails the build)
TODAY=$(date -u +%s)
stale=0
for f in $FILES; do
  lv=$(awk -F': *' '/^last_validated:/{print $2; exit}' "$f" 2>/dev/null)
  th=$(awk -F': *' '/^staleness_threshold:/{print $2; exit}' "$f" 2>/dev/null)
  [ -z "$lv" ] && continue
  th=${th:-90}
  # GNU date first, then BSD date (macOS); a date neither can parse is reported, never skipped silently
  if d=$(date -u -d "$lv" +%s 2>/dev/null) || d=$(date -u -j -f %Y-%m-%d "$lv" +%s 2>/dev/null); then
    age=$(( (TODAY - d) / 86400 ))
    if [ "$age" -gt "$th" ]; then
      echo "⚠ STALE: $f validated ${age}d ago (threshold ${th}d): re-validate against current code."
      stale=$((stale+1))
    fi
  else
    echo "⚠ UNPARSED: $f last_validated '$lv' is not YYYY-MM-DD."
  fi
done

if [ "$rc" -eq 0 ]; then
  echo "✓ repo-distill block and adapters in sync with .distill/ (sources_sha=$NOW_SRC)${stale:+; $stale stale file(s) flagged}"
fi
exit $rc
