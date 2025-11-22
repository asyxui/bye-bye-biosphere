extends Node3D
class_name ConnectionPoint

enum PointType { START, END }

@export var point_type: PointType = PointType.START

func _ready():
	ConveyorConnectionManager.register_point(self)

func _exit_tree():
	ConveyorConnectionManager.unregister_point(self)

func get_forward_dir() -> Vector3:
	return global_transform.basis.z
