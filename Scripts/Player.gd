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
		var center = get_viewport().size / 2
		var from = camera.project_ray_origin(center)
		var to = from + camera.project_ray_normal(center) * RAY_LENGTH
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			if not waiting_for_second_press:
				start_pos = result.position
				print(start_pos)
				waiting_for_second_press = true
			else:
				var end_pos = result.position
				print(end_pos)
				spawn_conveyor(start_pos, end_pos)
				waiting_for_second_press = false

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
