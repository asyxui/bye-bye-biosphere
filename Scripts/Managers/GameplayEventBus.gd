extends Node

signal event_published(event_type: StringName, subject_id: String, quantity: int)

const ITEM_MINED: StringName = &"item_mined"
const ITEM_CRAFTED: StringName = &"item_crafted"
const MACHINE_PLACED: StringName = &"machine_placed"
const ITEM_PRODUCED: StringName = &"item_produced"
const AUTOMATED_LINE_CONNECTED: StringName = &"automated_line_connected"
const ITEM_DELIVERED: StringName = &"item_delivered"
const BIOSPHERE_EVENT: StringName = &"biosphere_event"

func publish(event_type: StringName, subject_id: String = "", quantity: int = 1) -> void:
	if event_type.is_empty() or quantity <= 0:
		return
	event_published.emit(event_type, subject_id, quantity)
