extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Toggle whether mutating scene commands register on the editor undo stack.
When on, mutations are undoable (Ctrl+Z). When off, they apply directly with no
undo entry. Affects scene-graph commands (add/delete/reparent/prop/attach/group/
instance/rename); filesystem/config commands are unaffected.
Usage:
  config undo            print current state
  config undo on|off     enable/disable undo tracking"

static func get_command_name() -> String:
	return "undo"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0,max:1",
	})

func _execute(ctx:CompletionContext):
	var inst = EditorConsoleSingleton.get_instance()
	if inst == null or not is_instance_valid(inst):
		ctx.append_error("Console singleton unavailable.")
		return ExitCode.FAIL

	if positional_args.is_empty():
		ctx.append_output("undo tracking: %s" % _state_str(inst.undo_tracking))
		return ExitCode.OK

	match positional_args[0].to_lower():
		"on", "true", "1":
			inst.undo_tracking = true
		"off", "false", "0":
			inst.undo_tracking = false
		_:
			ctx.append_error("Expected 'on' or 'off', got '%s'." % positional_args[0])
			return ExitCode.FAIL

	ctx.append_output("undo tracking: %s" % _state_str(inst.undo_tracking))
	return ExitCode.OK

func _state_str(on:bool) -> String:
	return "on" if on else "off"
