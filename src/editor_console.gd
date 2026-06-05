class_name EditorConsoleSingleton #! singleton-module
extends SingletonRefCount
const SingletonRefCount = Singletons.RefCount

const SCRIPT = preload("res://addons/editor_console/src/editor_console.gd")

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const RightClickHandler = UtilsRemote.RightClickHandler
const BottomPanel = UtilsRemote.BottomPanel
const UNode = UtilsRemote.UNode
const UString = UtilsRemote.UString
const Pr = UString.PrintRich


const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Config = UtilsLocal.Config
const ScopeDataKeys = UtilsLocal.ScopeDataKeys
const Colors = UtilsLocal.Colors

const ConsoleCommandSetBase = UtilsLocal.ConsoleCommandSetBase
const CommandBase = UtilsLocal.CommandBase
const CompletionContext = UtilsLocal.CompletionContext

const ScriptEditorContext = preload("res://addons/editor_console/src/editor_plugins/script_editor.gd")


#region Old plugin.gd vars


var right_click_handler:RightClickHandler

var script_editor_context:ScriptEditorContext

var filter_line_edit:LineEdit
var main_hsplit:HSplitContainer
var console_line_container:UtilsLocal.ConsoleLineContainer

var show_filter:bool = true

#endregion



var settings_helper:UtilsRemote.SettingHelperEditor
var _console_replace_filter:bool=false

var console_line_edit:UtilsLocal.ConsoleLineContainer.ConsoleLineEdit
var last_command:String
var previous_commands = []
var current_command_index:int = -1

var os_label:RichTextLabel
var os_mode:= false
var os_user:String
var os_string_raw:String
var os_string:String
var os_home_dir:String
var os_cwd:String:
	set(value):
		value = value.trim_suffix("/")
		os_cwd = value
		_update_os_string()


var scope_dict = {}
var hidden_scope_dict = {}
var _temp_scope_dict = {}

var variable_dict = {}
var working_variable_dict = {}

var tokenizer:UtilsLocal.ConsoleTokenizer

var filter_button:Button
var clear_button:Button

func _init(plugin:EditorPlugin) -> void:
	if not FileAccess.file_exists(UtilsLocal.EDITOR_CONSOLE_SCOPE_PATH):
		DirAccess.make_dir_recursive_absolute(UtilsLocal.EDITOR_CONSOLE_SCOPE_PATH.get_base_dir())
		UtilsRemote.UFile.write_to_json({}, UtilsLocal.EDITOR_CONSOLE_SCOPE_PATH)
	
	settings_helper = UtilsRemote.SettingHelperEditor.new()
	settings_helper.subscribe_property(self, &"_console_replace_filter", EditorSet.CONSOLE_REPLACE_FILTER, false)
	settings_helper.initialize()
	
	os_user = UtilsLocal.ConsoleOS.get_os_string()
	os_cwd = ProjectSettings.globalize_path("res://")
	os_home_dir = UtilsLocal.ConsoleOS.get_os_home_dir()
	_update_os_string()
	
	script_editor_context = ScriptEditorContext.new()
	plugin.add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE, script_editor_context)
	
	# add func to load user config

func _ready() -> void:
	EditorNodeRef.call_on_ready(_add_console_line_edit)
	_ready_deferred.call_deferred()

func _ready_deferred():
	tokenizer = UtilsLocal.ConsoleTokenizer.new()
	_load_default_commands()
	EditorNodeRef.call_on_ready(_start_up_commands)

func _start_up_commands():
	var config = Config.get_merged_config()
	var startup = config.get_section(Config.STARTUP, [])
	for cmd in startup:
		execute_command(cmd)

static func get_singleton_name() -> String:
	return "EditorConsoleSingleton"

static func get_instance() -> EditorConsoleSingleton:
	return _get_instance(SCRIPT)

static func register_node(node:Node):
	return _register_node(SCRIPT, node)

static func unregister_node(node):
	_unregister_node(SCRIPT, node)

static func call_on_ready(callable:Callable):
	_call_on_ready(SCRIPT, callable)

static func instance_valid():
	return _instance_valid(SCRIPT)

static func _instance_valid_err():
	if instance_valid(): return true
	printerr("EditorConsole has not been instance by a plugin yet")
	return false

func _all_unregistered_callback():
	_remove_console_line_edit()
	if is_instance_valid(script_editor_context):
		var plugin = EditorPlugin.new()
		plugin.remove_context_menu_plugin(script_editor_context)
		plugin.queue_free()


