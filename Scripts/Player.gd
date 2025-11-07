extends CharacterBody3D

@onready var camera = $Camera3D
@export var conveyor_scene: PackedScene

const SPEED = 5.0
const SPRINTING_MODIFIER = 2
const JUMP_VELOCITY = 7
const MOUSE_SENSITIVITY = 0.002
const CONVEYOR_SCENE_LENGTH = 20.0
const RAY_LENGTH = 20.0

var waiting_for_second_press := false
var start_pos: Vector3
var preview_conveyor: StaticBody3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func spawn_conveyor(start: Vector3, end: Vector3):
	var conveyor = conveyor_scene.instantiate()

	var mid = (start + end) / 2.0
	var direction = (end - start).normalized()
	var length = start.distance_to(end)
	
	var basis = Basis()
	basis.x = direction
	basis.y = Vector3.UP
	basis.z = basis.x.cross(basis.y).normalized()
	basis = basis.orthonormalized()

	var transform = Transform3D(basis, mid)

	conveyor.global_transform = transform
	conveyor.scale.x = length / CONVEYOR_SCENE_LENGTH

	get_tree().current_scene.add_child(conveyor)

func get_center_hit() -> Vector3:
	var center = get_viewport().size / 2
	var from = camera.project_ray_origin(center)
	var to = from + camera.project_ray_normal(center) * RAY_LENGTH
	var space_state = get_world_3d().direct_space_state
	
	var exclude = [self]
	if preview_conveyor:
		exclude.append(preview_conveyor)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	else:
		return Vector3.ZERO

func _input(event):
	# Don't process input when game is paused
	if get_tree().paused:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		$Camera3D.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
		
	if event.is_action_pressed("click"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event.is_action_pressed("menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
	if event.is_action_pressed("place_conveyor"):
		var hit_point = get_center_hit()
		if hit_point != Vector3.ZERO:
			if !waiting_for_second_press:
				waiting_for_second_press = true
				start_pos = hit_point
				# Instantiate preview conveyor
				if preview_conveyor == null:
					preview_conveyor = conveyor_scene.instantiate()
					get_tree().current_scene.add_child(preview_conveyor)
			else:
				# Second click → finalize conveyor
				waiting_for_second_press = false
				spawn_conveyor(start_pos, hit_point)
				if preview_conveyor:
					preview_conveyor.queue_free()
					preview_conveyor = null
				start_pos = Vector3.ZERO

func _process(delta):
	if waiting_for_second_press and preview_conveyor != null:
		var hit_point = get_center_hit()
		var direction = (hit_point - start_pos).normalized()
		var mid = (start_pos + hit_point) / 2.0
		var length = start_pos.distance_to(hit_point)

		# Build basis for rotation
		var basis = Basis()
		basis.x = direction
		basis.y = Vector3.UP
		basis.z = basis.x.cross(basis.y).normalized()
		basis = basis.orthonormalized()

		var transform = Transform3D(basis, mid)
		preview_conveyor.global_transform = transform
		preview_conveyor.scale.x = length / CONVEYOR_SCENE_LENGTH

func _physics_process(delta: float) -> void:
	# Don't process movement when game is paused
	if get_tree().paused:
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var is_sprinting = Input.is_action_pressed("sprint")
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = SPEED if not is_sprinting else SPEED * SPRINTING_MODIFIER
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
