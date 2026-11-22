# Code Guidelines

Builds agent instructions (`AGENTS.md`) for a project by merging the universal rules with the technology, framework and architecture rules the project enables.

## Files

| Path | Purpose |
| --- | --- |
| `master.xml` | Universal rules, always included. |
| `technologies/`, `frameworks/`, `architectures/`, `deployment/` | Optional rule sets, included when chosen during the build. |
| `ex_xml_AGENTS.md` | Preamble used for the generated `AGENTS.md`. |
| `build_instructions.sh` | Builds the output. |
| `check_build_instructions.sh` | Smoke check for the build. |

## Build

```sh
build_instructions.sh
```

It takes no options.

Run it from your project root. It asks for the project configuration:

| Question | Answer |
| --- | --- |
| Project name | Free text. |
| Technologies, Frameworks, Architectures, Deployment | Comma-separated rule set names, e.g. `onion, modular`. The available names are shown; an unknown name is asked again. |
| Runtime, Database, Package manager | Free text. |
| Project-specific rule | One rule per line; an empty line finishes. Rules may contain commas. |

Every answer may be left empty. The answers are written into the instructions as the project configuration, followed by the chosen rule sets.

It then writes `AGENTS.md` to the current folder: the preamble from `ex_xml_AGENTS.md` followed by the merged XML rules. The XML is unindented and has its CDATA markers removed so it renders as text; only the Makefile and directory trees render as code.

If `AGENTS.md` exists, it asks first: `This will overwrite existing AGENTS.md, continue? y/n`. Anything other than `y` aborts.

Requires `bash` only.

## Shell alias (optional)

Run it from any project folder. It pulls the latest guidelines first:

```sh
alias build_instructions='git -C ~/code/dev_ pull && ~/code/dev_/prompts/code-guidelines/build_instructions.sh'
```

```sh
build_instructions   # asks the questions, writes AGENTS.md here
```

## Adding a rule set

Add `<name>.xml` to `technologies/`, `frameworks/`, `architectures/` or `deployment/`, and it appears in the build's list of choices. Run `bash check_build_instructions.sh` to verify the build still works.
