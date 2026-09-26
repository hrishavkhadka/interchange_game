class_name LaneLayout
extends RefCounted

# 'F' = forward, 'B' = backward
# Order: left → right when facing forward.

var lanes: Array[String] = []

static func parse(s: String) -> LaneLayout:
	var l := LaneLayout.new()
	for i in s.length():
		var c := s[i].to_upper()
		if c == "F" or c == "B":
			l.lanes.append(c)
		else:
			push_warning("LaneLayout: skipping invalid char '%s'" % c)
	return l

func size() -> int:
	return lanes.size()

func forward_count() -> int:
	var n := 0
	for d in lanes:
		if d == "F":
			n += 1
	return n

func backward_count() -> int:
	return size() - forward_count()

func as_string() -> String:
	return "".join(lanes)
