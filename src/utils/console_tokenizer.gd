
const PLUGIN_EXPORTED = false
const PRINT_DEBUG = EditorConsoleSingleton.PRINT_DEBUG

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Colors = UtilsLocal.Colors
const Config = UtilsLocal.Config
const CompletionContext = UtilsLocal.CompletionContext
const Execution = UtilsLocal.Execution

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UString = UtilsRemote.UString
const Pr = UtilsRemote.UString.PrintRich
const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

const HL_TOKENS = ["[", "]", "&&", "||", "==", "!=", "|"]
const UNDEFINED = "%%%__UNDEFINED__"

var editor_console:EditorConsoleSingleton

var active_ctx:CompletionContext
var execute:bool=false



static var _token_regex:RegEx
static var variable_regex:RegEx

var color_var_ok = "96f442"
var color_var_fail = "cc000c"
var color_var_value = "6d6d6d"

func _init(_active_ctx:CompletionContext) -> void:
	active_ctx = _active_ctx
	_initialize_regex()
	
	editor_console = EditorConsoleSingleton.get_instance()

static func _initialize_regex():
	if not is_instance_valid(_token_regex):
		_token_regex = RegEx.new()
		var sq     := "(?<sq>'[^']*')"
		var dq     := "(?<dq>\"(?:\\\\.|(?&cs)|[^\"\\\\])*\")"
		var cs     := "(?<cs>\\$\\((?:\\\\.|(?&dq)|(?&sq)|(?&cs)|(?&par)|[^()\"'\\\\])*\\))"
		var par    := "(?<par>\\((?:\\\\.|(?&dq)|(?&sq)|(?&cs)|(?&par)|[^()\"'\\\\])*\\))"
		var define := "(?(DEFINE)" + sq + dq + cs + par + ")"
		var word   := "(?:(?&dq)|(?&sq)|(?&cs)|\\\\.|[^\\s\"'\\\\])+"

		_token_regex = RegEx.new()
		_token_regex.compile(define + word)
	
	if not is_instance_valid(variable_regex) or true:
		variable_regex = RegEx.new()
		#variable_regex.compile("\\$[\\w+|?|@|#]\\b")
		variable_regex.compile("\\$(?:\\w+\\b|[?@#])")

static func get_variable_regex():
	_initialize_regex()
	return variable_regex


#! keys commands:PackedStringArray expanded:PackedStringArray args:PackedStringArray display:String
func parse_command_string_completion(input_string: String, allow_expand:=true) -> Dictionary:
	_initialize_regex()
	var result := {
		"commands": PackedStringArray(),
		"expanded": PackedStringArray(),
		"args": PackedStringArray(),
	}
	
	var split = split_args(input_string)
	var command_str:String = split[0]
	var args_str:String = split[1]
	
	var raw_command_data = _tokenize_string(command_str, false, false)
	result.commands = raw_command_data.expanded
	# allow expand will allow command substitution to run during autocomplete. This may be undesired
	var expanded_command_tok_data = _tokenize_string(command_str, allow_expand)
	result.expanded = expanded_command_tok_data.expanded
	var arg_tok_data = _tokenize_string(args_str, false)
	result.args = arg_tok_data.expanded
	
	return result


#! keys commands:PackedStringArray expanded:PackedStringArray args:PackedStringArray display:String
func parse_command_string_execute(input_string: String, display:=false) -> Dictionary:
	_initialize_regex()
	var result := {
		"expanded": PackedStringArray(),
		"args": PackedStringArray(),
		"display": ""
	}
	var split = split_args(input_string)
	var command_str:String = split[0]
	var args_str:String = split[1]
	
	var command_tok_data = _tokenize_string(command_str, true, display)
	result.expanded = command_tok_data.expanded
	var arg_tok_data = _tokenize_string(args_str, false, display)
	result.args = arg_tok_data.expanded
	
	if display:
		if arg_tok_data.display != "":
			result.display = "%s -- %s" % [command_tok_data.display, arg_tok_data.display]
		else:
			result.display = command_tok_data.display
		
	return result

