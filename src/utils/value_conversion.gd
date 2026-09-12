const PRINT_DEBUG = false
const UString = preload("res://addons/editor_console/src/utils/console_utils_remote.gd").UString

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
