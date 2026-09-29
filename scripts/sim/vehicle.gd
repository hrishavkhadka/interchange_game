class_name Vehicle
extends Node3D

var path: Array[PathStep] = []
var step_index: int = 0
var distance_on_step: float = 0.0
var speed: float = 0.0
var target_node: RoadNode
var length: float = 4.5
var color_seed: int = 0
var cooldown: float = 0.0

var _mesh: MeshInstance3D

func current_curve() -> Curve3D:
	if path.is_empty() or step_index >= path.size():
		return null
	return path[step_index].curve

func current_step_length() -> float:
	if path.is_empty() or step_index >= path.size():
		return 0.0
	return path[step_index].length

func current_lane() -> Lane:
	if path.is_empty() or step_index >= path.size():
		return null
	var s: PathStep = path[step_index]
	if not s.is_lane:
		return null
	return s.lane_ref

func desired_speed() -> float:
	if path.is_empty() or step_index >= path.size():
		return 0.0
	return path[step_index].speed

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

func setup(steps: Array[PathStep], t: RoadNode, seed_value: int, v0: float) -> void:
	path = steps
	target_node = t
	step_index = 0
	distance_on_step = 0.0
	speed = v0
	color_seed = seed_value
	cooldown = 0.0

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 1.4, 4.2)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = make_color(seed_value)
	mat.roughness = 0.7
	_mesh.material_override = mat
	add_child(_mesh)

	_update_transform()

# Splice a lateral move into the vehicle's path followed by `subsequent`.
# Called when a lane change is decided.
func begin_lane_change(target_lane: Lane, subsequent: Array[PathStep], cooldown_seconds: float) -> void:
	var p_cur: float = distance_on_step
	var c_cur: Curve3D = current_curve()
	if c_cur == null:
		return
	var start_p: Vector3 = c_cur.sample_baked(p_cur)

	var frac: float = p_cur / maxf(current_step_length(), 0.001)
	var p_tgt: float = frac * target_lane.length
	var end_p: Vector3 = target_lane.curve.sample_baked(p_tgt)

	var lat_curve := Curve3D.new()
	lat_curve.add_point(start_p)
	lat_curve.add_point(end_p)
	var lat_step := PathStep.make(lat_curve, target_lane.speed_limit, false)

	var new_path: Array[PathStep] = []
	for i in range(step_index):
		new_path.append(path[i])
	new_path.append(lat_step)
	new_path.append_array(subsequent)
	path = new_path
	distance_on_step = 0.0
	cooldown = cooldown_seconds

func _update_transform() -> void:
	var c := current_curve()
	if c == null:
		return
	var L := current_step_length()
	var d: float = clampf(distance_on_step, 0.0, L)
	var p: Vector3 = c.sample_baked(d)
	var ahead_d: float = minf(d + 0.5, L)
	var ahead: Vector3 = c.sample_baked(ahead_d)
	global_position = p + Vector3(0.0, 0.75, 0.0)
	var dir: Vector3 = ahead - p
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		look_at(global_position + dir.normalized(), Vector3.UP)
