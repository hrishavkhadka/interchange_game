class_name VehicleManager
extends Node3D

const SPAWN_INTERVAL: float = 2.0
const RNG_SEED: int = 987654321

var _timer: float = 0.0
var _color_seed: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = RNG_SEED
	LaneGraph.lanes_changed.connect(_on_lanes_changed)

func _on_lanes_changed() -> void:
	for c in get_children():
		c.queue_free()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= SPAWN_INTERVAL:
		_timer = 0.0
		_try_spawn()

func _try_spawn() -> void:
	if LaneGraph.lanes.is_empty():
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

	var path: Array[Lane] = LanePathfinder.find_path(start_lane, target)
	if path.is_empty():
		return

	var v := Vehicle.new()
	add_child(v)
	v.setup(path, target, _color_seed)
	_color_seed += 1

func _dead_end_nodes() -> Array[RoadNode]:
	var result: Array[RoadNode] = []
	for node in RoadGraph.nodes:
		if node.segment_ends.size() == 1:
			result.append(node)
	return result
