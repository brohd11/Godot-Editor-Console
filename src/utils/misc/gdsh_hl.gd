@tool
extends EditorSyntaxHighlighter

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleTokenizer = UtilsLocal.ConsoleTokenizer
const Colors = UtilsLocal.Colors

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const EditorColors = UtilsRemote.EditorColors

func _get_name() -> String:
	return "GDShell"

# --- Colour groups (editable in the inspector) ---------------------------
var color_default  : Color = Color(0.865, 0.968, 0.987, 1.0)  # plain text / arguments
var color_command  : Color = Colors.SCOPE  # word in command position
var color_function : Color = EditorColors.get_syntax_color(EditorColors.SyntaxColor.STRING)
var color_variable : Color = Colors.VAR_GREEN.darkened(0.3)  # $VAR  ${VAR}  "$VAR"
var color_string   : Color = color_default # Color(0.793, 0.951, 0.98, 1.0)  # "..."  '...'
var color_keyword  : Color = EditorColors.get_syntax_color(EditorColors.SyntaxColor.CONTROL_FLOW_KEYWORD)  # if elif else while for ...
var color_operator : Color = Colors.SYMBOL  # | || && ; = == != etc. also [ ]
var color_bracket  : Color = Color(0.819, 0.799, 0.32, 1.0) # EditorColors.get_syntax_color(EditorColors.SyntaxColor.TEXT)  # ( ) { }
var color_number   : Color = EditorColors.get_syntax_color(EditorColors.SyntaxColor.NUMBER)  # 123  4.5
var color_comment  : Color = EditorColors.get_syntax_color(EditorColors.SyntaxColor.COMMENT)  # # comment

const KEYWORDS := [
	"if", "elif", "else", "while", "for", "in",
	#"return", "break", "continue", # these are actually commands...
]

const _EXPECT = &"expect"

# Keywords whose *next* word is a command/condition (so `if return_test {`
# highlights return_test). `for`/`in`/`return` are deliberately excluded.
const CONDITION_KEYWORDS := ["if", "elif", "while", "else"]


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var te := get_text_edit()
	if te == null:
		return {}
	var text := te.get_line(line)
	var n := text.length()
	var colors: Array = []
	colors.resize(n)
	for k in n:
		colors[k] = color_default

	# Does this line begin inside a multi-line string? Ask the CodeEdit's
	# delimiter parser (column -1 = the region the line starts in) instead of
	# tracking end-of-line state ourselves. Requires " and ' to be registered
	# as string delimiters (the script editor already does this).
	var start_in_string := false
	var ce := te as CodeEdit
	if ce != null:
		start_in_string = ce.is_in_string(line) != -1

	# Context stack: each $( ) pushes a frame so quotes inside a substitution
	# are scoped separately from the surrounding string (handles nesting).
	var stack: Array = [{"dq": start_in_string, "sq": false, _EXPECT: not start_in_string}]

	var i := 0
	var after_function := false

	while i < n:
		var f: Dictionary = stack[-1]
		var c := text[i]

		# ---- single-quoted: literal, no expansion ------------------------
		if f["sq"]:
			colors[i] = color_string
			if c == "'":
				f["sq"] = false
				f[_EXPECT] = false
			i += 1
			continue

		# ---- double-quoted: $ expands, $( opens a sub-context ------------
		if f["dq"]:
			if c == "\\" and i + 1 < n:
				colors[i] = color_string
				colors[i + 1] = color_string
				i += 2
				continue
			if c == "$" and i + 1 < n and text[i + 1] == "(":
				colors[i] = color_operator
				colors[i + 1] = color_bracket
				stack.append({"dq": false, "sq": false, _EXPECT: true})
				i += 2
				continue
			if c == "$":
				var adv := _color_variable(text, i, colors)
				if adv > 0:
					i += adv
					continue
			colors[i] = color_string
			if c == "\"":
				f["dq"] = false
				f[_EXPECT] = false
			i += 1
			continue

		# ---- code context ------------------------------------------------
		if c == " " or c == "\t":
			i += 1
			continue

		if c == "#" and _is_comment_start(text, i):
			for k in range(i, n):
				colors[k] = color_comment
			break

		if c == "\"":
			colors[i] = color_string
			f["dq"] = true
			i += 1
			continue
		if c == "'":
			colors[i] = color_string
			f["sq"] = true
			i += 1
			continue

		if c == "$" and i + 1 < n and text[i + 1] == "(":   # command substitution
			colors[i] = color_operator
			colors[i + 1] = color_bracket
			stack.append({"dq": false, "sq": false, _EXPECT: true})
			i += 2
			continue
		if c == "$":
			var v := _color_variable(text, i, colors)
			if v > 0:
				i += v
				f[_EXPECT] = false
				continue

		# multi-char operators
		var two := text.substr(i, 2)
		if two == "&&" or two == "||" or two == ";;" or two == "==" \
				or two == "!=" or two == ">>" or two == "<<":
			colors[i] = color_operator
			colors[i + 1] = color_operator
			i += 2
			if two == "&&" or two == "||" or two == ";;":
				f[_EXPECT] = true
			continue

		# single-char operators
		if c == "|" or c == ";" or c == "&":
			colors[i] = color_operator
			i += 1
			f[_EXPECT] = true
			continue
		if c == "=" or c == "<" or c == ">" or c == "!":
			colors[i] = color_operator
			i += 1
			continue

		# closing a $( ) returns to the enclosing context (its dq may resume)
		if c == ")" and stack.size() > 1:
			colors[i] = color_bracket
			stack.pop_back()
			i += 1
			continue

		# brackets
		if c == "[" or c == "]":
			colors[i] = color_command
			i += 1
			f[_EXPECT] = false
			continue
		
		if c == "{" or c == "(":
			colors[i] = color_bracket
			i += 1
			f[_EXPECT] = true
			continue
		if c == "}" or c == ")":
			colors[i] = color_bracket
			i += 1
			f[_EXPECT] = false
			continue

		# numbers
		if _is_digit(c):
			var ns := i
			while i < n and (_is_digit(text[i]) or text[i] == "."):
				i += 1
			for k in range(ns, i):
				colors[k] = color_number
			continue

		# words: keyword / command / function / assignment / argument
		if _is_word_start(c):
			var ws := i
			while i < n and _is_word_char(text[i]):
				i += 1
			var word := text.substr(ws, i - ws)
			var col := color_default
			var next_expect := false

			if after_function:
				col = color_function             # `function foo` style
				after_function = false
			elif word in KEYWORDS:
				col = color_keyword
				if word == "function":
					after_function = true
				elif word in CONDITION_KEYWORDS:
					next_expect = true           # `if cmd {`, `while cmd {`, ...
			elif f[_EXPECT]:
				if i < n and text[i] == "=" \
						and not (i + 1 < n and text[i + 1] == "="):
					col = color_variable         # NAME=value assignment
				elif _is_function_def(text, i):
					col = color_function         # name() { ... }
				else:
					col = color_command          # command position

			for k in range(ws, i):
				colors[k] = col
			f[_EXPECT] = next_expect
			continue

		i += 1                                    # anything else

	return _collapse(colors)


