#! remote

const DockManager = preload("res://addons/addon_lib/dock_manager/dock_manager.gd")

const BottomPanel = preload("uid://b0bnfv62aocty") #! resolve EditorNodeRef.Refs.BottomPanel
const PopupHelper = preload("uid://bb13ihrvdkjdj") #! resolve PopupWrapper.PopupHelper
const RightClickHandler = preload("uid://mmtkf4h8er3m") #! resolve ClickHandlers.RightClickHandler

const SettingHelperEditor = preload("uid://c4l4v4eufkmtx") #! resolve ALibEditor.Settings.SettingHelperEditor
const EditorIcons = preload("uid://viocyrti6wce") #! resolve ALibEditor.Singleton.EditorIcons

const EditorColors = preload("uid://cpw0fsrs38esk") #! resolve UtilE.Colors
const UClassDetail = preload("uid://0a4i0eyxcij7") #! resolve UtilR.Objects.UClassDetail

const UFile = preload("uid://bqfy5cvhth0m1") #! resolve UtilR.Files.UFile
const GetFiles = preload("uid://2kt1rv8kqr3u") #! resolve UtilR.Files.GetFiles
const UNode = preload("uid://bnf4h0107r8b4") #! resolve UtilR.UNode
const UString = preload("uid://dce8d0wuh35gs") #! resolve UtilR.Strings.UString
const Pr = preload("uid://63vmnsxwd142") #! resolve UtilR.Strings.PrintRich
const Filter = preload("uid://d10l2rjus6c3k") #! resolve UtilR.Strings.Filter
const UOs = preload("uid://dppsxjnth11uc") #! resolve UtilR.UOs
const MemberParse = preload("uid://ccgs5uvjcchb1") #! resolve GDScriptParser.MemberParse

const UResource = preload("uid://72uu8yngsoht") #! resolve ALibRuntime.Utils.UResource
const UTexture = preload("uid://ddu76iygjkxih") #! resolve ALibRuntime.Utils.UTexture
const UList = preload("uid://cpehya7u8ggby") #! resolve ALibRuntime.Utils.UList