func _tokenize_string(text: String, expand:bool=true, display:=false) -> Dictionary:
	if text.is_empty():
		return {"expanded": PackedStringArray(), "display": ""}
	
	var expanded_tokens = []
	var display_string = ""
	var matches = _token_regex.search_all(text)
	for _match in matches:
		var token = _match.get_string()
		if token == "":
			if PRINT_DEBUG:
				print("BLANK TOK")
			continue
		
		# this seems to only be used by arguments, which are not having the old arg logic applied
		# potentially also by autocomplete. If not wanting to run the command substitiuion
		# perhaps a more granular setting could be used, to allow alias changes, but no commands to run.
		if not expand:
			var var_check = _check_variable(token, display)
			expanded_tokens.append(var_check)
			if display and var_check != token:
				display_string += " " + wrap_variable(token, var_check)
			continue
		
		var is_string = UString.is_string_or_string_name(token)
		
		# command substitution
		if token.lstrip("\"'").begins_with("$("): # and token.trim_prefix("$").strip_edges().begins_with("("):
			var stripped = UString.unquote(token)
			var var_check = _check_variable(stripped, display)
			if var_check == token:
				expanded_tokens.append(token)
				if display:
					display_string += " " + _get_token_color(token)
			else:
				if is_string:
					var qu = token[0]
					expanded_tokens.append(qu + var_check + qu)
					if display:
						var tok_display = qu + var_check
						tok_display += qu
						display_string += " " + wrap_variable(token, tok_display)
				else:
					var split = UString.string_safe_split_multi(var_check, [" ", "\t", "\n"])
					expanded_tokens.append_array(split)
					if display:
						var tok_display:= ""
						for s in split:
							tok_display += s
							if tok_display.length() > 20:
								break
							tok_display += " "
						
						display_string += " " + wrap_variable(token, tok_display)
			
			continue
		# end command substitution
		
		
		# expansion
		var expanded = [token]
		if not is_string:
			expanded = _expand_token(token, active_ctx.aliases)
		
		var expanded_display = ""
		for e in expanded:
			var var_check = _check_variable(e, display)
			if not display:
				expanded_tokens.append(var_check)
			
			if display:
				var is_undef = var_check.contains(UNDEFINED)
				if not is_undef:
					expanded_tokens.append(var_check)
					if var_check != e:
						expanded_display += " " + wrap_variable(e, var_check)
					else:
						expanded_display += " " + _get_token_color(e)
				
				else:
					expanded_tokens.append(e)
					var inner = var_check.replace(UNDEFINED, wrap_color("undef", color_var_fail))
					var undef = " " + wrap_variable(e, "__PLACEHOLDER__")
					undef = undef.replace("__PLACEHOLDER__", inner)
					expanded_display += " " + undef
		
		
		if display:
			expanded_display = expanded_display.strip_edges()
			if (expanded.size() > 1 or expanded[0] != token):
				display_string += " " + wrap_variable(expanded_display, token)
			else:
				display_string += " " + expanded_display # _get_token_color(expanded_display)
		# end expansion
	
	return {
		"expanded": expanded_tokens,
		"display": display_string.strip_edges()
	}


func _get_token_color(token:String):
	
	var var_token_check = UString.unquote(token)
	var is_string = UString.is_string_or_string_name(token)
	var quote_char = ""
	if is_string:
		quote_char = token[0]
		var_token_check = UString.unquote(token)
	
	if var_token_check in HL_TOKENS:
		var_token_check = wrap_color(var_token_check, UtilsLocal.Colors.SYMBOL.to_html())
	elif UClassDetail.get_global_class_path(var_token_check) != "":
		var_token_check = wrap_color(var_token_check, EditorColors.get_syntax_color(EditorColors.SyntaxColor.ENGINE_TYPE).to_html())
	elif is_instance_valid(active_ctx):
		if var_token_check in active_ctx.scopes:
			var_token_check = wrap_color(var_token_check, UtilsLocal.Colors.SCOPE.to_html())
		elif var_token_check in active_ctx.functions:
			var_token_check = wrap_color(var_token_check, EditorColors.get_syntax_color(EditorColors.SyntaxColor.FUNCTION_DEFINITION).to_html())
	
	# if active ctx not set, should be always though I think...
	elif var_token_check in editor_console.scope_dict or var_token_check in editor_console.hidden_scope_dict:
		var_token_check = wrap_color(var_token_check, UtilsLocal.Colors.SCOPE.to_html())
	
	if is_string:
		var_token_check = quote_char + var_token_check + quote_char
	
	return var_token_check


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


func _check_variable(token:String, display:=false):
	return check_variable(token, active_ctx, display)

