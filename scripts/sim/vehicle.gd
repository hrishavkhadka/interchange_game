class_name Vehicle
extends Node3D

var path: Array[Lane] = []
var path_index: int = 0
var current_lane: Lane
var distance: float = 0.0
var target_node: RoadNode

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
	path_index = 0
	current_lane = path[0]
	distance = 0.0

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 1.4, 4.2)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = make_color(color_seed)
	mat.roughness = 0.7
	_mesh.material_override = mat
	add_child(_mesh)

	_place_at_lane(distance)

func _physics_process(delta: float) -> void:
	if current_lane == null:
		queue_free()
		return

	var remaining_move: float = current_lane.speed_limit * delta
	while remaining_move > 0.0:
		var to_end: float = current_lane.length - distance
		if remaining_move < to_end:
			distance += remaining_move
			remaining_move = 0.0
		else:
			remaining_move -= to_end
			distance = 0.0
			if not _advance_to_next_lane():
				return

	_place_at_lane(distance)

func _advance_to_next_lane() -> bool:
	if current_lane.to_node == target_node:
		queue_free()
		return false
	path_index += 1
	if path_index >= path.size():
		queue_free()
		return false
	current_lane = path[path_index]
	return true

func _place_at_lane(dist: float) -> void:
	var p: Vector3 = current_lane.curve.sample_baked(dist)
	var ahead: Vector3 = current_lane.curve.sample_baked(minf(dist + 0.5, current_lane.length))
	global_position = p + Vector3(0.0, 0.75, 0.0)
	var d: Vector3 = ahead - p
	d.y = 0.0
	if d.length_squared() > 0.0001:
		look_at(global_position + d.normalized(), Vector3.UP)
