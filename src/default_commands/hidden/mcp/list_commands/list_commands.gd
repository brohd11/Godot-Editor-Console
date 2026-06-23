extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

const PREAMBLE = \
"Editor console — commands compose like a Unix shell.
- Pipe with | ; chain with && / || / ; ; multi-line gdsh scripts supported.
- Many commands read targets from stdin (node paths or res:// paths, one per line)
  and emit the same, so they chain: scene edited tree | scene edited prop --get position
- OS commands can be ran by prefixing with 'os', everything until the end of the line or the next pipe '|'
  will be ran verbatim through bash(mac, linux) or cmd.exe and output returned
- Bash style variables and command substitution is available
- With no stdin, node commands act on the current selection / edited scene.
- Output goes to stdout; errors and usage go to stderr.
- Run '<command> --help' for usage and flags on any command below.

Available Commands:"

static func get_command_name():
	return "list_commands"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	var ins = EditorConsoleSingleton.get_instance()
	ctx.append_output(PREAMBLE)
	ctx.append_output(ins.get_command_list())
