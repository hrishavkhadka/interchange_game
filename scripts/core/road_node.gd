class_name RoadNode
extends RefCounted

var id: int
var position: Vector3
# Each entry: { segment: RoadSegment, is_start: bool }
var segment_ends: Array = []

func _init(p_position: Vector3, p_id: int) -> void:
	position = p_position
	id = p_id

func degree() -> int:
	return segment_ends.size()

func add_segment_end(seg: RoadSegment, is_start: bool) -> void:
	segment_ends.append({ "segment": seg, "is_start": is_start })
