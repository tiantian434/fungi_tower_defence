class_name RemainsPacket
extends Node2D
## 先从尸体落点移动到前线菌结，再沿直连菌丝运到后方菌结。

signal arrived(packet: RemainsPacket)
signal interrupted(packet: RemainsPacket)

@export_range(1.0, 600.0, 1.0) var speed: float = 140.0

var edge: HyphaEdge
var progress: float = 0.0
var _source: Node2D
var _destination: Node2D
var _reverse: bool = false
var _on_edge: bool = false
var _travelling: bool = false
var _finished: bool = false


func start_transport(connection: HyphaEdge, source: Node2D, destination: Node2D) -> void:
	if _travelling or _finished:
		return
	edge = connection
	_source = source
	_destination = destination
	_travelling = true
	if not is_instance_valid(edge) or not edge.connects(source, destination):
		_finish(false)
		return
	_reverse = edge.end_node == source


func cancel_transport() -> void:
	_finish(false)


func _physics_process(delta: float) -> void:
	if not _travelling or _finished:
		return
	if not _route_is_valid():
		_finish(false)
		return

	var previous_position := global_position
	var step := maxf(speed, 0.0) * delta
	if not _on_edge:
		global_position = global_position.move_toward(_source.global_position, step)
		if global_position.distance_to(_source.global_position) < 0.01:
			_on_edge = true
	else:
		progress = minf(progress + step / maxf(edge.get_length(), 0.001), 1.0)
		global_position = edge.get_point_at(1.0 - progress if _reverse else progress)

	if previous_position.distance_squared_to(global_position) > 0.001:
		global_rotation = (global_position - previous_position).angle()
	if _on_edge and progress >= 1.0:
		_finish(true)


func _route_is_valid() -> bool:
	if not is_instance_valid(edge) or not edge.has_endpoints():
		return false
	if not is_instance_valid(_source) or not is_instance_valid(_destination):
		return false
	if _reverse:
		return edge.start_node == _destination and edge.end_node == _source
	return edge.start_node == _source and edge.end_node == _destination


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
