class_name LevelDataPanel
extends CanvasLayer

var _entries_container: VBoxContainer
var _panel: PanelContainer

func _ready() -> void:
	layer = 2
	visible = false
	_build()
	RoadGraph.graph_changed.connect(_on_graph_changed)

func set_expanded(on: bool) -> void:
	visible = on
	if on:
		_rebuild()

func _on_graph_changed() -> void:
	if visible:
		_rebuild()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 16
	_panel.offset_right = 416
	_panel.offset_top = -280
	_panel.offset_bottom = 280
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Level Data"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Per-entry vehicle counts to each exit. Total is the sum."
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(hint)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var distribute := Button.new()
	distribute.text = "Distribute all evenly"
	distribute.pressed.connect(_on_distribute_all)
	btn_row.add_child(distribute)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_entries_container = VBoxContainer.new()
	_entries_container.add_theme_constant_override("separation", 14)
	scroll.add_child(_entries_container)

func _rebuild() -> void:
	for c in _entries_container.get_children():
		c.queue_free()
	var entries: Array = []
	var exits: Array = []
	for n in RoadGraph.nodes:
		if n.segment_ends.size() != 1:
			continue
		if n.is_entry:
			entries.append(n)
		if n.is_exit:
			exits.append(n)
	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "No entries marked. Use the marker tool (⚑) to mark entry dead-ends."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entries_container.add_child(lbl)
		return
	if exits.is_empty():
		var warn := Label.new()
		warn.text = "Warning: no exits marked. Vehicles will fall back to random dead-ends."
		warn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.30))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entries_container.add_child(warn)
	var idx := 1
	for e in entries:
		_add_entry_row(e, idx, exits)
		idx += 1

func _add_entry_row(entry: RoadNode, idx: int, exits: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_entries_container.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var name_label := Label.new()
	name_label.text = "Entry E%d" % idx
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.custom_minimum_size = Vector2(80, 0)
	header.add_child(name_label)

	var total_label := Label.new()
	total_label.name = "TotalLabel"
	header.add_child(total_label)

	var dist_btn := Button.new()
	dist_btn.text = "Distribute"
	dist_btn.pressed.connect(func() -> void: _distribute_entry(entry, exits))
	header.add_child(dist_btn)

	for x in exits:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)

		var label := Label.new()
		label.text = "  → exit"
		label.custom_minimum_size = Vector2(120, 0)
		row.add_child(label)

		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 9999
		spin.step = 1
		spin.value = entry.demand.get(x.id, 0)
		spin.custom_minimum_size = Vector2(90, 0)
		var xid: int = x.id
		spin.value_changed.connect(func(v: float) -> void:
			entry.demand[xid] = int(v)
			_update_total(entry, total_label))
		row.add_child(spin)

	_update_total(entry, total_label)

func _update_total(entry: RoadNode, total_label: Label) -> void:
	var s := 0
	for v in entry.demand.values():
		s += int(v)
	total_label.text = "  Total: %d" % s

func _distribute_entry(entry: RoadNode, exits: Array) -> void:
	if exits.is_empty():
		return
	var total := 0
	for v in entry.demand.values():
		total += int(v)
	if total == 0:
		total = 20
	entry.demand.clear()
	var base := total / exits.size()
	var rem := total % exits.size()
	for i in exits.size():
		var x: RoadNode = exits[i]
		var v := base
		if i < rem:
			v += 1
		entry.demand[x.id] = v
	_rebuild()

func _on_distribute_all() -> void:
	var exits: Array = []
	for n in RoadGraph.nodes:
		if n.segment_ends.size() == 1 and n.is_exit:
			exits.append(n)
	for n in RoadGraph.nodes:
		if n.segment_ends.size() == 1 and n.is_entry:
			_distribute_entry(n, exits)
	_rebuild()
