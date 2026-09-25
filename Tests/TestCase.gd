extends RefCounted

var failed: bool = false
var failure_count: int = 0
var root: Node

func run(scene_tree: SceneTree) -> void:
	root = scene_tree.root
	_run()

func check(condition: bool, message: String = "") -> bool:
	if condition:
		return true
	failed = true
	failure_count += 1
	push_error("Test check failed%s" % (": " + message if not message.is_empty() else ""))
	return false

func _run() -> void:
	push_error("Test case did not implement _run()")
	failed = true
