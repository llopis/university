extends Node


const PORT: int = 9999

var _server: TCPServer
var _debug_commands: DebugCommands


func _ready() -> void:
	_debug_commands = DebugCommands.new()
	_server = TCPServer.new()
	var err: Error = _server.listen(PORT)
	if err != OK:
		push_warning("RemoteConsole: Could not listen on port %d (error %d). Remote console disabled." % [PORT, err])
		_server = null
		return
	print("RemoteConsole: Listening on port %d" % PORT)


func _process(_delta: float) -> void:
	if _server == null:
		return
	if not _server.is_connection_available():
		return
	var peer: StreamPeerTCP = _server.take_connection()
	peer.set_no_delay(true)
	var command_line: String = _read_line(peer)
	if command_line.is_empty():
		return
	var before_len: int = LimboConsole._output.text.length()
	LimboConsole.execute_command(command_line)
	var raw_output: String = LimboConsole._output.text.substr(before_len)
	var response: String = _strip_bbcode(raw_output).strip_edges()
	if response.is_empty():
		response = "OK"
	peer.put_data((response + "\n").to_utf8_buffer())


func _read_line(peer: StreamPeerTCP) -> String:
	var buf: PackedByteArray = PackedByteArray()
	var deadline: int = Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < deadline:
		if peer.get_available_bytes() > 0:
			var chunk: Array = peer.get_partial_data(1024)
			var chunk_data: PackedByteArray = chunk[1] as PackedByteArray
			if chunk[0] == OK and chunk_data.size() > 0:
				buf.append_array(chunk_data)
				if buf.has(10):
					break
		else:
			break
	return buf.get_string_from_utf8().strip_edges()


func _strip_bbcode(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)
