class_name VehicleManager
extends Node3D

@export var spawn_interval: float = 0.2
@export var spawn_clear_distance: float = 40.0
@export var max_vehicles: int = 200

var debug_lane_changes: bool = false
var debug_vehicle_seed: int = -1
var _debug_tick: int = 0

const RNG_SEED: int = 987654321
const MAX_LEADER_LOOKAHEAD_STEPS: int = 4

const IDM_A: float = 2.0
const IDM_B: float = 2.5
const IDM_S0: float = 2.0
const IDM_T: float = 1.2
const IDM_DELTA: float = 4.0
const IDM_MIN_ACCEL: float = -8.0

const B_SAFE: float = 4.0
const SAFETY_GAP_FACTOR: float = 1.2
const TARGET_LEADER_MIN_SPEED: float = 3.0

const MOBIL_TICK_INTERVAL: int = 1
const MIN_LANE_CHANGE_ROOM: float = 8.0
const LC_COOLDOWN: float = 3.0
const JUNCTION_ARRIVAL_COOLDOWN: float = 0.5

const LC_FORWARD_MIN: float = 12.0
const LC_FORWARD_TIME: float = 1.0

const EMPTY_MARGIN: int = 1

const YIELD_DIST: float = 25.0
const YIELD_OFFSET: float = 0.5
const YIELD_TIMEOUT: float = 4.0
const YIELD_INSIDE_SPEED: float = 0.5
const YIELD_COMMIT_DIST: float = 5.0

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
	_debug_tick += 1
	for v in _vehicles:
		_step_vehicle(v, occ, delta, run_mobil)
	for v in _vehicles:
		if is_instance_valid(v):
			v._update_transform()
	if debug_lane_changes and (_debug_tick % 120) == 0:
		_print_debug_summary()

func _print_debug_summary() -> void:
	var n_active: int = 0
	var n_lane: int = 0
	var n_trans: int = 0
	var n_lat: int = 0
	for v in _vehicles:
		if not is_instance_valid(v):
			continue
		n_active += 1
		if v.current_step_is_lateral():
			n_lat += 1
		elif v.current_lane() != null:
			n_lane += 1
		else:
			n_trans += 1
	print("[sim] active=%d lane_steps=%d transitions=%d lateral=%d" % [n_active, n_lane, n_trans, n_lat])

	var printed: int = 0
	for v in _vehicles:
		if printed >= 5:
			break
		if not is_instance_valid(v):
			continue
		var cur: Lane = v.current_lane()
		if cur == null:
			print("[sim]  v%d non-lane step idx=%d" % [v.color_seed, v.step_index])
			printed += 1
			continue
		var next_lane: Variant = _next_route_lane(v)
		var eligible: Array = _eligible_lanes(cur, next_lane)
		var cnt: int = 0
		for other in _vehicles:
			if other == v or not is_instance_valid(other):
				continue
			if other.current_curve() == cur.curve:
				cnt += 1
		var next_str: String = "null"
		if next_lane != null:
			var nl: Lane = next_lane
			next_str = "%s%d" % [nl.direction, nl.lane_index]
		print("[sim]  v%d lane=%s%d dist=%.1f room=%.1f cnt_lane=%d eligible=%d next=%s" % [
			v.color_seed, cur.direction, cur.lane_index,
			v.distance_on_step, v.current_step_length() - v.distance_on_step,
			cnt, eligible.size(), next_str])
		printed += 1

func _prune_dead() -> void:
	var alive: Array[Vehicle] = []
	for v in _vehicles:
		if is_instance_valid(v):
			alive.append(v)
	_vehicles = alive

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

	if v.current_step_is_lateral() and v.speed < Vehicle.STUCK_SPEED:
		v.stuck_timer += delta
		if v.stuck_timer > Vehicle.STUCK_TIME:
			v.abort_lane_change()
			v.stuck_timer = 0.0
	else:
		v.stuck_timer = 0.0

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

	var yield_gap: float = _junction_yield_gap(v)
	if yield_gap >= 0.0:
		v.yield_timer += delta
		var jitter: float = float(v.color_seed % 5) * 0.5
		if v.yield_timer > YIELD_TIMEOUT + jitter:
			yield_gap = -1.0
	else:
		v.yield_timer = 0.0

	if yield_gap >= 0.0 and yield_gap < gap:
		gap = yield_gap
		lead_speed = 0.0

	var accel: float = _idm(v.speed, v0, gap, lead_speed)
	var new_speed: float = v.speed + accel * delta
	if new_speed < 0.0:
		new_speed = 0.0
	v.speed = new_speed

	_advance(v, v.speed * delta)

