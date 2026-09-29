class_name VehicleManager
extends Node3D

@export var spawn_interval: float = 0.2
@export var spawn_clear_distance: float = 20.0
@export var max_vehicles: int = 200

const RNG_SEED: int = 987654321
const MAX_LEADER_LOOKAHEAD_STEPS: int = 4

const IDM_A: float = 2.5
const IDM_B: float = 1.0
const IDM_S0: float = 2.0
const IDM_T: float = 1.0
const IDM_DELTA: float = 4.0
const IDM_MIN_ACCEL: float = -12.0

const MOBIL_POLITENESS: float = 0.5
const MOBIL_THRESHOLD: float = 1.7
const B_SAFE: float = 2.0
const MOBIL_TICK_INTERVAL: int = 3
const MIN_LANE_CHANGE_ROOM: float = 12.0
const LC_COOLDOWN: float = 5.0
const JUNCTION_ARRIVAL_COOLDOWN: float = 1.2
const SAFETY_GAP_FACTOR: float = 1.0

const LC_FORWARD_MIN: float = 20.0
const LC_FORWARD_TIME: float = 2.0

var _timer: float = 0.0
var _tick_counter: int = 0
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
	_prune_dead()
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_try_spawn()

func _physics_process(delta: float) -> void:
	_prune_dead()
	var occ := _build_occupancy()
	var run_mobil: bool = (_tick_counter % MOBIL_TICK_INTERVAL) == 0
	_tick_counter += 1
	for v in _vehicles:
		_step_vehicle(v, occ, delta, run_mobil)
	for v in _vehicles:
		if is_instance_valid(v):
			v._update_transform()

func _prune_dead() -> void:
	var alive: Array[Vehicle] = []
	for v in _vehicles:
		if is_instance_valid(v):
			alive.append(v)
	_vehicles = alive

# Occupancy format: Dictionary<Curve3D, Array<{vehicle, dist}>>, sorted by dist.
# Each vehicle can appear in more than one list (its own curve, and the target
# lane during a lateral move). This is what makes a changing vehicle visible
# to the traffic already on the target lane.
func _build_occupancy() -> Dictionary:
	var occ: Dictionary = {}
	for v in _vehicles:
		if not is_instance_valid(v):
			continue
		var entries: Array = v.occupancy_entries()
		for e in entries:
			var ed: Dictionary = e
			var curve: Curve3D = ed["curve"]
			var dist: float = ed["dist"]
			if not occ.has(curve):
				occ[curve] = []
			occ[curve].append({ "vehicle": v, "dist": dist })
	for k in occ:
		var arr: Array = occ[k]
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["dist"] < b["dist"])
	return occ

func _step_vehicle(v: Vehicle, occ: Dictionary, delta: float, run_mobil: bool) -> void:
	if not is_instance_valid(v):
		return

	v.cooldown = maxf(0.0, v.cooldown - delta)
	if v.avoid_timer > 0.0:
		v.avoid_timer = maxf(0.0, v.avoid_timer - delta)
		if v.avoid_timer <= 0.0:
			v.avoid_lane = null

	if run_mobil and v.cooldown <= 0.0 and v.current_lane() != null:
		_maybe_lane_change(v, occ)

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
			var new_step: PathStep = v.path[v.step_index]
			if new_step.is_lane:
				v.lateral_target_lane = null
				v.cooldown = maxf(v.cooldown, JUNCTION_ARRIVAL_COOLDOWN)

# ------------------------------------------------------------------ MOBIL

func _maybe_lane_change(v: Vehicle, occ: Dictionary) -> void:
	var current: Lane = v.current_lane()
	if current == null:
		return
	if current.adjacent_lanes.is_empty():
		return

	var room: float = v.current_step_length() - v.distance_on_step
	if room < MIN_LANE_CHANGE_ROOM:
		return

	var a_cur: float = _current_accel(v, occ)

	for adj in current.adjacent_lanes:
		if adj == v.avoid_lane:
			continue
		if _mobil_ok(v, adj, occ, a_cur):
			_execute_lane_change(v, adj)
			return

