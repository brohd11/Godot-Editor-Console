extends EditorConsoleSingleton.CommandBase


const _HELP = \
"List all available console commands, with a usage preamble."

const PREAMBLE = \
"Editor console — commands compose like a Unix shell.
- Pipe with | ; chain with && / || / ; ; multi-line gdsh scripts supported.
- Many commands read targets from stdin (node paths or res:// paths, one per line)
  and emit the same, so they chain: scene edited tree | scene edited prop position
- OS commands can be ran by prefixing with 'os', everything until the end of the line or the next pipe '|'
  will be ran verbatim through bash(mac, linux) or cmd.exe and output returned
- Bash style variables and command substitution is available
- With no stdin, node commands act on the current selection / edited scene.
- Output goes to stdout; errors and usage go to stderr.
- After editing project files on disk from outside the editor, run 'editor scan' so
  added/removed files register. The editor does NOT auto-reload changes while it is
  unfocused (e.g. while you work in the terminal).
- If you edited a SCRIPT that already has running instances (an editor dock/plugin,
  or nodes in the open scene), run 'resource reload_script <res://path>' — this
  re-reads it from disk and rebinds the live instances. A plain 'editor scan' will
  not reload them. ('editor scan --focus' also works but steals OS focus.)
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
	
	var list = ins._cache.get(EditorConsoleSingleton.ConsoleBridge.COMMAND_LIST_KEY, "")
	if list.is_empty():
		list = ins.ConsoleBridge.build_mcp_command_list()
		ins._cache[EditorConsoleSingleton.ConsoleBridge.COMMAND_LIST_KEY] = list
	
	ctx.append_output(list)
