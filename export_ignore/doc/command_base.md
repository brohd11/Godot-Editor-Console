# Authoring Editor Console commands

Editor commands extend `EditorConsoleSingleton.CommandBase`, which extends
`GDSh.CommandBase`. Routing, flags, `--` payloads, help, and command discovery come
from GDSh. The editor base adds configuration, value conversion, method calls,
and undo helpers.

```gdscript
extends EditorConsoleSingleton.CommandBase

static func get_command_name() -> String:
    return "greet"

static func get_self_command_data() -> Dictionary:
    return _command_data({&"help": "Greet someone", &"positional_count": 1})

func _execute(ctx:Context) -> int:
    ctx.append_output("Hello " + positional_args[0])
    return ExitCode.OK

func _get_completions(completion:Completion):
    var options = Options.new()
    for name in completion.context.variables:
        options.add_option(name)
    return options.get_options()
```

Execution hooks (`_execute`, `_consume_self`) receive `GDSh.Context`. Completion
hooks receive `GDSh.Completion`; execution state is available through
`completion.context`, while caret/token/payload information belongs to the
completion request. Completion must not execute commands or mutate the session.
Arguments have already been unquoted; the old `_unwrap_quotes()` hook is removed.

`ctx.data` holds per-command routing information. It is not inherited wholesale
because function and loop control also use it. Editor UI bindings live separately
in `ctx.host_data`; use `EditorConsoleSingleton.get_console_host(ctx)` when a
command needs the submitting console. The binding may be absent for MCP calls.

Use `ctx.append_output`, `ctx.append_error`, and an `ExitCode` return value.
Pass the existing context when invoking `Execution.execute_command()` or
`Execution.source_file()` from a command.

Directories named `child/child.gd` form subcommands. `_get_commands()` may supply
custom routing; `_get_flags()` and `_process_flag()` define flags. `_get_target_positional_count()`
can change the argument count based on flags. Command metadata and option dictionaries
use `GDSh.Options`.

Plugins can continue registering command scripts or `Callable(Context)` handlers
with `EditorConsoleSingleton.register_temp_scope(name, command)` and unregistering
with `remove_temp_scope(name)`. Callable handlers receive the remaining tokens
in `ctx.unconsumed_tokens` and can return an integer exit status.

Existing custom commands must migrate from the old combined `CompletionContext`
to these two GDSh types. No legacy context adapter is provided.
