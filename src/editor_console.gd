class_name EditorConsoleSingleton #! singleton-module
extends SingletonRefCount
const SingletonRefCount = Singletons.RefCount

const PRINT_DEBUG = false # not PLUGIN_EXPORTED# or true

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

const ConsoleContainer = UtilsLocal.ConsoleContainer

const ConsoleCommandSetBase = UtilsLocal.ConsoleCommandSetBase
const CommandBase = UtilsLocal.CommandBase
const CompletionContext = UtilsLocal.CompletionContext
const Execution = UtilsLocal.Execution

const ScriptEditorContext = preload("res://addons/editor_console/src/editor_plugins/script_editor.gd")
const ConsoleBridge = preload("res://addons/editor_console/src/bridge/console_bridge.gd")


var right_click_handler:RightClickHandler
var script_editor_context:ScriptEditorContext

var filter_line_edit:LineEdit
var main_hsplit:HSplitContainer
var editor_container:UtilsLocal.ConsoleContainer
var console_containers:= []

var show_filter:bool = true

var settings_helper:UtilsRemote.SettingHelperEditor
var _console_replace_filter:bool=false
# When true, mutating scene commands register on the editor undo stack (Ctrl+Z).
# When false they apply directly with no undo entry. Toggle via `config undo on|off`.
var undo_tracking:bool = true

var _cache:= {}
var _bridge:ConsoleBridge

var scope_dict:= {}
var hidden_scope_dict:= {}
var _temp_scope_dict:= {}

var variable_dict:= {}
var working_variable_dict:= {}

var filter_button:Button
var clear_button:Button

func _init(plugin:EditorPlugin) -> void:
	
	settings_helper = UtilsRemote.SettingHelperEditor.new()
	settings_helper.subscribe_property(self, &"_console_replace_filter", EditorSet.CONSOLE_REPLACE_FILTER, false)
	settings_helper.subscribe_property(self, &"undo_tracking", EditorSet.TRACK_UNDO_REDO, true)
	settings_helper.initialize()
	
	script_editor_context = ScriptEditorContext.new()
	plugin.add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE, script_editor_context)
	
	
	# add func to load user config

func _ready() -> void:
	EditorNodeRef.call_on_ready(_add_console_line_edit)
	_ready_deferred.call_deferred()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)

func _ready_deferred():
	_load_default_commands()
	EditorNodeRef.call_on_ready(_start_up_commands)
	
	if EditorSet.get_enable_gdsh():
		EditorInterface.get_script_editor().register_syntax_highlighter(UtilsLocal.GdshHl.new())

func _start_up_commands():
	var config = Config.get_merged_config()
	var startup = config.get_section(Config.STARTUP, [])
	if startup.is_empty():
		return
	var cmds = "\n".join(startup).strip_edges()
	if cmds.is_empty():
		return
	var main_ctx = get_main_ctx()
	Execution.execute_command_multiline(cmds, main_ctx)
	
	

func _on_filesystem_changed():
	if _cache == null:
		_cache = {}
	_cache.erase("files")
	_cache.erase("dirs")

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
	
	_cache.erase(ConsoleBridge.COMMAND_LIST_KEY)
	
	_get_scope_set_data(UtilsLocal.DefaultCommands)
	scope_dict.merge(_temp_scope_dict, true)
	
	var config = Config.get_merged_config()
	
	var scopes = config.get_section(Config.SCOPE, {})
	for scope in scopes.keys():
		var data = scopes.get(scope)
		var script_path = data.get(ScopeDataKeys.SCRIPT)
		if not FileAccess.file_exists(script_path):
			printerr("Could not find script: %s" % script_path)
			continue
		var script = load(script_path)
		scope_dict[scope] = {ScopeDataKeys.SCRIPT: script}
	
	var sets = config.get_section(Config.SCOPE_SET, [])
	for script_path in sets:
		_get_scope_set_data(script_path)
	
	update_consoles()
	return true




static func register_persistent_scope(scope_name:String, script_path:String, project:bool=false):
	if not _instance_valid_err(): return
	if not FileAccess.file_exists(script_path):
		printerr("Could not load script: %s" % script_path)
		return
	
	var target_config = Config.get_target_config(project)
	var scopes = target_config.get_section(Config.SCOPE, {})
	
	if scopes.has(scope_name) or get_instance().scope_dict.has(scope_name):
		print("Scope already registered: %s" % scope_name)
		return
	scopes[scope_name] = {ScopeDataKeys.SCRIPT: script_path}
	target_config.write()
	get_instance()._load_default_commands()


