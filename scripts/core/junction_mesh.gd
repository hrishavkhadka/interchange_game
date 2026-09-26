class_name JunctionMesh
extends RefCounted

# 6 cm above the road surface; combined with the expanded hull this removes
# junction flicker at all camera distances.
const JUNCTION_LIFT: float = 0.08
# i don't think deepseek knows for sure if this constant EXPAND is here.
const EXPAND: float = 0.5

static func build(node: RoadNode) -> ArrayMesh:
	if node.segment_ends.size() < 2:
		return null

	var points: Array[Vector3] = []
	for entry in node.segment_ends:
		var seg: RoadSegment = entry["segment"]
		if not is_instance_valid(seg) or seg.road_type == null:
			continue
		var is_start: bool = entry["is_start"]
		var rt := seg.road_type
		var half_w := rt.total_width() * 0.5

		var other_end: Vector3
		if is_start:
			other_end = seg.end_node.position
		else:
			other_end = seg.start_node.position

		var dir := other_end - node.position
		dir.y = 0.0
		if dir.length_squared() < 0.0001:
			continue
		dir = dir.normalized()
		var perp := Vector3(-dir.z, 0.0, dir.x)

		points.append(node.position + perp * half_w)
		points.append(node.position - perp * half_w)

	if points.size() < 3:
		return null

	# Deduplicate within 1 cm
	var unique: Array[Vector3] = []
	for p in points:
		var dup := false
		for q in unique:
			if p.distance_to(q) < 0.01:
				dup = true
				break
		if not dup:
			unique.append(p)

	if unique.size() < 3:
		return null

	var hull := _convex_hull_xz(unique)
	if hull.size() < 3:
		return null

	var centroid := Vector3.ZERO
	for p in hull:
		centroid += p
	centroid /= float(hull.size())

	# Expand the hull outward from its centroid so it overlaps the road
	# ends instead of abutting them. This kills the seam flicker.
	const EXPAND := 0.5
	var expanded: Array[Vector3] = []
	for p in hull:
		var d := p - centroid
		d.y = 0.0
		if d.length_squared() > 0.0001:
			d = d.normalized()
		expanded.append(p + d * EXPAND)
	hull = expanded

	centroid.y = hull[0].y + JUNCTION_LIFT

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in hull.size():
		var j := (i + 1) % hull.size()
		var a: Vector3 = hull[i]
		var b: Vector3 = hull[j]
		a.y += RoadMesh.SURFACE_LIFT
		b.y += RoadMesh.SURFACE_LIFT
		_vert(st, centroid, Vector2(0.5, 0.5))
		_vert(st, a, Vector2(0.0, 0.0))
		_vert(st, b, Vector2(1.0, 0.0))
	return st.commit()

static func _vert(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(uv)
	st.add_vertex(p)

# Andrew's monotone chain. Returns CCW hull in XZ.
static func _convex_hull_xz(points: Array[Vector3]) -> Array[Vector3]:
	var pts := points.duplicate()
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		if absf(a.x - b.x) < 0.0001:
			return a.z < b.z
		return a.x < b.x)

	if pts.size() < 3:
		return pts

	var lower: Array[Vector3] = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)

	var upper: Array[Vector3] = []
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector3 = pts[i]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)

	lower.pop_back()
	upper.pop_back()
	var result: Array[Vector3] = []
	result.append_array(lower)
	result.append_array(upper)
	return result

static func _cross(o: Vector3, a: Vector3, b: Vector3) -> float:
	return (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
