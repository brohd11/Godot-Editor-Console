
const Config = EditorConsoleSingleton.Config
const UtilsRemote = EditorConsoleSingleton.UtilsRemote

const UOs = UtilsRemote.UOs
const UString = UtilsRemote.UString

const SETTING_EXEC_PATH = "mcp_exec_path"
const MCP_NAME = "godot-editor-console"

static func get_mcp_exec_path() -> String:
	var config:Config = Config.get_global_config()
	var settings = config.get_section(Config.SETTINGS, {})
	var exec_path = settings.get(&"mcp_exec_path", get_default_exec_path())
	return exec_path

static func get_default_exec_path() -> String:
	return UString.path_joinv([UOs.get_home_dir(), ".local", "bin", "godot-editor-console-mcp"])

static func remove_mcp(target:String):
	OS.execute(target, ["mcp", "remove", MCP_NAME])