# Colour a $variable starting at `i`. Returns chars consumed, or 0 if `$` is
# not a variable here.
func _color_variable(text: String, i: int, colors: Array) -> int:
	var n := text.length()
	if i + 1 >= n:
		return 0
	var c2 := text[i + 1]

	if c2 == "{":                                   # ${ ... }
		var j := i + 2
		while j < n and text[j] != "}":
			j += 1
		if j < n:
			j += 1
		for k in range(i, j):
			colors[k] = color_variable
		return j - i

	if c2 == "(":                                   # $( ... ) handled by caller
		return 0

	if _is_word_start(c2):                           # $name
		var j := i + 1
		while j < n and _is_word_char(text[j]):
			j += 1
		for k in range(i, j):
			colors[k] = color_variable
		return j - i

	# special parameters: $? $@ $# $$ $! $* $- $0..$9
	if c2 in ["?", "@", "#", "$", "!", "*", "-",
			"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		colors[i] = color_variable
		colors[i + 1] = color_variable
		return 2

	return 0


# True if what follows a word (skipping spaces) is "()".
func _is_function_def(text: String, after_word: int) -> bool:
	var n := text.length()
	var j := after_word
	while j < n and (text[j] == " " or text[j] == "\t"):
		j += 1
	if j >= n or text[j] != "(":
		return false
	j += 1
	while j < n and (text[j] == " " or text[j] == "\t"):
		j += 1
	return j < n and text[j] == ")"


# `#` only starts a comment at a token boundary (not mid-word like a#b).
func _is_comment_start(text: String, i: int) -> bool:
	if i == 0:
		return true
	var p := text[i - 1]
	return p == " " or p == "\t" or p == ";" or p == "|" \
			or p == "&" or p == "(" or p == "{"


# Collapse the per-char colour buffer into {col_start: {"color": c}} form.
func _collapse(colors: Array) -> Dictionary:
	var result := {}
	var last: Variant = null
	for i in colors.size():
		var col: Color = colors[i]
		if last == null or col != last:
			result[i] = {"color": col}
			last = col
	return result


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"

func _is_word_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"

func _is_word_char(c: String) -> bool:
	return _is_word_start(c) or _is_digit(c)