static func register_temp_scope(scope_name:String, object_or_callable:Variant) -> void: # for plugins
	if not _instance_valid_err(): return
	var ins = get_instance()
	var data = {}
	if object_or_callable is Callable:
		data[ScopeDataKeys.CALLABLE] = object_or_callable
	elif object_or_callable is GDScript or object_or_callable.get_class() == "RefCounted":
		data[ScopeDataKeys.SCRIPT] = object_or_callable
	else:
		printerr("Scope: %s - Unrecognized script or callable: %s" % [scope_name, object_or_callable])
		return
	
	ins._temp_scope_dict[scope_name] = data
	#set_var_highlighter()
	ins._load_default_commands()


static func remove_temp_scope(scope_name:String): # for plugins
	if not _instance_valid_err(): return
	var ins = get_instance()
	if not scope_name in ins._temp_scope_dict.keys():
		print("Scope not in temp scope data: %s" % scope_name)
		return
	ins._temp_scope_dict.erase(scope_name)
	ins._load_default_commands()



func _load_default_commands():
	scope_dict.clear()
	hidden_scope_dict.clear()
	variable_dict.clear()
	
	_get_scope_set_data(UtilsLocal.DefaultCommands)
	scope_dict.merge(_temp_scope_dict, true)
	
	var scope_data = UtilsLocal.get_scope_data()
	var scopes = scope_data.get(ScopeDataKeys.SCOPES, {})
	for scope in scopes.keys():
		var data = scopes.get(scope)
		var script_path = data.get(ScopeDataKeys.SCRIPT)
		if not FileAccess.file_exists(script_path):
			printerr("Could not find script: %s" % script_path)
			continue
		var script = load(script_path)
		scope_dict[scope] = {ScopeDataKeys.SCRIPT: script}
	
	var sets = scope_data.get(ScopeDataKeys.SETS, [])
	for script_path in sets:
		_get_scope_set_data(script_path)
	
	if is_instance_valid(console_line_edit):
		set_var_highlighter()
	
	return true


func set_var_highlighter():
	var current_scope_data = get_current_scope_data()
	
	var syn:UtilsLocal.SyntaxHl = console_line_edit.syntax_highlighter
	syn.scope_names = current_scope_data.keys()
	#syn.scope_names = scope_dict.keys()
	#syn.hidden_scope_names = hidden_scope_dict.keys()
	syn.var_names = variable_dict.keys()
	syn.clear_highlighting_cache()
	
	console_line_edit.scope_dict = scope_dict
	console_line_edit.combined_scope_dict = current_scope_data
	console_line_edit.variable_dict = variable_dict
	console_line_edit.editor_console = self

static func register_persistent_scope(scope_name:String, script_path:String):
	if not _instance_valid_err(): return
	if not FileAccess.file_exists(script_path):
		print("Could not load script: %s" % script_path)
		return
	var scope_data = UtilsLocal.get_scope_data()
	var scopes = scope_data.get(ScopeDataKeys.SCOPES, {})
	if scope_name in scopes.keys():
		print("Scope already registered: %s" % scope_name)
		return
	scopes[scope_name] = {ScopeDataKeys.SCRIPT: script_path}
	scope_data[ScopeDataKeys.SCOPES] = scopes
	UtilsLocal.save_scope_data(scope_data)
	get_instance()._load_default_commands()

static func remove_persistent_scope(scope_name):
	if not _instance_valid_err(): return
	var scope_data = UtilsLocal.get_scope_data()
	var scopes = scope_data.get(ScopeDataKeys.SCOPES, {})
	
	if not scope_name in scopes.keys():
		print("Scope not registered: %s" % scope_name)
		return
	
	scopes.erase(scope_name)
	scope_data[ScopeDataKeys.SCOPES] = scopes
	UtilsLocal.save_scope_data(scope_data)
	get_instance()._load_default_commands()

static func register_persistent_scope_set(script_path:String):
	if not _instance_valid_err(): return
	if not FileAccess.file_exists(script_path):
		print("Could not load script: %s" % script_path)
		return
	var scope_data = UtilsLocal.get_scope_data()
	var sets = scope_data.get(ScopeDataKeys.SETS, [])
	if script_path in sets:
		print("Script already registered as set: %s" % script_path)
		return
	
	sets.append(script_path)
	scope_data[ScopeDataKeys.SETS] = sets
	UtilsLocal.save_scope_data(scope_data)
	get_instance()._load_default_commands()

