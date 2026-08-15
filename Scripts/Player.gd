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
	
	add_to_group("player")
	
	# Register as saveable
	add_to_group("saveable")

func _on_tool_activated(_tool_id: String, slot_index: int) -> void:
	var tool = ToolManager.get_tool_in_slot(slot_index)
	if tool:
		# Check if this is the same tool that's already active and still has state
		if (ToolManager.active_tool_instance and active_tool and 
			active_tool.get_script().resource_path == tool.tool_script_path and
			active_tool._is_active):  # Only reuse if tool is still active (multi-step)
			# Same tool and still active, execute again (for multi-click tools like conveyor)
			active_tool.execute(null)  # Pass null since player is already cached
		else:
			# Different tool, no active tool, or tool finished (single-step), create a new instance
			var tool_instance = ToolManager.tool_executor.execute_tool(tool, self)
			if tool_instance:
				active_tool = tool_instance
				ToolManager.active_tool_instance = tool_instance

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
	elif event.is_action_pressed("right_click") and active_tool and active_tool.has_method("cancel"):
		active_tool.cancel()

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
