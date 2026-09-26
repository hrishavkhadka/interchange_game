class_name OrbitCamera
extends Node3D

@export var pan_speed: float = 1.0
@export var orbit_speed: float = 0.005
@export var zoom_factor: float = 1.15
@export var min_distance: float = 8.0
@export var max_distance: float = 800.0

var _pivot := Vector3.ZERO
var _yaw := 0.6
var _pitch := -0.9
var _distance := 120.0

var _orbiting := false
var _panning := false

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = mb.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_distance = clampf(_distance / zoom_factor, min_distance, max_distance)
					_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_distance = clampf(_distance * zoom_factor, min_distance, max_distance)
					_apply()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			_yaw -= mm.relative.x * orbit_speed
			_pitch = clampf(_pitch - mm.relative.y * orbit_speed, -1.5, -0.1)
			_apply()
		elif _panning:
			var right: Vector3 = _camera.global_transform.basis.x
			var forward: Vector3 = -_camera.global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var move: Vector3 = (-right * mm.relative.x + forward * mm.relative.y) * _distance * 0.001 * pan_speed
			_pivot += move
			_apply()

func _apply() -> void:
	if _camera == null:
		return
	var offset := Vector3(
		cos(_pitch) * sin(_yaw),
		-sin(_pitch),
		cos(_pitch) * cos(_yaw)
	) * _distance
	_camera.global_position = _pivot + offset
	_camera.look_at(_pivot, Vector3.UP)
