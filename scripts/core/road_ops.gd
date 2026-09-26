class_name RoadOps
extends RefCounted

# Returns array of records sorted by distance from `start`:
#   { "point": Vector3, "segment": RoadSegment, "distance": float }
static func find_crossings(start: Vector3, end: Vector3) -> Array:
	var result: Array = []
	var a_start := Vector2(start.x, start.z)
	var a_end := Vector2(end.x, end.z)

	for seg in RoadGraph.segments:
		if seg.start_node == null or seg.end_node == null:
			continue
		var b_start3 := seg.start_node.position
		var b_end3 := seg.end_node.position

		# Skip segments that share an endpoint with the candidate
		if _near(b_start3, start) or _near(b_start3, end):
			continue
		if _near(b_end3, start) or _near(b_end3, end):
			continue

		var b_start := Vector2(b_start3.x, b_start3.z)
		var b_end := Vector2(b_end3.x, b_end3.z)

		var hit_raw: Variant = _seg_intersect_2d(a_start, a_end, b_start, b_end)
		if hit_raw == null:
			continue
		var hp: Vector2 = hit_raw
		var p3 := Vector3(hp.x, 0.0, hp.y)
		result.append({
			"point": p3,
			"segment": seg,
			"distance": a_start.distance_to(hp),
		})

	result.sort_custom(func(a, b): return a["distance"] < b["distance"])
	return result

static func _near(a: Vector3, b: Vector3, eps: float = 0.01) -> bool:
	return a.distance_to(b) < eps

# Standard 2D segment intersection. Returns Vector2 or null.
static func _seg_intersect_2d(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Variant:
	var d1 := p2 - p1
	var d2 := p4 - p3
	var denom := d1.x * d2.y - d1.y * d2.x
	if absf(denom) < 0.0001:
		return null
	var diff := p3 - p1
	var t := (diff.x * d2.y - diff.y * d2.x) / denom
	var u := (diff.x * d1.y - diff.y * d1.x) / denom
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return null
	return p1 + d1 * t
	
# Returns { "segment": RoadSegment, "point": Vector3 } if `pos` lies within
# the footprint (half-width of centerline in XZ) of any registered segment,
# or null otherwise. Picks the nearest such segment.
static func find_segment_under_point(pos: Vector3) -> Variant:
	var best_dist := INF
	var best: Variant = null
	for seg in RoadGraph.segments:
		if seg.start_node == null or seg.end_node == null:
			continue
		if seg.road_type == null:
			continue
		var a := seg.start_node.position
		var b := seg.end_node.position
		# Only consider roughly same-height segments
		if absf(a.y - pos.y) > 0.5 or absf(b.y - pos.y) > 0.5:
			continue
		var proj := _project_to_segment_xz(pos, a, b)
		var flat_dist := Vector2(proj.x - pos.x, proj.z - pos.z).length()
		var half_w := seg.road_type.total_width() * 0.5
		if flat_dist <= half_w and flat_dist < best_dist:
			best_dist = flat_dist
			best = { "segment": seg, "point": proj }
	return best

static func _project_to_segment_xz(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var pp := Vector2(p.x, p.z)
	var ab := pb - pa
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a
	var t := clampf((pp - pa).dot(ab) / len_sq, 0.0, 1.0)
	var hit := pa + ab * t
	return Vector3(hit.x, a.y, hit.y)
	
# True if a segment from `start` to `end` would cross any existing segment
# that is not the T-junction target. Sharing an endpoint with a segment is
# fine (that is a normal connection).
static func is_placement_valid(start: Vector3, end: Vector3, t_segment: Variant) -> bool:
	if start.distance_to(end) < 1.0:
		return false
	var a2 := Vector2(start.x, start.z)
	var b2 := Vector2(end.x, end.z)
	for seg in RoadGraph.segments:
		if seg.start_node == null or seg.end_node == null:
			continue
		if t_segment != null and seg == t_segment:
			continue
		var sa := seg.start_node.position
		var sb := seg.end_node.position
		# Ignore segments we touch at an endpoint
		if _point_touches(sa, start, end) or _point_touches(sb, start, end):
			continue
		var hit_raw: Variant = _seg_intersect_2d(
			a2, b2, Vector2(sa.x, sa.z), Vector2(sb.x, sb.z))
		if hit_raw != null:
			return false
	return true

static func _point_touches(p: Vector3, a: Vector3, b: Vector3, eps: float = 0.5) -> bool:
	return p.distance_to(a) < eps or p.distance_to(b) < eps
