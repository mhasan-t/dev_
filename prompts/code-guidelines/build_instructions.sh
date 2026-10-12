#!/usr/bin/env bash
#
# build_instructions.sh
#
# Build project-specific agent instructions by merging:
#   1. master.xml (universal rules),
#   2. every technology / framework / architecture guideline file
#      enabled in the given project's project.xml, and
#   3. the complete project.xml contents.
#
# The result is written to the current folder, either
# inlined into AGENTS.md or as .ai/instructions.<file> linked from AGENTS.md.
# The AGENTS.md preamble comes from ex_xml_AGENTS.md. Asks before overwriting existing files.
#
# Usage:
#   ./build_instructions.sh [--output xml|md] [--file EXT] [--inline] [path/to/project.xml]
#
#   --output  Content format of the instructions. Default: xml
#   --file    Extension of .ai/instructions.<EXT>. Default: xml. Ignored with --inline.
#   --inline  Write the instructions directly into AGENTS.md instead of .ai/.
#   project.xml defaults to ./project.xml
#
# Examples:
#   # XML rules in .ai/instructions.xml, linked from AGENTS.md:
#   bash /path/to/code-guidelines/build_instructions.sh
#
#   # Markdown rules written into .ai/instructions.xml:
#   bash /path/to/code-guidelines/build_instructions.sh --output md --file xml
#
#   # Markdown rules inlined into AGENTS.md:
#   bash /path/to/code-guidelines/build_instructions.sh --output md --inline /path/to/project.xml

set -euo pipefail

GUIDELINES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_XML="$GUIDELINES_DIR/master.xml"
AGENTS_TEMPLATE="$GUIDELINES_DIR/ex_xml_AGENTS.md"

FORMAT="xml"
FILE_EXT="xml"
INLINE=false
PROJECT_XML="project.xml"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) FORMAT="${2:-}"; shift 2 ;;
        --file)   FILE_EXT="${2:-}"; shift 2 ;;
        --inline) INLINE=true; shift ;;
        -*)       echo "error: unknown option: $1" >&2; exit 1 ;;
        *)        PROJECT_XML="$1"; shift ;;
    esac
done

if [[ "$FORMAT" != "xml" && "$FORMAT" != "md" ]]; then
    echo "error: --output must be xml or md, got: $FORMAT" >&2
    exit 1
fi

if [[ ! "$FILE_EXT" =~ ^[A-Za-z0-9]+$ ]]; then
    echo "error: --file must be a plain extension such as xml or md, got: $FILE_EXT" >&2
    exit 1
fi

if [[ ! -f "$PROJECT_XML" ]]; then
    echo "error: project.xml not found at: $PROJECT_XML" >&2
    exit 1
fi

if [[ ! -f "$MASTER_XML" ]]; then
    echo "error: master.xml not found at: $MASTER_XML" >&2
    exit 1
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

append_project_xml() {
    {
        printf '\n    <!-- ============================================================\n'
        printf '         Project configuration: project.xml\n'
        printf '         ============================================================ -->\n\n'

        printf '    <project_configuration>\n'
        printf '        <project_xml><![CDATA[\n'
        cat "$PROJECT_XML"
        printf ']]></project_xml>\n'
        printf '    </project_configuration>\n'
        printf '\n'
    }
}

# Convert the merged XML document to Markdown: elements with children become
# headings, leaf elements become bullets, and preformatted text stays fenced.
xml_to_md() {
    python3 - "$1" <<'PY'
import sys, textwrap
import xml.etree.ElementTree as ET

def label(el):
    name = el.tag.replace("_", " ").capitalize()
    return " ".join([name, *el.attrib.values()])

def heading(el, depth):
    return f"\n{'#' * min(depth, 6)} {label(el)}\n"

def body(el):
    text = textwrap.dedent((el.text or "").strip("\n")).strip()
    if el.tag == "structure" and "```" not in text:
        text = f"```\n{text}\n```"
    return text

def render(el, depth, out):
    text = body(el)

    # project.xml is embedded as CDATA; render its parsed contents instead.
    if text.startswith("<?xml"):
        out.append(heading(el, depth))
        for child in ET.fromstring(text.encode()):
            render(child, depth + 1, out)
        return

    if len(el):
        out.append(heading(el, depth))
        if text:
            out.append(text + "\n")
        for child in el:
            render(child, depth + 1, out)
        return

    if not text:
        return

    # Multi-line non-rule leaves (purpose, structure, examples) read better as sections.
    if "\n" in text and el.tag != "rule":
        out.append(heading(el, depth) + f"\n{text}\n")
        return

    prefix = "- " if el.tag == "rule" else f"- **{label(el)}:** "
    out.append(prefix + textwrap.indent(text, "  ")[2:])

root = ET.parse(sys.argv[1]).getroot()
out = []
for child in root:
    render(child, 2, out)
print("\n".join(out).strip())
PY
}


TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Start with master.xml's opening/root content, excluding its final
# closing root tag.
sed '$d' "$MASTER_XML" > "$TMP"

# Add project.xml FIRST, immediately inside the root element.
append_project_xml >> "$TMP"

# Add enabled technology/framework/architecture guidelines.
for TAG in technology framework architecture; do
    FOLDER="$(folder_for_tag "$TAG")"

    while IFS= read -r NAME; do
        [[ -z "${NAME//[[:space:]]/}" ]] && continue

        append_rule_file "$GUIDELINES_DIR/$FOLDER/$NAME.xml" >> "$TMP"
    done < <(enabled_rules "$TAG")
done

# Close the root element opened by master.xml.
printf '%s\n' "$LAST_LINE" >> "$TMP"

if [[ "$FORMAT" == "md" ]]; then
    xml_to_md "$TMP" > "$TMP.md"
    mv "$TMP.md" "$TMP"
fi

INSTRUCTIONS=".ai/instructions.$FILE_EXT"
FILES=(AGENTS.md)
[[ "$INLINE" == true ]] || FILES+=("$INSTRUCTIONS")

# Ask before overwriting files that already exist in the current folder.
EXISTING=()
for F in "${FILES[@]}"; do
    [[ -e "$F" ]] && EXISTING+=("$F")
done
if [[ ${#EXISTING[@]} -gt 0 ]]; then
    ANSWER=""
    read -r -p "This will overwrite existing files [${EXISTING[*]}], continue? y/n " ANSWER || true
    if [[ "$ANSWER" != [yY] ]]; then
        echo "Aborted." >&2
        exit 1
    fi
fi

if [[ "$INLINE" == true ]]; then
    {
        sed 's/`\.ai\/instructions\.xml`/the instructions below/' "$AGENTS_TEMPLATE"
        printf '\n'
        cat "$TMP"
    } > AGENTS.md
else
    mkdir -p .ai
    cp "$TMP" "$INSTRUCTIONS"
    sed "s|\`\.ai/instructions\.xml\`|\`$INSTRUCTIONS\`|" "$AGENTS_TEMPLATE" > AGENTS.md
fi

echo "Created ${FILES[*]} in $PWD"
