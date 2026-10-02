class_name RoadNode
extends RefCounted

# Interior angle above which a 2-segment node is treated as a pass-through
# (no trim, no patch, no arcs, no junction rules). 180° = perfectly straight.
const PASS_THROUGH_ANGLE_DEG: float = 150.0

var id: int
var position: Vector3
var is_waypoint: bool = false
var segment_ends: Array = []

func _init(p_position: Vector3, p_id: int) -> void:
	position = p_position
	id = p_id

func degree() -> int:
	return segment_ends.size()

func add_segment_end(seg: RoadSegment, is_start: bool) -> void:
	segment_ends.append({ "segment": seg, "is_start": is_start })

# A node is a pass-through when it has exactly two attached segments and
# their outward directions are nearly collinear. Pass-through nodes behave
# as if the two segments were a single continuous road.
func is_pass_through() -> bool:
	if segment_ends.size() != 2:
		return false
	var dirs: Array[Vector3] = []
	for entry in segment_ends:
		var e: Dictionary = entry
		var seg: RoadSegment = e["segment"]
		if seg == null:
			return false
		var other: RoadNode
		if e["is_start"]:
			other = seg.end_node
		else:
			other = seg.start_node
		if other == null:
			return false
		var d: Vector3 = other.position - position
		d.y = 0.0
		if d.length_squared() < 0.01:
			return false
		dirs.append(d.normalized())
	var ang: float = dirs[0].angle_to(dirs[1])
	return ang > deg_to_rad(PASS_THROUGH_ANGLE_DEG)
