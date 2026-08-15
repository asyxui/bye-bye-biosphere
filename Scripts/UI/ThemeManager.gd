## Applies the three UI directions to the shared semantic GameTheme resource.
extends Node

const FIELD_INSTRUMENT := "Field Instrument"
const BIO_INDUSTRIAL := "Bio-industrial"
const COLD_AUTOMATION := "Cold Automation"
const SETTINGS_PATH := "user://ui_theme.cfg"

const PROFILES := {
	FIELD_INSTRUMENT: {"surface": Color("#252B2D"), "inset": Color("#111516"), "border": Color("#626C6F"), "active": Color("#A9CED3"), "text": Color("#E7E1D4"), "warning": Color("#D99B36")},
	BIO_INDUSTRIAL: {"surface": Color("#272D29"), "inset": Color("#151814"), "border": Color("#59635A"), "active": Color("#A7BB91"), "text": Color("#E4E0D0"), "warning": Color("#B87052")},
	COLD_AUTOMATION: {"surface": Color("#18242D"), "inset": Color("#0D141A"), "border": Color("#365165"), "active": Color("#78C7E8"), "text": Color("#EDF6F8"), "warning": Color("#F2B65B")},
}

var current_theme := FIELD_INSTRUMENT
var game_theme: Theme

func _ready() -> void:
	game_theme = load("res://Assets/GameTheme.tres")
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		current_theme = config.get_value("interface", "theme", FIELD_INSTRUMENT)
	apply_theme(current_theme)

func get_theme_names() -> PackedStringArray:
	return PackedStringArray([FIELD_INSTRUMENT, BIO_INDUSTRIAL, COLD_AUTOMATION])

func apply_theme(theme_name: String) -> void:
	if not PROFILES.has(theme_name):
		return
	current_theme = theme_name
	var colors: Dictionary = PROFILES[theme_name]
	_set_box("PanelContainer", "panel", colors.surface, colors.border)
	_set_box("Panel", "panel", colors.surface, colors.border)
	_set_box("LineEdit", "normal", colors.inset, colors.border)
	_set_box("Button", "normal", colors.surface, colors.border)
	_set_box("Button", "hover", colors.surface.lightened(0.12), colors.active, 2)
	_set_box("Button", "focus", colors.surface.lightened(0.12), colors.active, 2)
	_set_box("Button", "pressed", colors.inset, colors.active, 2)
	_set_box("ProgressBar", "background", colors.inset, colors.inset)
	_set_box("ProgressBar", "fill", colors.active, colors.active)
	_set_box("InventorySlot", "panel", colors.inset, colors.border)
	_set_box("InventorySlotSelected", "panel", colors.surface.lightened(0.08), colors.active, 2)
	_set_box("InventorySlotDragSource", "panel", colors.surface.lightened(0.08), colors.active, 2)
	_set_box("InventorySlotDropTarget", "panel", colors.surface.lightened(0.05), colors.warning, 2)
	game_theme.set_color("font_color", "Label", colors.text)
	game_theme.set_color("font_color", UIThemeTypes.DISPLAY_TITLE, colors.text)
	game_theme.set_color("font_color", UIThemeTypes.SCREEN_TITLE, colors.text)
	game_theme.set_color("font_color", UIThemeTypes.SECTION_TITLE, colors.active)
	game_theme.set_color("font_color", UIThemeTypes.STATUS_ACTIVE, colors.active)
	game_theme.set_color("font_color", UIThemeTypes.STATUS_WARNING, colors.warning)
	ProjectSettings.set_setting("gui/theme/custom", game_theme.resource_path)
	var config := ConfigFile.new()
	config.set_value("interface", "theme", current_theme)
	config.save(SETTINGS_PATH)

func _set_box(type: StringName, property: StringName, color: Color, border: Color, width := 1) -> void:
	var box := game_theme.get_stylebox(property, type) as StyleBoxFlat
	if box:
		box.bg_color = color
		box.border_color = border
		box.border_width_left = width
		box.border_width_top = width
		box.border_width_right = width
		box.border_width_bottom = width
