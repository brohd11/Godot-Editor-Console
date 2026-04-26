
const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Colors = UtilsLocal.Colors

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UString = UtilsRemote.UString
const Pr = UtilsRemote.UString.PrintRich
const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

var editor_console:EditorConsoleSingleton



var _token_regex:= RegEx.new()

var color_var_ok = "96f442"
var color_var_fail = "cc000c"
var color_var_value = "6d6d6d"

func _init() -> void:
	var pattern = "\"[^\"]*\"|'[^']*'|(\\[(?:[^\\[\\]]|(?1))*\\])|(\\{(?:[^{}]|(?2))*\\})|(\\((?:[^()]|(?3))*\\))|\\S+"
	_token_regex.compile(pattern)
	
	editor_console = EditorConsoleSingleton.get_instance()

func parse_command_string(input_string: String) -> Dictionary:
	var result := {
		"commands": PackedStringArray(),
		"args": PackedStringArray(),
		"display":"",
	}
	var command_str := input_string
	var args_str := ""
	var separator_pos = input_string.find(" -- ")
	if separator_pos != -1:
		command_str = input_string.substr(0, separator_pos).strip_edges()
		args_str = input_string.substr(separator_pos + 4).strip_edges()
	else:
		# If no separator, the whole string is considered commands
		command_str = input_string.strip_edges()
	
	var command_tok_data = _tokenize_string(command_str)
	var arg_tok_data = _tokenize_string(args_str)
	result.commands = command_tok_data.tokens
	result.args = arg_tok_data.tokens
	
	if arg_tok_data.display != "":
		result.display = "%s -- %s" % [command_tok_data.display, arg_tok_data.display]
	else:
		result.display = command_tok_data.display
	
	return result

func _tokenize_string(text: String) -> Dictionary:
	var tokens = PackedStringArray()
	if text.is_empty():
		return {"tokens":tokens, "display":""}
	
	var pr = Pr.new()
	
	var matches = _token_regex.search_all(text)
	for _match in matches:
		var token = _match.get_string()
		# Check for and remove the surrounding quotes from the captured token
		if (token.begins_with("\"") and token.ends_with("\"")) or \
			(token.begins_with("'") and token.ends_with("'")):
			# This removes the first and last character (the quote)
			token = token.substr(1, token.length() - 2)
		
		var var_token_check = token
		if token.begins_with("$"):
			var_token_check = _check_variable(token)
			if var_token_check != token:
				pr.append(" ").append(token, color_var_ok).append(" ").append(var_token_check, color_var_value)
			else:
				pr.append(" ").append(token, color_var_fail).append(" ").append("Could not get var", color_var_value)
		elif token in editor_console.scope_dict or token in editor_console.hidden_scope_dict:
			var token_str = "%s" % token
			if _match != matches[0]:
				token_str = " %s" % token
			pr.append(token_str, editor_console.Colors.SCOPE)
		elif UClassDetail.get_global_class_path(token) != "":
			pr.append(" %s" % token, EditorColors.get_syntax_color(EditorColors.SyntaxColor.ENGINE_TYPE))
		elif token.find("<") > -1:
			if editor_console:
				var_token_check = _check_variable(token)
			pr.append(" %s" % token)
		elif token.find("#") > -1:
			if editor_console:
				var_token_check = _check_variable(token)
			pr.append(" %s" % token)
		else:
			pr.append(" %s" % token)
		
		tokens.push_back(var_token_check)
	
	return {
		"tokens": tokens,
		"display": pr.get_string().strip_edges(),
	}


