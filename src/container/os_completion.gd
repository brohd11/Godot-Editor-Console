extends "res://addons/addon_lib/gdsh/completion.gd"
const Adapter = preload("res://addons/editor_console/src/utils/os_adapter.gd")

func get_completions() -> Dictionary:
	context = Context.new_ctx("OS completion", _session, true)
	context.execute = false
	return Adapter.complete(raw_text.left(caret_col), self)
