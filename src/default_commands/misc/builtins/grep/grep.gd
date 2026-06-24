extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Keep stdin lines matching a pattern (substring by default).
Substring match by default; pass --regex for patterns. Flags must come BEFORE the
pattern. For full coreutils behavior on mac/linux, use 'os grep'.
Usage: ... | grep <pattern> [--regex] [--ignore-case] [--invert]"

var regex_flag := false
var ignore_case_flag := false
var invert_flag := false

static func get_command_name() -> String:
	return "grep"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--regex", {&"help": "Treat the pattern as a regular expression."})
	options.add_option("--ignore-case", {&"help": "Case-insensitive match."})
	options.add_option("--invert", {&"help": "Keep lines that do not match."})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--regex":
		regex_flag = true
	elif flag == "--ignore-case":
		ignore_case_flag = true
	elif flag == "--invert":
		invert_flag = true

func _execute(ctx:CompletionContext):
	var pattern = positional_args[0]
	var regex:RegEx
	if regex_flag:
		regex = RegEx.new()
		var compiled := regex.compile(("(?i)" if ignore_case_flag else "") + pattern)
		if compiled != OK:
			ctx.append_error("Invalid regex: " + pattern)
			return ExitCode.FAIL

	for line in ctx.stdin.split("\n", false):
		var matched:bool
		if regex_flag:
			matched = regex.search(line) != null
		elif ignore_case_flag:
			matched = line.containsn(pattern)
		else:
			matched = line.contains(pattern)
		if matched != invert_flag:
			ctx.append_output(line)
