class_name RemainsPacket
extends Node2D
## 先收至覆盖尸体的菌结，再沿派送时确定的路径运输。中断由调度系统结算。

signal arrived(packet: RemainsPacket)
signal interrupted(packet: RemainsPacket)

@export_range(1.0, 600.0, 1.0) var speed: float = 140.0

var edge: HyphaEdge
var progress: float = 0.0
var _route: Array[HyphaEdge] = []
var _waypoints: Array[Node2D] = []
var _segment: int = -1
var _travelling: bool = false
var _finished: bool = false


func start_transport(route: Array[HyphaEdge], source: Node2D, destination: Node2D) -> void:
	if _travelling or _finished:
		return
	_route = route.duplicate()
	_travelling = true
	if not is_instance_valid(source) or not is_instance_valid(destination):
		_finish(false)
		return
	_waypoints.append(source)
	var current := source
	for connection in _route:
		if not is_instance_valid(connection) or not connection.is_usable():
			_finish(false)
			return
		var next: Node2D = connection.end_node if connection.start_node == current else connection.start_node
		if not connection.connects(current, next) or next in _waypoints:
			_finish(false)
			return
		_waypoints.append(next)
		current = next
	if current != destination:
		_finish(false)


func cancel_transport() -> void:
	_finish(false)


func _physics_process(delta: float) -> void:
	if not _travelling or _finished:
		return
	if not _route_is_valid():
		_finish(false)
		return

	var previous_position := global_position
	var remaining_step := maxf(speed, 0.0) * delta
	if _segment == -1:
		var source_position := _waypoints[0].global_position
		var pickup_distance := global_position.distance_to(source_position)
		global_position = global_position.move_toward(source_position, remaining_step)
		remaining_step = maxf(remaining_step - pickup_distance, 0.0)
		if global_position.distance_to(source_position) < 0.01:
			_segment = 0

	while _segment >= 0 and _segment < _route.size() and remaining_step > 0.0:
		edge = _route[_segment]
		var length := maxf(edge.get_length(), 0.001)
		var distance_left := (1.0 - progress) * length
		progress = minf(progress + remaining_step / length, 1.0)
		var reversed := edge.end_node == _waypoints[_segment]
		global_position = edge.get_point_at(1.0 - progress if reversed else progress)
		remaining_step = maxf(remaining_step - distance_left, 0.0)
		if progress >= 1.0:
			_segment += 1
			progress = 0.0

	if previous_position.distance_squared_to(global_position) > 0.001:
		global_rotation = (global_position - previous_position).angle()
	if _segment == _route.size():
		_finish(true)


func _route_is_valid() -> bool:
	for waypoint in _waypoints:
		if not is_instance_valid(waypoint) or waypoint.is_queued_for_deletion():
			return false
	for index in range(_route.size()):
		if not is_instance_valid(_route[index]) or not _route[index].connects(
			_waypoints[index], _waypoints[index + 1]
		):
			return false
	return not _waypoints.is_empty()


func _finish(was_delivered: bool) -> void:
	if _finished:
		return
	_finished = true
	_travelling = false
	if was_delivered:
		arrived.emit(self)
	else:
		interrupted.emit(self)
	queue_free()
