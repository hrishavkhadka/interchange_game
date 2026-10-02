class_name JunctionRenderer
extends Node3D

var _material: StandardMaterial3D

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.22, 0.22, 0.25)
	_material.roughness = 0.95
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	RoadGraph.graph_changed.connect(_rebuild)

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	for node in RoadGraph.nodes:
		if node.segment_ends.size() < 2:
			continue
		# Pure waypoints (2 segments, flagged) do not form a junction.
		if node.is_waypoint and node.segment_ends.size() == 2:
			continue
		var mesh := JunctionMesh.build(node)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material
		add_child(mi)
