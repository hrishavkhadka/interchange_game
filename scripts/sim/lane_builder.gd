class_name LaneBuilder
extends RefCounted

static func build_lane_curve(segment_curve: Curve3D, rt: RoadType, lane_index: int, direction: String) -> Curve3D:
	var total_length: float = segment_curve.get_baked_length()
	if total_length < 0.1:
		return null
	var samples: int = maxi(8, int(total_length * 0.5))
	var offset: float = rt.lane_right_offset(lane_index)
	var delta: float = 0.2

	var points: Array[Vector3] = []
	points.resize(samples + 1)
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var along: float = t * total_length
		var p: Vector3 = segment_curve.sample_baked(along)

		# Centered-difference tangent so endpoints are well defined.
		var prev_along: float = maxf(along - delta, 0.0)
		var next_along: float = minf(along + delta, total_length)
		var prev_p: Vector3 = segment_curve.sample_baked(prev_along)
		var next_p: Vector3 = segment_curve.sample_baked(next_along)

		var tangent: Vector3 = next_p - prev_p
		tangent.y = 0.0
		if tangent.length_squared() < 0.0001:
			tangent = next_p - p
			tangent.y = 0.0
		if tangent.length_squared() < 0.0001:
			tangent = p - prev_p
			tangent.y = 0.0
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()

		var right: Vector3 = tangent.cross(Vector3.UP)
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()

		points[i] = p + right * offset

	if direction == "B":
		points.reverse()

	var curve := Curve3D.new()
	for p in points:
		curve.add_point(p)
	return curve
