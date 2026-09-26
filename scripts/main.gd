extends Node3D

func _ready() -> void:
	_setup_environment()
	_setup_light()
	_setup_ground()
	var camera := _setup_camera()
	var builder := _setup_builder(camera)
	
	var toolbar := SnapToolbar.new()
	toolbar.name = "SnapToolbar"
	toolbar.setup(builder.settings)
	add_child(toolbar)
	
	var hud := _setup_hud()
	builder.cost_changed.connect(hud.set_cost)

	# New:
	var visualizer := RoadGraphVisualizer.new()
	visualizer.name = "RoadGraphVisualizer"
	add_child(visualizer)

	# New:
	var junctions := JunctionRenderer.new()
	junctions.name = "JunctionRenderer"
	add_child(junctions)

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
	mi.position = Vector3(0, -0.15, 0)      # ← ground sits 15 cm below roads
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

	# Build a default road type in code for Phase 1.
	var rt := RoadType.new()
	rt.id = "two_lane"
	rt.display_name = "2-lane two-way"
	rt.lane_layout_string = "FB"
	rt.lane_width = 3.2
	rt.speed_limit_kmh = 50.0
	builder.road_type = rt

	add_child(builder)
	return builder

func _setup_hud() -> HUD:
	var hud := HUD.new()
	add_child(hud)
	return hud