func _check_variable(arg:String):
	if arg.begins_with("$"):
		var variable_callable = editor_console.variable_dict.get(arg)
		if variable_callable:
			var variable = variable_callable.call()
			if variable is String:
				editor_console.working_variable_dict[variable] = variable
				return variable
			else:
				editor_console.working_variable_dict[variable.to_string()] = variable
				return variable.to_string()
	
	
	var exp_idx = arg.find('{#')
	if exp_idx > -1:
		var exp = Expression.new()
		var arg_stripped = arg.replace("'","").replace('"',"").trim_prefix("{#").trim_suffix("}")
		if arg_stripped.find("<") > -1:
			
			pass
		var err = exp.parse(arg_stripped)
		if err == OK:
			var result = exp.execute()
			print(result)
			var type = Var.check_type(arg)
			if type:
				result = Var.string_to_type(result, type)
			editor_console.working_variable_dict[arg] = result
			return arg
	
	var type_str = Var.check_type(arg)
	if type_str:
		var variable = Var.string_to_type(arg, type_str)
		editor_console.working_variable_dict[arg] = variable
		return arg
	
	return arg

func get_arg_variables(args:Array):
	var vars = []
	for arg in args:
		vars.append(get_variable(arg))
	return vars

func get_variable(variable_string):
	var variable = editor_console.working_variable_dict.get(variable_string)
	if variable:
		return variable
	else:
		#printerr("Failed to get variable: %s" % variable_string)
		return variable_string



class Var:
	const NUM_TYPES = ["int", "float"]
	
	static func auto_convert(arg:Variant, target_type:int):
		var passed_type = typeof(arg)
		print("Convert: ", arg, type_string(passed_type), " -> " ,type_string(target_type))
		if passed_type == TYPE_STRING: # string conversions
			arg = arg as String
			if target_type == TYPE_OBJECT:
				return null
			if target_type == TYPE_STRING_NAME:
				return StringName(arg)
			elif target_type == TYPE_BOOL:
				if arg in ["true", "t", "y", "1"]:
					return true
				if arg in ["false", "f", "n", "0"]:
					return false
			elif target_type == TYPE_FLOAT:
				var val = arg.to_float()
				if is_zero_approx(val) and not arg.is_valid_float():
					return null
				return val
			elif target_type == TYPE_INT:
				var val = arg.to_int()
				if val == 0 and not arg.begins_with("0"):
					return null
				return val
			elif target_type == TYPE_ARRAY:
				if not arg.begins_with("[") and arg.ends_with("]"):
					return null
				var contents = arg.trim_prefix("[").trim_suffix("]")
				var array = []
				var parts = contents.split(",", false)
				for p:String in parts:
					var stripped = p.strip_edges()
					if stripped.ends_with("'") or stripped.ends_with('"'):
						array.append(UString.unquote(stripped))
					else:
						array.append(infer_type(stripped))
				return array
			else:
				var converted = type_convert(arg, target_type)
				print("CONVERTED::", converted)
				return converted
		
		
		return null
	
	
	static func infer_type(string:String):
		if string in ["true", "t", "y"]:
			return true
		if string in ["false", "f", "n"]:
			return false
		if string.is_valid_int():
			return string.to_int()
		if string.is_valid_float():
			return string.to_float()
		if string.is_valid_html_color():
			return Color.html(string)
		
		return string
	
	static func check_type(arg):
		var type_idx = arg.find("<")
		if type_idx > -1 and arg.find(">") > type_idx:
			var raw_arg = arg.get_slice("<", 0)
			var type = arg.get_slice("<", 1)
			type = type.get_slice(">", 0)
			var variable = Var.string_to_type(raw_arg, type)
			return type
		return
	
	
	static func string_to_type(arg:String, type_str:String):
		if type_str in NUM_TYPES:
			return _string_to_num(arg, type_str)
		if type_str == "b":
			return _string_to_bool(arg)
	
	
	static func _string_to_num(arg:String, type_str:String):
		if type_str == "int":
			return arg.to_int()
		if type_str == "float":
			return arg.to_float()
	
	static func _string_to_bool(arg):
		if arg == "true" or arg == "1":
			return true
		elif arg == "false" or arg == "0":
			return false
		else:
			printerr("Error getting argument: %s" % arg)
			return arg
		
