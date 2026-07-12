extends Control

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const Options = UtilsRemote.RightClickHandler.Options
const SplitType = EditorPanelSingleton.PluginSplitPanel.SplitType

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")

const ConsoleContainer = UtilsLocal.ConsoleContainer

var _content_vbox:VBoxContainer
var rich_text_label:RichTextLabel
var line_edit_container: ConsoleContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = UtilsRemote.EditorColors.get_theme_color(UtilsRemote.EditorColors.ThemeColor.BASE)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	
	_content_vbox = VBoxContainer.new()
	add_child(_content_vbox)
	_content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	rich_text_label = RichTextLabel.new()
	rich_text_label.selection_enabled = true
	rich_text_label.context_menu_enabled = true
	_content_vbox.add_child(rich_text_label)
	rich_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_text_label.bbcode_enabled = true
	
	line_edit_container = ConsoleContainer.new()
	line_edit_container.rich_text_label = rich_text_label # set before ready
	
	_content_vbox.add_child(line_edit_container)
	
	
	#_content_vbox.add_spacer(false).size_flags_vertical = Control.SIZE_SHRINK_END


func get_split_options() -> Options:
	var split = EditorPanelSingleton.get_split_panel_ancestor(self)
	var options = Options.new()
	if not is_instance_valid(split):
		return options
	options.add_option("Console/Left", _new_split.bind(SplitType.HORIZONTAL_L))
	options.add_option("Console/Right", _new_split.bind(SplitType.HORIZONTAL_R))
	options.add_option("Console/Up", _new_split.bind(SplitType.VERTICAL_U))
	options.add_option("Console/Down", _new_split.bind(SplitType.VERTICAL_D))
	
	return options

func _new_split(direction:SplitType) -> void:
	var split = EditorPanelSingleton.get_split_panel_ancestor(self)
	split.new_split(self, new(), direction)
