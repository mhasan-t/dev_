# Code Guidelines

Builds agent instructions (`AGENTS.md`) for a project by merging the universal rules with the technology, framework and architecture rules the project enables.

## Files

| Path | Purpose |
| --- | --- |
| `master.xml` | Universal rules, always included. |
| `technologies/`, `frameworks/`, `architectures/`, `deployment/` | Optional rule sets, included when chosen during the build. |
| `ex_xml_AGENTS.md` | Preamble used for the generated `AGENTS.md`. |
| `build_instructions.sh` | Builds the output. |
| `check_build_instructions.sh` | Smoke check: builds every option combination. |

## Build

```sh
build_instructions.sh [--output xml|md] [--file EXT] [--inline]
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--output` | `xml` | Content format: `xml` or `md`. |
| `--file` | `xml` | Extension of `.ai/instructions.<EXT>`. Ignored with `--inline`. |
| `--inline` | off | Put the instructions directly in `AGENTS.md` instead of `.ai/`. |

`--output` and `--file` are independent: `--output md --file xml` writes Markdown content to `instructions.xml`. XML written to a `.md` file (`--inline`, or `--file md`) is unindented and has its CDATA markers removed, so it renders as text; only the Makefile and directory trees render as code.

Run it from your project root. It asks for the project configuration:

| Question | Answer |
| --- | --- |
| Project name | Free text. |
| Technologies, Frameworks, Architectures, Deployment | Comma-separated rule set names, e.g. `onion, modular`. The available names are shown; an unknown name is asked again. |
| Runtime, Database, Package manager | Free text. |
| Project-specific rule | One rule per line; an empty line finishes. Rules may contain commas. |

Every answer may be left empty. The answers are written into the instructions as the project configuration, followed by the chosen rule sets.

It then writes to the current folder:

```
AGENTS.md              # default: tells the agent to read .ai/instructions.xml
.ai/instructions.xml   # omitted with --inline, where AGENTS.md holds everything
```

If any of these files exist, it asks first: `This will overwrite existing files [AGENTS.md], continue? y/n`. Anything other than `y` aborts.

Examples:

```sh
build_instructions.sh                              # XML in .ai/instructions.xml
build_instructions.sh --output md --file md        # Markdown in .ai/instructions.md
build_instructions.sh --output md --inline         # Markdown inside AGENTS.md
```

Requires `bash` and `python3` (standard library only, used for `--output md`).

## Shell alias (optional)

Run it from any project folder. It pulls the latest guidelines first:

```sh
alias build_instructions='git -C ~/code/dev_ pull && ~/code/dev_/prompts/code-guidelines/build_instructions.sh'
```

```sh
build_instructions --output md   # asks the questions, writes AGENTS.md and .ai/ here
```

## Adding a rule set

Add `<name>.xml` to `technologies/`, `frameworks/`, `architectures/` or `deployment/`, and it appears in the build's list of choices. Run `bash check_build_instructions.sh` to verify the build still works.
