class_name LaneBuilder
extends RefCounted

const DELTA: float = 0.2
const TRIM_FACTOR: float = 5

# Trim each lane by `TRIM_FACTOR * lane_width` at each segment end. This is
# enough that lane endpoints sit on the "near side" of the point where the
# two lanes' centerlines would intersect at a junction, for every turn angle
# up to about 150 degrees. If trim is too small, junction transition curves
# loop back on themselves; if too large, short segments break.
static func trim_distance(rt: RoadType) -> float:
	return rt.lane_width * TRIM_FACTOR

static func build_lane_curve(segment_curve: Curve3D, rt: RoadType, lane_index: int, direction: String) -> Curve3D:
	var total_length: float = segment_curve.get_baked_length()
	if total_length < 0.1:
		return null
	var trim: float = trim_distance(rt)
	var max_trim: float = total_length * 0.4
	if trim > max_trim:
		trim = max_trim
	var usable: float = total_length - 2.0 * trim
	if usable < 0.1:
		return null

	var samples: int = maxi(6, int(usable * 0.5))
	var offset: float = rt.lane_right_offset(lane_index)

	var points: Array[Vector3] = []
	points.resize(samples + 1)
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var along: float = trim + t * usable
		var p: Vector3 = segment_curve.sample_baked(along)

		var prev_along: float = maxf(along - DELTA, 0.0)
		var next_along: float = minf(along + DELTA, total_length)
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
