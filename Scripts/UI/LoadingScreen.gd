## Loading screen for world transitions
extends Control

class_name LoadingScreen

@onready var loading_label = $VBoxContainer/LoadingLabel
@onready var progress_bar = $VBoxContainer/ProgressBar

signal loading_complete

var _is_loading = false
var _animate_progress = false


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	# Animate progress bar while loading
	if _animate_progress and progress_bar.value < 90:
		progress_bar.value += delta * 15.0  # Slowly increment progress


## Show loading screen
func show_loading(operation_name: String = "Loading...") -> void:
	if _is_loading:
		push_error("Loading already in progress")
		return
	
	_is_loading = true
	_animate_progress = true
	loading_label.text = operation_name
	progress_bar.value = 0
	show()


## Hide loading screen with fade-out animation
func hide_loading() -> void:
	_animate_progress = false
	progress_bar.value = 100
	_is_loading = false
	
	# Fade out the loading screen
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func():
		hide()
		modulate = Color.WHITE  # Reset for next use
		loading_complete.emit()
	)


## Update loading progress (0-100)
func set_progress(percentage: float) -> void:
	progress_bar.value = clamp(percentage, 0, 100)

