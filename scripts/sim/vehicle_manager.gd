class_name VehicleManager
extends Node3D

const SPAWN_INTERVAL: float = 2.0
const SPAWN_CLEAR_DISTANCE: float = 20.0
const RNG_SEED: int = 987654321
const MAX_VEHICLES: int = 200
const MAX_LEADER_LOOKAHEAD_STEPS: int = 4

const IDM_A: float = 1.5
const IDM_B: float = 2.0
const IDM_S0: float = 2.0
const IDM_T: float = 1.2
const IDM_DELTA: float = 4.0
const IDM_MIN_ACCEL: float = -8.0

var _timer: float = 0.0
var _color_seed: int = 0
var _rng := RandomNumberGenerator.new()
var _vehicles: Array[Vehicle] = []

func _ready() -> void:
	_rng.seed = RNG_SEED
	LaneGraph.lanes_changed.connect(_on_lanes_changed)

func _on_lanes_changed() -> void:
	for c in get_children():
		c.queue_free()
	_vehicles.clear()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= SPAWN_INTERVAL:
		_timer = 0.0
		_try_spawn()

func _physics_process(delta: float) -> void:
	_prune_dead()
	var occ := _build_occupancy()
	for v in _vehicles:
		_step_vehicle(v, occ, delta)
	for v in _vehicles:
		if is_instance_valid(v):
			v._update_transform()

func _prune_dead() -> void:
	var alive: Array[Vehicle] = []
	for v in _vehicles:
		if is_instance_valid(v):
			alive.append(v)
	_vehicles = alive

func _build_occupancy() -> Dictionary:
	var occ: Dictionary = {}
	for v in _vehicles:
		var c := v.current_curve()
		if c == null:
			continue
		if not occ.has(c):
			occ[c] = []
		occ[c].append(v)
	for k in occ:
		var arr: Array = occ[k]
		arr.sort_custom(func(a: Vehicle, b: Vehicle) -> bool:
			return a.distance_on_step < b.distance_on_step)
	return occ

func _step_vehicle(v: Vehicle, occ: Dictionary, delta: float) -> void:
	var v0: float = v.desired_speed()
	var leader: Variant = _find_leader(v, occ)

	var gap: float = INF
	var lead_speed: float = 0.0
	if leader != null:
		var info: Dictionary = leader
		gap = info["gap"]
		var lv: Vehicle = info["vehicle"]
		lead_speed = lv.speed

	var accel: float = _idm(v.speed, v0, gap, lead_speed)
	var new_speed: float = v.speed + accel * delta
	if new_speed < 0.0:
		new_speed = 0.0
	v.speed = new_speed

	_advance(v, v.speed * delta)

func _advance(v: Vehicle, move: float) -> void:
	var safety: int = 0
	while move > 0.0 and safety < 8:
		safety += 1
		if v.step_index >= v.path.size():
			v.queue_free()
			return
		var step: PathStep = v.path[v.step_index]
		var remaining: float = step.length - v.distance_on_step
		if move < remaining:
			v.distance_on_step += move
			move = 0.0
		else:
			move -= remaining
			v.distance_on_step = 0.0
			v.step_index += 1
			if v.step_index >= v.path.size():
				v.queue_free()
				return

func _find_leader(v: Vehicle, occ: Dictionary) -> Variant:
	var c := v.current_curve()
	if c == null:
		return null

	var list: Array = occ.get(c, [])
	var idx: int = _binary_search_gt(list, v.distance_on_step)
	if idx < list.size():
		var leader: Vehicle = list[idx]
		var center_gap: float = leader.distance_on_step - v.distance_on_step
		var gap: float = center_gap - (v.length + leader.length) * 0.5
		if gap < 0.0:
			gap = 0.0
		return { "vehicle": leader, "gap": gap }

	var accum: float = v.current_step_length() - v.distance_on_step
	var max_walk: int = mini(v.step_index + MAX_LEADER_LOOKAHEAD_STEPS, v.path.size())
	for i in range(v.step_index + 1, max_walk):
		var step: PathStep = v.path[i]
		var lst: Array = occ.get(step.curve, [])
		if not lst.is_empty():
			var leader2: Vehicle = lst[0]
			var gap2: float = accum + leader2.distance_on_step - (v.length + leader2.length) * 0.5
			if gap2 < 0.0:
				gap2 = 0.0
			return { "vehicle": leader2, "gap": gap2 }
		accum += step.length
	return null

