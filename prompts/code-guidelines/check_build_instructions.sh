#!/usr/bin/env bash
#
# Smoke check for build_instructions.sh: builds every output/file/inline
# combination and verifies the expected files and formats.
#
# Usage: bash check_build_instructions.sh

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run one build and print the created output directory.
build() {
    sleep 1 # output folders are per-second timestamps
    bash "$DIR/build_instructions.sh" "$@" "$DIR/project.xml" | sed 's/^Created //'
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
        rm -rf "$OUT"
    done

    OUT="$(build --output "$FORMAT" --inline)"
    [[ ! -e "$OUT/.ai" ]]
    grep -q 'Read the instructions below' "$OUT/AGENTS.md"
    rm -rf "$OUT"
done

echo "ok"
