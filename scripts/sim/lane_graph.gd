extends Node

signal lanes_changed

var lanes: Array[Lane] = []

func _ready() -> void:
	RoadGraph.graph_changed.connect(_rebuild)

func _rebuild() -> void:
	lanes.clear()
	var trims := _compute_node_trims()

	for seg in RoadGraph.segments:
		if seg.road_type == null or seg.curve == null:
			continue
		if seg.start_node == null or seg.end_node == null:
			continue
		var start_trim: float = trims.get(seg.start_node.id, 0.0)
		var end_trim: float = trims.get(seg.end_node.id, 0.0)
		var layout := seg.road_type.layout()
		for i in layout.size():
			var dir: String = layout.lanes[i]
			var lane := _make_lane(seg, i, dir, start_trim, end_trim)
			if lane != null:
				lanes.append(lane)

	_build_connections()
	_build_transitions()
	lanes_changed.emit()

func _compute_node_trims() -> Dictionary:
	var trims: Dictionary = {}
	for node in RoadGraph.nodes:
		var ends: Array = node.segment_ends
		if ends.size() < 2:
			trims[node.id] = 0.0
			continue

		var min_angle: float = PI
		for i in ends.size():
			for j in range(i + 1, ends.size()):
				var e1: Dictionary = ends[i]
				var e2: Dictionary = ends[j]
				var s1: RoadSegment = e1["segment"]
				var s2: RoadSegment = e2["segment"]
				var d1: Vector3 = _outward_dir(s1, e1["is_start"], node)
				var d2: Vector3 = _outward_dir(s2, e2["is_start"], node)
				if d1.length_squared() < 0.01 or d2.length_squared() < 0.01:
					continue
				var ang: float = d1.angle_to(d2)
				if ang < min_angle:
					min_angle = ang

		var factor: float = LaneBuilder.trim_factor_for_angle(min_angle)

		# Base trim on the widest lane offset at this node (outer lane of the
		# widest attached road). For a 2-lane road, this is lane_width/2.
		var max_half_width: float = 0.0
		for e in ends:
			var s: RoadSegment = e["segment"]
			if s.road_type == null:
				continue
			var hw: float = s.road_type.total_width() * 0.5
			if hw > max_half_width:
				max_half_width = hw
		trims[node.id] = factor * max_half_width
	return trims

static func _outward_dir(seg: RoadSegment, is_start: bool, node: RoadNode) -> Vector3:
	var other: RoadNode
	if is_start:
		other = seg.end_node
	else:
		other = seg.start_node
	if other == null:
		return Vector3.ZERO
	var d: Vector3 = other.position - node.position
	d.y = 0.0
	if d.length_squared() < 0.01:
		return Vector3.ZERO
	return d.normalized()

func _make_lane(seg: RoadSegment, lane_index: int, direction: String, start_trim: float, end_trim: float) -> Lane:
	var curve := LaneBuilder.build_lane_curve(seg.curve, seg.road_type, lane_index, direction, start_trim, end_trim)
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

	if dist < 0.1:
		var straight := Curve3D.new()
		straight.add_point(start_p)
		straight.add_point(end_p)
		return straight

	var start_t: Vector3 = _end_tangent(from_lane.curve, from_lane.length)
	var end_t: Vector3 = _start_tangent(to_lane.curve)

	var handle_len: float = dist / 3.0
	var p1: Vector3 = start_p + start_t * handle_len
	var p2: Vector3 = end_p - end_t * handle_len

	var samples: int = maxi(6, int(dist * 1.5))
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
