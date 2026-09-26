class_name RoadMesh
extends RefCounted

const SAMPLES_PER_METER := 0.5
const MIN_SAMPLES := 8
const SURFACE_LIFT := 0.02   # ← new: lift road surface above ground to avoid z-fighting

# Returns an ArrayMesh with one surface: the road slab top.
# UVs: u = 0 (left edge) → 1 (right edge), v = 0 → 1 along the curve.
static func build_slab(curve: Curve3D, rt: RoadType) -> ArrayMesh:
	var length := curve.get_baked_length()
	if length < 0.1:
		return null

	var samples := maxi(MIN_SAMPLES, int(length * SAMPLES_PER_METER))
	var half_width := rt.total_width() * 0.5

	# Pre-sample positions and tangents.
	var positions: Array[Vector3] = []
	var tangents: Array[Vector3] = []
	positions.resize(samples + 1)
	tangents.resize(samples + 1)

	for i in range(samples + 1):
		var t := float(i) / float(samples)
		var offset := t * length
		var pos := curve.sample_baked(offset)
		var ahead := curve.sample_baked(minf(offset + 0.05, length))
		var tan := ahead - pos
		if tan.length_squared() < 0.0001:
			tan = Vector3.FORWARD
		positions[i] = pos
		tangents[i] = tan.normalized()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(samples):
		var p0 := positions[i]
		var p1 := positions[i + 1]
		var t0 := tangents[i]
		var t1 := tangents[i + 1]

		# "Right" perpendicular, horizontal (Y is up).
		var r0 := Vector3.UP.cross(t0)
		var r1 := Vector3.UP.cross(t1)
		if r0.length_squared() < 0.001:
			r0 = Vector3.RIGHT
		if r1.length_squared() < 0.001:
			r1 = Vector3.RIGHT
		r0 = r0.normalized()
		r1 = r1.normalized()

		var l0 := p0 - r0 * half_width
		var rr0 := p0 + r0 * half_width
		var l1 := p1 - r1 * half_width
		var rr1 := p1 + r1 * half_width

		var v0 := float(i) / float(samples)
		var v1 := float(i + 1) / float(samples)

		# Triangle 1
		_vert(st, l0, Vector3.UP, Vector2(0.0, v0))
		_vert(st, rr0, Vector3.UP, Vector2(1.0, v0))
		_vert(st, l1, Vector3.UP, Vector2(0.0, v1))
		# Triangle 2
		_vert(st, rr0, Vector3.UP, Vector2(1.0, v0))
		_vert(st, rr1, Vector3.UP, Vector2(1.0, v1))
		_vert(st, l1, Vector3.UP, Vector2(0.0, v1))

	return st.commit()

static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)
