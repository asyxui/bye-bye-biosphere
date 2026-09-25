extends "res://Tests/TestCase.gd"

const SMELTER_SCENE: PackedScene = preload("res://Scenes/Machines/Smelter.tscn")
const SINK_SCENE: PackedScene = preload("res://Scenes/Machines/Sink.tscn")
const QUEST_JOURNAL_SCENE: PackedScene = preload("res://Scenes/UI/QuestJournal.tscn")
const QUEST_TRACKER_SCRIPT: Script = preload("res://Scripts/UI/QuestTracker.gd")

func _run() -> void:
	var was_creative := GameStateManager.is_creative_mode()
	GameStateManager.set_creative_mode(false)
	QuestManager.clear_save_data()
	var tracker := _create_tracker()
	root.add_child(tracker)
	check(tracker.visible)
	var journal := QUEST_JOURNAL_SCENE.instantiate() as Control
	root.add_child(journal)
	check(journal.get_node("Panel/MarginContainer/VBoxContainer/Content/QuestListPanel/MarginContainer/QuestList").get_child_count() == 1)
	check(journal.get_node("Panel/MarginContainer/VBoxContainer/Content/Detail/StepTitle").text == "Gather resources")
	check(journal.get_node("Panel/MarginContainer/VBoxContainer/Content/Detail/Objectives").get_child_count() == 2)

	GameplayEventBus.publish(GameplayEventBus.ITEM_CRAFTED, "9")
	GameplayEventBus.publish(GameplayEventBus.MACHINE_PLACED, "manual_smelter")
	GameplayEventBus.publish(GameplayEventBus.ITEM_PRODUCED, "5", 7)
	GameplayEventBus.publish(GameplayEventBus.ITEM_MINED, "8", 99)
	GameStateManager.set_creative_mode(true)
	check(not tracker.visible)
	GameplayEventBus.publish(GameplayEventBus.ITEM_MINED, "8", 12)
	GameplayEventBus.publish(GameplayEventBus.ITEM_MINED, "6", 1)
	GameplayEventBus.publish(GameplayEventBus.ITEM_DELIVERED, "5", 10)
	var creative_mode_completions := _completed_steps()
	check(creative_mode_completions.has("manual_smelter"))
	check(creative_mode_completions.has("produce_ingots"))
	check(not creative_mode_completions.has("recover_site"))
	check(QuestManager.get_active_step().is_empty())

	GameStateManager.set_creative_mode(false)
	check(tracker.visible)
	check(not _completed_steps().has("recover_site"))
	GameplayEventBus.publish(GameplayEventBus.ITEM_MINED, "wrong_item", 100)
	GameplayEventBus.publish(GameplayEventBus.ITEM_MINED, "8", 12)
	GameplayEventBus.publish(GameplayEventBus.ITEM_MINED, "6", 1)
	check(_completed_steps().has("recover_site"))
	check(_completed_steps().has("manual_smelter"))
	check(_completed_steps().has("produce_ingots"))
	check(QuestManager.get_active_step().get("step_id", "") == "automated_line")

	var smelter: Node3D = SMELTER_SCENE.instantiate() as Node3D
	var sink: Node3D = SINK_SCENE.instantiate() as Node3D
	root.add_child(smelter)
	root.add_child(sink)
	var output_port := smelter.get_node("Output") as ConnectionPoint
	var input_port := sink.get_node("Input") as ConnectionPoint
	var belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3(0, 0, 2), "quest_test_belt")
	ConveyorConnectionManager.register_belt(belt)
	check(not ConveyorConnectionManager.has_valid_automated_line())
	check(ConveyorConnectionManager.connect_belt_endpoint(belt, ConnectionPoint.PointType.START, output_port))
	check(not ConveyorConnectionManager.has_valid_automated_line())
	check(ConveyorConnectionManager.connect_belt_endpoint(belt, ConnectionPoint.PointType.END, input_port))
	check(ConveyorConnectionManager.has_valid_automated_line())
	check(_completed_steps().has("automated_line"))
	check(QuestManager.get_journal_entries()[0].complete)
	check(QuestManager.get_active_step().get("step_id", "") == "delivery_order")

	check(ConveyorConnectionManager.remove_conveyor(belt, false, false))
	check(_completed_steps().has("automated_line"))
	smelter.queue_free()
	sink.queue_free()

	GameplayEventBus.publish(GameplayEventBus.ITEM_DELIVERED, "wrong_item", 20)
	GameplayEventBus.publish(GameplayEventBus.ITEM_DELIVERED, "5", 9)
	check(not _completed_steps().has("delivery_order"))
	GameplayEventBus.publish(GameplayEventBus.ITEM_DELIVERED, "5", 1)
	check(_completed_steps().has("delivery_order"))
	var saved_state: Dictionary = QuestManager.get_save_data()
	QuestManager.clear_save_data()
	QuestManager.load_save_data(saved_state)
	check(_completed_steps().size() == 5)

	SaveManager.clear_all_saveables()
	check(_completed_steps().is_empty())
	check(QuestManager.get_active_step().get("step_id", "") == "recover_site")
	tracker.queue_free()
	journal.queue_free()
	GameStateManager.set_creative_mode(was_creative)

func _completed_steps() -> Array:
	var completed: Array = []
	for step in QuestManager.get_journal_entries()[0].steps:
		if bool(step.complete):
			completed.append(str(step.step_id))
	return completed

func _create_tracker() -> Control:
	var tracker := QUEST_TRACKER_SCRIPT.new() as Control
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	var vertical := VBoxContainer.new()
	vertical.name = "VBoxContainer"
	var goal := Label.new()
	goal.name = "Goal"
	var progress := Label.new()
	progress.name = "Progress"
	vertical.add_child(goal)
	vertical.add_child(progress)
	margin.add_child(vertical)
	tracker.add_child(margin)
	return tracker
