extends GDSh.TUICommand
## Interactive plugin manager; editor services are isolated for fixture-backed tests.
const _KEYS = "↑↓ Move · PgUp/Dn · Home/End · Enter Toggle · R Refresh · Esc Exit"
var _plugins:Array[Dictionary] = []
var _selected:=0
var _first:=0
var _scroll_remainder:=0.0
var _status_text:String


static func get_command_name() -> String:
	return "plugin"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": "Open the interactive addon plugin list.\nEnter toggles the selected plugin; R refreshes; Escape exits. Editor Console cannot disable itself.\nUse editor plugin enable for noninteractive changes."})


func update(message:TUIMsg) -> void:
	match message.type:
		TUIMsg.Type.INIT:
			if not _editor_available():
				context.append_error("editor plugin: Godot editor services are required")
				quit(ExitCode.FAIL)
				return
			_selected = 0
			_first = 0
			_scroll_remainder = 0
			_refresh()
		TUIMsg.Type.RESIZE:
			_reveal_selected()
		TUIMsg.Type.MOUSE:
			_scroll(message.payload)
		TUIMsg.Type.KEY:
			var event:InputEventKey = message.payload
			if not event.pressed:
				return
			match event.keycode:
				KEY_ESCAPE: quit()
				KEY_R:
					if not event.echo: _refresh()
				KEY_ENTER, KEY_KP_ENTER:
					if not event.echo: _toggle_selected()
				KEY_UP: _selected -= 1
				KEY_DOWN: _selected += 1
				KEY_PAGEUP: _selected -= _page_size()
				KEY_PAGEDOWN: _selected += _page_size()
				KEY_HOME: _selected = 0
				KEY_END: _selected = _plugins.size() - 1
				_: return
			_selected = clampi(_selected, 0, maxi(0, _plugins.size() - 1))
			_reveal_selected()
			_update_hint()


func view() -> String:
	if viewport_size.y == 0:
		return ""
	var lines:PackedStringArray = ["[color=#9bbfe5]Plugins (%d)[/color]" % _plugins.size()]
	if _plugins.is_empty() and viewport_size.y > 1:
		lines.append("No addon plugin.cfg files found. Press R to refresh.")
	for index in range(_first, mini(_plugins.size(), _first + maxi(0, viewport_size.y - 1))):
		var plugin = _plugins[index]
		var state = "invalid" if not plugin.error.is_empty() else ("enabled " if plugin.enabled else "disabled")
		var label = "%s  %s (%s)%s" % [state, _escape(plugin.name), _escape(plugin.id), " [host]" if plugin.protected else ""]
		# Literal brackets in the host marker must not be parsed as BBCode.
		label = label.replace("[host]", "[lb]host]")
		if index == _selected:
			lines.append("[bgcolor=#38577a][color=#ffffff]> %s[/color][/bgcolor]" % label)
		else:
			lines.append("  " + label)
	return "\n".join(lines)


func _refresh() -> void:
	var selected_id = _plugins[_selected].id if not _plugins.is_empty() else ""
	_plugins = _list_plugins()
	_plugins.sort_custom(func(a, b): return a.id < b.id)
	var host_id = _host_plugin_id()
	for index in _plugins.size():
		var plugin = _plugins[index]
		plugin.protected = plugin.id == host_id
		plugin.enabled = _is_enabled(plugin.id) if plugin.error.is_empty() else false
		if plugin.id == selected_id:
			_selected = index
	_selected = clampi(_selected, 0, maxi(0, _plugins.size() - 1))
	_status_text = ""
	_reveal_selected()
	_update_hint()


func _toggle_selected() -> void:
	if _plugins.is_empty():
		return
	var id:String = _plugins[_selected].id
	# Rescan before mutating: the selected addon may have been removed externally.
	_refresh()
	if _plugins.is_empty() or _plugins[_selected].id != id:
		_status_text = "Plugin disappeared: " + id
		return
	var plugin = _plugins[_selected]
	if plugin.protected:
		_status_text = "Editor Console hosts this view and cannot disable itself."
		return
	if not plugin.error.is_empty():
		_status_text = plugin.error
		return
	var target:bool = not _is_enabled(id)
	_set_enabled(id, target)
	# Godot's setter returns no result: display the state actually reported afterward.
	_refresh()
	_status_text = ("Enabled " if target else "Disabled ") + id if _is_enabled(id) == target \
			else "Could not change %s; see the editor log." % id


func _update_hint() -> void:
	if not _status_text.is_empty():
		hint = _status_text + " · Enter Toggle · R Refresh · Esc Exit"
	elif not _plugins.is_empty() and _plugins[_selected].protected:
		hint = "Editor Console hosts this view (locked) · ↑↓ Move · Esc Exit"
	elif not _plugins.is_empty() and not _plugins[_selected].error.is_empty():
		hint = _plugins[_selected].error + " · R Refresh · Esc Exit"
	else:
		hint = _KEYS


func _page_size() -> int:
	return maxi(1, viewport_size.y - 1)


func _reveal_selected() -> void:
	_first = clampi(_first, maxi(0, _selected - _page_size() + 1), _selected)
	_first = mini(_first, maxi(0, _plugins.size() - _page_size()))


func _scroll(event:InputEvent) -> void:
	var delta:=0.0
	if event is InputEventPanGesture:
		delta = event.delta.y * 3
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: delta = event.factor * 3
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: delta = -event.factor * 3
	_scroll_remainder += delta
	var steps = int(_scroll_remainder)
	_scroll_remainder -= steps
	_first = clampi(_first + steps, 0, maxi(0, _plugins.size() - _page_size()))


static func _escape(text:String) -> String:
	return text.replace("\n", " ").replace("\r", " ").replace("[", "[lb]")


func _editor_available() -> bool:
	return Engine.is_editor_hint()


func _addons_path() -> String:
	return "res://addons"


func _list_plugins() -> Array[Dictionary]:
	var plugins:Array[Dictionary] = []
	for id in DirAccess.get_directories_at(_addons_path()):
		var directory = _addons_path().path_join(id)
		var path = directory.path_join("plugin.cfg")
		if not FileAccess.file_exists(path):
			continue
		var config = ConfigFile.new()
		var error = config.load(path)
		var name = str(config.get_value("plugin", "name", id)) if error == OK else id
		var script = str(config.get_value("plugin", "script", "")) if error == OK else ""
		var issue = "Cannot read plugin.cfg: " + id if error != OK else ""
		if issue.is_empty() and (script.is_empty() or not FileAccess.file_exists(directory.path_join(script))):
			issue = "Missing plugin script: " + id
		plugins.append({"id": id, "name": name if not name.is_empty() else id, "error": issue})
	return plugins


func _host_plugin_id() -> String:
	# Derive the enclosing addon from its resource location, including relocated exports.
	var script:Script = preload("res://addons/editor_console/src/editor_console.gd")
	var directory = script.resource_path.get_base_dir()
	while directory.begins_with("res://addons/"):
		if FileAccess.file_exists(directory.path_join("plugin.cfg")):
			return directory.trim_prefix("res://addons/")
		directory = directory.get_base_dir()
	return ""


func _is_enabled(id:String) -> bool:
	return EditorInterface.is_plugin_enabled(id)


func _set_enabled(id:String, enabled:bool) -> void:
	EditorInterface.set_plugin_enabled(id, enabled)