func _junction_yield_gap(v: Vehicle) -> float:
	if v.current_lane() == null:
		return -1.0
	if not v.current_step_is_lane():
		return -1.0
	var node := v.current_lane().to_node
	if node == null:
		return -1.0
	var room: float = v.current_step_length() - v.distance_on_step
	if room > YIELD_DIST:
		return -1.0
	var my_lane: Lane = v.current_lane()
	var conflicts: Array = LaneGraph.conflicting_lanes.get(my_lane, [])
	if conflicts.is_empty():
		return -1.0
	var any_inside: bool = false
	for other in conflicts:
		if _lane_has_vehicle_inside(other):
			any_inside = true
			break
	if not any_inside:
		return -1.0
	var gap_to_line: float = room - YIELD_OFFSET
	if gap_to_line < 0.0:
		gap_to_line = 0.0
	return gap_to_line

func _lane_has_vehicle_inside(lane: Lane) -> bool:
	for v in _vehicles:
		if not is_instance_valid(v):
			continue
		if v.speed < YIELD_INSIDE_SPEED:
			continue
		if v.step_index >= v.path.size():
			continue
		var step: PathStep = v.path[v.step_index]
		if step.is_transition and v.step_index >= 1:
			var prev_step: PathStep = v.path[v.step_index - 1]
			if prev_step.lane_ref == lane:
				return true
		if step.is_lane and step.lane_ref == lane:
			if v.step_index + 1 < v.path.size():
				var nxt: PathStep = v.path[v.step_index + 1]
				if nxt.is_transition:
					var remaining: float = step.length - v.distance_on_step
					if remaining <= YIELD_COMMIT_DIST:
						return true
	return false

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
			v.step_index += 1
			if v.step_index >= v.path.size():
				v.queue_free()
				return
			var new_step: PathStep = v.path[v.step_index]
			v.distance_on_step = new_step.start_dist
			if new_step.is_lane:
				v.complete_lane_change()
				v.cooldown = maxf(v.cooldown, JUNCTION_ARRIVAL_COOLDOWN)

# ------------------------------------------------------------------ Direction B: lane choice

func _next_route_lane(v: Vehicle) -> Variant:
	for i in range(v.step_index + 1, v.path.size()):
		var step: PathStep = v.path[i]
		if step.is_transition:
			if i + 1 < v.path.size():
				var ns: PathStep = v.path[i + 1]
				if ns.is_lane:
					return ns.lane_ref
			return null
	return null

func _eligible_lanes(current: Lane, next_lane: Variant) -> Array:
	var result: Array = []
	for lane in LaneGraph.lanes:
		if lane.segment != current.segment:
			continue
		if lane.direction != current.direction:
			continue
		if next_lane != null:
			var nl: Lane = next_lane
			if not lane.next_curves.has(nl):
				continue
		result.append(lane)
	return result

func _count_on_lane(lane: Lane, occ: Dictionary, exclude: Vehicle) -> int:
	var count: int = 0
	var lst: Array = occ.get(lane.curve, [])
	for e in lst:
		var ed: Dictionary = e
		var ov: Vehicle = ed["vehicle"]
		if ov == exclude:
			continue
		if not is_instance_valid(ov):
			continue
		count += 1
	return count

