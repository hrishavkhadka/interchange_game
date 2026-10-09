class_name ArcGenerator
extends RefCounted

static func generate(node: RoadNode, all_lanes: Array) -> Array:
	if node == null or node.segment_ends.size() < 2:
		return []
	if node.is_pass_through():
		return _generate_pass_through(node, all_lanes)
	return _generate_junction(node, all_lanes)

# At a pass-through there are exactly two collinear segments. Each arriving
# lane connects to the departing lane on the OTHER segment that shares its
# direction and is closest in lane index.
static func _generate_pass_through(node: RoadNode, all_lanes: Array) -> Array:
	var result: Array = []
	var incoming: Array = []
	var outgoing: Array = []
	for lane_v in all_lanes:
		var lane: Lane = lane_v
		if lane.to_node == node and lane.from_node != node:
			incoming.append(lane)
		if lane.from_node == node and lane.to_node != node:
			outgoing.append(lane)
	for il_v in incoming:
		var il: Lane = il_v
		var best: Lane = null
		var best_dl: int = 9999
		for ol_v in outgoing:
			var ol: Lane = ol_v
			if ol.segment == il.segment:
				continue
			if ol.direction != il.direction:
				continue
			var dl: int = absi(ol.lane_index - il.lane_index)
			if dl < best_dl:
				best_dl = dl
				best = ol
		if best != null:
			result.append({ "from_lane": il, "to_lane": best })
	return result

