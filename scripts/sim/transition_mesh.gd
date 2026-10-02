class_name TransitionMesh
extends Node3D

const LIFT: float = 0.07
const SAMPLES: int = 12
const MIN_LENGTH: float = 0.5

var _mesh: MeshInstance3D
var _material: StandardMaterial3D

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.22, 0.22, 0.25)
	_material.roughness = 0.95
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _material
	add_child(_mesh)
	LaneGraph.lanes_changed.connect(_rebuild)

func _rebuild() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drawn: int = 0
	for arc in LaneGraph.arcs:
		var c: Curve3D = arc.curve
		if c == null:
			continue
		if arc.length < MIN_LENGTH:
			continue
		if arc.node != null and arc.node.is_waypoint and arc.node.segment_ends.size() == 2:
			continue
		var lane_hw: float = arc.from_lane.segment.road_type.lane_width * 0.5
		var d_hw: float = arc.to_lane.segment.road_type.lane_width * 0.5
		var hw: float = minf(lane_hw, d_hw)
		_build_ribbon(st, c, hw)
		drawn += 1
	_mesh.mesh = st.commit()
	print("[transition_mesh] drew %d ribbons" % drawn)

func _build_ribbon(st: SurfaceTool, c: Curve3D, half_width: float) -> void:
	var length: float = c.get_baked_length()
	if length < 0.1:
		return
	var samples: int = maxi(4, SAMPLES)
	var prev_l: Vector3 = Vector3.ZERO
	var prev_r: Vector3 = Vector3.ZERO
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var along: float = t * length
		var p: Vector3 = c.sample_baked(along)
		var ahead_d: float = minf(along + 0.2, length)
		var behind_d: float = maxf(along - 0.2, 0.0)
		var ahead: Vector3 = c.sample_baked(ahead_d)
		var behind: Vector3 = c.sample_baked(behind_d)
		var tangent: Vector3 = ahead - behind
		tangent.y = 0.0
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()
		var right: Vector3 = tangent.cross(Vector3.UP)
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()
		var l: Vector3 = p - right * half_width + Vector3(0.0, LIFT, 0.0)
		var r: Vector3 = p + right * half_width + Vector3(0.0, LIFT, 0.0)
		if i > 0:
			_tri(st, prev_l, prev_r, l)
			_tri(st, prev_r, r, l)
		prev_l = l
		prev_r = r

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.add_vertex(c)
