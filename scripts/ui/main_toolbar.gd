class_name MainToolbar
extends CanvasLayer

signal mode_requested(mode: int)

var _mode: int = 1
var _buttons: Array[Button] = []

func _ready() -> void:
	layer = 3

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_right = 216
	panel.offset_top = -64
	panel.offset_bottom = -16
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	_add_mode_button(row, "Cursor", 0, "Pointer mode - inspect and select")
	_add_mode_button(row, "Roads", 1, "Road building mode")
	_set_mode_visual(_mode)

func get_mode() -> int:
	return _mode

func _add_mode_button(parent: Control, label_text: String, mode_id: int, tip: String) -> void:
	var b := Button.new()
	b.text = label_text
	b.toggle_mode = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(90, 36)
	b.pressed.connect(func() -> void: _request(mode_id))
	parent.add_child(b)
	_buttons.append(b)

func _request(m: int) -> void:
	if m == _mode:
		_set_mode_visual(_mode)
		return
	_mode = m
	_set_mode_visual(_mode)
	mode_requested.emit(_mode)

func _set_mode_visual(m: int) -> void:
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == m)
