extends MeshInstance3D

# first number is m/s
const SPEED = 2.0 / 3.0
var material_instance: ORMMaterial3D

func _ready():
	var original_mat = get_surface_override_material(0)
	if original_mat:
		material_instance = original_mat.duplicate()
		set_surface_override_material(0, material_instance)
		
	if material_instance and mesh:
		var aabb = mesh.get_aabb()
		var length = aabb.size.x * global_transform.basis.get_scale().x
		material_instance.uv1_scale.x = length
		
func _process(delta: float) -> void:
	if material_instance:
		material_instance.uv1_offset.x += delta * SPEED
