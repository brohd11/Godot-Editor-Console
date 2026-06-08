const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const RightClickHandler = UtilsRemote.RightClickHandler
const BottomPanel = UtilsRemote.BottomPanel
const UNode = UtilsRemote.UNode
const UString = UtilsRemote.UString
const Pr = UString.PrintRich


const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
#const Config = UtilsLocal.Config
#const ScopeDataKeys = UtilsLocal.ScopeDataKeys
#const Colors = UtilsLocal.Colors

#const ConsoleCommandSetBase = UtilsLocal.ConsoleCommandSetBase
#const CommandBase = UtilsLocal.CommandBase
const CompletionContext = UtilsLocal.CompletionContext

const TEST_PATH = "/Users/brohd/Library/Application Support/Godot/addons/editor_console/test.gdsh"
static func run_test():
	var string = FileAccess.get_file_as_string(TEST_PATH)
	var input_ctx = CompletionContext.new()
	execute_command_multiline(string, input_ctx)
	print("DONE")
	print(input_ctx.output)

enum ParseState { NORMAL, IN_FUNCTION, IN_CONDITIONAL }

static func execute_command_multiline(string: String, parent_ctx: CompletionContext):
	var parse_state := ParseState.NORMAL
	var accumulated_lines: PackedStringArray = []
	var block_name := ""        # func name or condition string
	var brace_depth := 0

	var lines := string.split("\n", false)
	for i in range(lines.size()):
		var line: String = lines[i]
		line = UString.remove_comment(line).strip_edges()
		if line.is_empty():
			continue

		match parse_state:
			ParseState.IN_FUNCTION:
				brace_depth += line.count("{") - line.count("}")
				if brace_depth <= 0:
					# closing } reached — store function, don't include this line
					parent_ctx.functions[block_name] = "\n".join(accumulated_lines)
					accumulated_lines.clear()
					block_name = ""
					parse_state = ParseState.NORMAL
				else:
					accumulated_lines.append(line)

			ParseState.IN_CONDITIONAL:
				brace_depth += line.count("{") - line.count("}")
				if brace_depth <= 0:
					# closing } — evaluate condition and run body if true
					_handle_conditional(block_name, accumulated_lines, parent_ctx)
					accumulated_lines.clear()
					block_name = ""
					parse_state = ParseState.NORMAL
				else:
					accumulated_lines.append(line)

			ParseState.NORMAL:
				# --- function def: my_func() { ---
				if _is_function_def(line):
					block_name = _extract_function_name(line)
					brace_depth = 1
					parse_state = ParseState.IN_FUNCTION
					accumulated_lines.clear()

				# --- conditional: if <condition> { ---
				elif line.begins_with("if ") and line.ends_with("{"):
					block_name = line.substr(3, line.length() - 4).strip_edges()
					brace_depth = 1
					parse_state = ParseState.IN_CONDITIONAL
					accumulated_lines.clear()

				# --- variable assignment: NAME=value or NAME=$(cmd) ---
				elif _is_assignment(line):
					_handle_assignment(line, parent_ctx)

				# --- fall through to command execution ---
				else:
					var sub_ctx = execute_command(line, {
						&"parent_ctx": parent_ctx
					})
					print("EXECUTING:", line, " -> ", sub_ctx.output)
	
				print("INPUT OUTPUT::",parent_ctx.output.strip_edges())


# ---- detection helpers ----

static func _is_function_def(line: String) -> bool:
	# matches: my_func() {   or   my_func(){
	return line.ends_with("{") and "(" in line and ")" in line

static func _extract_function_name(line: String) -> String:
	return line.substr(0, line.find("(")).strip_edges()

static func _is_assignment(line: String) -> bool:
	if "=" not in line:
		return false
	var left := line.substr(0, line.find("=")).strip_edges()
	# valid var name: letters, digits, underscore, no spaces
	return left.is_valid_identifier()


# ---- handlers ----