static func remove_persistent_scope(scope_name, project:bool=false):
	if not _instance_valid_err(): return
	
	var target_config = Config.get_target_config(project)
	var scopes = target_config.get_section(Config.SCOPE, {})
	
	if not scopes.has(scope_name):
		print("Scope not registered: %s" % scope_name)
		return
	
	scopes.erase(scope_name)
	target_config.write()
	get_instance()._load_default_commands()

static func register_persistent_scope_set(script_path:String, project:bool=false):
	if not _instance_valid_err(): return
	if not FileAccess.file_exists(script_path):
		print("Could not load script: %s" % script_path)
		return
	
	var target_config = Config.get_target_config(project)
	var sets = target_config.get_section(Config.SCOPE_SET, [])
	if script_path in sets:
		print("Script already registered as set: %s" % script_path)
		return
	
	sets.append(script_path)
	target_config.write()
	get_instance()._load_default_commands()

static func remove_persistent_scope_set(script_path:String, project:bool=false) -> void:
	if not _instance_valid_err(): return
	
	var target_config = Config.get_target_config(project)
	var sets = target_config.get_section(Config.SCOPE_SET, [])
	if not script_path in sets:
		print("Script set not registered: %s" % script_path)
		return
	
	var idx = sets.find(script_path)
	sets.remove_at(idx)
	
	target_config.write()
	get_instance()._load_default_commands()

static func register_command_dir(dir_path:String, project:bool=false):
	if not _instance_valid_err(): return
	if not dir_path.get_extension() == "":
		print("Directory path has extension: ", dir_path)
		return
	if not dir_path.ends_with("/"):
		dir_path += "/"
	
	var target_config = Config.get_target_config(project)
	var dirs = target_config.get_section(Config.COMMAND_DIRS, [])
	if dir_path in dirs:
		print("Script already registered as set: %s" % dir_path)
		return
	
	dirs.append(dir_path)
	target_config.write()
	get_instance()._load_default_commands()
	pass

static func remove_command_dir(dir_path:String, project:bool=false):
	if not _instance_valid_err(): return
	
	var target_config = Config.get_target_config(project)
	var dirs = target_config.get_section(Config.COMMAND_DIRS, [])
	if not dir_path in dirs:
		print("Script set not registered: %s" % dir_path)
		return
	
	var idx = dirs.find(dir_path)
	dirs.remove_at(idx)
	
	target_config.write()
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


#! keys parent_ctx:CompletionContext print:bool add_to_hist:bool os_mode:bool
#! keys console_container:ConsoleContainer
static func execute_interactive(input_text:String, params:={}):
	var console_container:ConsoleContainer = params.get(&"console_container")
	var print_to_log = params.get(&"print", false)
	var add_to_hist = params.get(&"add_to_hist", false)
	var active_ctx = params.get(&"parent_ctx")
	if not is_instance_valid(active_ctx):
		active_ctx = CompletionContext.new_ctx(input_text, null, true)
	
	var full_display = ""
	var split_delim = UString.string_safe_split(input_text, ";")
	for i in range(split_delim.size()):
		var line:String = split_delim[i]
		var expand_data:Dictionary = Execution.expand_commands(line, active_ctx, true)
		if active_ctx.exit_requested:
			return # expand can return an error
		
		var expanded_commands:Array = expand_data.command_statements
		if expanded_commands.size() == 1 and expanded_commands[0] == "":
			continue
		
		full_display += expand_data.display
		if i < split_delim.size() - 1:
			full_display += "; "
	
	if is_instance_valid(console_container):
		if print_to_log and input_text.strip_edges() != "os":
			var display = ""
			if not active_ctx.os_mode: # need to deal with the console container
				display = "%s %s" % [console_container.get_console_label_string(false), full_display]
			else:
				display = "%s %s" % [console_container.get_console_label_string(true), input_text.strip_edges()]
			
			console_container.print_to_console(display)
		
		if add_to_hist:
			console_container.add_to_history(input_text)
	
	
	Execution.execute_command_multiline(input_text, active_ctx)
	
	active_ctx.strip_output_newlines()
	active_ctx.strip_error_newlines()
	
	if is_instance_valid(console_container) and print_to_log:
		if not active_ctx.stdout.is_empty():
			console_container.print_to_console(active_ctx.stdout)
		if not active_ctx.stderr.is_empty():
			console_container.print_to_console("stderr:")
			console_container.print_to_console(active_ctx.stderr)
	else:
		active_ctx.clean_output()



