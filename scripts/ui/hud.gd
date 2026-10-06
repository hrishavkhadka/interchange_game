class_name HUD
extends CanvasLayer

var _cost_label: Label
var _road_type_label: Label
var _hint_label: Label

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(280, 160)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_cost_label = Label.new()
	_cost_label.text = "Spent: 0"
	vbox.add_child(_cost_label)

	_road_type_label = Label.new()
	_road_type_label.text = "Road: 2-lane two-way"
	vbox.add_child(_road_type_label)

	_hint_label = Label.new()
	_hint_label.text = "_hint_label.text = \"LMB: place road (click, click)\\nRMB: cancel\\nEsc: cancel\\n1-9/0: road type\\nL: lane overlay\\nWASD: pan  QE: yaw  RF: tilt  TG: zoom\""
	_hint_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(_hint_label)

	add_child(panel)

func set_cost(v: float) -> void:
	if _cost_label != null:
		_cost_label.text = "Spent: %.0f" % v

func set_road_type(name: String) -> void:
	if _road_type_label != null:
		_road_type_label.text = "Road: " + name
