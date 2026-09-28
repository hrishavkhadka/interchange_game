class_name Vehicle
extends Node3D

var path: Array[Lane] = []
var target_node: RoadNode

var _lane_index: int = 0
var _distance: float = 0.0
var _curve: Curve3D
var _curve_length: float
var _curve_speed: float
var _on_transition: bool = false

var _mesh: MeshInstance3D

static func make_color(seed_value: int) -> Color:
	var palette: Array[Color] = [
		Color(0.85, 0.20, 0.20),
		Color(0.20, 0.45, 0.85),
		Color(0.95, 0.85, 0.20),
		Color(0.30, 0.75, 0.35),
		Color(0.85, 0.55, 0.20),
		Color(0.80, 0.80, 0.85),
		Color(0.30, 0.30, 0.35),
	]
	return palette[seed_value % palette.size()]

func setup(p: Array[Lane], t: RoadNode, color_seed: int) -> void:
	path = p
	target_node = t
	_lane_index = 0
	_distance = 0.0
	_on_transition = false
	_curve = path[0].curve
	_curve_length = path[0].length
	_curve_speed = path[0].speed_limit

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 1.4, 4.2)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = make_color(color_seed)
	mat.roughness = 0.7
	_mesh.material_override = mat
	add_child(_mesh)

	_place_at(_distance)

func _physics_process(delta: float) -> void:
	if _curve == null:
		queue_free()
		return

	var move: float = _curve_speed * delta
	var safety: int = 0
	while move > 0.0 and safety < 8:
		safety += 1
		var to_end: float = _curve_length - _distance
		if move < to_end:
			_distance += move
			move = 0.0
		else:
			move -= to_end
			_distance = 0.0
			if not _advance():
				return

	_place_at(_distance)

func _advance() -> bool:
	if _on_transition:
		# Finished a transition; step onto the next lane.
		_lane_index += 1
		if _lane_index >= path.size():
			queue_free()
			return false
		var lane: Lane = path[_lane_index]
		_curve = lane.curve
		_curve_length = lane.length
		_curve_speed = lane.speed_limit
		_on_transition = false
		return true

	# Finished a lane.
	if _lane_index >= path.size() - 1:
		# Last lane; despawn at its end.
		queue_free()
		return false

	var from_lane: Lane = path[_lane_index]
	var to_lane: Lane = path[_lane_index + 1]
	if not from_lane.next_curves.has(to_lane):
		queue_free()
		return false
	var tc: Curve3D = from_lane.next_curves[to_lane]
	_curve = tc
	_curve_length = tc.get_baked_length()
	_curve_speed = minf(from_lane.speed_limit, to_lane.speed_limit)
	_on_transition = true
	return true

func _place_at(dist: float) -> void:
	var p: Vector3 = _curve.sample_baked(dist)
	var ahead_dist: float = minf(dist + 0.5, _curve_length)
	var ahead: Vector3 = _curve.sample_baked(ahead_dist)
	global_position = p + Vector3(0.0, 0.75, 0.0)
	var d: Vector3 = ahead - p
	d.y = 0.0
	if d.length_squared() > 0.0001:
		look_at(global_position + d.normalized(), Vector3.UP)
