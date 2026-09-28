extends Node

signal lanes_changed

var lanes: Array[Lane] = []

func _ready() -> void:
	RoadGraph.graph_changed.connect(_rebuild)

func _rebuild() -> void:
	lanes.clear()

	for seg in RoadGraph.segments:
		if seg.road_type == null or seg.curve == null:
			continue
		if seg.start_node == null or seg.end_node == null:
			continue
		var layout := seg.road_type.layout()
		for i in layout.size():
			var dir: String = layout.lanes[i]
			var lane := _make_lane(seg, i, dir)
			if lane != null:
				lanes.append(lane)

	_build_connections()
	lanes_changed.emit()

func _make_lane(seg: RoadSegment, lane_index: int, direction: String) -> Lane:
	var curve := LaneBuilder.build_lane_curve(seg.curve, seg.road_type, lane_index, direction)
	if curve == null:
		return null
	var lane := Lane.new()
	lane.segment = seg
	lane.lane_index = lane_index
	lane.direction = direction
	lane.curve = curve
	lane.length = curve.get_baked_length()
	if direction == "F":
		lane.from_node = seg.start_node
		lane.to_node = seg.end_node
	else:
		lane.from_node = seg.end_node
		lane.to_node = seg.start_node
	lane.speed_limit = seg.road_type.speed_limit_kmh / 3.6
	return lane

func _build_connections() -> void:
	# Group lanes by from_node id for quick lookup.
	var by_from: Dictionary = {}
	for lane in lanes:
		if lane.from_node == null:
			continue
		var key: int = lane.from_node.id
		if not by_from.has(key):
			by_from[key] = []
		by_from[key].append(lane)

	for arriving in lanes:
		var node := arriving.to_node
		if node == null:
			continue
		var departing_list: Array = by_from.get(node.id, [])
		for d in departing_list:
			var departing: Lane = d
			if departing.segment == arriving.segment:
				continue  # U-turn
			arriving.next_lanes.append(departing)
			departing.prev_lanes.append(arriving)

func lanes_departing_from(node: RoadNode) -> Array[Lane]:
	var result: Array[Lane] = []
	for lane in lanes:
		if lane.from_node == node:
			result.append(lane)
	return result

func lanes_arriving_at(node: RoadNode) -> Array[Lane]:
	var result: Array[Lane] = []
	for lane in lanes:
		if lane.to_node == node:
			result.append(lane)
	return result
