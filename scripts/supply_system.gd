class_name SupplySystem
extends Node
## 调度母核到一个器官的供养，负责扣款、预留和最终结算。

signal transport_changed(in_transit: int, delivered: int, interrupted: int)
signal notice(message: String)

const PACKET_NUTRITION: int = 1

class Shipment:
	var source: MotherCore
	var receiver: AttackOrgan
	var packet: NutrientPacket

@export var mother_core: MotherCore
@export var target_organ: AttackOrgan
@export var supply_edge: HyphaEdge
@export var packet_container: Node2D
@export var packet_scene: PackedScene

var delivered_packets: int = 0
var interrupted_packets: int = 0
var _shipments: Dictionary[int, Shipment] = {}


func request_supply() -> bool:
	return _dispatch_packet(true)


func get_in_transit_count() -> int:
	return _shipments.size()


func _on_dispatch_timer_timeout() -> void:
	if is_instance_valid(target_organ) and target_organ.needs_supply():
		_dispatch_packet(false)


func _dispatch_packet(show_rejection: bool) -> bool:
	if not is_instance_valid(mother_core) or not is_instance_valid(target_organ):
		return _reject("缺少母核或供养器官", show_rejection)
	if not is_instance_valid(supply_edge) or not supply_edge.has_endpoints():
		return _reject("菌丝缺少端点，暂时无法供养", show_rejection)
	if supply_edge.start_node != mother_core or supply_edge.end_node != target_organ.get_parent():
		return _reject("供养线路没有连接母核和目标菌结", show_rejection)
	if not is_instance_valid(packet_container) or packet_scene == null:
		return _reject("供养系统缺少营养包配置", show_rejection)

	if not target_organ.reserve_nutrition(PACKET_NUTRITION):
		return _reject("库存与在途供养已占满容量", show_rejection)
	if not mother_core.try_spend_nutrition(PACKET_NUTRITION):
		target_organ.cancel_reservation(PACKET_NUTRITION)
		return _reject("母核无法提供营养：余额不足或生命值已归零", show_rejection)

	var instance := packet_scene.instantiate()
	if not instance is NutrientPacket:
		instance.free()
		target_organ.cancel_reservation(PACKET_NUTRITION)
		mother_core.add_nutrition(PACKET_NUTRITION)
		return _reject("营养包场景类型不正确", show_rejection)

	var packet := instance as NutrientPacket
	var shipment := Shipment.new()
	shipment.source = mother_core
	shipment.receiver = target_organ
	shipment.packet = packet
	var shipment_id := packet.get_instance_id()
	_shipments[shipment_id] = shipment
	packet.arrived.connect(_on_packet_arrived)
	packet.interrupted.connect(_on_packet_interrupted)
	packet.tree_exiting.connect(_on_packet_removed.bind(shipment_id))
	packet_container.add_child(packet)
	_emit_transport_changed()
	packet.start_transport(supply_edge)
	return true


func _reject(message: String, show_rejection: bool) -> bool:
	if show_rejection:
		notice.emit(message)
	return false


func _on_packet_arrived(packet: NutrientPacket) -> void:
	_settle_shipment(packet.get_instance_id(), true)


func _on_packet_interrupted(packet: NutrientPacket) -> void:
	_settle_shipment(packet.get_instance_id(), false)


func _on_packet_removed(shipment_id: int) -> void:
	_settle_shipment(shipment_id, false)


func _settle_shipment(shipment_id: int, was_delivered: bool) -> void:
	var shipment: Shipment = _shipments.get(shipment_id)
	if shipment == null:
		return

	# 先移除记录；到达信号和节点退出不会重复入库或退款。
	_shipments.erase(shipment_id)
	var accepted := false
	if was_delivered and is_instance_valid(shipment.receiver):
		accepted = shipment.receiver.complete_delivery(PACKET_NUTRITION)

	if accepted:
		delivered_packets += 1
		notice.emit("营养已送达攻击器官")
	else:
		if is_instance_valid(shipment.receiver):
			shipment.receiver.cancel_reservation(PACKET_NUTRITION)
		if is_instance_valid(shipment.source):
			shipment.source.add_nutrition(PACKET_NUTRITION)
		interrupted_packets += 1
		notice.emit("供养已取消，营养退回母核")
	_emit_transport_changed()


func _emit_transport_changed() -> void:
	transport_changed.emit(get_in_transit_count(), delivered_packets, interrupted_packets)


func _exit_tree() -> void:
	for shipment_id in _shipments.keys():
		var shipment: Shipment = _shipments[shipment_id]
		if is_instance_valid(shipment.packet):
			shipment.packet.cancel_transport()
		else:
			_settle_shipment(shipment_id, false)