static func remove_persistent_scope_set(script_path:String) -> void:
	if not _instance_valid_err(): return
	var scope_data = UtilsLocal.get_scope_data()
	var sets = scope_data.get(ScopeDataKeys.SETS, [])
	if not script_path in sets:
		print("Script set not registered: %s" % script_path)
		return
	
	var idx = sets.find(script_path)
	sets.remove_at(idx)
	
	scope_data[ScopeDataKeys.SETS] = sets
	UtilsLocal.save_scope_data(scope_data)
	get_instance()._load_default_commands()

static func register_command_dir(dir_path:String):
	if not _instance_valid_err(): return
	if not dir_path.get_extension() == "":
		print("Directory path has extension: ", dir_path)
		return
	if not dir_path.ends_with("/"):
		dir_path += "/"
	var scope_data = UtilsLocal.get_scope_data()
	var dirs = scope_data.get(ScopeDataKeys.COMMAND_DIRS, [])
	if dir_path in dirs:
		print("Script already registered as set: %s" % dir_path)
		return
	
	dirs.append(dir_path)
	scope_data[ScopeDataKeys.COMMAND_DIRS] = dirs
	UtilsLocal.save_scope_data(scope_data)
	get_instance()._load_default_commands()
	pass

static func remove_command_dir(dir_path:String):
	if not _instance_valid_err(): return
	var scope_data = UtilsLocal.get_scope_data()
	var dirs = scope_data.get(ScopeDataKeys.COMMAND_DIRS, [])
	if not dir_path in dirs:
		print("Script set not registered: %s" % dir_path)
		return
	
	var idx = dirs.find(dir_path)
	dirs.remove_at(idx)
	
	scope_data[ScopeDataKeys.COMMAND_DIRS] = dirs
	UtilsLocal.save_scope_data(scope_data)
	get_instance()._load_default_commands()
	pass


func get_scope_script(scope_name):
	var scope = null
	if hidden_scope_dict.has(scope_name):
		scope = hidden_scope_dict[scope_name]
	elif scope_dict.has(scope_name):
		scope = scope_dict[scope_name]
	if scope == null: return
	return scope.get(ScopeDataKeys.SCRIPT)

func _get_scope_set_data(path_or_script):
	var script:Script
	if path_or_script is Script:
		script = path_or_script
	else:
		script = load(path_or_script)
	
	if UNode.has_static_method_compat("register_scopes", script):
		var register_scopes = script.register_scopes()
		scope_dict.merge(_process_scope_data(register_scopes))
	
	if UNode.has_static_method_compat("register_hidden_scopes", script):
		var register_hidden_scopes = script.register_hidden_scopes()
		hidden_scope_dict.merge(_process_scope_data(register_hidden_scopes))
	
	if UNode.has_static_method_compat("register_variables", script):
		var register_variables = script.register_variables()
		variable_dict.merge(register_variables)

func _process_scope_data(scope_data_dict:Dictionary) -> Dictionary:
	var scope_dict_keys = scope_dict.keys()
	var temp_dict = {}
	for scope in scope_data_dict.keys():
		if scope in scope_dict_keys:
			print("Scope name conflict: %s" % scope)
		var scope_data = scope_data_dict.get(scope)
		var scope_script
		var scope_callable
		if scope_data is Dictionary:
			scope_script = scope_data.get(ScopeDataKeys.SCRIPT)
			scope_callable = scope_data.get(ScopeDataKeys.CALLABLE)
		elif scope_data is Callable:
			scope_callable = scope_data
		elif scope_data is GDScript or scope_data.get_class() == "RefCounted":
			scope_script = scope_data
		else:
			printerr("Scope: %s - Unrecognized script or callable: %s" % [scope, scope_data])
			continue
		
		temp_dict[scope] = {}
		if scope_callable != null:
			temp_dict[scope][ScopeDataKeys.CALLABLE] = scope_callable
		elif scope_script != null:
			temp_dict[scope][ScopeDataKeys.SCRIPT] = scope_script
		
	return temp_dict

func get_current_scope_data():
	var dict = {}
	dict.merge(scope_dict.duplicate())
	dict.merge(hidden_scope_dict.duplicate())
	return dict


