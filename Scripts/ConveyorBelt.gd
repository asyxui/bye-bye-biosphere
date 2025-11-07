extends MeshInstance3D

# first number is m/s
const SPEED = 2.0 / 1.5


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	get_surface_override_material(0).uv1_offset.x += delta * SPEED
