## Shared, deliberately restrained transitions for UI overlays.
class_name UITransitions
extends RefCounted

static func open(control: Control, offset := Vector2(0, 4)) -> Tween:
	control.show()
	control.modulate.a = 0.0
	control.position += offset
	var tween := control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.12)
	tween.tween_property(control, "position", control.position - offset, 0.12)
	return tween

static func close(control: Control) -> Tween:
	var tween := control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, 0.09)
	tween.tween_callback(control.hide)
	return tween