func _update_os_string():
	os_string = _get_console_label_string(true)
	if os_label:
		os_label.text = os_string

func _toggle_os_mode():
	os_mode = not os_mode
	console_line_edit.syntax_highlighter.os_mode = os_mode
	console_line_edit.os_mode = os_mode
	if os_mode:
		_update_os_string()
		print_rich(_get_console_label_string(), " Entered OS mode.")
		if console_line_edit.visible:
			os_label.show()
	else:
		os_label.text = _get_console_label_string()
		print_rich(_get_console_label_string(), " Exited OS mode")

func _get_console_label_string(os:=false):
	if os:
		var display_cwd = os_cwd#.trim_prefix(os_home_dir)
		if display_cwd == "":
			display_cwd = "/"
		elif display_cwd == os_home_dir:
			display_cwd = "~"
		else:
			if true: # make this a setting?
				display_cwd = display_cwd.trim_suffix("/").get_file()
			else:
				display_cwd = "~/" + display_cwd
		return Pr.new().append(os_user, Colors.OS_USER).append(":").append(display_cwd, Colors.OS_PATH).append(" $").get_string()
	
	var accent_color = UtilsRemote.EditorColors.get_theme_color(UtilsRemote.EditorColors.ThemeColor.ACCENT)
	return Pr.new().append("Console$", accent_color).get_string()

func set_console_text(text:String) -> void:
	_set_console_text(text)

func _set_console_text(text:String) -> void:
	console_line_edit.text = text
	await console_line_edit.get_tree().process_frame
	console_line_edit.set_caret_column(text.length())

## Command order - clear, os, help, command_dict, finally check global
func parse_input(ctx:CompletionContext, print_to_log:=true) -> void:
	if ctx.expanded_command_statements.is_empty():
		ctx.expand()
	
	ctx.execute_parse()
	
	if ctx.expanded_text.is_empty():
		return
	
	if ctx.print and ctx.expanded_text.strip_edges() != "os":
	#if print_to_log and ctx.expanded_text.strip_edges() != "os":
		if not os_mode:
			ctx.console_display_string = "%s %s" % [_get_console_label_string(), ctx.display_text]
		else:
			ctx.console_display_string = "%s %s" % [os_string, ctx.raw_text.strip_edges()]
		
		#if print_to_log:
		print_rich(ctx.console_display_string)
	
	if ctx.expanded_command_statements.size() == 1 or os_mode:
		ctx.execute_parse()
		_parse_input(ctx)
	else:
		var working_ctx = null
		if ctx.add_to_hist:
			_add_to_history(ctx.raw_text)
		
		for i in range(ctx.expanded_command_statements.size()):
			var cmd = ctx.expanded_command_statements[i].strip_edges()
			var new_ctx = CompletionContext.new(cmd)
			#print("CALLING:", cmd)
			new_ctx.execute_parse()
			new_ctx.chained_command = true
			new_ctx.add_to_hist = false
			new_ctx.print = ctx.print and i == ctx.expanded_command_statements.size() - 1
			
			if is_instance_valid(working_ctx):
				new_ctx.input = working_ctx.output.strip_edges()
			
			_parse_input(new_ctx)
			working_ctx = new_ctx
		
		ctx.output = working_ctx.output
	
	ctx.output = ctx.output.strip_edges(false, true).lstrip("\n")
	
	#if print_to_log:
	if ctx.print:
		if ctx.error != "":
			print(ctx.error.lstrip("\n"))
		elif not ctx.output.is_empty():
		#elif print_to_log and not ctx.output.is_empty():
			if ctx.output.contains("[/color]"):
				print_rich(ctx.output)
			else:
				print(ctx.output)
	
	
func _parse_input(ctx:CompletionContext) -> void:
	working_variable_dict.clear()
	current_command_index = -1
	var terminal_input = ctx.expanded_text
	
	terminal_input = terminal_input.strip_edges()
	if terminal_input == "": return
	
	if ctx.add_to_hist:
		_add_to_history(ctx.raw_text)
	
	var tokens:Array = ctx.unconsumed_tokens
	if tokens.find("--") > -1:
		tokens.remove_at(tokens.rfind("--"))
	
	if tokens.size() == 0:
		return
	
	ctx.execute = true
	
	var c_1 = tokens[0]
	if c_1 == "clear" or (os_mode and tokens.size() > 1 and tokens[1] == "clear"):
		if os_mode: # clear reroutes in os mode, pop os from unconsumed
			ctx.unconsumed_tokens.pop_front()
		_scope_parse("clear", ctx)
		return
	
	if terminal_input == "os":
		toggle_os_mode()
		return
	if os_mode or terminal_input.begins_with("os"):
		_scope_parse("os", ctx)
		return
	
	if c_1.to_lower() == "help":
		c_1 = c_1.to_lower()
	
	c_1 = UString.get_member_access_front(c_1)
	var parse_scopes = _scope_parse(c_1, ctx)
	if parse_scopes == Keys.NO_MATCHING_COMMAND:
		_scope_parse("global", ctx)
	
	if scope_dict.is_empty():
		ctx.append_error("Need to load command set.")


