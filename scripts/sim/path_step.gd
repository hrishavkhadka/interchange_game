class_name PathStep
extends RefCounted

var curve: Curve3D
var length: float
var speed: float
var is_lane: bool

static func make(c: Curve3D, s: float, is_lane_step: bool) -> PathStep:
	var p := PathStep.new()
	p.curve = c
	p.length = c.get_baked_length()
	p.speed = s
	p.is_lane = is_lane_step
	return p
