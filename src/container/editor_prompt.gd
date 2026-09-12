extends "res://addons/addon_lib/gdsh/console.gd"
## Editor transcripts support command-produced BBCode, like the editor log.
var host:WeakRef

func _get_host():
	return host.get_ref() if host != null else null

func _add_to_history(command:String) -> void:
	var container = _get_host()
	if is_instance_valid(container) and container.os_mode and command.begins_with("os "):
		command = command.trim_prefix("os ").strip_edges()
	super._add_to_history(command)

func _append_command(command:String) -> void:
	if command == "os":
		return # The toggle reports the mode change itself.
	if output != null:
		super._append_command(command)
	elif is_instance_valid(_get_host()):
		_get_host().print_to_console(prompt_label.text + " " + format_command(command))

func _append_result(result:Context) -> void:
	if output != null:
		if not result.stdout.is_empty(): output.append_text(result.stdout)
		if not result.stderr.is_empty():
			output.push_color(Color("ff6b6b"))
			output.append_text("stderr:\n" + result.stderr)
			output.pop()
		output.scroll_to_line.call_deferred(maxi(0, output.get_line_count() - 1))
	elif is_instance_valid(_get_host()):
		if not result.stdout.is_empty(): _get_host().print_to_console(result.stdout.rstrip("\n"))
		if not result.stderr.is_empty(): _get_host().print_to_console("stderr:\n" + result.stderr.rstrip("\n"))
