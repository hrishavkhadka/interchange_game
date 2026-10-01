class_name LaneArc
extends RefCounted

# One directed connection across a node, from `from_lane` to `to_lane`.
# The curve runs in world space between the two lanes' trimmed endpoints.
# Arcs belong to a specific node; conflicts only matter between arcs at
# the same node.

var from_lane: Lane
var to_lane: Lane
var node: RoadNode
var curve: Curve3D
var length: float
var conflicting_arcs: Array = []   # Array[LaneArc]
#var claimed_by_lane: Lane = null #DS told to add this but said nevermind don't change anything so i just left this here commented.

# Per-tick reservation slot, set by VehicleManager.
var primary = null   # Vehicle or null

static func make(from_lane: Lane, to_lane: Lane, node: RoadNode, curve: Curve3D) -> LaneArc:
	var a := LaneArc.new()
	a.from_lane = from_lane
	a.to_lane = to_lane
	a.node = node
	a.curve = curve
	a.length = curve.get_baked_length() if curve != null else 0.0
	return a
