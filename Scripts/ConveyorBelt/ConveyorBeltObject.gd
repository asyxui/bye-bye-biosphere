class_name ConveyorBeltObject

var start: Vector3
var end: Vector3

func _init(p_start: Vector3, p_end: Vector3):
	start = p_start
	end = p_end
	
func to_dict() -> Dictionary:
	return {
		"start": [start.x, start.y, start.z],
		"end": [end.x, end.y, end.z]
	}

static func from_dict(d: Dictionary) -> ConveyorBeltObject:
	if not d.has("start") or not d.has("end"):
		push_error("Invalid conveyor belt JSON entry: %s" % d)
		return null

	return ConveyorBeltObject.new(
		Vector3(d["start"][0], d["start"][1], d["start"][2]),
		Vector3(d["end"][0], d["end"][1], d["end"][2])
	)
