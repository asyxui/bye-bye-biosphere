extends Control

@onready var quality_slider = $Panel/MarginContainer/VBoxContainer/TabContainer/Graphics/VBoxContainer/QualitySlider
@onready var quality_value = $Panel/MarginContainer/VBoxContainer/TabContainer/Graphics/VBoxContainer/QualityValue
@onready var master_slider = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/VBoxContainer/MasterSlider
@onready var master_value = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/VBoxContainer/MasterValue
@onready var music_slider = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/VBoxContainer/MusicSlider
@onready var music_value = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/VBoxContainer/MusicValue
@onready var sfx_slider = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/VBoxContainer/SFXSlider
@onready var sfx_value = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/VBoxContainer/SFXValue
@onready var sensitivity_slider = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/VBoxContainer/SensitivitySlider
@onready var sensitivity_value = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/VBoxContainer/SensitivityValue

const QUALITY_LABELS = ["Very Low", "Low", "Medium", "High", "Ultra"]

func _ready():
	# Connect slider signals
	quality_slider.value_changed.connect(_on_quality_changed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	# Initialize display values
	_on_quality_changed(quality_slider.value)
	_on_master_changed(master_slider.value)
	_on_music_changed(music_slider.value)
	_on_sfx_changed(sfx_slider.value)
	_on_sensitivity_changed(sensitivity_slider.value)

func _on_quality_changed(value: float):
	var index = int(value) - 1
	quality_value.text = QUALITY_LABELS[index]

func _on_master_changed(value: float):
	master_value.text = str(int(value)) + "%"

func _on_music_changed(value: float):
	music_value.text = str(int(value)) + "%"

func _on_sfx_changed(value: float):
	sfx_value.text = str(int(value)) + "%"

func _on_sensitivity_changed(value: float):
	sensitivity_value.text = str(snapped(value, 0.1)) + "x"
