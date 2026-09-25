## Presentation-only conveyor item visuals.
## Missing visual nodes never affect the logical belt simulation.
extends StaticBody3D

var _visual_root: Node3D = null
var _visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	_visual_root = get_node_or_null("ItemVisuals") as Node3D

func _process(_delta: float) -> void:
	if _visual_root == null:
		return
	var belt_data: Variant = get_meta("conveyor_belt_object", null)
	if not belt_data is ConveyorBeltObject:
		_hide_all_visuals()
		return
	var belt: ConveyorBeltObject = belt_data as ConveyorBeltObject
	var required_visuals: int = belt.items.size()
	while _visuals.size() < required_visuals:
		_visuals.append(_create_visual())
	while _visuals.size() > required_visuals:
		var stale: MeshInstance3D = _visuals.pop_back()
		stale.queue_free()

	for index in range(required_visuals):
		var item: ConveyorItem = belt.items[index]
		var visual: MeshInstance3D = _visuals[index]
		item.visual_node = visual
		visual.global_position = belt.start.lerp(belt.end, item.progress) + Vector3.UP * 0.16
		visual.visible = true

func _create_visual() -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.54, 0.12, 1.0)
	material.metallic = 0.2
	material.roughness = 0.45
	visual.material_override = material
	_visual_root.add_child(visual)
	return visual

func _hide_all_visuals() -> void:
	for visual in _visuals:
		visual.visible = false
