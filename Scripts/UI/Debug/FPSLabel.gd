class_name FPSLabel
extends Label

var enabled := false

func _ready() -> void:
	HUDManager.register_fps_label(self)

func _process(_delta: float) -> void:
	if not enabled:
		return
	text = "FPS: %d" % Engine.get_frames_per_second()

func toggle_label() -> void:
	enabled = !enabled
	visible = enabled
	set_process(enabled)
