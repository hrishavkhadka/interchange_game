class_name RoadSegment
extends Node3D

var road_type: RoadType
var curve: Curve3D
var start_node: RoadNode
var end_node: RoadNode

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _rebuild_pending: bool = false

func _ready() -> void:
	RoadGraph.graph_changed.connect(_on_graph_changed)
	_do_rebuild()

func setup(rt: RoadType, c: Curve3D) -> void:
	road_type = rt
	curve = c
	# Synchronous build on setup so previews (which don't see graph_changed)
	# still render. For real segments this runs before add_child, so it is a
	# no-op; _ready then performs the actual build.
	if is_inside_tree():
		_do_rebuild()

func length() -> float:
	if curve == null:
		return 0.0
	return curve.get_baked_length()

func avg_abs_height() -> float:
	if curve == null:
		return 0.0
	var n := 16
	var total := 0.0
	var baked := curve.get_baked_length()
	for i in n:
		var t := float(i) / float(n - 1)
		total += absf(curve.sample_baked(t * baked).y)
	return total / float(n)

func cost() -> float:
	if road_type == null or curve == null:
		return 0.0
	var L := length()
	var lanes := road_type.lane_count()
	var cfg := CostConfig.new()
	var base := L * float(lanes) * cfg.lane_rate
	return base

func set_preview_validity(valid: bool) -> void:
	if _material == null:
		return
	if valid:
		_material.albedo_color = Color(0.22, 0.22, 0.25)
	else:
		_material.albedo_color = Color(0.68, 0.15, 0.15)

func _on_graph_changed() -> void:
	if _rebuild_pending:
		return
	_rebuild_pending = true
	call_deferred("_do_rebuild")

func _do_rebuild() -> void:
	_rebuild_pending = false
	if not is_inside_tree():
		return
	if is_queued_for_deletion():
		return
	_ensure_mesh_instance()
	if road_type == null or curve == null:
		return
	var L := curve.get_baked_length()
	var inset_start: float = 0.0
	var inset_end: float = 0.0
	if not _is_pure_waypoint(start_node):
		inset_start = minf(RoadMesh.VISUAL_INSET, L / 3.0)
	if not _is_pure_waypoint(end_node):
		inset_end = minf(RoadMesh.VISUAL_INSET, L / 3.0)
	var mesh := RoadMesh.build_slab(curve, road_type, inset_start, inset_end)
	_mesh_instance.mesh = mesh

static func _is_pure_waypoint(node: RoadNode) -> bool:
	if node == null:
		return false
	return node.is_waypoint and node.segment_ends.size() == 2

func _ensure_mesh_instance() -> void:
	if _mesh_instance != null:
		return
	_mesh_instance = MeshInstance3D.new()
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.22, 0.22, 0.25)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 0.95
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