func _maybe_lane_change(v: Vehicle, occ: Dictionary) -> void:
	var current: Lane = v.current_lane()
	if current == null:
		return
	var next_lane: Variant = _next_route_lane(v)
	
	if next_lane == null:
		return
	var room: float = v.current_step_length() - v.distance_on_step
	if room < MIN_LANE_CHANGE_ROOM:
		return

	var eligible: Array = _eligible_lanes(current, next_lane)
	if eligible.size() < 2:
		return

	var my_count: int = _count_on_lane(current, occ, v)

	var best: Lane = current
	var best_count: int = my_count
	for lane_v in eligible:
		var l: Lane = lane_v
		if l == current:
			continue
		var c: int = _count_on_lane(l, occ, v)
		if c < best_count:
			best_count = c
			best = l

	if best == current:
		return
	if best == v.avoid_lane:
		return
	if my_count - best_count < EMPTY_MARGIN:
		return

	if debug_lane_changes and (debug_vehicle_seed < 0 or debug_vehicle_seed == v.color_seed):
		print("[lc] v%d seg=%d cur=%d cnt=%d -> tgt=%d cnt=%d" % [
			v.color_seed, current.segment.get_instance_id(),
			current.lane_index, my_count,
			best.lane_index, best_count])

	if not _change_safe(v, best, occ):
		return

	_execute_lane_change(v, best)

func _change_safe(v: Vehicle, target: Lane, occ: Dictionary) -> bool:
	var p_par: float = _project_onto_lane(v.global_position, target)

	var tgt_lead: Variant = _leader_on_lane_at(target, p_par, occ)
	if tgt_lead != null:
		var li: Dictionary = tgt_lead
		var lv: Vehicle = li["vehicle"]
		if lv.speed < TARGET_LEADER_MIN_SPEED:
			return false
		var lgap: float = li["gap"]
		var min_lead_gap: float = IDM_S0 + v.speed * IDM_T * SAFETY_GAP_FACTOR
		if lgap < min_lead_gap:
			return false
		var a_L_new: float = _idm(lv.speed, lv.desired_speed(), lgap, v.speed)
		if a_L_new < -B_SAFE:
			return false

	var tgt_fol: Variant = _follower_on_lane_at(target, p_par, occ)
	if tgt_fol != null:
		var fi: Dictionary = tgt_fol
		var fv: Vehicle = fi["vehicle"]
		var fgap: float = fi["gap"]
		var min_fol_gap: float = IDM_S0 + fv.speed * IDM_T * SAFETY_GAP_FACTOR
		if fgap < min_fol_gap:
			return false
		var a_F_new: float = _idm(fv.speed, fv.desired_speed(), fgap, v.speed)
		if a_F_new < -B_SAFE:
			return false
	return true

func _remaining_lanes(v: Vehicle) -> Array:
	var result: Array = []
	for i in range(v.step_index, v.path.size()):
		var step: PathStep = v.path[i]
		if step.is_lane and step.lane_ref != null:
			result.append(step.lane_ref)
	return result

func _execute_lane_change(v: Vehicle, target_lane: Lane) -> void:
	var p_par: float = _project_onto_lane(v.global_position, target_lane)
	var lc_len: float = maxf(LC_FORWARD_MIN, v.speed * LC_FORWARD_TIME)
	var max_off: float = target_lane.length - 2.0
	if p_par + lc_len > max_off:
		lc_len = max_off - p_par
	if lc_len < 6.0:
		return
	var target_off: float = p_par + lc_len

	var remaining: Array = _remaining_lanes(v)
	if remaining.is_empty():
		return
	remaining[0] = target_lane
	var new_steps: Array[PathStep] = _build_steps_from_offset(remaining, target_off)
	if new_steps.is_empty():
		return
	v.begin_lane_change(target_lane, p_par, target_off, new_steps, LC_COOLDOWN)

func _build_steps_from_offset(lanes: Array, offset: float) -> Array[PathStep]:
	var steps: Array[PathStep] = []
	for i in range(lanes.size()):
		var lane: Lane = lanes[i]
		if i == 0:
			var sd: float = clampf(offset, 0.0, lane.length - 0.5)
			if sd < 0.0:
				sd = 0.0
			steps.append(PathStep.make(lane.curve, lane.speed_limit, true, lane, sd))
		else:
			steps.append(PathStep.make(lane.curve, lane.speed_limit, true, lane))
		if i + 1 < lanes.size():
			var nxt: Lane = lanes[i + 1]
			if lane.next_curves.has(nxt):
				var tc: Curve3D = lane.next_curves[nxt]
				if tc != null and tc.get_baked_length() > 0.05:
					var sp: float = minf(lane.speed_limit, nxt.speed_limit)
					steps.append(PathStep.make(tc, sp, false, null, 0.0, true))
	return steps

