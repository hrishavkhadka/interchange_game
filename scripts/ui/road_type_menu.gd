class_name RoadTypeMenu
extends CanvasLayer

signal type_selected(index: int, name: String)

const NAMES := [
	"1: 2-lane two-way",
	"2: 2-lane one-way",
	"3: 4-lane two-way",
	"4: 4-lane one-way",
	"5: 3-lane one-way",
	"6: 5-lane one-way",
	"7: 3-lane (2+1)",
	"8: 5-lane (3+2)",
	"9: 6-lane (3+3)",
	"0: 6-lane (4+2)",
]

var _buttons: Array[Button] = []

func _ready() -> void:
	layer = 2
	visible = false

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_right = 216
	panel.offset_top = -420
	panel.offset_bottom = -76
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Road Type"
	vbox.add_child(title)

	for i in NAMES.size():
		var b := Button.new()
		b.text = NAMES[i]
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: _select(i))
		vbox.add_child(b)
		_buttons.append(b)

func set_expanded(on: bool) -> void:
	visible = on

func set_selected(i: int) -> void:
	for k in _buttons.size():
		_buttons[k].set_pressed_no_signal(k == i)

func _select(i: int) -> void:
	set_selected(i)
	type_selected.emit(i, NAMES[i].split(": ")[1])