static func check_variable(token:String, active:CompletionContext, display:=false):
	if not token.contains("$"):
		return token
	_initialize_regex()
	#^r should this be unquoted here?
	if token.begins_with("$("):
		if PRINT_DEBUG:
			print("CHECK VAR: ", token)
		
		if not is_instance_valid(active) or not active.execute:
			return token  # don't want to execute when doing completions
		
		var stripped = token.trim_prefix("$(").trim_suffix(")")
		stripped = check_variable(stripped, active, display) # check nested variables before sending
		var sub_shell_ctx:CompletionContext = Execution.execute_command(stripped, {
			&"parent_ctx": active,
			&"sub_shell": true
		})
		
		return sub_shell_ctx.strip_output_newlines()
	
	var is_string = UString.is_string_or_string_name(token)
	var quote_char = ""
	if is_string:
		quote_char = token[0]
		if quote_char == "'":
			return token
	
	if token.contains("$"):
		var stripped_token = token
		if is_string:
			stripped_token = UString.unquote(token)
		
		var matches = variable_regex.search_all(stripped_token)
		
		var new_string = ""
		var last_end = 0
		for i in range(matches.size()):
			var m = matches[i]
			var var_string = m.get_string()
			# in os mode, this can pass through env variables
			# returning quotes as default, otherwise the value can dissapear
			
			
			var var_check = ""
			if var_string.trim_prefix("$").is_valid_int():
				var index = var_string.trim_prefix("$").to_int()
				if index == 0:
					var_check = active.variables.get("$0")
				else:
					index -= 1
					if index < active.positional_args.size():
						var_check = active.positional_args[index]
					else:
						var_check = ""
					
			elif var_string in ["$?", "$#", "$@"]: #special handled chars
				match var_string:
					"$?": var_check = str(active.last_status)
					"$#": var_check = str(active.positional_args.size())
					"$@": var_check = " ".join(active.positional_args)
			else:
				var default_empty = "" if is_string else "''"
				var default = var_string if active.os_mode else default_empty
				if display: 
					#default = var_string + UNDEFINED
					default = UNDEFINED
				var_check = active.variables.get(var_string, default)
			
			if PRINT_DEBUG:
				print(display, ":DISP:TOKEN:",var_string, " -> ", var_check)
			
			if var_check != var_string and var_check.contains("$") and not var_check.contains(UNDEFINED):
				if PRINT_DEBUG:
					print("RECUR CHEK;", var_string, " -> ", var_check)
				var_check = check_variable(var_check, active)
			
			var left = stripped_token.substr(last_end, m.get_start() - last_end)
			new_string += left + var_check
			last_end = m.get_end()
		
		new_string += stripped_token.substr(last_end)
		
		if is_string:
			new_string = quote_char + new_string + quote_char
		
		if PRINT_DEBUG:
			print("RETURN:", token, " -> ", new_string)
		return new_string
	return token


static func wrap_color(string:String, color:String):
	return "[color=%s]%s[/color]" % [color, string]

func wrap_variable(var_name:String, value:String):
	var template = "[color=%s][[/color]%s[color=%s]]%s[/color]"
	return template % [color_var_value, shorten_var_string(value), color_var_value, shorten_var_string(var_name)]

static func shorten_var_string(string:String):
	if string.length() > 20:
		string = string.left(20) + "..."
	return string.replace("\n", " ").strip_edges()

static func split_args(input_string:String) -> Array[String]:
	var command_str := input_string
	var args_str := ""
	if input_string.find("-- ") == -1:
		return [command_str, args_str]
	var delim = "-- "
	var separator_pos = UString.string_safe_find(input_string, delim, 0)
	if separator_pos != -1:
		command_str = input_string.substr(0, separator_pos).strip_edges()
		args_str = input_string.substr(separator_pos + delim.length()).strip_edges()
	else:
		# If no separator, the whole string is considered commands
		command_str = input_string.strip_edges()
	return [command_str, args_str]


static func shell_quote(s: String, quote_char:="'") -> String:
	# Wrap in single quotes; turn any embedded ' into '\''
	if quote_char == "'":
		return "'" + s.replace("'", "'\\''") + "'"
	else:
		return '"' + s.replace('"', '\\"') + '"'

static func clean_alias_token(token:String):
	return token.trim_prefix("@literal")