func _add_console_line_edit():
	_get_editor_log_button_refs()
	
	filter_line_edit = BottomPanel.get_filter_line_edit()
	var vbox = filter_line_edit.get_parent()
	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(main_hsplit)
	
	editor_container = UtilsLocal.ConsoleContainer.new()
	editor_container.is_editor = true
	filter_line_edit.reparent(main_hsplit)
	filter_line_edit.show()
	main_hsplit.add_child(editor_container)
	
	editor_container.custom_minimum_size.y = filter_line_edit.size.y
	
	editor_container.console_button.pressed.connect(_toggle_console)
	editor_container.console_button.gui_input.connect(_on_button_gui_input)
	
	if is_instance_valid(filter_button):
		filter_button.toggled.connect(_on_filter_toggled)
	
	update_consoles()
	
	right_click_handler = RightClickHandler.new()
	editor_container.add_child(right_click_handler)


func _remove_console_line_edit():
	var editor_log_hbox = main_hsplit.get_parent()
	filter_line_edit.reparent(editor_log_hbox)
	filter_line_edit.show()
	
	main_hsplit.queue_free()
	filter_line_edit = null


func _get_editor_log_button_refs():
	var editor_log_button_container = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_BUTTON_CONTAINER)
	#print(editor_log_button_container)
	var buttons = UNode.recursive_get_nodes(editor_log_button_container)
	for b in buttons:
		if b is not Button:
			continue
		if UNode.get_signal_callable(b, "pressed", "EditorLog::_clear_request") != null:
			clear_button = b
		if UNode.get_signal_callable(b, "toggled", "EditorLog::_set_search_visible") != null:
			filter_button = b


func _on_filter_toggled(toggled:bool) -> void: # this is the filter toggle in editor log panel
	editor_container.visible = toggled
	if toggled:
		if not editor_container.line_edit.visible: # if console is not visible, show filter regardless of last setting
			filter_line_edit.show()
		elif not _can_show_filter():
			filter_line_edit.hide()
			editor_container.line_edit.grab_focus()
		else:
			filter_line_edit.visible = show_filter


func _toggle_console():
	editor_container.line_edit.visible = not editor_container.line_edit.visible
	if editor_container.line_edit.visible:
		main_hsplit.collapsed = false
		editor_container.console_panel.show()
		editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editor_container.line_edit.grab_focus()
		if not _can_show_filter():
			filter_line_edit.hide()
	else:
		editor_container.console_panel.hide()
		filter_line_edit.show()
		editor_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		main_hsplit.collapsed = true


func _on_button_gui_input(event):
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index == 2:
			var options = RightClickHandler.Options.new()
			options.add_option("Toggle Console", _toggle_console)
			if editor_container.line_edit.visible:
				options.add_option("Toggle Filter", _toggle_filter)
				
				# these would be dependenet on os_mode
				#options.add_option("OS/Toggle Mode", _toggle_os_mode)
				#if os_mode:
					#options.add_option("OS/Toggle Label", _toggle_os_label_minimum_size)
			right_click_handler.display_on_control(options, editor_container.console_button)



func _toggle_filter(): #^ right click toggle
	filter_line_edit.visible = not filter_line_edit.visible
	show_filter = filter_line_edit.visible

func _can_show_filter():
	return not _console_replace_filter and show_filter


func update_consoles():
	for container:ConsoleContainer in console_containers:
		container.new_ctx() # this 


static func run_gdsh(file_path:String, main_ctx:CompletionContext=null):
	if not is_instance_valid(main_ctx):
		main_ctx = get_main_ctx()

	Execution.source_file(file_path, main_ctx)
	return main_ctx






func get_gdrc():
	var main_ctx = CompletionContext.new()
	main_ctx.title = "MainCTX"
	main_ctx.execute = true
	
	main_ctx.scopes = scope_dict.duplicate()
	main_ctx.scopes.merge(hidden_scope_dict.duplicate())
	
	var config = Config.get_merged_config()
	main_ctx.aliases = config.get_section(Config.ALIAS, {}).duplicate()
	
	var home_gdrc = UtilsLocal.ConsoleOS.get_os_home_dir().path_join(".gdrc")
	if FileAccess.file_exists(home_gdrc):
		Execution.source_file(home_gdrc, main_ctx)
	
	var project_gdrc = "res://.gdrc"
	if FileAccess.file_exists(project_gdrc):
		Execution.source_file(project_gdrc, main_ctx)
	
	for var_name in variable_dict.keys():
		var val = variable_dict[var_name]
		if val is Callable:
			val = val.call()
		
		main_ctx.variables[var_name] = str(val)
	
	
	
	
	#^ caching? maybe not needed..
	#var cache_mod_time = _cache.get(file_path, -1)
	#var current_mod_time = FileAccess.get_modified_time(file_path)
	#if cache_mod_time == current_mod_time:
		#return
	#_cache[file_path] = current_mod_time
	
	
	return main_ctx

