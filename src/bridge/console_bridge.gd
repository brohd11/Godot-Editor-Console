@tool
extends Node

## Loopback TCP listener that runs editor_console commands sent by an external
## client (e.g. the Go MCP server / CLI) and returns the captured output.
##
## Protocol: newline-delimited JSON over 127.0.0.1.
##   request:  {"id": 1, "cmd": "tree | count", "token": "optional"}\n
##   response: {"id": 1, "stdout": "...", "stderr": "...", "exit_code": 0}\n
##
## Bound to loopback only and started on demand (see ConsoleBridge.start_bridge).

const _READ_CHUNK := 65536

var _server: TCPServer

#region External control (moved from EditorConsoleSingleton)

## Run a console command line non-interactively and return captured output.
## Reuses the exact line-submit path (execute_interactive), so ';', pipes, '&&'/'||',
## gdsh functions and multiline all behave identically to typing in the console.
static func run_command_capture(text:String) -> Dictionary:
	var ctx = EditorConsoleSingleton.get_main_ctx()
	EditorConsoleSingleton.execute_interactive(text, {
		&"parent_ctx": ctx,
		&"print": false,
	})
	return {
		"stdout": ctx.stdout,
		"stderr": ctx.stderr,
		"exit_code": ctx.exit_code,
	}


## Start the loopback TCP bridge so an external client (Go MCP server / CLI) can run
## commands against the live editor. Off by default; loopback only. Returns an Error code.
static func start_bridge(port:int=9510, token:String="") -> int:
	if not EditorConsoleSingleton._instance_valid_err(): return FAILED
	var ins = EditorConsoleSingleton.get_instance()
	if not is_instance_valid(ins._bridge):
		ins._bridge = EditorConsoleSingleton.ConsoleBridge.new()
		ins._bridge.name = "ConsoleBridge"
		ins.add_child(ins._bridge)
	return ins._bridge.start(port, token)


static func stop_bridge() -> void:
	if not EditorConsoleSingleton._instance_valid_err(): return
	var ins = EditorConsoleSingleton.get_instance()
	if is_instance_valid(ins._bridge):
		ins._bridge.stop()
		ins._bridge.queue_free()
		ins._bridge = null


static func bridge_status() -> Dictionary:
	if not EditorConsoleSingleton._instance_valid_err(): return {"listening": false, "port": 0}
	var ins = EditorConsoleSingleton.get_instance()
	if is_instance_valid(ins._bridge) and ins._bridge.is_listening():
		return {"listening": true, "port": ins._bridge.get_port(), "token": ins._bridge.has_token()}
	return {"listening": false, "port": 0, "token": false}

#endregion
var _port: int = 0
var _token: String = ""
# each entry: { "peer": StreamPeerTCP, "buf": String }
var _conns: Array = []


func start(port: int, token: String = "") -> int:
	stop()
	_server = TCPServer.new()
	var err := _server.listen(port, "127.0.0.1")
	if err != OK:
		_server = null
		return err
	_port = port
	_token = token
	set_process(true)
	return OK


func stop() -> void:
	set_process(false)
	for conn in _conns:
		var peer: StreamPeerTCP = conn.get("peer")
		if peer != null:
			peer.disconnect_from_host()
	_conns.clear()
	if _server != null:
		_server.stop()
		_server = null
	_port = 0


func is_listening() -> bool:
	return _server != null and _server.is_listening()


func get_port() -> int:
	return _port


func has_token() -> bool:
	return _token != ""


func _process(_delta: float) -> void:
	if _server == null:
		return

	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer != null:
			_conns.append({"peer": peer, "buf": ""})

	var keep: Array = []
	for conn in _conns:
		var peer: StreamPeerTCP = conn.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue # drop disconnected peers

		var avail := peer.get_available_bytes()
		if avail > 0:
			var result := peer.get_partial_data(min(avail, _READ_CHUNK))
			if result[0] == OK:
				conn.buf += (result[1] as PackedByteArray).get_string_from_utf8()

		var nl := (conn.buf as String).find("\n")
		if nl != -1:
			var line := (conn.buf as String).substr(0, nl)
			_handle_line(peer, line)
			peer.disconnect_from_host()
			continue # one request per connection; drop after responding

		keep.append(conn)
	_conns = keep


func _handle_line(peer: StreamPeerTCP, line: String) -> void:
	var resp := {}
	var json := JSON.new()
	if json.parse(line) != OK or not (json.data is Dictionary):
		resp = {"id": null, "stdout": "", "stderr": "Invalid JSON request", "exit_code": 2}
	else:
		var req: Dictionary = json.data
		var id = req.get("id", null)
		if not req.has("cmd"):
			resp = {"id": id, "stdout": "", "stderr": "Missing 'cmd' field", "exit_code": 2}
		elif _token != "" and str(req.get("token", "")) != _token:
			resp = {"id": id, "stdout": "", "stderr": "Unauthorized", "exit_code": 1}
		else:
			var out: Dictionary = run_command_capture(str(req.get("cmd", "")))
			resp = {
				"id": id,
				"stdout": out.get("stdout", ""),
				"stderr": out.get("stderr", ""),
				"exit_code": out.get("exit_code", 0),
			}

	var payload := JSON.stringify(resp) + "\n"
	peer.put_data(payload.to_utf8_buffer())



#region list_commands - here to keep mcp logic together

const TO_IGNORE = ["help"]

static func build_mcp_command_list() -> String:
	var ins = EditorConsoleSingleton.get_instance()
	var list = {}
	for scope_name in ins.scope_dict.keys():
		var scope = ins.scope_dict[scope_name]
		var obj = scope.get("script")
		_get_scope_commands(obj.new(), "", list)
	
	for scope_name in ins.hidden_scope_dict.keys():
		var scope = ins.hidden_scope_dict[scope_name]
		var obj = scope.get("script")
		_get_scope_commands(obj.new(), "", list)
	
	var string = ""
	for entry in list.keys():
		if entry.begins_with("__") or entry in TO_IGNORE:
			continue
		if entry.begins_with("misc builtins"):
			continue
		string += entry + ": " + list[entry] + "\n"
	
	return string

static func _get_scope_commands(scope:EditorConsoleSingleton.CommandBase, current_path:String, list:Dictionary):
	var path = current_path + " " + scope.get_command_name()
	path = path.strip_edges()
	var help = scope.get_help_string()
	if help == null or help == "":
		help = "Undocumented or namespace"
	elif help.contains("\n"):
		help = help.get_slice("\n", 0)
	list[path] = help
	
	var subs = scope.get_commands()
	for s in subs.keys():
		var cmd_data = subs[s]
		var get_cmd = cmd_data.get(&"get_command")
		if get_cmd != null:
			var cmd = get_cmd.call()
			_get_scope_commands(cmd, path, list)
		#else:
			#var sub_p = path + " " + str(s)
			#sub_p = sub_p.strip_edges()
			#list[sub_p] = ""

#endregion
