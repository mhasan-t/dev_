# Code Guidelines

Builds agent instructions (`AGENTS.md`) for a project by merging the universal rules with the technology, framework and architecture rules the project enables.

## Files

| Path | Purpose |
| --- | --- |
| `master.xml` | Universal rules, always included. |
| `technologies/`, `frameworks/`, `architectures/` | Optional rule sets, included when enabled in `project.xml`. |
| `project.xml` | Template for a project's profile and enabled rules. |
| `ex_xml_AGENTS.md` | Preamble used for the generated `AGENTS.md`. |
| `build_instructions.sh` | Builds the output. |
| `check_build_instructions.sh` | Smoke check: builds every option combination. |

## 1. Configure the project

Copy `project.xml` into your project and edit it. List the rule sets to include by file name, without `.xml`:

```xml
<enabled_rules>
  <technology>typescript</technology>
  <framework>express</framework>
  <architecture>modular</architecture>
</enabled_rules>
```

Commented-out entries are ignored. Put project-specific rules in `<project_overrides>`.

## 2. Build

```sh
build_instructions.sh [--output xml|md] [--file EXT] [--inline] [project.xml]
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--output` | `xml` | Content format: `xml` or `md`. |
| `--file` | `xml` | Extension of `.ai/instructions.<EXT>`. Ignored with `--inline`. |
| `--inline` | off | Put the instructions directly in `AGENTS.md` instead of `.ai/`. |
| `project.xml` | `./project.xml` | Project profile to build from. |

`--output` and `--file` are independent: `--output md --file xml` writes Markdown content to `instructions.xml`. XML written to a `.md` file (`--inline`, or `--file md`) is wrapped in a ```` ```xml ```` code block so it renders as one block.

Run it from your project root. It writes to the current folder:

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
build_instructions.sh path/to/project.xml       # different project.xml
```

Requires `bash` and `python3` (standard library only, used for `--output md`).

## Shell aliases (optional)

Run these from any project folder. They pull the latest guidelines first:

```sh
alias get_project_xml='git -C ~/code/dev_ pull && cp ~/code/dev_/prompts/code-guidelines/project.xml ./project.xml'
alias build_instructions='git -C ~/code/dev_ pull && ~/code/dev_/prompts/code-guidelines/build_instructions.sh'
```

```sh
get_project_xml                  # copies project.xml here; edit it
build_instructions --output md   # writes AGENTS.md and .ai/ here
```

## Adding a rule set

Add `<name>.xml` to `technologies/`, `frameworks/` or `architectures/`, then enable it in `project.xml` with that name. Run `bash check_build_instructions.sh` to verify the build still works.
