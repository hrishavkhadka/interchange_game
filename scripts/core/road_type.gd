class_name RoadType
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var lane_layout_string: String = "FB"
@export var lane_width: float = 3.2
@export var speed_limit_kmh: float = 50.0
@export var slab_thickness: float = 0.2

var _layout: LaneLayout

func layout() -> LaneLayout:
	if _layout == null or _layout.as_string() != lane_layout_string:
		_layout = LaneLayout.parse(lane_layout_string)
	return _layout

func lane_count() -> int:
	return layout().size()

func total_width() -> float:
	return lane_count() * lane_width

func lane_left_offset(i: int) -> float:
	return -total_width() * 0.5 + i * lane_width

func lane_center_offset(i: int) -> float:
	return lane_left_offset(i) + lane_width * 0.5
