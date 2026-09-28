class_name RoadGraphVisualizer
extends Node3D

const SPHERE_RADIUS := 1.2
const SPHERE_LIFT := 0.4
const WAYPOINT_RADIUS := 0.5
const WAYPOINT_LIFT := 0.25

var _sphere: SphereMesh
var _waypoint_sphere: SphereMesh
var _material: StandardMaterial3D
var _waypoint_material: StandardMaterial3D

func _ready() -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = SPHERE_RADIUS
	_sphere.height = SPHERE_RADIUS * 2.0

	_waypoint_sphere = SphereMesh.new()
	_waypoint_sphere.radius = WAYPOINT_RADIUS
	_waypoint_sphere.height = WAYPOINT_RADIUS * 2.0

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.45, 0.10)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_waypoint_material = StandardMaterial3D.new()
	_waypoint_material.albedo_color = Color(0.35, 0.70, 1.0)
	_waypoint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	RoadGraph.graph_changed.connect(_rebuild)

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	for n in RoadGraph.nodes:
		var render_as_waypoint: bool = n.is_waypoint and n.degree() <= 2
		var mi := MeshInstance3D.new()
		if render_as_waypoint:
			mi.mesh = _waypoint_sphere
			mi.material_override = _waypoint_material
			mi.position = n.position + Vector3(0.0, WAYPOINT_LIFT, 0.0)
		else:
			mi.mesh = _sphere
			mi.material_override = _material
			mi.position = n.position + Vector3(0.0, SPHERE_LIFT, 0.0)
		add_child(mi)
