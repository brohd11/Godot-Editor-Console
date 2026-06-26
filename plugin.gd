@tool
extends EditorPlugin

const PLUGIN_NAME = "EditorConsole"
const CONTAINER_PATH = "res://addons/editor_console/src/container/main_container.gd"

var dm_im:DockManager.InstanceManager

func _get_plugin_name() -> String:
	return "Editor Console"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Terminal", "EditorIcons")

func _enter_tree() -> void:
	EditorPanelSingleton.register_panel(PLUGIN_NAME, CONTAINER_PATH)
	
	add_tool_menu_item(PLUGIN_NAME, _on_tool_menu)
	EditorConsoleSingleton.register_node(self)
	
	dm_im = DockManager.InstanceManager.new(self, true)


func _exit_tree() -> void:
	remove_tool_menu_item(PLUGIN_NAME)
	EditorConsoleSingleton.unregister_node(self)
	
	dm_im.clean_up()
	EditorPanelSingleton.unregister_panel(PLUGIN_NAME)

func _on_tool_menu():
	var layout = EditorPanelSingleton.PluginSplitPanel.Layout.new()
	layout.add_panel(CONTAINER_PATH)
	var sps = EditorPanelSingleton.PluginSplitPanel.new()

	dm_im.new_freeable_dock_manager(sps, DockManager.Slot.FLOATING)
	
	sps.load_layout(layout)
