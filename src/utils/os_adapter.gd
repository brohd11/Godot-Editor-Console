extends RefCounted
## Editor-owned shell boundary. GDSh remains unaware of OS/double-dollar syntax.
const Sh = preload("res://addons/addon_lib/gdsh/gdsh.gd")
const Lexer = preload("res://addons/addon_lib/gdsh/internal/lexer.gd")
static var _request_id:int = 0

static func shell_quote(value:String) -> String:
	return "'" + value.replace("'", "'\\''") + "'"

static func _quoted_value(value:String, quote:String) -> String:
	if OS.get_name() == "Windows":
		var escaped = value.replace("%", "%%").replace('"', '"^""')
		return escaped if quote == '"' else '"' + escaped + '"'
	if quote == '"':
		return value.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
	return shell_quote(value)

## Find a balanced substitution without interpreting its body.
static func _substitution_end(text:String, start:int) -> int:
	var depth = 1
	var quote = ""
	var i = start + 1
	while i < text.length():
		var ch = text[i]
		if ch == "\\" and quote != "'":
			i += 2
			continue
		if ch == "$" and text.substr(i + 1, 1) == "(" and quote != "'":
			var nested = _substitution_end(text, i + 1)
			if nested < 0: return -1
			i = nested + 1
			continue
		if not quote.is_empty():
			if ch == quote: quote = ""
		elif ch in ["'", '"']:
			quote = ch
		elif ch == "(": depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0: return i
		i += 1
	return -1

static func expand(text:String, ctx:Sh.Context, seen:Dictionary={}) -> Dictionary:
	var out = ""
	var quote = ""
	var i = 0
	while i < text.length():
		var ch = text[i]
		if ch == "\\" and quote != "'":
			out += text.substr(i, 2)
			i += 2
			continue
		if ch in ["'", '"']:
			if quote.is_empty(): quote = ch
			elif ch == quote: quote = ""
			out += ch
			i += 1
			continue
		if quote != "'" and ch == "$":
			var passthrough = text.substr(i, 2) == "$$"
			var dollar = i + 1 if passthrough else i
			if text.substr(dollar + 1, 1) == "(":
				var end = _substitution_end(text, dollar + 1)
				if end < 0: return {"error": "Unclosed OS command substitution", "text": ""}
				var body = text.substr(dollar + 2, end - dollar - 2)
				if passthrough:
					out += "$(" + body + ")"
				else:
					var child = Sh.Context.new_ctx("OS substitution", ctx, true)
					Sh.Execute.execute_command_multiline(body, child)
					ctx.append_error(child.stderr)
					var value = child.stdout.rstrip("\n")
					if quote.is_empty():
						var fields:Array = []
						for field in value.replace("\t", " ").replace("\n", " ").split(" ", false):
							fields.append(_quoted_value(field, ""))
						out += " ".join(fields)
					else:
						out += _quoted_value(value, quote)
				i = end + 1
				continue
			if passthrough:
				out += "$"
				i += 2
				continue
			var end = i + 1
			if text.substr(end, 1) in ["?", "#", "@"]: end += 1
			else:
				while end < text.length() and Lexer._identifier_char(text[end]): end += 1
			if end > i + 1:
				out += _quoted_value(str(ctx.get_variable(text.substr(i, end - i))), quote)
				i = end
				continue
		# Alias fragments expand only outside quotes and on complete words.
		if quote.is_empty() and (i == 0 or text[i - 1] in [" ", "\t", ";", "|"]):
			var end = i
			while end < text.length() and not text[end] in [" ", "\t", "\n", ";", "|", "&", "'", '"', "$", "(", ")"]: end += 1
			var word = text.substr(i, end - i)
			if ctx.aliases.has(word):
				if seen.has(word): return {"error": "GDSh alias cycle: " + word, "text": ""}
				var next = seen.duplicate()
				next[word] = true
				var expanded = expand(str(ctx.aliases[word]).trim_prefix("@literal"), ctx, next)
				if not expanded.error.is_empty(): return expanded
				out += expanded.text
				i = end
				continue
		out += ch
		i += 1
	if not quote.is_empty(): return {"error": "Unclosed OS quote", "text": ""}
	return {"error": "", "text": out}

