class_name RoadSegment
extends Node3D

var road_type: RoadType
var curve: Curve3D

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D

var start_node: RoadNode
var end_node: RoadNode

func setup(rt: RoadType, c: Curve3D) -> void:
	road_type = rt
	curve = c
	_rebuild()

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
	# Phase 1: no height surcharges. Added in Phase 5.
	return base

func _rebuild() -> void:
	_ensure_mesh_instance()
	if road_type == null or curve == null:
		return
	var L := curve.get_baked_length()
	var inset: float = minf(RoadMesh.VISUAL_INSET, L / 3.0)
	var mesh := RoadMesh.build_slab(curve, road_type, inset, inset)
	_mesh_instance.mesh = mesh

func _ensure_mesh_instance() -> void:
	if _mesh_instance != null:
		return
	_mesh_instance = MeshInstance3D.new()
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.22, 0.22, 0.25)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # temporary: we'll fix winding later
	_material.roughness = 0.95
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)

func set_preview_validity(valid: bool) -> void:
	if _material == null:
		return
	if valid:
		_material.albedo_color = Color(0.22, 0.22, 0.25)
	else:
		_material.albedo_color = Color(0.68, 0.15, 0.15)