static func _handle_assignment(line: String, ctx: CompletionContext):
	var eq_pos := line.find("=")
	var var_name := line.substr(0, eq_pos).strip_edges()
	var value := line.substr(eq_pos + 1).strip_edges()

	# command substitution: VAR=$(some_command)
	if value.begins_with("$(") and value.ends_with(")"):
		var inner_cmd := value.substr(2, value.length() - 3)
		# recurse through your existing executor, capture stdout
		
		# pass parent to
		var sub_ctx = execute_command(inner_cmd, {
			&"parent_ctx": ctx,
			&"write_to_parent": false, # so that the output is not captured
		})
		value = sub_ctx.output.strip_edges()
		print("ASSIGNMENT VAL FUNC:", value)
	else:
		#print("ASSIGNMENT VAL SIMPLE:", value)
		pass

	# strip surrounding quotes if present
	if (value.begins_with("\"") and value.ends_with("\"")) \
		or (value.begins_with("'") and value.ends_with("'")):
		value = value.substr(1, value.length() - 2)
	
	value = _substitute_vars(value, ctx)

	ctx.variables["$" + var_name] = value


static func _handle_conditional(condition: String, body_lines: PackedStringArray, ctx: CompletionContext):
	if _evaluate_condition(condition, ctx):
		var body := "\n".join(body_lines)
		print("IN COND:", ctx.output.strip_edges())
		execute_command_multiline(body, ctx)
		print("AFTER COND:", ctx.output.strip_edges())


static func _evaluate_condition(condition: String, ctx: CompletionContext) -> bool:

	# check for method call form: "value".begins_with("x")
	# check for comparison: "left" == "right"  /  "left" != "right"
	if " == " in condition:
		var parts := condition.split(" == ", true, 1)
		return _substitute_vars(parts[0].strip_edges(), ctx) == _substitute_vars(parts[1].strip_edges(), ctx)
	elif " != " in condition:
		var parts := condition.split(" != ", true, 1)
		return _substitute_vars(parts[0].strip_edges(), ctx) != _substitute_vars(parts[1].strip_edges(), ctx)

	# method call as boolean: "value".begins_with("v")
	# parse and evaluate via String method dispatch
	# ... expand as needed

	return false


static func _substitute_vars(string, ctx:CompletionContext):
	if UString.is_string_or_string_name(string):
		if string[0] == "'":
			return string
		string = UString.unquote(string)
	return ctx.variables.get(string, string)


static func get_single_command_ctx(string:String, parent_ctx:CompletionContext):
	var ctx = CompletionContext.new(string)
	ctx.print = false
	ctx.add_to_hist = false
	ctx.variables = parent_ctx.variables.duplicate()
	ctx.functions = parent_ctx.functions.duplicate()
	ctx.expand()
	ctx.execute_parse()
	return ctx


#! keys i-EditorConsoleSingleton.parse_input_text; ctx_obj:CompletionContext parent_ctx:CompletionContext input_ctx:CompletionContext
#! keys write_to_parent:bool
## ctx object can be passed as argument, it should have text set already.
static func execute_command(text:String, params:={}):
	#var ctx = params.get(&"ctx_obj")
	var parent_ctx = params.get(&"parent_ctx")
	var input_ctx = params.get(&"input_ctx")
	var write_to_parent = params.get(&"write_to_parent", true)
	#if not is_instance_valid(ctx):
	var ctx = CompletionContext.new_ctx(text, parent_ctx)
	ctx.execute_parse()
	
	if is_instance_valid(input_ctx):
		ctx.input = input_ctx.output
 
	var instance = EditorConsoleSingleton.get_instance()
	
	params[&"main_ctx"] = ctx
	instance.parse_input_text(text, params)
	if write_to_parent and is_instance_valid(parent_ctx):
		print("CHILD::", ctx.output)
		print("PARENT::", parent_ctx.output)
		if not ctx.output.is_empty():
			parent_ctx.append_output(ctx.output)
	return ctx

static func source_file(file_path:String, main_ctx:CompletionContext=null):
	if not is_instance_valid(main_ctx):
		main_ctx = EditorConsoleSingleton.get_main_ctx()
	
	var file_string = FileAccess.get_file_as_string(file_path)
	if file_string.begins_with("#!gdsh"):
		execute_command_multiline(file_string, main_ctx)
		return main_ctx
	
	execute_command("os " + file_path, {
		&"parent_ctx": main_ctx
	})
	print("SOURCE::", main_ctx.output)
	return main_ctx
