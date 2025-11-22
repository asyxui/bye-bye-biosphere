extends Node

var points: Array[Node3D] = []
const SNAP_DISTANCE := 2

func register_point(p: Node3D):
	points.append(p)

func unregister_point(p: Node3D):
	points.erase(p)

func find_closest_connection(hit_pos: Vector3) -> ConnectionPoint:
	var closest: ConnectionPoint = null
	var closest_dist := SNAP_DISTANCE

	for point in points:
		var dist := point.global_position.distance_to(hit_pos)
		if dist < closest_dist:
			closest = point
			closest_dist = dist

	return closest
