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

func try_destroy() -> void:
	MapManager._destroy(get_origin(), get_direction())

func get_origin() -> Vector3:
	return camera.get_global_transform().origin
	
func get_direction() -> Vector3:
	return - camera.get_global_transform_interpolated().basis.z.normalized()

func _input(event):
	# Don't process input when game is paused or modal is active
	if GameStateManager.is_modal_active():
		return
	
	# Check current input state - only process gameplay input in gameplay state
	if not InputManager.has_input_focus("gameplay"):
		return
	
	# Toggle inventory with inventory action (I key)
	if event.is_action_pressed("inventory"):
		# Don't open inventory if debug console input is focused
		if DebugConsole.instance and DebugConsole.instance.input_line and DebugConsole.instance.input_line.has_focus():
			return
		HUDManager.toggle_inventory()
		return
		
	if event.is_action_pressed("click"):
		# Only capture mouse if no UI is open
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not HUDManager.is_inventory_open() and not HUDManager.is_debug_console_open():
			InputManager.request_mouse_capture("gameplay")
		# Activate the currently selected tool
		var hud = get_tree().current_scene.get_node_or_null("Hud")
		if hud:
			var action_bar = hud.get_node_or_null("ActionBar")
			if action_bar:
				var current_slot = action_bar.current_slot
				if current_slot >= 0:
					ToolManager.activate_tool(current_slot)
	
	# Cancel tool preview with right-click
	if event.is_action_pressed("right_click"):
		if active_tool and active_tool.has_method("cancel"):
			active_tool.cancel()

	if event.is_action_pressed("release_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			InputManager.request_mouse_release("gameplay")

	# Ignore movement input if debug input bar is focused
	if DebugConsole.instance and DebugConsole.instance.input_line and DebugConsole.instance.input_line.has_focus():
		return
		
	if event is InputEventMouseMotion and InputManager.is_mouse_captured():
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		$Camera3D.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
			
	if event.is_action_pressed("destroy_test"):
		MapManager._destroy(get_origin(), get_direction())
		

func _process(_delta: float) -> void:
	# Update active tool preview if it has one (for conveyor tool, etc)
	if active_tool and active_tool.has_method("on_update"):
		active_tool.on_update(_delta)

func _physics_process(delta: float) -> void:
	# Don't process movement when game is paused
	if get_tree().paused:
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Ignore movement input if debug input bar is focused
	if DebugConsole.instance and DebugConsole.instance.input_line and DebugConsole.instance.input_line.has_focus():
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
