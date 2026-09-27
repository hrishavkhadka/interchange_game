extends Node

signal node_added(node: RoadNode)
signal graph_changed()

const SNAP_RADIUS := 5.0

var nodes: Array[RoadNode] = []
var segments: Array[RoadSegment] = []
var _next_id := 1

func find_nearest(pos: Vector3, radius: float = SNAP_RADIUS) -> RoadNode:
	var best: RoadNode = null
	var best_dist := radius
	for n in nodes:
		var d := n.position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = n
	return best

func get_or_create(pos: Vector3) -> RoadNode:
	var existing := find_nearest(pos)
	if existing != null:
		return existing
	var node := RoadNode.new(pos, _next_id)
	_next_id += 1
	nodes.append(node)
	node_added.emit(node)
	graph_changed.emit()
	return node

func register_segment(seg: RoadSegment) -> void:
	if not segments.has(seg):
		segments.append(seg)
		graph_changed.emit()

func unregister_segment(seg: RoadSegment) -> void:
	segments.erase(seg)
	graph_changed.emit()

func clear() -> void:
	nodes.clear()
	segments.clear()
	_next_id = 1
	graph_changed.emit()
