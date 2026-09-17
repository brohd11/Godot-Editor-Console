extends "res://addons/addon_lib/gdsh/console.gd"
## Editor transcripts support command-produced BBCode, like the editor log.
var host:WeakRef
## A partial line held back while streaming into the editor log, which prints whole lines only.
var _stream_residual:String
var _stream_residual_error:=false

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

func _stream_enabled() -> bool:
	if not super():
		return false
	if not EditorConsoleSingleton.instance_valid():
		return false
	return EditorConsoleSingleton.get_instance().stream_output

func _stream_begin(result:Context) -> void:
	_stream_residual = ""
	_stream_residual_error = false
	super(result)

func _stream_end(result:Context) -> void:
	super(result) # Drains pending chunks, which may leave a partial line behind.
	_flush_residual()

func discard_pending_stream() -> void:
	super()
	_stream_residual = ""
	_stream_residual_error = false

## Streamed text renders as BBCode here, matching `_append_result` and the editor log: `scan`
## emits `[url=...]`, and this is the transcript that shows it as a link.
func _stream_chunk(text:String, is_error:bool) -> void:
	if output != null:
		if not is_error:
			output.append_text(text)
			return
		output.push_color(Color("ff6b6b"))
		if not _stream_err_header:
			_stream_err_header = true
			output.append_text("stderr:\n")
		output.append_text(text)
		output.pop()
		return
	_stream_to_log(text, is_error)

## The docked console has no transcript and prints into the editor log, which appends its own
## newline per call. Hold a partial line until its newline arrives so lines are not split.
func _stream_to_log(text:String, is_error:bool) -> void:
	if not is_instance_valid(_get_host()):
		return
	if is_error != _stream_residual_error:
		_flush_residual()
		_stream_residual_error = is_error
	var lines = (_stream_residual + text).split("\n")
	_stream_residual = lines[-1]
	for i in lines.size() - 1:
		_get_host().print_to_console(_log_line(lines[i], is_error))

func _flush_residual() -> void:
	if _stream_residual.is_empty():
		return
	if is_instance_valid(_get_host()):
		_get_host().print_to_console(_log_line(_stream_residual, _stream_residual_error))
	_stream_residual = ""

func _log_line(line:String, is_error:bool) -> String:
	return "[color=ff6b6b]%s[/color]" % line if is_error else line

func _append_result(result:Context) -> void:
	var tail = _stream_tail(result.stdout, _stream_out_len)
	var err_tail = _stream_tail(result.stderr, _stream_err_len)
	if output != null:
		if not tail.is_empty(): output.append_text(tail)
		if not err_tail.is_empty():
			output.push_color(Color("ff6b6b"))
			if not _stream_err_header: output.append_text("stderr:\n")
			output.append_text(err_tail)
			output.pop()
		output.scroll_to_line.call_deferred(maxi(0, output.get_line_count() - 1))
	elif is_instance_valid(_get_host()):
		if not tail.is_empty(): _get_host().print_to_console(tail.rstrip("\n"))
		if not err_tail.is_empty():
			var header = "" if _stream_err_header else "stderr:\n"
			_get_host().print_to_console(header + err_tail.rstrip("\n"))
