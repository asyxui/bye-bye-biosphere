class_name F3Screen
extends Label

var enabled := false

var player: Node3D
var voxel_world: Node3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	voxel_world = get_tree().get_first_node_in_group("voxel_world")

func _process(_delta: float) -> void:
	if not enabled:
		return
	var pos := player.global_position
	text = """FPS: %d
Position: x: %.1f, y: %.1f, z: %.1f
Biome: %s
""" % [Engine.get_frames_per_second(), pos.x, pos.y, pos.z, voxel_world.generator.get_biome_at(pos)]

func toggle_label() -> void:
	enabled = !enabled
	visible = enabled
	set_process(enabled)
