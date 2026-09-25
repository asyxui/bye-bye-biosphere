extends Control

var _terrain_profile := PackedVector2Array([
	Vector2(0, 41), Vector2(31, 41), Vector2(47, 31), Vector2(66, 31),
	Vector2(79, 39), Vector2(105, 39), Vector2(126, 22), Vector2(149, 22),
	Vector2(164, 36), Vector2(188, 36), Vector2(204, 28), Vector2(224, 28),
	Vector2(242, 41), Vector2(300, 41),
])

var _phase := 0.0


func _ready() -> void:
	set_process(false)
	queue_redraw()


func start() -> void:
	set_process(true)


func stop() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * 0.7, TAU)
	queue_redraw()


func _draw() -> void:
	var accent: Color = ThemeManager.PROFILES[ThemeManager.current_theme].active
	var baseline := size.y - 4.0
	var scan_x := size.x * (0.5 + 0.5 * sin(_phase))
	var silhouette := _scaled_profile(0.0)
	var lower_contour := _scaled_profile(7.0)
	var upper_contour := _scaled_profile(-5.0)
	draw_line(Vector2(0, baseline), Vector2(size.x, baseline), Color(accent, 0.14), 1.0, true)
	draw_polyline(upper_contour, Color(accent, 0.12), 1.0, true)
	draw_polyline(lower_contour, Color(accent, 0.22), 1.0, true)
	draw_polyline(silhouette, Color(accent, 0.68), 1.5, true)
	draw_rect(Rect2(scan_x - 5.0, 7.0, 10.0, baseline - 7.0), Color(accent, 0.05))
	draw_line(Vector2(scan_x, 7.0), Vector2(scan_x, baseline), Color(accent, 0.85), 1.0, true)
	for point in [Vector2(47, 31), Vector2(126, 22), Vector2(204, 28), Vector2(242, 41)]:
		var distance := absf(point.x - scan_x)
		var strength := 0.18 + 0.82 * (1.0 - clampf(distance / 56.0, 0.0, 1.0))
		draw_circle(point, 2.0, Color(accent, strength))


func _scaled_profile(vertical_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in _terrain_profile:
		points.append(Vector2(point.x * size.x / 300.0, point.y + vertical_offset))
	return points
