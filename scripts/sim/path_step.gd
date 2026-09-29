class_name PathStep
extends RefCounted

var curve: Curve3D
var length: float
var speed: float
var is_lane: bool
var lane_ref: Lane   # non-null only for lane steps

static func make(c: Curve3D, s: float, is_lane_step: bool, lane: Variant = null) -> PathStep:
	var p := PathStep.new()
	p.curve = c
	p.length = c.get_baked_length()
	p.speed = s
	p.is_lane = is_lane_step
	if lane != null:
		p.lane_ref = lane
	return p
