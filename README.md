# Godot Editor Console

Godot 4.6+

Editor Console adds a console to the Output panel, plus standalone
windows through the tool menu.

Provides editor/resource/script commands, undo integration,
configuration and startup scripts, global-class calls, OS mode, and the optional
MCP bridge. GDSh remains usable independently of the editor plugin.

## Commands

Execution engine is [gdsh](https://github.com/brohd11/godot-gdsh.git)

GDSh commands are available directly and through `builtins`, which will list the available commands in autocomplete:

```text
echo hello
builtins echo hello
source res://example.gdsh
```

Editor console included commands are grouped under `misc editor_console` and can also be accessed directly:

```text
misc editor_console ls
ls
editor scene tree | count
```

## OS mode

Enter bare `os` to toggle OS mode for the current console. Its prompt shows
`user@host`, the working directory, and `$`. Enter `os` again to return to GDSh.
`os <command>` outside that mode invokes an OS command once:

```text
os printf 'one\ntwo\n' | count
```

Here `printf` runs in the system shell and `count` runs in GDSh. In persistent OS
mode, a submitted line's pipes and operators belong to the system shell.
Standalone `cd` updates the console working directory; `clear` and
`clear --history` operate on the current console.

OS inputs have two expansion layers:

| Syntax | Meaning |
| --- | --- |
| `$name` | GDSh variable; missing names expand to empty |
| `$$name` | Pass `$name` to the system shell |
| `$(commands)` | GDSh command substitution |
| `$$(commands)` | Pass `$(commands)` and its body to the shell |
| `'literal text'` | Preserve literal contents, including dollar signs |

Double quotes allow expansion while preserving a single argument. GDSh values
are quoted before being passed to the shell; their contents do not become shell
syntax. Unquoted GDSh command substitutions retain GDSh's whitespace splitting.
Aliases also expand before OS execution.

The current shells are zsh on macOS, bash on Linux, and cmd.exe on
Windows. Native shell syntax is platform-specific (`$name`/`$(...)` are POSIX shell
forms); Windows `%NAME%` syntax remains available. Process status and separate
stdout/stderr are returned to GDSh.

## Configuration and integration

Project/global configuration, `.gdrc`, startup commands, scope registrations,
and script-editor actions remain supported. Each interactive console keeps its
own session. `new_ctx` or configuration reload rebuilds it from configuration.
MCP calls use fresh configured sessions and return `stdout`, `stderr`, and
`exit_code` for the requested submission.

Custom commands now use GDSh's separate `Context` and `Completion` types.
See [command authoring](export_ignore/doc/command_base.md) and the
[command overview](export_ignore/doc/commands.md). The editor command base extends
GDSh's base and keeps editor-specific helpers. GDSh is also available directly
through `EditorConsoleSingleton.GDSh`.

## Packaging and validation

Include the GDSh module with its builtin scripts, font, and font license. Builtin
scripts are explicit preload dependencies so plugin exports can relocate them.
The runtime module has no editor dependency. Godot resource exports must include
dynamically discovered editor command scripts; use all resources and include
`*.gdsh` for shell scripts. The optional Plugin Exporter can bundle the console
and resolve its dependency paths for use as a sub-plugin.

Run the isolated integration checks from the project root:

```sh
python3 tests/editor_console/run_headless.py --godot godot
python3 tests/gdsh/run_headless.py --godot godot --export
```

The optional Go MCP server is described in [its repository](https://github.com/brohd11/Godot-Editor-Console-MCP).
