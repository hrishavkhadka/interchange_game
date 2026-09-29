class_name PathStep
extends RefCounted

var curve: Curve3D
var length: float
var speed: float
var is_lane: bool
var is_transition: bool   # true for junction transition curves
var lane_ref: Lane
var start_dist: float = 0.0

static func make(c: Curve3D, s: float, is_lane_step: bool, lane: Variant = null, sd: float = 0.0, is_transition_step: bool = false) -> PathStep:
	var p := PathStep.new()
	p.curve = c
	p.length = c.get_baked_length()
	p.speed = s
	p.is_lane = is_lane_step
	p.is_transition = is_transition_step
	p.start_dist = sd
	if lane != null:
		p.lane_ref = lane
	return p