# ------------------------------------------------------------------ leader / IDM

func _find_leader(v: Vehicle, occ: Dictionary) -> Variant:
	var c := v.current_curve()
	if c == null:
		return null
	var list: Array = occ.get(c, [])
	var idx: int = _binary_search_gt(list, v.distance_on_step)
	for k in range(idx, list.size()):
		var e: Dictionary = list[k]
		var other: Vehicle = e["vehicle"]
		if not is_instance_valid(other) or other == v:
			continue
		var d: float = e["dist"]
		var gap: float = (d - v.distance_on_step) - (v.length + other.length) * 0.5
		if gap < 0.0:
			gap = 0.0
		return { "vehicle": other, "gap": gap }
	var accum: float = v.current_step_length() - v.distance_on_step
	var max_walk: int = mini(v.step_index + MAX_LEADER_LOOKAHEAD_STEPS, v.path.size())
	for i in range(v.step_index + 1, max_walk):
		var step: PathStep = v.path[i]
		var lst: Array = occ.get(step.curve, [])
		for e2 in lst:
			var e2d: Dictionary = e2
			var other2: Vehicle = e2d["vehicle"]
			if not is_instance_valid(other2) or other2 == v:
				continue
			var d2: float = e2d["dist"]
			if d2 < step.start_dist:
				continue
			var gap2: float = accum + (d2 - step.start_dist) - (v.length + other2.length) * 0.5
			if gap2 < 0.0:
				gap2 = 0.0
			return { "vehicle": other2, "gap": gap2 }
		accum += step.length - step.start_dist
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

func _leader_on_lane_at(lane: Lane, dist: float, occ: Dictionary) -> Variant:
	var lst: Array = occ.get(lane.curve, [])
	for e in lst:
		var ed: Dictionary = e
		var ov: Vehicle = ed["vehicle"]
		if not is_instance_valid(ov):
			continue
		var d: float = ed["dist"]
		if d >= dist:
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
		var d: float = Vector2(p.x - pos.x, p.z - pos.z).length_squared()
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
		var d1: float = Vector2(p1.x - pos.x, p1.z - pos.z).length_squared()
		var d2: float = Vector2(p2.x - pos.x, p2.z - pos.z).length_squared()
		if d1 < d2:
			hi = m2
		else:
			lo = m1
	return clampf(((lo + hi) * 0.5) * L, 0.0, L)

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

# ------------------------------------------------------------------ spawn

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

	var source_lanes: Array = LaneGraph.lanes_departing_from(source)
	if source_lanes.is_empty():
		return

	var best_lane: Lane = null
	var best_route: Array = []
	var best_count: int = 999999
	for lane_v in source_lanes:
		var lane: Lane = lane_v
		var r: Array = LanePathfinder.find_path(lane, target)
		if r.is_empty():
			continue
		var c: int = _count_at_lane_start(lane)
		if c < best_count:
			best_count = c
			best_lane = lane
			best_route = r

	if best_lane == null:
		return
	if not _start_lane_is_clear(best_lane):
		return

	var steps: Array[PathStep] = _build_steps(best_route)
	if steps.is_empty():
		return

	var v := Vehicle.new()
	add_child(v)
	var v0: float = steps[0].speed
	v.setup(steps, target, _color_seed, v0)
	_vehicles.append(v)
	_color_seed += 1

func _count_at_lane_start(lane: Lane) -> int:
	var count: int = 0
	for v in _vehicles:
		if not is_instance_valid(v):
			continue
		if v.current_curve() != lane.curve:
			continue
		count += 1
	return count

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

func _build_steps(lanes: Array) -> Array[PathStep]:
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
					steps.append(PathStep.make(tc, sp, false, null, 0.0, true))
	return steps

func _dead_end_nodes() -> Array:
	var result: Array = []
	for node in RoadGraph.nodes:
		if node.segment_ends.size() == 1:
			result.append(node)
	return result