func _scope_parse(_name, ctx:CompletionContext):
	var scope = scope_dict.get(_name)
	if scope == null:
		scope = hidden_scope_dict.get(_name)
	if scope == null:
		return Keys.NO_MATCHING_COMMAND
	var script = scope.get(ScopeDataKeys.SCRIPT)
	var callable = scope.get(ScopeDataKeys.CALLABLE)
	var result
	if callable:
		result = callable.call(ctx)
	else:
		if script is GDScript:
			script = ensure_fresh_script(script)
			script = script.new()
		
		if script.has_method("execute"):
			result = script.execute(ctx)
		else:
			ctx.append_error("Could not parse in object: %s" % scope)
	
	#if result != null: # this is now CommandBase.ExitCode
		#print(result)


func _add_to_history(command:String):
	last_command = command
	var history_prompt = command
	if os_mode and history_prompt.begins_with("os"):
		history_prompt = history_prompt.trim_prefix("os").strip_edges()
	var cmd_index = previous_commands.rfind(history_prompt)
	if cmd_index == -1:
		previous_commands.append(history_prompt)
	else:
		previous_commands.remove_at(cmd_index)
		previous_commands.append(history_prompt)

func _console_gui_input(event: InputEvent) -> void:
	if not console_line_edit.has_focus():
		return
	
	if event is InputEventKey:
		var keycode = event.keycode
		var keycode_text = event.as_text_keycode()
		if event.is_pressed() and keycode == KEY_ENTER:
			_on_console_text_submitted(console_line_edit.text)
		
		if not event.is_pressed():
			return
		
		if keycode == KEY_UP:
			prev_command()
		elif keycode == KEY_DOWN:
			next_command()
		elif keycode_text == "Ctrl+Shift+Up":
			prev_valid_command()
		elif keycode_text == "Ctrl+Shift+Down":
			next_valid_command()


func _on_console_text_submitted(new_text:String) -> void:
	var ctx = CompletionContext.new()
	ctx.set_line_edit(console_line_edit)
	#ctx.parse()
	parse_input(ctx)

	await console_line_edit.get_tree().process_frame
	console_line_edit.clear()
	
	var console_text = get_console_text_box() as RichTextLabel
	console_text.scroll_to_line(console_text.get_line_count())

func prev_command():
	current_command_index -= 1
	if current_command_index < -1:
		current_command_index = previous_commands.size() - 1
	if current_command_index == -1:
		console_line_edit.clear()
		return
	if current_command_index < previous_commands.size():
		_set_console_text(previous_commands[current_command_index])

func next_command():
	current_command_index += 1
	if current_command_index > previous_commands.size() - 1:
		current_command_index = -1
		console_line_edit.clear()
		return
	if current_command_index < previous_commands.size():
		_set_console_text(previous_commands[current_command_index])


## UNSURE
func prev_valid_command():
	var console_line_text = console_line_edit.text
	if console_line_text.strip_edges() == "":
		return
	var commands = console_line_text.split(" ")
	var next_command = commands[0]
	for com in commands:
		next_command = scope_dict.get(com)
		if not next_command:
			break

func next_valid_command():
	var console_line_text = console_line_edit.text
	if console_line_text.strip_edges() == "":
		return

##


func get_console_text_box():
	return EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL)


#region Old plugin.gd Logic


#^ should move this into the console line container? or make a new object to house it at least, would clean it up a bit in here

