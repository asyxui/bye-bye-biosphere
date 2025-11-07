extends StaticBody3D


const SPEED = 2.0  # meters per second

func _physics_process(delta: float):
	# local X direction in global space
	var forward = global_transform.basis.x.normalized()
	constant_linear_velocity = forward * SPEED
