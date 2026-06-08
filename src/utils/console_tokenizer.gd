
const PLUGIN_EXPORTED = false
const PRINT_DEBUG = PLUGIN_EXPORTED or false

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Colors = UtilsLocal.Colors
const Config = UtilsLocal.Config

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UString = UtilsRemote.UString
const Pr = UtilsRemote.UString.PrintRich
const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

var editor_console:EditorConsoleSingleton

var variables := {}


static var _token_regex:RegEx
static var _variable_regex:RegEx

var color_var_ok = "96f442"
var color_var_fail = "cc000c"
var color_var_value = "6d6d6d"

func _init() -> void:
	_initialize_regex()
	
	editor_console = EditorConsoleSingleton.get_instance()

func _initialize_regex():
	if not is_instance_valid(_token_regex):
		_token_regex = RegEx.new()
		var pattern = "\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*'|(\\[^']*)|(\\{(?:[^{}]|(?2))*\\})|(\\((?:[^()]|(?3))*\\))|\\S+"
		#var pattern = "\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*'|(\\[(?:[^\\[\\]]|(?1))*\\])|(\\{(?:[^{}]|(?2))*\\})|(\\((?:[^()]|(?3))*\\))|\\S+"
		_token_regex.compile(pattern)
	
	if not is_instance_valid(_variable_regex):
		_variable_regex = RegEx.new()
		_variable_regex.compile("\\$\\w+\\b")

#! keys commands:PackedStringArray expanded:PackedStringArray args:PackedStringArray display:String
func parse_command_string(input_string: String, expand:=false) -> Dictionary:
	_initialize_regex()
	var result := {
		"commands": PackedStringArray(),
		"expanded": PackedStringArray(),
		"args": PackedStringArray(),
		"display":"",
	}
	var command_str := input_string
	var args_str := ""
	var string_map = UString.get_string_map(input_string)
	var delim = "-- "
	var separator_pos = UString.string_safe_find(input_string, delim, 0, string_map)
	if separator_pos != -1:
		command_str = input_string.substr(0, separator_pos).strip_edges()
		args_str = input_string.substr(separator_pos + delim.length()).strip_edges()
	else:
		# If no separator, the whole string is considered commands
		command_str = input_string.strip_edges()
	
	var command_tok_data = _tokenize_string(command_str, expand)
	var arg_tok_data = _tokenize_string(args_str)
	result.commands = command_tok_data.tokens
	result.expanded = command_tok_data.expanded
	result.args = arg_tok_data.tokens
	
	if arg_tok_data.display != "":
		result.display = "%s -- %s" % [command_tok_data.display, arg_tok_data.display]
	else:
		result.display = command_tok_data.display
	
	return result


func _tokenize_string(text: String, expand:bool=false) -> Dictionary:
	var tokens = PackedStringArray()
	if text.is_empty():
		return {"tokens":tokens, "expanded": PackedStringArray(), "display":""}
	
	var config = Config.get_merged_config()
	var alias_data:Dictionary = config.get_section(Config.ALIAS)
	
	var pr = Pr.new()
	
	var expanded_tokens = []
	var matches = _token_regex.search_all(text)
	for _match in matches:
		var token = _match.get_string()
		if token == "":
			if PRINT_DEBUG:
				print("BLANK TOK")
			continue
		
		var is_first = _match == matches[0]
		var is_expanded = false
		
		if expand:
			var expanded = _expand_token(token, alias_data)
			is_expanded = expanded[0] != token
			if is_expanded:
				pr.append("[", color_var_value)
			
			for i in range(expanded.size()):
				var e = expanded[i]
				var var_check = _get_token_color(e, pr, i > 0 or not is_expanded, false)
				expanded_tokens.append(var_check)
				is_first = false
			
			if is_expanded:
				pr.append("]", color_var_value)
				_get_token_color(token, pr, false, is_expanded)
		
		if not expand:
			var var_token_check = _get_token_color(token, pr, not is_first, is_expanded)
			tokens.push_back(var_token_check)
		else:
			tokens.push_back(_check_variable(token))
	
	
	return {
		"tokens": tokens,
		"expanded": expanded_tokens,
		"display": pr.get_string().strip_edges(),
	}