func _add_console_line_edit():
	_get_editor_log_button_refs()
	
	#var filter_check = BottomPanel.get_filter_line_edit()
	#if filter_check is not LineEdit:
		#print("Filter is not found: %s" % filter_check)
		#return
	filter_line_edit = BottomPanel.get_filter_line_edit()
	var vbox = filter_line_edit.get_parent()
	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(main_hsplit)
	
	console_line_container = UtilsLocal.ConsoleLineContainer.new()
	filter_line_edit.reparent(main_hsplit)
	filter_line_edit.show()
	main_hsplit.add_child(console_line_container)
	
	console_line_container.apply_styleboxes(filter_line_edit)
	console_line_container.custom_minimum_size.y = filter_line_edit.size.y
	
	os_label = console_line_container.os_label
	os_label.text = _get_console_label_string()
	console_line_container.console_line_edit.gui_event_passthrough.connect(_console_gui_input)
	console_line_container.console_button.pressed.connect(_toggle_console)
	console_line_container.console_button.gui_input.connect(_on_button_gui_input)
	
	console_line_edit = console_line_container.console_line_edit
	if is_instance_valid(filter_button):
		filter_button.toggled.connect(_on_filter_toggled)
	
	set_var_highlighter()
	
	right_click_handler = RightClickHandler.new()
	console_line_container.add_child(right_click_handler)


func _remove_console_line_edit():
	var editor_log_hbox = main_hsplit.get_parent()
	filter_line_edit.reparent(editor_log_hbox)
	filter_line_edit.show()
	
	main_hsplit.queue_free()
	filter_line_edit = null


func _get_editor_log_button_refs():
	var editor_log_button_container = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_BUTTON_CONTAINER)
	var editor_log_containers = editor_log_button_container.get_children()
	for item in editor_log_containers:
		if item is not HBoxContainer:
			continue
		var children = item.get_children()
		for c in children:
			if UNode.get_signal_callable(c, "pressed", "EditorLog::_clear_request") != null:
				clear_button = c
			if UNode.get_signal_callable(c, "toggled", "EditorLog::_set_search_visible") != null:
				filter_button = c


func _on_filter_toggled(toggled:bool) -> void: # this is the filter toggle in editor log panel
	console_line_container.visible = toggled
	if toggled:
		if not console_line_edit.visible: # if console is not visible, show filter regardless of last setting
			filter_line_edit.show()
		elif not _can_show_filter():
			filter_line_edit.hide()
			console_line_edit.grab_focus()
		else:
			filter_line_edit.visible = show_filter


func _toggle_console():
	var console_line_edit = console_line_container.console_line_edit
	console_line_edit.visible = not console_line_edit.visible
	if console_line_edit.visible:
		main_hsplit.collapsed = false
		console_line_container.console_panel.show()
		console_line_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		console_line_edit.grab_focus()
		if not _can_show_filter():
			filter_line_edit.hide()
	else:
		console_line_container.console_panel.hide()
		filter_line_edit.show()
		console_line_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		main_hsplit.collapsed = true


func _on_button_gui_input(event):
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index == 2:
			var options = RightClickHandler.Options.new()
			options.add_option("Toggle Console", _toggle_console)
			if console_line_container.console_line_edit.visible:
				options.add_option("Toggle Filter", _toggle_filter)
				options.add_option("OS/Toggle Mode", _toggle_os_mode)
				if os_mode:
					options.add_option("OS/Toggle Label", _toggle_os_label_minimum_size)
			right_click_handler.display_on_control(options, console_line_container.console_button)



func _toggle_filter(): #^ right click toggle
	filter_line_edit.visible = not filter_line_edit.visible
	show_filter = filter_line_edit.visible

func _can_show_filter():
	return not _console_replace_filter and show_filter

func toggle_os_mode() -> void:
	_toggle_os_mode()

func _toggle_os_label_minimum_size() -> void:
	os_label.fit_content = not os_label.fit_content
	if not os_label.fit_content:
		os_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		os_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

## ctx object can be passed as argument, it should have text set already.
static func execute_command(text:String, ctx_obj:CompletionContext=null, input_ctx:CompletionContext=null):
	var ctx = ctx_obj
	if not is_instance_valid(ctx):
		ctx = CompletionContext.new(text)
		ctx.expand()
		ctx.execute_parse()
	
	if is_instance_valid(input_ctx):
		ctx.input = input_ctx.output
		ctx.print = input_ctx.print
		ctx.add_to_hist = input_ctx.add_to_hist
 
	var instance = get_instance()
	instance.parse_input(ctx)
	return ctx

