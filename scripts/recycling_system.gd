class_name RecyclingSystem
extends Node
## 领取尸体、预留后方容量和结算运输。运输中始终保留原尸体作为资源记录。

signal recycling_changed(in_transit: int, delivered: int, interrupted: int)

class Shipment:
	var remains: EnemyRemains
	var receiver: DigestiveOrgan
	var packet: RemainsPacket
	var nutrition: int

@export var collector: RecoveryOrgan
@export var digestive_organ: DigestiveOrgan
@export var return_edge: HyphaEdge
@export var remains_container: Node2D
@export var packet_container: Node2D
@export var packet_scene: PackedScene

var delivered_count: int = 0
var interrupted_count: int = 0
var _shipments: Dictionary[int, Shipment] = {}


func get_in_transit_count() -> int:
	return _shipments.size()


func _on_dispatch_timer_timeout() -> void:
	try_dispatch()


func try_dispatch() -> bool:
	if not is_instance_valid(collector) or not is_instance_valid(digestive_organ):
		return false
	if not is_instance_valid(return_edge) or not return_edge.connects(
		collector.get_parent(), digestive_organ.get_parent()
	):
		return false
	if not is_instance_valid(packet_container) or packet_scene == null:
		return false
	var remains := _find_nearest_remains()
	if remains == null or not digestive_organ.reserve_remains():
		return false
	if not remains.try_claim():
		digestive_organ.cancel_reservation()
		return false

	var instance := packet_scene.instantiate()
	if not instance is RemainsPacket:
		instance.free()
		digestive_organ.cancel_reservation()
		remains.release_claim(remains.global_position)
		return false
	var packet := instance as RemainsPacket
	var shipment := Shipment.new()
	shipment.remains = remains
	shipment.receiver = digestive_organ
	shipment.packet = packet
	shipment.nutrition = remains.nutrition_value
	var shipment_id := packet.get_instance_id()
	_shipments[shipment_id] = shipment
	packet.arrived.connect(_on_packet_arrived)
	packet.interrupted.connect(_on_packet_interrupted)
	packet.tree_exiting.connect(_on_packet_removed.bind(shipment_id))
	packet_container.add_child(packet)
	packet.global_position = remains.global_position
	_emit_recycling_changed()
	collector.play_collect_feedback()
	packet.start_transport(return_edge, collector.get_parent(), digestive_organ.get_parent())
	return true


func _find_nearest_remains() -> EnemyRemains:
	if not is_instance_valid(remains_container):
		return null
	var nearest: EnemyRemains = null
	var nearest_distance := collector.pickup_radius * collector.pickup_radius
	for child in remains_container.get_children():
		if child is EnemyRemains and child.is_available():
			var distance := collector.global_position.distance_squared_to(child.global_position)
			if distance <= nearest_distance:
				nearest = child
				nearest_distance = distance
	return nearest


func _on_packet_arrived(packet: RemainsPacket) -> void:
	_settle_shipment(packet.get_instance_id(), true)


func _on_packet_interrupted(packet: RemainsPacket) -> void:
	_settle_shipment(packet.get_instance_id(), false)


func _on_packet_removed(shipment_id: int) -> void:
	_settle_shipment(shipment_id, false)


func _settle_shipment(shipment_id: int, was_delivered: bool) -> void:
	var shipment: Shipment = _shipments.get(shipment_id)
	if shipment == null:
		return
	_shipments.erase(shipment_id)
	var accepted := false
	if was_delivered and is_instance_valid(shipment.receiver) and (
		is_instance_valid(shipment.remains) and not shipment.remains.is_queued_for_deletion()
	):
		accepted = shipment.receiver.complete_delivery(shipment.nutrition)
	if accepted:
		shipment.remains.queue_free()
		delivered_count += 1
	else:
		if is_instance_valid(shipment.receiver):
			shipment.receiver.cancel_reservation()
		if is_instance_valid(shipment.remains):
			var drop_position := shipment.remains.global_position
			if is_instance_valid(shipment.packet):
				drop_position = shipment.packet.global_position
			shipment.remains.release_claim(drop_position)
		interrupted_count += 1
	_emit_recycling_changed()


func _emit_recycling_changed() -> void:
	recycling_changed.emit(get_in_transit_count(), delivered_count, interrupted_count)


func _exit_tree() -> void:
	for shipment_id in _shipments.keys():
		var shipment: Shipment = _shipments[shipment_id]
		if is_instance_valid(shipment.packet):
			shipment.packet.cancel_transport()
		else:
			_settle_shipment(shipment_id, false)