static func _generate_junction(node: RoadNode, all_lanes: Array) -> Array:
	var result: Array = []
	var arriving: Array = []
	var departing: Array = []
	for lane_v in all_lanes:
		var lane: Lane = lane_v
		if lane.to_node == node and lane.from_node != node:
			_add_to_group(arriving, lane)
		if lane.from_node == node and lane.to_node != node:
			_add_to_group(departing, lane)

	if arriving.is_empty() or departing.is_empty():
		return result

	for a in arriving:
		var al: Array = a["lanes"]
		al.sort_custom(func(x, y): return x.lane_index < y.lane_index)
	for d in departing:
		var dl: Array = d["lanes"]
		dl.sort_custom(func(x, y): return x.lane_index < y.lane_index)

	var n_in: int = arriving.size()
	var n_out: int = departing.size()

	# Reference directions: from the far end of the arriving segment toward
	# the node (the direction a driver is heading as they arrive), and from
	# the node outward along the departing segment.
	var entry_dirs: Array = []
	for i in n_in:
		var seg: RoadSegment = arriving[i]["segment"]
		var other: RoadNode = _far_end(seg, node)
		if other == null:
			entry_dirs.append(Vector3.FORWARD)
			continue
		var d: Vector3 = node.position - other.position
		d.y = 0.0
		if d.length_squared() < 0.001:
			d = Vector3.FORWARD
		entry_dirs.append(d.normalized())

	var exit_dirs: Array = []
	for j in n_out:
		var seg2: RoadSegment = departing[j]["segment"]
		var other2: RoadNode = _far_end(seg2, node)
		if other2 == null:
			exit_dirs.append(Vector3.FORWARD)
			continue
		var d2: Vector3 = other2.position - node.position
		d2.y = 0.0
		if d2.length_squared() < 0.001:
			d2 = Vector3.FORWARD
		exit_dirs.append(d2.normalized())

	# 1. Commitment matrix. Skip U-turns (same segment).
	var C: Array = []
	for i in n_in:
		var row: Array = []
		for j in n_out:
			var is_uturn: bool = arriving[i]["segment"] == departing[j]["segment"]
			row.append(0 if is_uturn else 1)
		C.append(row)

	# 2. Distribute surplus lanes.
	var in_surplus: Array = []
	for i in n_in:
		var committed: int = 0
		for j in n_out:
			committed += int(C[i][j])
		in_surplus.append(arriving[i]["lanes"].size() - committed)

	var out_surplus: Array = []
	for j in n_out:
		var committed2: int = 0
		for i in n_in:
			committed2 += int(C[i][j])
		out_surplus.append(departing[j]["lanes"].size() - committed2)

	var safety: int = 0
	while safety < 500:
		safety += 1
		var best_i: int = -1
		var best_j: int = -1
		var best_score: int = 0
		for i in n_in:
			if in_surplus[i] <= 0:
				continue
			for j in n_out:
				if out_surplus[j] <= 0:
					continue
				if C[i][j] == 0:
					continue
				var score: int = mini(in_surplus[i], out_surplus[j])
				if score > best_score:
					best_score = score
					best_i = i
					best_j = j
		if best_i < 0:
			break
		C[best_i][best_j] += 1
		in_surplus[best_i] -= 1
		out_surplus[best_j] -= 1

	# 3. Lane assignment.
	for i in n_in:
		var entry_lanes: Array = arriving[i]["lanes"]
		var lane_count: int = entry_lanes.size()
		if lane_count == 0:
			continue
		var ref_dir: Vector3 = entry_dirs[i]

		# Sort exits by signed angle. Ascending -> rightmost first.
		var exits_sorted: Array = []
		for j in n_out:
			if C[i][j] <= 0:
				continue
			var ang: float = _signed_angle_xz(ref_dir, exit_dirs[j])
			exits_sorted.append({ "j": j, "angle": ang })
		exits_sorted.sort_custom(func(x, y): return x["angle"] < y["angle"])

		# Flat list of commitments in right-to-left order.
		var commitments: Array = []
		for e in exits_sorted:
			var j2: int = e["j"]
			var count: int = C[i][j2]
			for _k in count:
				commitments.append(j2)
		if commitments.is_empty():
			continue

		# Spread commitments across entry lanes.
		var n_c: int = commitments.size()
		var entry_lanes_for_exit: Dictionary = {}
		for k in n_c:
			var j3: int = commitments[k]
			var lane_pos: int = 0
			if n_c > 1 and lane_count > 1:
				lane_pos = int(round(float(k) * float(lane_count - 1) / float(n_c - 1)))
			lane_pos = clampi(lane_pos, 0, lane_count - 1)
			var from_lane: Lane = entry_lanes[lane_pos]
			if not entry_lanes_for_exit.has(j3):
				entry_lanes_for_exit[j3] = []
			if not entry_lanes_for_exit[j3].has(from_lane):
				entry_lanes_for_exit[j3].append(from_lane)

		# Match to exit lanes by index order.
		for j4 in entry_lanes_for_exit.keys():
			var entry_lanes_list: Array = entry_lanes_for_exit[j4]
			entry_lanes_list.sort_custom(func(x, y): return x.lane_index < y.lane_index)
			var exit_lanes_list: Array = departing[j4]["lanes"]
			exit_lanes_list.sort_custom(func(x, y): return x.lane_index < y.lane_index)
			var count2: int = entry_lanes_list.size()
			var ec: int = exit_lanes_list.size()
			if ec == 0:
				continue
			for k2 in count2:
				var from_lane2: Lane = entry_lanes_list[k2]
				var exit_idx: int = 0
				if count2 > 1 and ec > 1:
					exit_idx = int(round(float(k2) * float(ec - 1) / float(count2 - 1)))
				exit_idx = clampi(exit_idx, 0, ec - 1)
				var to_lane: Lane = exit_lanes_list[exit_idx]
				result.append({ "from_lane": from_lane2, "to_lane": to_lane })

	return result

static func _add_to_group(groups: Array, lane: Lane) -> void:
	for g in groups:
		if g["segment"] == lane.segment:
			var gl: Array = g["lanes"]
			gl.append(lane)
			return
	groups.append({ "segment": lane.segment, "lanes": [lane] })

static func _far_end(seg: RoadSegment, node: RoadNode) -> RoadNode:
	if seg.start_node == node:
		return seg.end_node
	if seg.end_node == node:
		return seg.start_node
	return null

static func _signed_angle_xz(a: Vector3, b: Vector3) -> float:
	var cross_y: float = a.x * b.z - a.z * b.x
	var dot: float = a.x * b.x + a.z * b.z
	return atan2(cross_y, dot)
