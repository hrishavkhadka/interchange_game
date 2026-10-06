extends Node

signal overrides_changed

# Keys are strings of the form node_id|from_seg_id|from_idx|to_seg_id|to_idx.
# A key being present means the arc between those lanes is disabled by the
# player. Absent = enabled.
var _disabled: Dictionary = {}

func _key(node: RoadNode, from_lane: Lane, to_lane: Lane) -> String:
	if node == null or from_lane == null or to_lane == null:
		return ""
	if from_lane.segment == null or to_lane.segment == null:
		return ""
	return "%d|%d|%d|%d|%d" % [
		node.id,
		from_lane.segment.get_instance_id(),
		from_lane.lane_index,
		to_lane.segment.get_instance_id(),
		to_lane.lane_index,
	]

func is_disabled(node: RoadNode, from_lane: Lane, to_lane: Lane) -> bool:
	var k := _key(node, from_lane, to_lane)
	return k != "" and _disabled.has(k)

func set_disabled(node: RoadNode, from_lane: Lane, to_lane: Lane, on: bool) -> void:
	var k := _key(node, from_lane, to_lane)
	if k == "":
		return
	if on:
		_disabled[k] = true
	else:
		_disabled.erase(k)
	overrides_changed.emit()

func clear() -> void:
	_disabled.clear()
	overrides_changed.emit()
