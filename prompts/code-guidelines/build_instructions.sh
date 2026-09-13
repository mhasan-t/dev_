#!/usr/bin/env bash
#
# build_instructions.sh
#
# Build a single project-specific guidelines file by merging:
#   1. master.xml (universal rules), and
#   2. every technology / framework / architecture guideline file
#      enabled in the given project's project.xml.
#
# The fragments are inserted before master.xml's closing root tag so
# the result is one coherent document.
#
# Usage:
#   ./build_instructions.sh [path/to/project.xml] [path/to/output.xml]
#
#   Both arguments are optional:
#     - project.xml defaults to ./project.xml
#     - output defaults to instructions.xml next to project.xml
#
# Examples:
#   # From inside a project directory:
#   bash /path/to/code-guidelines/build_instructions.sh
#
#   # Explicit paths:
#   bash /path/to/code-guidelines/build_instructions.sh \
#        /path/to/my-project/project.xml \
#        /path/to/my-project/instructions.xml

set -euo pipefail

GUIDELINES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_XML="$GUIDELINES_DIR/master.xml"

PROJECT_XML="${1:-project.xml}"
OUTPUT="${2:-}"

if [[ ! -f "$PROJECT_XML" ]]; then
    echo "error: project.xml not found at: $PROJECT_XML" >&2
    exit 1
fi

if [[ ! -f "$MASTER_XML" ]]; then
    echo "error: master.xml not found at: $MASTER_XML" >&2
    exit 1
fi

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$(cd "$(dirname "$PROJECT_XML")" && pwd)/instructions.xml"
fi

# master.xml must end with the closing root tag so fragments can be
# inserted before it.
LAST_LINE="$(tail -n 1 "$MASTER_XML")"
if [[ "$LAST_LINE" != *"</ai_coding_guidelines>"* ]]; then
    echo "error: $MASTER_XML does not end with </ai_coding_guidelines>" >&2
    exit 1
fi

# Print the names enabled for a rule category (technology, framework,
# architecture) inside <enabled_rules>, ignoring commented-out entries.
enabled_rules() {
    local tag="$1"
    sed -n '/<enabled_rules>/,/<\/enabled_rules>/p' "$PROJECT_XML" \
        | sed 's/<!--.*-->//g' \
        | sed -n "s/^.*<$tag>\([^<]*\)<\/$tag>.*$/\1/p"
}

folder_for_tag() {
    case "$1" in
        technology)   echo "technologies" ;;
        framework)    echo "frameworks" ;;
        architecture) echo "architectures" ;;
    esac
}

append_rule_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "error: guideline file not found for enabled rule: ${path#"$GUIDELINES_DIR"/}" >&2
        exit 1
    fi
    {
        printf '\n    <!-- ============================================================\n'
        printf '         %s\n' "${path#"$GUIDELINES_DIR"/}"
        printf '         ============================================================ -->\n\n'
        cat "$path"
        printf '\n'
    }
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Everything in master.xml except the final closing root tag.
sed '$d' "$MASTER_XML" > "$TMP"

for TAG in technology framework architecture; do
    FOLDER="$(folder_for_tag "$TAG")"
    while IFS= read -r NAME; do
        # Skip empty lines.
        [[ -z "${NAME//[[:space:]]/}" ]] && continue
        append_rule_file "$GUIDELINES_DIR/$FOLDER/$NAME.xml" >> "$TMP"
    done < <(enabled_rules "$TAG")
done

# Close the root element opened by master.xml.
printf '%s\n' "$LAST_LINE" >> "$TMP"

mv "$TMP" "$OUTPUT"
trap - EXIT

echo "Created $OUTPUT"
