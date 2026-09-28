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

# Offset of lane `i` from the segment centerline, along the segment's right
# vector (forward.cross(UP)). Positive = right of forward direction.
#
# Layout string is interpreted left-to-right when facing forward. For
# right-hand driving we mirror the index so lane 0 (leftmost in the string)
# ends up on the right of the road. This makes "FB" a US-style two-lane
# road: F on the driver's right, B on the driver's right of their own
# direction (i.e. on the left of forward).
func lane_right_offset(i: int) -> float:
	var n: int = lane_count()
	if n <= 0:
		return 0.0
	var mirrored: int = n - 1 - i
	return -total_width() * 0.5 + lane_width * (float(mirrored) + 0.5)