func _mobil_ok(v: Vehicle, target: Lane, occ: Dictionary, a_cur: float) -> bool:
	var p_par: float = _parallel_distance(v, target)

	var tgt_lead: Variant = _leader_on_lane_at(target, p_par, occ)
	var tgt_fol: Variant = _follower_on_lane_at(target, p_par, occ)

	if tgt_fol != null:
		var fi: Dictionary = tgt_fol
		var fv: Vehicle = fi["vehicle"]
		var fgap: float = fi["gap"]
		var min_gap: float = IDM_S0 + fv.speed * IDM_T * SAFETY_GAP_FACTOR
		if fgap < min_gap:
			return false

	if tgt_lead != null:
		var li: Dictionary = tgt_lead
		var lv: Vehicle = li["vehicle"]
		var lgap: float = li["gap"]
		var min_lead_gap: float = IDM_S0 + v.speed * IDM_T * SAFETY_GAP_FACTOR
		if lgap < min_lead_gap:
			return false

	if tgt_lead != null:
		var li2: Dictionary = tgt_lead
		var lv2: Vehicle = li2["vehicle"]
		var lgap2: float = li2["gap"]
		var a_L_new: float = _idm(lv2.speed, lv2.desired_speed(), lgap2, v.speed)
		if a_L_new < -B_SAFE:
			return false

	var a_F_new: float = 0.0
	if tgt_fol != null:
		var fi2: Dictionary = tgt_fol
		var fv2: Vehicle = fi2["vehicle"]
		var fgap2: float = fi2["gap"]
		a_F_new = _idm(fv2.speed, fv2.desired_speed(), fgap2, v.speed)
		if a_F_new < -B_SAFE:
			return false

	var a_F_old: float = 0.0
	if tgt_fol != null:
		var fi3: Dictionary = tgt_fol
		var fv3: Vehicle = fi3["vehicle"]
		if tgt_lead != null:
			var li3: Dictionary = tgt_lead
			var lv3: Vehicle = li3["vehicle"]
			var gap_to_lead: float = li3["gap"] + fi3["gap"]
			a_F_old = _idm(fv3.speed, fv3.desired_speed(), gap_to_lead, lv3.speed)
		else:
			a_F_old = _idm(fv3.speed, fv3.desired_speed(), INF, 0.0)

	var a_new: float = _accel_in_lane(v, target, p_par, occ)
	var gain: float = (a_new - a_cur) + MOBIL_POLITENESS * (a_F_new - a_F_old)
	return gain > MOBIL_THRESHOLD

func _current_accel(v: Vehicle, occ: Dictionary) -> float:
	var leader: Variant = _find_leader(v, occ)
	if leader == null:
		return _idm(v.speed, v.desired_speed(), INF, 0.0)
	var info: Dictionary = leader
	return _idm(v.speed, v.desired_speed(), info["gap"], info["vehicle"].speed)

func _accel_in_lane(v: Vehicle, target: Lane, p_par: float, occ: Dictionary) -> float:
	var lead: Variant = _leader_on_lane_at(target, p_par, occ)
	if lead == null:
		return _idm(v.speed, target.speed_limit, INF, 0.0)
	var info: Dictionary = lead
	return _idm(v.speed, target.speed_limit, info["gap"], info["vehicle"].speed)

func _leader_on_lane_at(lane: Lane, dist: float, occ: Dictionary) -> Variant:
	var lst: Array = occ.get(lane.curve, [])
	for e in lst:
		var ed: Dictionary = e
		var ov: Vehicle = ed["vehicle"]
		if not is_instance_valid(ov):
			continue
		var d: float = ed["dist"]
		if d > dist:
			var gap: float = d - dist - (ov.length + 4.5) * 0.5
			if gap < 0.0:
				gap = 0.0
			return { "vehicle": ov, "gap": gap }
	return null

func _follower_on_lane_at(lane: Lane, dist: float, occ: Dictionary) -> Variant:
	var lst: Array = occ.get(lane.curve, [])
	var best: Vehicle = null
	var best_d: float = -INF
	for e in lst:
		var ed: Dictionary = e
		var ov: Vehicle = ed["vehicle"]
		if not is_instance_valid(ov):
			continue
		var d: float = ed["dist"]
		if d < dist and d > best_d:
			best_d = d
			best = ov
	if best == null:
		return null
	var gap: float = dist - best_d - (best.length + 4.5) * 0.5
	if gap < 0.0:
		gap = 0.0
	return { "vehicle": best, "gap": gap }

func _parallel_distance(v: Vehicle, target: Lane) -> float:
	return _project_onto_lane(v.global_position, target)

static func _project_onto_lane(pos: Vector3, lane: Lane) -> float:
	var L: float = lane.length
	if L < 0.1:
		return 0.0
	var samples: int = 16
	var best_d: float = INF
	var best_t: float = 0.0
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var p: Vector3 = lane.curve.sample_baked(t * L)
		var d: float = p.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best_t = t
	var step: float = 1.0 / float(samples)
	var lo: float = maxf(best_t - step, 0.0)
	var hi: float = minf(best_t + step, 1.0)
	for _i in range(8):
		var m1: float = lerpf(lo, hi, 1.0 / 3.0)
		var m2: float = lerpf(lo, hi, 2.0 / 3.0)
		var p1: Vector3 = lane.curve.sample_baked(m1 * L)
		var p2: Vector3 = lane.curve.sample_baked(m2 * L)
		if p1.distance_squared_to(pos) < p2.distance_squared_to(pos):
			hi = m2
		else:
			lo = m1
	return clampf(((lo + hi) * 0.5) * L, 0.0, L)

