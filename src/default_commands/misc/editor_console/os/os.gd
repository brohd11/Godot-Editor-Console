extends EditorConsoleSingleton.CommandBase
const Adapter = preload("res://addons/editor_console/src/utils/os_adapter.gd")
const _OS_LINUX = "Linux"
const _OS_MAC = "macOS"
const _OS_WIN = "Windows"

static func get_command_name() -> String:
	return "os"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"discoverable": false,
		&"help": "Run an OS command. $name/$(...) expand in GDSh; $$name/$$(...) pass to the shell. Bare os toggles interactive OS mode.",
		&"raw": true,
	})

func execute_raw(text:String, ctx:Context) -> int:
	return Adapter.execute(text, ctx)

func complete_raw(text:String, completion:Completion) -> Dictionary:
	return Adapter.complete(text, completion)

func _execute(_ctx:Context):
	return ExitCode.OK

static func get_os_user() -> String:
	var system = OS.get_name()
	match system:
		_OS_LINUX, _OS_MAC: return OS.get_environment("USER")
		_OS_WIN: return OS.get_environment("USERNAME")
		_: return "user"

static func get_os_host() -> String:
	var system = OS.get_name()
	match system:
		_OS_LINUX, _OS_MAC:
			var hostname = OS.get_environment("HOSTNAME").strip_edges()
			if hostname == "":
				var output = []
				var _exit = OS.execute("hostname",[], output)
				hostname = output[0].strip_edges()
				if hostname == "":
					if system == _OS_LINUX:
						hostname = "linux-pc"
					else:
						hostname = "mac"
			return hostname
		_OS_WIN:
			return OS.get_environment("COMPUTERNAME")
		_: return "Unrecongnized"

static func get_os_string():
	return "%s@%s" % [get_os_user(), get_os_host()]

static func get_os_home_dir() -> String:
	var system = OS.get_name()
	match system:
		_OS_LINUX, _OS_MAC: return OS.get_environment("HOME")
		_OS_WIN: return OS.get_environment("USERPROFILE")
		_: return "NO HOME"
