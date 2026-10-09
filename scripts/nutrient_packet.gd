class_name NutrientPacket
extends Node2D
## 一次运输：从菌丝起点出发，到达终点后发出通知。

signal arrived(packet: NutrientPacket)
signal interrupted(packet: NutrientPacket)

@export_range(1.0, 600.0, 1.0) var speed: float = 150.0

var edge: HyphaEdge
var progress: float = 0.0
var _travelling: bool = false
var _finished: bool = false


func start_transport(connection: HyphaEdge) -> void:
	if _travelling or _finished:
		return

	edge = connection
	_travelling = true
	if not is_instance_valid(edge) or not edge.has_endpoints():
		_finish(false)
		return

	global_position = edge.get_point_at(0.0)


func cancel_transport() -> void:
	_finish(false)


func _physics_process(delta: float) -> void:
	if not _travelling or _finished:
		return

	if not is_instance_valid(edge) or not edge.has_endpoints():
		_finish(false)
		return

	var distance := maxf(edge.get_length(), 0.001)
	progress = minf(progress + maxf(speed, 0.0) * delta / distance, 1.0)
	global_position = edge.get_point_at(progress)
	global_rotation = (edge.get_point_at(1.0) - edge.get_point_at(0.0)).angle()

	if progress >= 1.0:
		_finish(true)


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