func _execute_lane_change(v: Vehicle, target_lane: Lane) -> void:
	var p_par: float = _parallel_distance(v, target_lane)

	# The S-curve must end ahead of the vehicle, not beside it. Aim for
	# max(20 m, 2 s of travel). If the target lane is too short to fit that,
	# shrink the forward distance, but never below 8 m.
	var lc_len: float = maxf(LC_FORWARD_MIN, v.speed * LC_FORWARD_TIME)
	var max_off: float = target_lane.length - 2.0
	if p_par + lc_len > max_off:
		lc_len = max_off - p_par
		if lc_len < 8.0:
			return
	var target_off: float = p_par + lc_len

	var new_route: Array[Lane] = LanePathfinder.find_path(target_lane, v.target_node)
	if new_route.is_empty():
		return
	var new_steps: Array[PathStep] = _build_steps_from_offset(new_route, target_off)
	if new_steps.is_empty():
		return
	v.begin_lane_change(target_lane, target_off, new_steps, LC_COOLDOWN)

func _build_steps_from_offset(lanes: Array[Lane], offset: float) -> Array[PathStep]:
	var steps: Array[PathStep] = []
	for i in range(lanes.size()):
		var lane: Lane = lanes[i]
		if i == 0 and offset > 0.1:
			var trimmed := _trim_curve_start(lane.curve, offset)
			if trimmed == null:
				return steps
			steps.append(PathStep.make(trimmed, lane.speed_limit, true, lane))
		else:
			steps.append(PathStep.make(lane.curve, lane.speed_limit, true, lane))
		if i + 1 < lanes.size():
			var nxt: Lane = lanes[i + 1]
			if lane.next_curves.has(nxt):
				var tc: Curve3D = lane.next_curves[nxt]
				if tc != null and tc.get_baked_length() > 0.05:
					var sp: float = minf(lane.speed_limit, nxt.speed_limit)
					steps.append(PathStep.make(tc, sp, false))
	return steps

static func _trim_curve_start(c: Curve3D, from_dist: float) -> Curve3D:
	var L: float = c.get_baked_length()
	if from_dist >= L - 0.5:
		return null
	var remaining: float = L - from_dist
	var samples: int = maxi(4, int(remaining * 0.5))
	var out := Curve3D.new()
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var d: float = from_dist + t * remaining
		out.add_point(c.sample_baked(d))
	return out

# ------------------------------------------------------------------ core

func _find_leader(v: Vehicle, occ: Dictionary) -> Variant:
	var c := v.current_curve()
	if c == null:
		return null

	var list: Array = occ.get(c, [])
	var idx: int = _binary_search_gt(list, v.distance_on_step)
	if idx < list.size():
		var ed: Dictionary = list[idx]
		var leader: Vehicle = ed["vehicle"]
		if not is_instance_valid(leader) or leader == v:
			# Skip self; lateral moves register the changer in the target lane.
			for k in range(idx + 1, list.size()):
				var e2: Dictionary = list[k]
				var l2: Vehicle = e2["vehicle"]
				if is_instance_valid(l2) and l2 != v:
					var leader2: Vehicle = l2
					var d2: float = e2["dist"]
					var center_gap2: float = d2 - v.distance_on_step
					var gap2: float = center_gap2 - (v.length + leader2.length) * 0.5
					if gap2 < 0.0:
						gap2 = 0.0
					return { "vehicle": leader2, "gap": gap2 }
			return null
		var leader_dist: float = ed["dist"]
		var center_gap: float = leader_dist - v.distance_on_step
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
			var e3: Dictionary = lst[0]
			var leader3: Vehicle = e3["vehicle"]
			if not is_instance_valid(leader3):
				continue
			var gap3: float = accum + e3["dist"] - (v.length + leader3.length) * 0.5
			if gap3 < 0.0:
				gap3 = 0.0
			return { "vehicle": leader3, "gap": gap3 }
		accum += step.length
	return null

func _binary_search_gt(list: Array, dist: float) -> int:
	var lo: int = 0
	var hi: int = list.size()
	while lo < hi:
		var mid: int = (lo + hi) / 2
		var e: Dictionary = list[mid]
		if e["dist"] <= dist:
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
	if _vehicles.size() >= max_vehicles:
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
		if not is_instance_valid(v):
			continue
		var c := v.current_curve()
		if c != lane.curve:
			continue
		if v.distance_on_step < spawn_clear_distance:
			return false
	return true

func _build_steps(lanes: Array[Lane]) -> Array[PathStep]:
	var steps: Array[PathStep] = []
	for i in range(lanes.size()):
		var lane: Lane = lanes[i]
		steps.append(PathStep.make(lane.curve, lane.speed_limit, true, lane))
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
