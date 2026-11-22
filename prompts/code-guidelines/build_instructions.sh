#!/usr/bin/env bash
#
# build_instructions.sh
#
# Build project-specific agent instructions by merging:
#   1. master.xml (universal rules),
#   2. the project configuration, asked for interactively, and
#   3. every technology / framework / architecture guideline file enabled
#      in that configuration.
#
# The result is written to AGENTS.md in the current folder, after the
# preamble from ex_xml_AGENTS.md. Asks before overwriting an existing AGENTS.md.
#
# Usage:
#   bash /path/to/code-guidelines/build_instructions.sh

set -euo pipefail

GUIDELINES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_XML="$GUIDELINES_DIR/master.xml"
AGENTS_TEMPLATE="$GUIDELINES_DIR/ex_xml_AGENTS.md"

if [[ $# -gt 0 ]]; then
    echo "error: unexpected argument: $1 (no options are accepted)" >&2
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

# Read one answer from stdin, trimmed. Empty when input ends.
ask() {
    local answer=""
    read -r -p "$1: " answer || true
    read -r answer <<< "$answer" || true
    printf '%s' "$answer"
}

# Ask for comma-separated guideline names from a folder and print them one
# per line. Unknown names are asked again interactively and fail otherwise.
ask_rules() {
    local folder="$1" available names name ok
    available="$(cd "$GUIDELINES_DIR/$folder" && ls -- *.xml | sed 's/\.xml$//' | paste -sd, - | sed 's/,/, /g')"

    while true; do
        IFS=, read -ra names <<< "$(ask "${folder^} [$available]")"
        ok=true
        for name in "${names[@]}"; do
            read -r name <<< "$name" || true
            [[ -z "$name" ]] && continue
            if [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && -f "$GUIDELINES_DIR/$folder/$name.xml" ]]; then
                printf '%s\n' "$name"
            else
                echo "error: unknown $folder entry: $name" >&2
                ok=false
            fi
        done
        $ok && return
        [[ -t 0 ]] || exit 1
    done
}

xml_escape() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

append_rule_file() {
    local path="$1"

    {
        printf '\n    <!-- ============================================================\n'
        printf '         %s\n' "${path#"$GUIDELINES_DIR"/}"
        printf '         ============================================================ -->\n\n'
        cat "$path"
        printf '\n'
    }
}

# Print the project configuration from the answers collected below.
append_project_config() {
    local field rule
    printf '\n    <!-- ============================================================\n'
    printf '         Project configuration\n'
    printf '         ============================================================ -->\n\n'

    printf '    <project_configuration>\n'
    for field in name technologies frameworks architectures deployment runtime database package_manager; do
        if [[ -n "${PROJECT[$field]}" ]]; then
            printf '        <%s>%s</%s>\n' "$field" "$(xml_escape "${PROJECT[$field]}")" "$field"
        fi
    done
    if [[ ${#OVERRIDES[@]} -gt 0 ]]; then
        printf '        <project_overrides>\n'
        for rule in "${OVERRIDES[@]}"; do
            printf '            <rule>%s</rule>\n' "$(xml_escape "$rule")"
        done
        printf '        </project_overrides>\n'
    fi
    printf '    </project_configuration>\n'
}

# Collect the project configuration.
declare -A PROJECT ENABLED
OVERRIDES=()
PROJECT[name]="$(ask "Project name")"
for FOLDER in technologies frameworks architectures deployment; do
    ENABLED[$FOLDER]="$(ask_rules "$FOLDER")"
    PROJECT[$FOLDER]="$(paste -sd, - <<< "${ENABLED[$FOLDER]}" | sed 's/,/, /g')"
done
PROJECT[runtime]="$(ask "Runtime (e.g. node, python 3.12)")"
PROJECT[database]="$(ask "Database")"
PROJECT[package_manager]="$(ask "Package manager")"
while RULE="$(ask "Project-specific rule (empty to finish)")" && [[ -n "$RULE" ]]; do
    OVERRIDES+=("$RULE")
done

TMP="$(mktemp)"
trap 'rm -f "$TMP" "$TMP.md"' EXIT

# Start with master.xml's opening/root content, excluding its final
# closing root tag.
sed '$d' "$MASTER_XML" > "$TMP"

# AGENTS.md holds the instructions itself, so drop the pointer block.
sed -i '/<project_context>/,/<\/project_context>/d' "$TMP"

# Add the project configuration FIRST, immediately inside the root element.
append_project_config >> "$TMP"

# Add enabled technology/framework/architecture guidelines.
for FOLDER in technologies frameworks architectures deployment; do
    while IFS= read -r NAME; do
        if [[ -n "$NAME" ]]; then
            append_rule_file "$GUIDELINES_DIR/$FOLDER/$NAME.xml" >> "$TMP"
        fi
    done <<< "${ENABLED[$FOLDER]}"
done

# Close the root element opened by master.xml.
printf '%s\n' "$LAST_LINE" >> "$TMP"

# Make raw XML render as text in AGENTS.md:
# - indented lines would become code blocks, so remove indentation
#   (keeping relative indentation inside ``` blocks: Makefile tabs, trees);
# - CDATA markers hide their content when rendered, so drop them;
# - ``` blocks need surrounding blank lines to be recognised as code.
awk '
    /^[ \t]*```/ {
        if (!fence) { indent = match($0, /[^ \t]/) - 1; print "" }
        fence = !fence; sub(/^[ \t]+/, ""); print
        if (!fence) print ""
        next
    }
    fence { print substr($0, indent + 1); next }
          { sub(/^[ \t]+/, ""); gsub(/<!\[CDATA\[|\]\]>/, ""); if (NF || prev) print; prev = NF }
' "$TMP" > "$TMP.md"

if [[ -e AGENTS.md ]]; then
    ANSWER=""
    read -r -p "This will overwrite existing AGENTS.md, continue? y/n " ANSWER || true
    if [[ "$ANSWER" != [yY] ]]; then
        echo "Aborted." >&2
        exit 1
    fi
fi

{
    sed 's/`\.ai\/instructions\.xml`/the instructions below/' "$AGENTS_TEMPLATE"
    printf '\n'
    cat "$TMP.md"
} > AGENTS.md

echo "Created AGENTS.md in $PWD"
