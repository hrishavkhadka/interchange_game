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
	_build_transitions()
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
	var by_from: Dictionary = {}
	for lane in lanes:
		if lane.from_node == null:
			continue
		var key: int = lane.from_node.id
		if not by_from.has(key):
			by_from[key] = []
		by_from[key].append(lane)

	for arriving in lanes:
		arriving.next_lanes.clear()
		arriving.prev_lanes.clear()

	for arriving in lanes:
		var node := arriving.to_node
		if node == null:
			continue
		var departing_list: Array = by_from.get(node.id, [])
		for d in departing_list:
			var departing: Lane = d
			if departing.segment == arriving.segment:
				continue
			arriving.next_lanes.append(departing)
			departing.prev_lanes.append(arriving)

func _build_transitions() -> void:
	for arriving in lanes:
		arriving.next_curves.clear()
		for departing in arriving.next_lanes:
			var c := _make_transition(arriving, departing)
			if c != null:
				arriving.next_curves[departing] = c

static func _make_transition(from_lane: Lane, to_lane: Lane) -> Curve3D:
	var start_p: Vector3 = from_lane.curve.sample_baked(from_lane.length)
	var end_p: Vector3 = to_lane.curve.sample_baked(0.0)
	var dist: float = start_p.distance_to(end_p)

	if dist < 0.05:
		return null

	var start_t: Vector3 = _end_tangent(from_lane.curve, from_lane.length)
	var end_t: Vector3 = _start_tangent(to_lane.curve)

	var p1: Vector3 = start_p + start_t * (dist / 3.0)
	var p2: Vector3 = end_p - end_t * (dist / 3.0)

	var samples: int = maxi(4, int(dist * 1.5))
	var curve := Curve3D.new()
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var p: Vector3 = _bezier3(start_p, p1, p2, end_p, t)
		curve.add_point(p)
	return curve

static func _end_tangent(c: Curve3D, length: float) -> Vector3:
	var p_end: Vector3 = c.sample_baked(length)
	var p_before: Vector3 = c.sample_baked(maxf(length - 0.3, 0.0))
	var t: Vector3 = p_end - p_before
	t.y = 0.0
	if t.length_squared() < 0.0001:
		return Vector3.FORWARD
	return t.normalized()

static func _start_tangent(c: Curve3D) -> Vector3:
	var length: float = c.get_baked_length()
	var p_start: Vector3 = c.sample_baked(0.0)
	var p_after: Vector3 = c.sample_baked(minf(0.3, length))
	var t: Vector3 = p_after - p_start
	t.y = 0.0
	if t.length_squared() < 0.0001:
		return Vector3.FORWARD
	return t.normalized()

static func _bezier3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3

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