static func run_gdsh(file_path:String):
	var file_string = FileAccess.get_file_as_string(file_path)
	var commands = file_string.split("\n", false)
	
	var working_ctx = CompletionContext.new()
	working_ctx.print = false
	working_ctx.add_to_hist = false
	
	for c in commands:
		var out = EditorConsoleSingleton.execute_command(c, null, working_ctx)
		working_ctx = out
	



#! keys require_quotes:bool current_command:CommandBase show_commands:bool show_flags:bool line_edit:CodeEdit
#! keys inherited_ctx:CompletionContext
static func get_completion_for_input(input:String, params:={}):
	if params.get(&"require_quotes", false):
		if not UString.is_string_or_string_name(input) or not input[0] == '"':
			return {}
	input = UString.unquote(input)
	
	var current_command = params.get(&"current_command")
	var show_commands = params.get(&"show_commands", true)
	var show_flags = params.get(&"show_flags", true)
	
	var ctx = CompletionContext.new(input)
	if params.has(&"line_edit"):
		ctx.line_edit = params.line_edit
	
	ctx.completion_parse()
	
	if params.has(&"inherited_ctx"):
		var inh_ctx:CompletionContext = params.inherited_ctx
		ctx.word_before_cursor = inh_ctx.word_before_cursor
		ctx.char_before_cursor = inh_ctx.char_before_cursor
	
	
	
	var options = CommandBase.Options.new()
	if ctx.token_before_cursor.begins_with("@"): # list aliases
		var config = UtilsLocal.Config.get_merged_config()
		var alias_data = config.get_section(UtilsLocal.Config.ALIAS)
		for k in alias_data.keys():
			var val = UtilsLocal.ConsoleTokenizer.clean_alias_token(alias_data[k])
			options.add_option(k + " = [%s]" % val, {
				&"insert": k
			})
		return options.get_options()
	
	var console = get_instance()
	
	var first_word:String = ""
	if ctx.unconsumed_tokens.size() > 0:
		first_word = ctx.unconsumed_tokens[0]
	
	if first_word.find(".") > -1:
		var front = UtilsRemote.UString.get_member_access_front(first_word)
		first_word = front
	
	var scope_script = console.get_scope_script(first_word)
	if not is_instance_valid(scope_script) and UtilsRemote.UClassDetail.get_global_class_path(first_word) != "":
		scope_script = console.get_scope_script("global")
	
	if not (is_instance_valid(scope_script)):
		for scope:String in console.scope_dict.keys():
			options.add_option(scope)
		
		if is_instance_valid(current_command): # this would be in the context of a quoted command, should only be on first word
			options.merge(current_command.get_flags(true))
		return options.get_options()
	
	#if ctx.word_before_cursor == first_word:
		#return {} # whats this for? From original completion logic..
	
	var ins = scope_script.new()
	var completion = ins.complete(ctx)
	if completion == null:
		return {}
	elif completion is Dictionary:
		pass
	elif completion.has_method("get_options"):
		completion = completion.get_options()
	else:
		print("Unhandled completion result: ", completion)
		return {}
	
	
	options.set_options(completion)
	
	var command_meta = options.get_options().get(UtilsLocal.Options.Keys.COMMAND_META, {})
	var show_variables = command_meta.get(UtilsLocal.Options.Keys.SHOW_VARIABLES, false)
	#show_variables = true #ALERT
	if ctx.argument_index > -1:
		options.remove_option(UtilsLocal.Options.ARG_DELIMITER)
		if show_variables:
			var var_nms = console.variable_dict.keys()
			if var_nms.size() > 0:
				options.add_separator("Variables")
			for nm in var_nms:
				options.add_option(nm)
		
	
	var options_dict = options.get_options()
	for option in options_dict.keys():
		var data = options_dict[option]
		if data.has(&"get_command"):
			if not show_commands:
				options_dict.erase(option)
		else:
			if not show_flags:
				options_dict.erase(option)
	
	return options_dict


static func load_command(path:String) -> Resource:
	if not UFile.path_in_res(path):
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	else:
		return load(path)

static func ensure_fresh_script(script:GDScript) -> Resource:
	return UtilsRemote.UResource.ensure_fresh_load(script)

#endregion

class EditorSet:
	const CONSOLE_REPLACE_FILTER = &"plugin/editor_console/active_console_replace_filter"

class Keys:
	const NO_MATCHING_COMMAND = &"NO_MATCHING_COMMAND"
