#!/usr/bin/env bash
#
# Smoke check for build_instructions.sh: builds every output/file/inline
# combination in a temporary folder, verifies the expected files and formats,
# and checks input validation and the overwrite prompt.
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

# Run one build in a fresh folder and print that folder.
build() {
    local out
    out="$(mktemp -d -p "$WORK")"
    (cd "$out" && bash "$DIR/build_instructions.sh" "$@" <<< "$ANSWERS" > /dev/null)
    echo "$out"
}

for FORMAT in xml md; do
    for EXT in xml md; do
        OUT="$(build --output "$FORMAT" --file "$EXT")"
        F="$OUT/.ai/instructions.$EXT"
        grep -q "\`.ai/instructions.$EXT\`" "$OUT/AGENTS.md"
        grep -q 'Use A &amp; B, always.\|Use A & B, always.' "$F"
        grep -qi 'project.context' "$F"
        if [[ "$FORMAT" == xml && "$EXT" == md ]]; then
            grep -qx '<ai_coding_guidelines>' "$F"
        elif [[ "$FORMAT" == xml ]]; then
            python3 -I -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$F"
            grep -q '<architecture name="modular">' "$F"
            grep -q '<deployment name="docker-compose">' "$F"
        else
            grep -q '^## Universal rules$' "$F"
        fi
    done

    OUT="$(build --output "$FORMAT" --inline)"
    [[ ! -e "$OUT/.ai" ]]
    grep -q 'Read the instructions below' "$OUT/AGENTS.md"
    grep -qi 'project.context' "$OUT/AGENTS.md" && exit 1
    [[ "$FORMAT" == md ]] || grep -qx '<ai_coding_guidelines>' "$OUT/AGENTS.md"
done

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
