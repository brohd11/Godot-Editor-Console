@tool
extends Node

## Loopback TCP listener that runs editor_console commands sent by an external
## client (e.g. the Go MCP server / CLI) and returns the captured output.
##
## Protocol: newline-delimited JSON over 127.0.0.1.
##   request:  {"id": 1, "cmd": "dev tree | dev count", "token": "optional"}\n
##   response: {"id": 1, "stdout": "...", "stderr": "...", "exit_code": 0}\n
##
## Bound to loopback only and started on demand (see EditorConsoleSingleton.start_bridge).

const _READ_CHUNK := 65536

var _server: TCPServer
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
			var out: Dictionary = EditorConsoleSingleton.run_command_capture(str(req.get("cmd", "")))
			resp = {
				"id": id,
				"stdout": out.get("stdout", ""),
				"stderr": out.get("stderr", ""),
				"exit_code": out.get("exit_code", 0),
			}

	var payload := JSON.stringify(resp) + "\n"
	peer.put_data(payload.to_utf8_buffer())