static func execute(text:String, ctx:Sh.Context) -> int:
	var expanded = expand(text.strip_edges(), ctx)
	if not expanded.error.is_empty():
		ctx.append_error(expanded.error)
		return Sh.CommandBase.ExitCode.ERR
	var command:String = expanded.text
	if command.is_empty(): return Sh.CommandBase.ExitCode.OK
	# Standalone cd updates the GDSh session; compound shell scripts keep shell semantics.
	var scanned = Lexer.scan(command)
	var words:Array = scanned.tokens.filter(func(token): return token.kind == "word")
	if scanned.error.is_empty() and not words.is_empty() and words[0].raw == "cd" \
			and scanned.tokens.size() == words.size() + 1:
		return _change_directory(command, ctx)
	return _run_shell(command, ctx)

static func _change_directory(command:String, ctx:Sh.Context) -> int:
	# Resolve shell variables/tilde in the shell before updating the session.
	var probe = Sh.Context.new_ctx("OS cd", ctx, true)
	var script = command + (" && cd" if OS.get_name() == "Windows" else " && pwd -P")
	var status = _run_shell(script, probe)
	ctx.append_error(probe.stderr)
	if status != 0: return status
	var target = probe.stdout.strip_edges().split("\n")[-1].strip_edges()
	if not DirAccess.dir_exists_absolute(target):
		ctx.append_error("Directory does not exist: " + target)
		return Sh.CommandBase.ExitCode.ERR
	ctx.propogate(Sh.Context.Propagate.PROPERTY, "cwd", target)
	return 0

static func _write(path:String, text:String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	return true

static func _run_shell(command:String, ctx:Sh.Context) -> int:
	var platform = OS.get_name()
	if not platform in ["macOS", "Linux", "Windows"]:
		ctx.append_error("Unsupported OS: " + platform)
		return Sh.CommandBase.ExitCode.ERR
	_request_id += 1
	var directory = ProjectSettings.globalize_path("user://addons/editor_console/tmp")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		ctx.append_error("Cannot create OS command temporary directory")
		return Sh.CommandBase.ExitCode.ERR
	var prefix = directory.path_join("%s-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec(), _request_id])
	var is_win = platform == "Windows"
	var script_path = prefix + (".bat" if is_win else ".sh")
	var error_path = prefix + ".err"
	var input_path = prefix + ".in"
	var cwd = ProjectSettings.globalize_path(ctx.cwd)
	var script:String
	var executable:String
	var args:Array
	if is_win:
		executable = "cmd.exe"
		args = ["/D", "/C", script_path]
		script = '@echo off\r\ncd /d "%s" || exit /b 1\r\n(\r\n%s\r\n) 2>"%s"' % [cwd, command, error_path]
		if not ctx.stdin.is_empty(): script += ' <"%s"' % input_path
	else:
		executable = "zsh" if platform == "macOS" else "bash"
		args = [script_path]
		var rc = "~/.zshrc" if platform == "macOS" else "~/.bashrc"
		script = "[ ! -f %s ] || source %s\ncd %s || exit 1\n(\n%s\n) 2>%s" % [rc, rc, shell_quote(cwd), command, shell_quote(error_path)]
		if not ctx.stdin.is_empty(): script += " <" + shell_quote(input_path)
	if not _write(script_path, script) or not _write(input_path, ctx.stdin):
		ctx.append_error("Cannot write OS command temporary files")
		for path in [script_path, input_path]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		return Sh.CommandBase.ExitCode.ERR
	var output:Array = []
	var status = OS.execute(executable, args, output, true)
	for line in output: ctx.append_output(str(line))
	if FileAccess.file_exists(error_path): ctx.append_error(FileAccess.get_file_as_string(error_path))
	for path in [script_path, error_path, input_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if status < 0:
		ctx.append_error("Failed to execute shell: " + executable)
		return Sh.CommandBase.ExitCode.ERR
	return status

static func complete(text:String, completion:Sh.Completion) -> Dictionary:
	var scanned = Lexer.scan(text, true)
	var words:Array = scanned.tokens.filter(func(token): return token.kind == "word")
	var tail = "" if text.right(1) in [" ", "\t", ""] or words.is_empty() else str(words[-1].raw)
	completion.token_before_cursor = tail
	completion.word_before_cursor = tail
	completion.char_before_cursor = text.right(1)
	if tail.begins_with("$$"): return {}
	if tail.begins_with("$") and not tail.begins_with("$("):
		var options = Sh.Options.new()
		for name in completion.context.variables: options.add_option(name)
		return options.get_options()
	if words.is_empty(): return {}
	if words[0].raw == "cd":
		return Sh.Completion.new("cd " + tail, completion.context).get_completions()
	return {}