static func get_main_ctx():
	var ins = get_instance()
	#var ctx = CompletionContext.new()
	var gdrc = ins.get_gdrc()
	
	return gdrc

#! keys require_quotes:bool current_command:CommandBase show_commands:bool show_flags:bool line_edit:CodeEdit
#! keys inherited_ctx:CompletionContext
static func get_completion_for_input(input_text:String, params:={}):
	if params.get(&"require_quotes", false):
		if not UString.is_string_or_string_name(input_text) or not input_text[0] == '"':
			return {} # single quotes not allowed, why?
	
	var console = get_instance()
	
	input_text = UString.unquote(input_text)
	
	var current_command = params.get(&"current_command")
	var show_commands = params.get(&"show_commands", true)
	var show_flags = params.get(&"show_flags", true)
	
	var main = params.get(&"ctx")
	if not is_instance_valid(main):
		main = get_main_ctx()
	
	var ctx = CompletionContext.new_ctx(input_text, main)
	ctx.execute = false # ctx should not be execute for a completion
	
	if params.has(&"line_edit"):
		ctx.line_edit = params.line_edit
	
	ctx.completion_parse()
	
	if params.has(&"inherited_ctx"):
		var inh_ctx:CompletionContext = params.inherited_ctx
		ctx.word_before_cursor = inh_ctx.word_before_cursor
		ctx.char_before_cursor = inh_ctx.char_before_cursor
	
	var options = CommandBase.Options.new()
	if ctx.token_before_cursor.begins_with("@"): # list aliases
		for k in ctx.aliases.keys():
			var val = UtilsLocal.ConsoleTokenizer.clean_alias_token(ctx.aliases[k])
			options.add_option(k + " = [%s]" % val, {
				&"insert": k
			})
		return options.get_options()
	
	
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
		if ctx.functions.has(first_word):
			return {} # would need some way to get completion from function
		
		for scope:String in console.scope_dict.keys():
			options.add_option(scope)
		
		for f in ctx.functions.keys():
			options.add_option(f + "[func]", {
				&"insert": f
			})
		
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
		printerr("EditorConsoleSingleton::get_completion_for_input - Unhandled completion result: ", completion)
		return {}
	
	
	options.set_options(completion)
	
	var command_meta = options.get_options().get(UtilsLocal.Options.Keys.COMMAND_META, {})
	var show_variables = command_meta.get(UtilsLocal.Options.Keys.SHOW_VARIABLES, false)
	#show_variables = true #ALERT
	if ctx.payload_arg_index > -1:
		options.remove_option(UtilsLocal.Options.ARG_DELIMITER)
		if show_variables:
			var var_nms = console.variable_dict.keys()
			#var var_nms = ctx.variables.keys() # this will needs some work!
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

static func get_file_paths():
	return get_instance()._get_cached("files")

static func get_dir_paths():
	return get_instance()._get_cached("dirs")

func _get_cached(key:String):
	if _cache == null:
		_cache = {}
	if _cache.has(key):
		return _cache[key]
	if key == "files":
		_cache[key] = UFile.get_files("res://")
	elif key == "dirs":
		_cache[key] = UFile.scan_for_dirs("res://", false, false)
	
	return _cache.get(key)


class EditorSet:
	const CONSOLE_REPLACE_FILTER = &"plugin/editor_console/active_console_replace_filter"
	const TRACK_UNDO_REDO = &"plugin/editor_console/track_undo_redo"
	const ENABLE_GDSH = &"plugin/editor_console/enable_gdshell_highlighter"
	
	static func get_enable_gdsh():
		var ed_set = EditorInterface.get_editor_settings()
		if not ed_set.has_setting(ENABLE_GDSH):
			ed_set.set_setting(ENABLE_GDSH, false)
		return ed_set.get_setting(ENABLE_GDSH)
		

class Keys:
	const NO_MATCHING_COMMAND = &"NO_MATCHING_COMMAND"


static func new_console(window:=false):
	var container = UtilsLocal.ConsoleMainContainer.new()
	if not window:
		return container
	
	var win = Window.new()
	win.size = Vector2i(800, 800)
	win.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_KEYBOARD_FOCUS
	
	win.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.close_requested.connect(win.queue_free)
	
	EditorInterface.get_base_control().add_child(win)
	return win
