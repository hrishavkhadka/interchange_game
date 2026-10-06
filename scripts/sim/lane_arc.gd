class_name LaneArc
extends RefCounted

var from_lane: Lane
var to_lane: Lane
var node: RoadNode
var curve: Curve3D
var length: float
var conflicting_arcs: Array = []
var primary = null
var enabled: bool = true

static func make(from_lane: Lane, to_lane: Lane, node: RoadNode, curve: Curve3D) -> LaneArc:
	var a := LaneArc.new()
	a.from_lane = from_lane
	a.to_lane = to_lane
	a.node = node
	a.curve = curve
	a.length = curve.get_baked_length() if curve != null else 0.0
	return a
