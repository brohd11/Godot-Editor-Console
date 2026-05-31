extends EditorConsoleSingleton.CommandBase

const UFile = UtilsRemote.UFile
const UString = UtilsRemote.UString
const GDScriptParse = UString.GDScriptParse

static func get_command_name() -> String:
	return "bundle"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": "Load preloads into the current script."
	})


func _execute(_ctx:CompletionContext):
	_resolve_const(ScriptEditorRef.get_current_code_edit())

static func _resolve_const(script_editor:CodeEdit):
	var current_script_path = ScriptEditorRef.get_current_script().resource_path
	var current_script_dir = current_script_path.get_base_dir()
	var completed_preloads := {}
	var pending_preloads = []
	var current_indent_level = 0
	var i = -1
	while true:
		if i > 7500:
			print("LINED OUT AT 7500 lines")
			return
		i += 1
		if i == script_editor.get_line_count():
			if pending_preloads.is_empty():
				return
			#if at the end of the file, just start dumping all pending
			script_editor.insert_line_at(i - 1, "")
			script_editor.insert_line_at(i, "")
			process_pending(script_editor, i, pending_preloads, completed_preloads)
			continue
		
		var line = script_editor.get_line(i)
		var indent = script_editor.get_indent_level(i)
		var stripped = line.strip_edges()
		if stripped.begins_with("#"):
			script_editor.set_line(i, "")
			stripped = ""
			line = ""
		else:
			stripped = UString.strip_comment(stripped)
		var line_dec = GDScriptParse.get_line_declaration(stripped).strip_edges()
		if line_dec == "class": # classes just adjust indent
			current_indent_level = indent + script_editor.indent_size
		elif line_dec != "":
			current_indent_level = indent
		elif stripped.begins_with("extends "):
			# extends can be folded in too
			var extended = stripped.get_slice("extends ", 1)
			extended = UString.strip_comment(extended).strip_edges()
			if UtilsRemote.UClassDetail.get_global_class_path(extended) != "":
				extended = UtilsRemote.UClassDetail.get_global_class_path(extended)
			elif not (extended.begins_with("'") or extended.begins_with('"')):
				continue # non string extends are skipped
			extended = UString.unquote(extended)
			
			if extended.is_relative_path():
				extended = current_script_dir.path_join(extended) as String
				extended = extended.simplify_path()
			
			var new_name = extended.trim_prefix("res://").get_basename().replace("/", "_")
			pending_preloads.append('const %s = preload("%s")' % [new_name, extended])
			script_editor.set_line(i, line.get_slice("extends", 0) + "extends " + new_name)
			
		elif current_indent_level == 0 and not pending_preloads.is_empty():
			# blank line with current indent level of
			process_pending(script_editor, i, pending_preloads, completed_preloads)
			continue
		
		if not stripped.begins_with("const"):
			continue
		var const_data = GDScriptParse.get_var_or_const_info(stripped)
		if const_data == null:
			continue
		
		var const_name = const_data[0]
		var assignment = const_data[2]
		
		if assignment.ends_with(".gd"):
			var whitespace = "\t".repeat(int(indent * 0.25))
			script_editor.set_line(i, whitespace + "pass #" + line.strip_edges())
			if not check_history(const_name, assignment, completed_preloads):
				pass #^c if it is already done, pass
			elif current_indent_level == 0:
				dump_file(script_editor, i, assignment, const_name)
				completed_preloads[const_name] = assignment
			else:
				pending_preloads.append(stripped)


static func process_pending(script_editor:CodeEdit, line_number:int, pending:Array, completed:Dictionary):
	var pending_stripped = pending.pop_front()
	var pending_const_data = GDScriptParse.get_var_or_const_info(pending_stripped)
	var const_name = pending_const_data[0]
	var assignment = pending_const_data[2]
	if not check_history(const_name, assignment, completed):
		return
	dump_file(script_editor, line_number, assignment, const_name)
	completed[const_name] = assignment



static func dump_file(script_editor:CodeEdit, line_number:int, type_path:String, const_name:String, indent:String= ""):
	
	#print("DUMPING::", type_path.get_file() , " -> ", line_number)
	
	var script = load(type_path)
	var code_lines = script.source_code.split("\n")
	script_editor.start_action(TextEdit.ACTION_TYPING)
	line_number += 1
	script_editor.insert_line_at(line_number, indent + "# resolved const -> class")
	line_number += 1
	script_editor.insert_line_at(line_number, indent + "class %s:" % const_name)
	line_number += 1
	var has_valid_code = false
	for j in range(code_lines.size()):
		var code_line = code_lines[j]
		if code_line.begins_with("class_name"):
			continue
		if code_line.begins_with("@tool"):
			continue
		var empty = UString.strip_comment(code_line).strip_edges() == ""
		if empty:
			continue
		if not has_valid_code and not empty:
			has_valid_code = true
		script_editor.insert_line_at(line_number, indent +  "\t" + code_line)
		line_number += 1
	script_editor.end_action()


static func check_history(name:String, assignment:String, completed:Dictionary):
	if completed.has(name):
		if completed[name] != assignment:
			printerr("Imported class doesn't name clash, not of same type.")
			printerr("First: ", completed[name])
			printerr("Second: ", assignment)
		return false
	return true
