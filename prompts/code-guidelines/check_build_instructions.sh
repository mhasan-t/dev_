#!/usr/bin/env bash
#
# Smoke check for build_instructions.sh: builds every output/file/inline
# combination in a temporary folder, verifies the expected files and formats,
# and checks the overwrite prompt.
#
# Usage: bash check_build_instructions.sh

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Run one build in a fresh folder and print that folder.
build() {
    local out
    out="$(mktemp -d -p "$WORK")"
    (cd "$out" && bash "$DIR/build_instructions.sh" "$@" "$DIR/project.xml" < /dev/null > /dev/null)
    echo "$out"
}

for FORMAT in xml md; do
    for EXT in xml md; do
        OUT="$(build --output "$FORMAT" --file "$EXT")"
        grep -q "\`.ai/instructions.$EXT\`" "$OUT/AGENTS.md"
        if [[ "$FORMAT" == xml ]]; then
            python3 -I -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$OUT/.ai/instructions.$EXT"
        else
            grep -q '^## Universal rules$' "$OUT/.ai/instructions.$EXT"
        fi
    done

    OUT="$(build --output "$FORMAT" --inline)"
    [[ ! -e "$OUT/.ai" ]]
    grep -q 'Read the instructions below' "$OUT/AGENTS.md"
done

# Existing files: "n" keeps them, "y" overwrites them.
cd "$WORK"
echo keep > AGENTS.md
echo n | bash "$DIR/build_instructions.sh" "$DIR/project.xml" > /dev/null 2>&1 && exit 1
[[ "$(cat AGENTS.md)" == keep ]]
echo y | bash "$DIR/build_instructions.sh" "$DIR/project.xml" > /dev/null 2>&1
grep -q 'Repository Instructions' AGENTS.md

echo "ok"
