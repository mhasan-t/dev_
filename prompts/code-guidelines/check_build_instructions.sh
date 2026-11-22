#!/usr/bin/env bash
#
# Smoke check for build_instructions.sh: builds AGENTS.md in a temporary
# folder, verifies its content, and checks input validation and the
# overwrite prompt.
#
# Usage: bash check_build_instructions.sh

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Answers to the interactive questions: name, technologies, frameworks,
# architectures, deployment, runtime, database, package manager, project rules
# (a blank line, or end of input, finishes the rules).
ANSWERS="$(printf '%s\n' 'Demo <App>' 'python,' 'fastapi' 'onion, modular' 'docker-compose' 'python 3.12' 'postgresql' 'uv' 'Use A & B, always.')"

OUT="$(mktemp -d -p "$WORK")"
(cd "$OUT" && bash "$DIR/build_instructions.sh" <<< "$ANSWERS" > /dev/null)
[[ "$(ls -A "$OUT")" == AGENTS.md ]]
F="$OUT/AGENTS.md"
grep -q 'Read the instructions below' "$F"
grep -qx '<ai_coding_guidelines>' "$F"
grep -q 'Use A &amp; B, always.' "$F"
grep -q '<architecture name="modular">' "$F"
grep -q '<deployment name="docker-compose">' "$F"
grep -qi 'project.context' "$F" && exit 1

# Options are no longer accepted.
bash "$DIR/build_instructions.sh" --inline < /dev/null > /dev/null 2>&1 && exit 1

cd "$WORK"

# Unknown or path-like rule names are rejected.
printf '%s\n' x 'python, nope' | bash "$DIR/build_instructions.sh" > /dev/null 2>&1 && exit 1
printf '%s\n' x '../master' | bash "$DIR/build_instructions.sh" > /dev/null 2>&1 && exit 1

# Existing files: "n" keeps them, "y" overwrites them.
echo keep > AGENTS.md
printf '%s\n\nn\n' "$ANSWERS" | bash "$DIR/build_instructions.sh" > /dev/null 2>&1 && exit 1
[[ "$(cat AGENTS.md)" == keep ]]
printf '%s\n\ny\n' "$ANSWERS" | bash "$DIR/build_instructions.sh" > /dev/null 2>&1
grep -q 'Repository Instructions' AGENTS.md

echo "ok"
