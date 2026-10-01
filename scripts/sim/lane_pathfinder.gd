class_name LanePathfinder
extends RefCounted

const MAX_ITERATIONS: int = 20000
const LANE_CHANGE_PENALTY: float = 15.0

static func find_path(start_lane: Lane, target_node: RoadNode) -> Array[Lane]:
	var empty: Array[Lane] = []
	if start_lane == null or target_node == null:
		return empty
	if start_lane.to_node == target_node:
		var single: Array[Lane] = [start_lane]
		return single

	var open: Array = [[0.0, start_lane, [start_lane]]]
	var visited: Dictionary = {}
	var iterations: int = 0

	while not open.is_empty() and iterations < MAX_ITERATIONS:
		iterations += 1
		# Stable-ish ordering: sort by cost, then by lane_index so ties
		# always resolve in the same direction for the same inputs.
		open.sort_custom(func(a, b) -> bool:
			if absf(a[0] - b[0]) > 0.001:
				return a[0] < b[0]
			var la: Lane = a[1]
			var lb: Lane = b[1]
			return la.lane_index < lb.lane_index)

		var current: Array = open.pop_front()
		var cost: float = current[0]
		var lane: Lane = current[1]
		var path: Array = current[2]

		if visited.has(lane):
			continue
		visited[lane] = true

		for next_lane in lane.next_lanes:
			if visited.has(next_lane):
				continue
			var step_cost: float = next_lane.length
			# Penalize crossing lane indices or switching direction.
			if next_lane.lane_index != lane.lane_index:
				step_cost += LANE_CHANGE_PENALTY
			if next_lane.direction != lane.direction:
				step_cost += LANE_CHANGE_PENALTY
			var new_cost: float = cost + step_cost
			var new_path: Array = path.duplicate()
			new_path.append(next_lane)
			if next_lane.to_node == target_node:
				var result: Array[Lane] = []
				for l in new_path:
					result.append(l)
				return result
			open.append([new_cost, next_lane, new_path])

	return empty