func _get_token_color(token:String, pr:Pr, leading_space:bool, is_expanded:bool):
	var is_string = UString.is_string_or_string_name(token)
	var quote_char = ""
	if is_string:
		quote_char = token[0]
	var var_token_check = token
	
	if leading_space:
		pr.append(" ")
	
	if token.contains("$"):
		var stripped_token = token
		if UString.is_string_or_string_name(token):
			stripped_token = UString.unquote(token)
		#print("STRIPPED:", stripped_token)
		
		var matches = _variable_regex.search_all(stripped_token)
		if is_string:
			pr.append(quote_char)
		
		var new_string = ""
		var last_end = 0
		for i in range(matches.size()):
			var m = matches[i]
			var var_string = m.get_string()
			var var_check = variables.get(var_string, var_string)
			var left = stripped_token.substr(last_end, m.get_start() - last_end)
			new_string += left + var_check
			last_end = m.get_end()
			if var_check:
				pr.append(left).append("[", color_var_value).append(var_check).append("]", color_var_value).append(var_string, color_var_ok)
			else:
				pr.append(var_string)
			
			if i < matches.size() - 1:
				pr.append(" ")
		
		new_string += stripped_token.substr(last_end)
		
		if is_string:
			pr.append(quote_char)
			new_string = quote_char + new_string + quote_char
		
		#print("RETURN:", token, " -> ", new_string)
		return new_string
	
	if is_expanded:
		pr.append("%s" % token, color_var_value)
	elif token in editor_console.scope_dict or token in editor_console.hidden_scope_dict:
		pr.append(token, editor_console.Colors.SCOPE)
	elif UClassDetail.get_global_class_path(token) != "":
		pr.append("%s" % token, EditorColors.get_syntax_color(EditorColors.SyntaxColor.ENGINE_TYPE))
	elif token.find("<") > -1:
		if editor_console:
			var_token_check = _check_variable(token)
		pr.append("%s" % token)
	elif token.find("#") > -1: # not sure what this is about? expression?
		if editor_console:
			var_token_check = _check_variable(token)
		pr.append("%s" % token)
	else:
		pr.append("%s" % token)
	
	return var_token_check


static func shell_quote(s: String, quote_char:="'") -> String:
	# Wrap in single quotes; turn any embedded ' into '\''
	if quote_char == "'":
		return "'" + s.replace("'", "'\\''") + "'"
	else:
		return '"' + s.replace('"', '\\"') + '"'


func _expand_token(token, alias_data:Dictionary, seen_tokens:={}):
	if seen_tokens.has(token):
		return []
	seen_tokens[token] = true
	var quote_char = ""
	if UString.is_string_or_string_name(token):
		quote_char = token[0]
		if quote_char == "'":
			return [token]
		token = UString.unquote(token)
	
	var expanded_tokens = []
	var parts = [token]
	if token.contains(" "):
		parts = UString.string_safe_split(token, " ", true)
	
	for tok in parts:
		if tok == " ":
			continue
		var expand = alias_data.get(tok)
		if expand == null:
			expanded_tokens.append(tok)
			continue
		expand = clean_alias_token(expand)
		var recur_expanded = _expand_token(expand, alias_data, seen_tokens)
		expanded_tokens.append_array(recur_expanded)
	if quote_char != "":
		var requote = " ".join(expanded_tokens)
		if not UString.is_string_or_string_name(requote):
			requote = '"' + requote + '"'
		
		if PRINT_DEBUG:
			print("REQUOTE:", requote)
		
		return [requote]
	return expanded_tokens

static func clean_alias_token(token:String):
	return token.trim_prefix("@literal")

#func _check_variable(arg:String):
	#if arg.begins_with("$"):
		#var variable_callable = editor_console.variable_dict.get(arg)
		#if variable_callable:
			#var variable = variable_callable.call()
			#if variable is String:
				#editor_console.working_variable_dict[variable] = variable
				#return variable
			#else:
				#editor_console.working_variable_dict[variable.to_string()] = variable
				#return variable.to_string()
	#
	#
	#var exp_idx = arg.find('{#')
	#if exp_idx > -1:
		#var expr = Expression.new()
		#var arg_stripped = arg.replace("'","").replace('"',"").trim_prefix("{#").trim_suffix("}")
		#if arg_stripped.find("<") > -1:
			#
			#pass
		#var err = expr.parse(arg_stripped)
		#if err == OK:
			#var result = expr.execute()
			#if PRINT_DEBUG:
				#print(result)
			#var type = Var.check_type(arg)
			#if type:
				#result = Var.string_to_type(result, type)
			#editor_console.working_variable_dict[arg] = result
			#return arg
	#
	#var type_str = Var.check_type(arg)
	#if type_str:
		#var variable = Var.string_to_type(arg, type_str)
		#editor_console.working_variable_dict[arg] = variable
		#return arg
	#
	#return arg

func _check_variable(token:String):
	# should be a while loop? to make sure variables set to other variables are checked?
	if token.begins_with("$"):
		var var_check = variables.get(token)
		if var_check != null:
			if var_check is String:
				return var_check
			return str(var_check)
	
	return token
	
	
	var exp_idx = token.find('{#')
	if exp_idx > -1:
		var expr = Expression.new()
		var arg_stripped = token.replace("'","").replace('"',"").trim_prefix("{#").trim_suffix("}")
		if arg_stripped.find("<") > -1:
			
			pass
		var err = expr.parse(arg_stripped)
		if err == OK:
			var result = expr.execute()
			if PRINT_DEBUG:
				print(result)
			var type = Var.check_type(token)
			if type:
				result = Var.string_to_type(result, type)
			editor_console.working_variable_dict[token] = result
			return token
	
	var type_str = Var.check_type(token)
	if type_str:
		var variable = Var.string_to_type(token, type_str)
		editor_console.working_variable_dict[token] = variable
		return token
	
	return token

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
		if PRINT_DEBUG:
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
				if PRINT_DEBUG:
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
