extends Node3D

# ---- References ----
@export var voxel_terrain: VoxelLodTerrain  # assigned by the spawner after instantiate()

@onready var anim: AnimationPlayer = $"dog/AnimationPlayer"  # adjust path to match your scene tree

# ---- Movement tuning ----
@export var fall_speed: float = 5.0
@export var walk_speed: float = 1.5
@export var turn_speed: float = 4.0
@export var wander_duration_range: Vector2 = Vector2(2.0, 5.0)
@export var idle_duration_range: Vector2 = Vector2(1.0, 3.0)

# ---- State ----
enum State { FALLING, IDLE, WANDER, PETTED }
var state: State = State.FALLING
var state_timer: float = 0.0
var move_direction: Vector3 = Vector3.ZERO
var pet_timer: float = 0.0


func _ready() -> void:
	add_to_group("Petable")
	state = State.FALLING


func _process(delta: float) -> void:
	state_timer -= delta

	match state:
		State.FALLING:
			_do_fall(delta)

		State.IDLE:
			#anim.play("idle")
			if state_timer <= 0.0:
				_enter_wander()

		State.WANDER:
			#anim.play("walk")
			_do_wander_step(delta)
			if state_timer <= 0.0:
				_enter_idle()

		State.PETTED:
			#anim.play("happy")
			pet_timer -= delta
			if pet_timer <= 0.0:
				_enter_idle()


# ---- State transitions ----

func _enter_idle() -> void:
	state = State.IDLE
	state_timer = randf_range(idle_duration_range.x, idle_duration_range.y)

func _enter_wander() -> void:
	state = State.WANDER
	state_timer = randf_range(wander_duration_range.x, wander_duration_range.y)
	var angle = randf_range(0, TAU)
	move_direction = Vector3(cos(angle), 0, sin(angle))

func pet() -> void:
	state = State.PETTED
	pet_timer = 2.0
	# spawn a little particle/heart effect, play a bark/pant sound, etc.


# ---- Falling / grounding ----

func _do_fall(delta: float) -> void:
	var voxel_tool = voxel_terrain.get_voxel_tool()
	var below = global_position + Vector3(0, 5, 0)
	var ground_result = voxel_tool.raycast(below, Vector3.DOWN, 1000.0)

	if ground_result:
		var ground_world = voxel_terrain.to_global(Vector3(ground_result.position))
		print("FALL: pos=", global_position, " raw_hit=", ground_result.position, " ground_world=", ground_world)
		if global_position.y > ground_world.y + 0.1:
			global_position.y -= fall_speed * delta
		else:
			global_position.y = ground_world.y + 0.5
			_enter_idle()
	else:
		print("FALL: no ground_result at all, below=", below)
		global_position.y -= fall_speed * delta
		

# ---- Wandering ----

func _pick_new_direction() -> void:
	var angle = randf_range(0, TAU)
	move_direction = Vector3(cos(angle), 0, sin(angle))

func _do_wander_step(delta: float) -> void:
	var voxel_tool = voxel_terrain.get_voxel_tool()

	var ahead = global_position + move_direction * 1.0 + Vector3(0, 5, 0)
	var ahead_result = voxel_tool.raycast(ahead, Vector3.DOWN, 15.0)

	if not ahead_result:
		_pick_new_direction()  # just turn, don't reset the wander timer
		return

	global_position += move_direction * walk_speed * delta

	var below = global_position + Vector3(0, 5, 0)
	var ground_result = voxel_tool.raycast(below, Vector3.DOWN, 15.0)
	if ground_result:
		global_position.y = voxel_terrain.to_global(Vector3(ground_result.position)).y + 0.5

	var target_rotation = atan2(move_direction.x, move_direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, turn_speed * delta)
