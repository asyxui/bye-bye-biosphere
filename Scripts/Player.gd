extends CharacterBody3D

@onready var camera = $Camera3D
@export var conveyor_scene: PackedScene

const SPEED = 5.0
const SPRINTING_MODIFIER = 2
const JUMP_VELOCITY = 7
const MOUSE_SENSITIVITY = 0.002
const RAY_LENGTH = 20.0

var active_tool: Object = null  # Reference to the currently active tool script

func _ready() -> void:
	# Listen for tool activation
	ToolManager.tool_activated.connect(_on_tool_activated)
	ToolManager.active_tool_invalidated.connect(_on_active_tool_invalidated)
	
	add_to_group("player")
	
	# Register as saveable
	add_to_group("saveable")

func _on_tool_activated(_tool_id: String, slot_index: int) -> void:
	var tool = ToolManager.get_tool_in_slot(slot_index)
	if not tool:
		cancel_active_tool()
		return

	if _can_reuse_active_tool(tool):
		# Same resource identity and an intentional multi-step continuation.
		active_tool.execute(null)
		_sync_active_tool_reference()
		return

	cancel_active_tool()
	var tool_instance = ToolManager.tool_executor.execute_tool(tool, self)
	if tool_instance and tool_instance.has_method("get_tool_id") and tool_instance.get_tool_id() == tool.id and tool_instance._is_active and tool.is_multi_step:
		active_tool = tool_instance
		ToolManager.active_tool_instance = tool_instance
	else:
		active_tool = null
		ToolManager.active_tool_instance = null

func _can_reuse_active_tool(tool: ToolResource) -> bool:
	return active_tool != null \
		and ToolManager.active_tool_instance == active_tool \
		and active_tool.has_method("get_tool_id") \
		and active_tool.get_tool_id() == tool.id \
		and tool.is_multi_step \
		and active_tool._is_active

func _sync_active_tool_reference() -> void:
	if active_tool == null or not active_tool._is_active or not active_tool.is_multi_step():
		active_tool = null
		ToolManager.active_tool_instance = null

func _on_active_tool_invalidated(_new_tool_id: String) -> void:
	# ToolManager already canceled its cached instance. Cancel a local instance
	# too if it was out of sync, then drop both references.
	if active_tool != null and active_tool.has_method("cancel"):
		active_tool.cancel()
	active_tool = null
	ToolManager.active_tool_instance = null

func cancel_active_tool() -> void:
	var cached_tool = ToolManager.active_tool_instance
	if active_tool != null and active_tool.has_method("cancel"):
		active_tool.cancel()
	if cached_tool != null and cached_tool != active_tool and cached_tool.has_method("cancel"):
		cached_tool.cancel()
	active_tool = null
	ToolManager.active_tool_instance = null

func get_player_transform() -> Transform3D:
	return camera.get_global_transform()
	
func get_direction() -> Vector3:
	return - camera.get_global_transform_interpolated().basis.z.normalized()

## Mouse motion must be observed before GUI controls consume it. It remains
## gated by UIManager, so overlays and paused menus never rotate the camera.
func _input(event: InputEvent) -> void:
	if not UIManager.allows_gameplay_input():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		$Camera3D.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
	elif event.is_action_pressed("click") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_activate_selected_tool()
	elif event.is_action_pressed("right_click") and (active_tool != null or ToolManager.active_tool_instance != null):
		cancel_active_tool()

func _activate_selected_tool() -> void:
	var current_slot = UIManager._root.get_action_bar().current_slot
	if current_slot >= 0:
		ToolManager.activate_tool(current_slot)

func _process(_delta: float) -> void:
	# Update active tool preview if it has one (for conveyor tool, etc)
	if active_tool and active_tool.has_method("on_update"):
		active_tool.on_update(_delta)

func _physics_process(delta: float) -> void:
	# Don't process movement when game is paused
	if get_tree().paused:
		return

	# Add the gravity (only if gravity is enabled)
	if GameStateManager.gravity_enabled and not is_on_floor():
		velocity += get_gravity() * delta

	if not UIManager.allows_gameplay_input():
		return

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

## Saveable interface: get unique save key
func get_save_key() -> String:
	return "player"


## Get player save data
func get_save_data() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"rotation": {
			"x": rotation.x,
			"y": rotation.y,
			"z": rotation.z
		}
	}


## Load player from save data
func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var pos = data["position"]
		global_position = Vector3(pos.get("x", 0), pos.get("y", 0), pos.get("z", 0))
	
	if data.has("rotation"):
		var rot = data["rotation"]
		rotation = Vector3(rot.get("x", 0), rot.get("y", 0), rot.get("z", 0))

## Reset player position to origin (called during world transitions)
func clear_save_data() -> void:
	global_position = Vector3.ZERO
	rotation = Vector3.ZERO