class Var:
	const NUM_TYPES = ["int", "float"]
	
	static func auto_convert(arg:Variant, target_type:int, base_type:String=""):
		var passed_type = typeof(arg)
		if PRINT_DEBUG:
			print("Convert: ", arg, " ", type_string(passed_type), " -> " ,type_string(target_type))
		if passed_type == TYPE_STRING: # string conversions
			arg = arg as String
			if target_type == TYPE_INT and base_type != "":
				var int_chk = _check_class_for_const(arg, base_type)
				if int_chk != -1:
					return int_chk
			
			
			if target_type == TYPE_OBJECT:
				return null
			if target_type == TYPE_STRING_NAME:
				return StringName(arg)
			elif target_type == TYPE_STRING:
				return arg
			elif target_type == TYPE_BOOL:
				if arg == "true":
					return true
				if arg == "false":
					return false
				return null
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
			elif target_type in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I,
					TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I]:
				# Build structured types from a bare or prefixed tuple, e.g. "(1, 0, 0)"
				# or "Vector3(1, 0, 0)". target_type disambiguates Vec3 vs Color etc.
				if target_type == TYPE_COLOR and (arg.begins_with("#") or arg.is_valid_html_color()):
					return Color(arg)
				var nums := _parse_tuple(arg)
				var need := {
					TYPE_VECTOR2: 2, TYPE_VECTOR2I: 2,
					TYPE_VECTOR3: 3, TYPE_VECTOR3I: 3,
					TYPE_VECTOR4: 4, TYPE_VECTOR4I: 4,
					TYPE_COLOR: 3, TYPE_RECT2: 4, TYPE_RECT2I: 4,
				}
				if nums.size() < need[target_type]:
					return null
				match target_type:
					TYPE_VECTOR2:  return Vector2(nums[0], nums[1])
					TYPE_VECTOR2I: return Vector2i(nums[0], nums[1])
					TYPE_VECTOR3:  return Vector3(nums[0], nums[1], nums[2])
					TYPE_VECTOR3I: return Vector3i(nums[0], nums[1], nums[2])
					TYPE_VECTOR4:  return Vector4(nums[0], nums[1], nums[2], nums[3])
					TYPE_VECTOR4I: return Vector4i(nums[0], nums[1], nums[2], nums[3])
					TYPE_COLOR:    return Color(nums[0], nums[1], nums[2], nums[3] if nums.size() > 3 else 1.0)
					TYPE_RECT2:    return Rect2(nums[0], nums[1], nums[2], nums[3])
					TYPE_RECT2I:   return Rect2i(nums[0], nums[1], nums[2], nums[3])
			else:
				# Last resort: let Godot parse its own var_to_str output (prefixed forms).
				var parsed = str_to_var(arg)
				if PRINT_DEBUG:
					print("CONVERTED::", parsed)
				if parsed != null:
					return parsed


		return null

	# Parse a numeric tuple from "(a, b, c)", "[a, b, c]", "Type(a, b, c)" or "a, b, c".
	# Returns an Array of floats, or an empty Array if any component isn't numeric.
	static func _parse_tuple(s:String) -> Array:
		s = s.strip_edges()
		var open := s.find("(")
		if open == -1:
			open = s.find("[")
		if open != -1:
			var close := s.rfind(")")
			if close == -1:
				close = s.rfind("]")
			if close > open:
				s = s.substr(open + 1, close - open - 1)
		var out := []
		for p in s.split(",", false):
			var t := p.strip_edges()
			if not t.is_valid_float():
				return []
			out.append(t.to_float())
		return out
	
	static func _check_class_for_const(arg:String, base_type:String):
		if ClassDB.class_has_integer_constant(base_type, arg):
			return ClassDB.class_get_integer_constant(base_type, arg)
		elif arg.count(".") >= 1:
			var front = UString.get_member_access_front(arg)
			var back = UString.trim_member_access_back(arg)
			if arg.count(".") == 2:
				return _check_class_for_const(back, front)
			elif arg.count(".") > 2:
				return -1
			if ClassDB.class_has_enum(base_type, front):
				return ClassDB.class_get_integer_constant(front, back)
			elif ClassDB.class_exists(front):
				return _check_class_for_const(back, front)
		return -1
	
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


# deprecation station

func _get_token_color_old(token:String, pr:Pr, leading_space:bool, is_expanded:bool):
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
		
		var matches = variable_regex.search_all(stripped_token)
		if is_string:
			pr.append(quote_char)
		
		var new_string = ""
		var last_end = 0
		for i in range(matches.size()):
			var m = matches[i]
			var var_string = m.get_string()
			var var_check = active_ctx.variables.get(var_string, var_string)
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
		
		return new_string
	
	if is_expanded:
		pr.append("%s" % token, color_var_value)
	elif token in editor_console.scope_dict or token in editor_console.hidden_scope_dict:
		pr.append(token, UtilsLocal.Colors.SCOPE)
	elif UClassDetail.get_global_class_path(token) != "":
		pr.append("%s" % token, EditorColors.get_syntax_color(EditorColors.SyntaxColor.ENGINE_TYPE))
	elif token.find("<") > -1:
		var_token_check = _check_variable(token)
		pr.append("%s" % token)
	elif token.find("#") > -1: # not sure what this is about? expression?
		var_token_check = _check_variable(token)
		pr.append("%s" % token)
	else:
		pr.append("%s" % token)
	
	return var_token_check
