class_name PathStep
extends RefCounted

var curve: Curve3D
var length: float
var speed: float
var is_lane: bool
var lane_ref: Lane       # non-null for lane steps
var arc_ref: LaneArc     # non-null for arc steps
var start_dist: float = 0.0

static func make(c: Curve3D, s: float, is_lane_step: bool, lane: Variant = null, sd: float = 0.0, arc: Variant = null) -> PathStep:
	var p := PathStep.new()
	p.curve = c
	p.length = c.get_baked_length()
	p.speed = s
	p.is_lane = is_lane_step
	p.start_dist = sd
	if lane != null:
		p.lane_ref = lane
	if arc != null:
		p.arc_ref = arc
	return p
