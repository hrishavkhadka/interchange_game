class_name Vehicle
extends Node3D

const LATERAL_SAMPLES: int = 16
const AVOID_SECONDS: float = 8.0

var path: Array[PathStep] = []
var step_index: int = 0
var distance_on_step: float = 0.0
var speed: float = 0.0
var target_node: RoadNode
var length: float = 4.5
var color_seed: int = 0
var cooldown: float = 0.0
var avoid_lane: Lane = null
var avoid_timer: float = 0.0

# While a lateral move is in progress, the vehicle's own curve is a private
# spline that nobody else traverses. To make the changer visible to traffic
# already on the target lane, we register it in the target lane's occupancy
# list for the duration of the move.
var lateral_target_lane: Lane = null
var lateral_occupancy_dist: float = 0.0

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
	avoid_lane = null
	avoid_timer = 0.0
	lateral_target_lane = null
	lateral_occupancy_dist = 0.0

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

# Entries this vehicle occupies for other vehicles' leader lookups. Normally
# one entry (its current curve). During a lateral move it also occupies the
# target lane at the distance it will arrive at.
func occupancy_entries() -> Array:
	var result: Array = []
	var c := current_curve()
	if c != null:
		result.append({ "curve": c, "dist": distance_on_step })
	if lateral_target_lane != null:
		result.append({ "curve": lateral_target_lane.curve, "dist": lateral_occupancy_dist })
	return result

func begin_lane_change(
		target_lane: Lane,
		target_offset: float,
		subsequent: Array[PathStep],
		cooldown_seconds: float) -> void:
	var c_cur: Curve3D = current_curve()
	if c_cur == null:
		return
	var old_lane: Lane = current_lane()

	var start_p: Vector3 = c_cur.sample_baked(distance_on_step)
	var t_off: float = clampf(target_offset, 0.0, target_lane.length)
	var end_p: Vector3 = target_lane.curve.sample_baked(t_off)

	var ahead_d: float = minf(distance_on_step + 2.0, current_step_length())
	var ahead_p: Vector3 = c_cur.sample_baked(ahead_d)
	var start_t: Vector3 = ahead_p - start_p
	start_t.y = 0.0
	if start_t.length_squared() < 0.001:
		start_t = Vector3.FORWARD
	start_t = start_t.normalized()

	var t_ahead_d: float = minf(t_off + 2.0, target_lane.length)
	var t_ahead_p: Vector3 = target_lane.curve.sample_baked(t_ahead_d)
	var end_t: Vector3 = t_ahead_p - end_p
	end_t.y = 0.0
	if end_t.length_squared() < 0.001:
		end_t = start_t
	end_t = end_t.normalized()

	# Handle length equal to one third of the forward extent, at least 4 m.
	# Because `target_offset` is chosen ahead of the parallel position, the
	# curve naturally extends forward and looks like a real lane change.
	var forward: float = end_p.distance_to(start_p)
	var handle: float = maxf(forward / 3.0, 4.0)
	var p1: Vector3 = start_p + start_t * handle
	var p2: Vector3 = end_p - end_t * handle

	var lat_curve := Curve3D.new()
	for i in range(LATERAL_SAMPLES + 1):
		var t: float = float(i) / float(LATERAL_SAMPLES)
		var p: Vector3 = _bezier3(start_p, p1, p2, end_p, t)
		lat_curve.add_point(p)

	var lat_step := PathStep.make(lat_curve, target_lane.speed_limit, false)

	var new_path: Array[PathStep] = []
	for i in range(step_index):
		new_path.append(path[i])
	new_path.append(lat_step)
	new_path.append_array(subsequent)
	path = new_path
	distance_on_step = 0.0
	cooldown = cooldown_seconds
	if old_lane != null:
		avoid_lane = old_lane
		avoid_timer = AVOID_SECONDS

	# Register in the target lane for the duration of the move.
	lateral_target_lane = target_lane
	lateral_occupancy_dist = t_off

static func _bezier3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3

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
