# Godot Editor Console

Godot 4.6+

Editor Console adds a console to the Output panel, plus standalone
windows through the tool menu.

Provides editor/resource/script commands, undo integration,
configuration and startup scripts, script and live-node calls, OS mode, and the optional
MCP bridge.

## Commands

Execution engine is [gdsh](https://github.com/brohd11/godot-gdsh.git)

GDSh builtins and the console utilities are hidden root commands. Call them
directly or through their namespace; `hidden` lists the namespaces:

```text
echo hello
hidden utils echo hello
```

- [gdsh-lib-utils](https://github.com/brohd11/godot-gdsh-lib-utils.git)
- [gdsh-lib-tree](https://github.com/brohd11/godot-gdsh-lib-tree.git)

Editor-only utilities (`os`, `term`, `mcp`, etc) are hidden and accessible directly,
they are listed under `misc editor_console`.

Core targets work at runtime and in the editor:

```text
MyGlobalClass.Inner call answer
editor script.Inner call answer
script list_global --name=My*
script res://tools/example.gd list --methods
node /root/Main call --engine get_child_count
cn /root/Main
pwn
Child get_path
gdsh res://scripts/boot.gdsh first second
```

`script` requires an explicit or piped target; `editor script` selects the current
editor Script resource. Both support inner-class/preload chains, including
`editor script.Inner.Nested` and bare `res://file.gd.Inner` targets. `format text`
reads the live editor buffer; `editor script --text` reads the selected resource's source.

`config global registry --add MyClass` registers project-level suggestions after
`script`. Use `--rm` to remove names, no action flag to query their status, and
`--global` to edit user configuration. Existing `config.global_classes` entries are
reused and merged. Registration affects suggestions only: every valid class remains
callable, and `script --class=` still completes all classes. List global classes with
`script list_global`.

## Interactive plugin list

Run `editor plugin` in a docked or floating console to browse immediate `res://addons/*/plugin.cfg`
entries and their enabled status. Enter toggles the selected addon without closing
the list; held Enter does not repeat. Arrows, Page Up/Down, Home/End and wheel/pan
scrolling navigate, `R` rescans while preserving selection, and Escape exits.
Editor Console's own addon is shown as locked because it hosts the view.

The list uses `GDShTUI.ScreenCommand` and the reusable `GDShTUI.List` component, with no native scrollbar.
See [GDSh TUI components](../addon_lib/gdsh_lib/tui/README.md) for screen navigation and composition.
Custom TUIs override `update(message: GDSh.TUIMsg)` and `view() -> String`; see GDSh's
[TUI guide](../addon_lib/gdsh/_export_ignore/docs/tui.md) for a complete list example,
message types, viewport sizing and lifecycle hooks.
`editor plugin enable` remains available for noninteractive use. The docked TUI temporarily
replaces the editor log's content area and restores its controls on exit; log messages
continue to accumulate while it is open. Commands with multiple modes can override
`_execute(ctx)` and call `await run()` to enter their TUI.

## OS mode

Enter `os` to toggle OS mode for the current console.
`os <command>` outside that mode invokes an OS command once from GDSh:

```text
os printf 'one\ntwo\n' | count
```

Here `printf` runs in the system shell and `count` runs in GDSh. In toggled OS
mode, the whole line is passed to the system shell.

OS inputs have two expansion layers:

| Syntax | Meaning |
| --- | --- |
| `$name` | GDSh variable; missing names expand to empty |
| `$$name` | Pass `$name` to the system shell |
| `$(commands)` | GDSh command substitution |
| `$$(commands)` | Pass `$(commands)` and its body to the shell |
| `'literal text'` | Preserve literal contents, including dollar signs |

Double quotes allow expansion while preserving the result as a single argument. GDSh values
are quoted before being passed to the shell, their contents do not become shell syntax.

Unquoted GDSh command substitutions retain GDSh's whitespace splitting.
Aliases also expand before OS execution.

Currently shells are hardcoded: zsh on macOS, bash on Linux, and cmd.exe on
Windows. Native shell syntax is platform-specific (`$name`/`$(...)` are POSIX shell
forms); Windows `%NAME%` syntax remains available. Process status and separate
stdout/stderr are returned to GDSh.

## Configuration and integration

`.gdrc` file is a script that runs on the first instance of the console. There
can be one in your home directory and one in your project for overides.

Other config is handled in Godot's Editor Settings directory, `./addons/editor_console/config.yml`

Each console instance keeps its own session. `new_ctx` or configuration reload rebuilds it from configuration.
MCP calls use fresh configured sessions and return `stdout`, `stderr`, and `exit_code` for the requested submission.

Custom commands use GDSh's `Context` and `Completion` types.
See [command authoring](export_ignore/doc/command_base.md) and the
[command overview](export_ignore/doc/commands.md). The editor command base extends
GDSh's base and keeps editor-specific helpers. GDSh is also available directly
through `EditorConsoleSingleton.GDSh`.

## Validation

Run the isolated integration checks from the project root:

```sh
python3 tests/editor_console/run_headless.py --godot godot
python3 tests/gdsh/run_headless.py --godot godot --export
```

Optional Go [MCP server](https://github.com/brohd11/Godot-Editor-Console-MCP).
