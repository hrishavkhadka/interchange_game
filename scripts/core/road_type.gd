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

# Offset of the CENTER of lane `i` from the segment centerline, along the
# RIGHT direction of the segment curve (forward tangent). For layout "FB"
# with i=0, the offset is negative (the lane sits on the left side of the
# centerline when facing forward).
func lane_right_offset(i: int) -> float:
	return -total_width() * 0.5 + lane_width * (float(i) + 0.5)
