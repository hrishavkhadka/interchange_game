extends Node3D

var _builder: RoadBuilder
var _vehicles: VehicleManager

func _ready() -> void:
	_setup_environment()
	_setup_light()
	_setup_ground()
	var camera := _setup_camera()
	_builder = _setup_builder(camera)
	var hud := _setup_hud()
	_builder.cost_changed.connect(hud.set_cost)
	_builder.road_type_changed.connect(func(_idx: int, name: String) -> void:
		hud.set_road_type(name))
	_builder.set_road_type_index(0)
	hud.set_road_type("2-lane two-way")

	var visualizer := RoadGraphVisualizer.new()
	visualizer.name = "RoadGraphVisualizer"
	add_child(visualizer)

	var junctions := JunctionRenderer.new()
	junctions.name = "JunctionRenderer"
	add_child(junctions)

	var transitions := TransitionMesh.new()
	transitions.name = "TransitionMesh"
	add_child(transitions)

	var lane_vis := LaneVisualizer.new()
	lane_vis.name = "LaneVisualizer"
	add_child(lane_vis)

	_vehicles = VehicleManager.new()
	_vehicles.name = "VehicleManager"
	add_child(_vehicles)

	var snap_toolbar := SnapToolbar.new()
	snap_toolbar.name = "SnapToolbar"
	snap_toolbar.setup(_builder.settings)
	add_child(snap_toolbar)

	var main_toolbar := MainToolbar.new()
	main_toolbar.name = "MainToolbar"
	add_child(main_toolbar)

	var snap_expanded: bool = false
	main_toolbar.mode_requested.connect(func(m: int) -> void:
		_builder.set_mode(m)
		snap_toolbar.set_expanded(snap_expanded and m == 1))
	main_toolbar.snapping_toggled.connect(func(on: bool) -> void:
		snap_expanded = on
		snap_toolbar.set_expanded(on and main_toolbar.get_mode() == 1))

	_builder.set_mode(main_toolbar.get_mode())

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_1: _builder.set_road_type_index(0)
			KEY_2: _builder.set_road_type_index(1)
			KEY_3: _builder.set_road_type_index(2)
			KEY_4: _builder.set_road_type_index(3)
			KEY_K:
				_vehicles.debug_lane_changes = not _vehicles.debug_lane_changes
				print("[debug] lane-change logging = ", _vehicles.debug_lane_changes)

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _setup_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)

func _setup_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(300, 300)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, -0.15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.34, 0.28)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)

func _setup_camera() -> OrbitCamera:
	var root := Node3D.new()
	root.set_script(preload("res://scripts/camera/orbit_camera.gd"))
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.far = 4000.0
	root.add_child(cam)
	add_child(root)
	return root

func _setup_builder(_camera: OrbitCamera) -> RoadBuilder:
	var builder := Node3D.new()
	builder.set_script(preload("res://scripts/build/road_builder.gd"))
	builder.name = "RoadBuilder"

	var preview_root := Node3D.new()
	preview_root.name = "PreviewRoot"
	builder.add_child(preview_root)

	var segments_root := Node3D.new()
	segments_root.name = "SegmentsRoot"
	builder.add_child(segments_root)

	add_child(builder)
	return builder

func _setup_hud() -> HUD:
	var hud := HUD.new()
	add_child(hud)
	return hud
