# Godot Editor Console

Godot 4.6+

Editor Console adds a console to the Output panel, plus standalone
windows through the tool menu.

Provides editor/resource/script commands, undo integration,
configuration and startup scripts, global-class calls, OS mode, and the optional
MCP bridge. GDSh remains usable independently of the editor plugin.

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

Editor-only utilities (`os`, `term`, `global`, `mcp`, etc) are hidden and accessible directly, 
they are listed under `misc editor_console`.

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

The optional Go MCP server is described in [its repository](https://github.com/brohd11/Godot-Editor-Console-MCP).
