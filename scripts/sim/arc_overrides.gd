extends Node

signal overrides_changed

var _disabled: Dictionary = {}

var _node_idx: Dictionary = {}
var _seg_idx: Dictionary = {}

func refresh_indices() -> void:
	_node_idx.clear()
	_seg_idx.clear()
	for i in RoadGraph.nodes.size():
		_node_idx[RoadGraph.nodes[i]] = i
	for i in RoadGraph.segments.size():
		_seg_idx[RoadGraph.segments[i]] = i

func _index_of_node(node: RoadNode) -> int:
	if _node_idx.is_empty() and RoadGraph.nodes.size() > 0:
		refresh_indices()
	return _node_idx.get(node, -1)

func _index_of_segment(seg: RoadSegment) -> int:
	if _seg_idx.is_empty() and RoadGraph.segments.size() > 0:
		refresh_indices()
	return _seg_idx.get(seg, -1)

func _key(node: RoadNode, from_lane: Lane, to_lane: Lane) -> String:
	var ni: int = _index_of_node(node)
	var fsi: int = _index_of_segment(from_lane.segment)
	var tsi: int = _index_of_segment(to_lane.segment)
	if ni < 0 or fsi < 0 or tsi < 0:
		return ""
	return "%d|%d|%d|%d|%d" % [ni, fsi, from_lane.lane_index, tsi, to_lane.lane_index]

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

func set_disabled_stable(node_idx: int, from_seg_idx: int, from_lane_idx: int, to_seg_idx: int, to_lane_idx: int, on: bool) -> void:
	var k := "%d|%d|%d|%d|%d" % [node_idx, from_seg_idx, from_lane_idx, to_seg_idx, to_lane_idx]
	if on:
		_disabled[k] = true
	else:
		_disabled.erase(k)

func serialize() -> Array:
	var result: Array = []
	for k in _disabled:
		var parts: PackedStringArray = String(k).split("|")
		if parts.size() != 5:
			continue
		result.append({
			"node": int(parts[0]),
			"from_seg": int(parts[1]),
			"from_lane": int(parts[2]),
			"to_seg": int(parts[3]),
			"to_lane": int(parts[4]),
		})
	return result

func clear() -> void:
	_disabled.clear()
	overrides_changed.emit()
