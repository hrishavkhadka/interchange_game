class_name Lane
extends RefCounted

var segment: RoadSegment
var lane_index: int
var direction: String
var curve: Curve3D
var length: float
var from_node: RoadNode
var to_node: RoadNode
var speed_limit: float
var next_lanes: Array[Lane] = []
var prev_lanes: Array[Lane] = []
var next_curves: Dictionary = {}
var adjacent_lanes: Array[Lane] = []