func _binary_search_gt(list: Array, dist: float) -> int:
	var lo: int = 0
	var hi: int = list.size()
	while lo < hi:
		var mid: int = (lo + hi) / 2
		var mv: Vehicle = list[mid]
		if mv.distance_on_step <= dist:
			lo = mid + 1
		else:
			hi = mid
	return lo

func _idm(v: float, v0: float, gap: float, lead_speed: float) -> float:
	if v0 < 0.1:
		v0 = 0.1
	var free_term: float = 1.0 - pow(v / v0, IDM_DELTA)
	var interaction: float = 0.0
	if is_finite(gap):
		if gap <= 0.01:
			return IDM_MIN_ACCEL
		var dv: float = v - lead_speed
		var s_star: float = IDM_S0 + maxf(0.0, v * IDM_T + v * dv / (2.0 * sqrt(IDM_A * IDM_B)))
		interaction = pow(s_star / gap, 2.0)
	var accel: float = IDM_A * (free_term - interaction)
	return clampf(accel, IDM_MIN_ACCEL, IDM_A)

func _try_spawn() -> void:
	if LaneGraph.lanes.is_empty():
		return
	if _vehicles.size() >= MAX_VEHICLES:
		return
	var dead_ends := _dead_end_nodes()
	if dead_ends.size() < 2:
		return

	var src_idx: int = _rng.randi_range(0, dead_ends.size() - 1)
	var source: RoadNode = dead_ends[src_idx]

	var tgt_idx: int = _rng.randi_range(0, dead_ends.size() - 2)
	if tgt_idx >= src_idx:
		tgt_idx += 1
	var target: RoadNode = dead_ends[tgt_idx]

	var source_lanes: Array[Lane] = LaneGraph.lanes_departing_from(source)
	if source_lanes.is_empty():
		return
	var start_lane: Lane = source_lanes[0]

	if not _start_lane_is_clear(start_lane):
		return

	var path: Array[Lane] = LanePathfinder.find_path(start_lane, target)
	if path.is_empty():
		return

	var steps: Array[PathStep] = _build_steps(path)
	if steps.is_empty():
		return

	var v := Vehicle.new()
	add_child(v)
	var v0: float = steps[0].speed
	v.setup(steps, target, _color_seed, v0)
	_vehicles.append(v)
	_color_seed += 1

func _start_lane_is_clear(lane: Lane) -> bool:
	for v in _vehicles:
		if v.current_curve() != lane.curve:
			continue
		if v.distance_on_step < SPAWN_CLEAR_DISTANCE:
			return false
	return true

func _build_steps(lanes: Array[Lane]) -> Array[PathStep]:
	var steps: Array[PathStep] = []
	for i in range(lanes.size()):
		var lane: Lane = lanes[i]
		steps.append(PathStep.make(lane.curve, lane.speed_limit, true))
		if i + 1 < lanes.size():
			var nxt: Lane = lanes[i + 1]
			if lane.next_curves.has(nxt):
				var tc: Curve3D = lane.next_curves[nxt]
				if tc != null and tc.get_baked_length() > 0.05:
					var sp: float = minf(lane.speed_limit, nxt.speed_limit)
					steps.append(PathStep.make(tc, sp, false))
	return steps

func _dead_end_nodes() -> Array[RoadNode]:
	var result: Array[RoadNode] = []
	for node in RoadGraph.nodes:
		if node.segment_ends.size() == 1:
			result.append(node)
	return result
