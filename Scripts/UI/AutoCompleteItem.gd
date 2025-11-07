extends VBoxContainer
class_name AutoCompleteItem

@export var text: String = ""
@export var selected: bool = false
@export var highlight_color: Color = Color(1, 1, 0)
@export var normal_color: Color = Color(0.88, 0.9, 0.95)

@onready var item_label: Label = $MarginContainer/Label

func _ready():
	_update_visuals()

func update(label_text: String, is_selected: bool) -> void:
	text = label_text
	selected = is_selected
	_update_visuals()

func _update_visuals():
	item_label.text = text
	if selected:
		item_label.add_theme_color_override("font_color", highlight_color)
		item_label.add_theme_color_override("font_outline_color", Color(0.2,0.2,0,0.7))
		item_label.add_theme_constant_override("outline_size", 2)
	else:
		item_label.add_theme_color_override("font_color", normal_color)
		item_label.add_theme_color_override("font_outline_color", Color(0,0,0,0.5))
		item_label.add_theme_constant_override("outline_size", 1)
