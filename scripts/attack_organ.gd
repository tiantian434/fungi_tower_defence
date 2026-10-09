class_name AttackOrgan
extends Node2D
## 器官管理本地库存和外观；武器通过 consume_nutrition 消耗库存。

signal inventory_changed(stored: int, incoming: int, capacity: int)
signal selection_requested

const STORED_COLOR := Color("f5d577")
const INCOMING_COLOR := Color("8d794a")
const EMPTY_COLOR := Color("3b4b42")

@export_range(1, 6, 1) var capacity: int = 6
@export_range(0, 6, 1) var initial_nutrition: int = 4
@export_range(0, 6, 1) var refill_target: int = 3

var nutrition: int = 0
var incoming_nutrition: int = 0
var _fire_tween: Tween

@onready var inventory_slots: HBoxContainer = $InventorySlots
@onready var cap: Polygon2D = $Cap


func _ready() -> void:
	nutrition = clampi(initial_nutrition, 0, capacity)
	_update_inventory()


func needs_supply() -> bool:
	return nutrition + incoming_nutrition < clampi(refill_target, 0, capacity)


func reserve_nutrition(amount: int) -> bool:
	if amount <= 0 or nutrition + incoming_nutrition + amount > capacity:
		return false

	incoming_nutrition += amount
	_update_inventory()
	return true


func complete_delivery(amount: int) -> bool:
	if amount <= 0 or incoming_nutrition < amount or nutrition + amount > capacity:
		return false

	incoming_nutrition -= amount
	nutrition += amount
	_update_inventory()
	return true


func cancel_reservation(amount: int) -> bool:
	if amount <= 0 or incoming_nutrition < amount:
		return false

	incoming_nutrition -= amount
	_update_inventory()
	return true


func consume_nutrition(amount: int = 1) -> bool:
	if amount <= 0 or nutrition < amount:
		return false

	nutrition -= amount
	_update_inventory()
	return true


func play_fire_feedback() -> void:
	if _fire_tween != null and _fire_tween.is_valid():
		_fire_tween.kill()
	cap.scale = Vector2(1.12, 0.9)
	_fire_tween = create_tween()
	_fire_tween.tween_property(cap, "scale", Vector2.ONE, 0.18)


func _update_inventory() -> void:
	for index in range(inventory_slots.get_child_count()):
		var slot := inventory_slots.get_child(index) as ColorRect
		slot.visible = index < capacity
		if index < nutrition:
			slot.color = STORED_COLOR
		elif index < nutrition + incoming_nutrition:
			slot.color = INCOMING_COLOR
		else:
			slot.color = EMPTY_COLOR
	inventory_changed.emit(nutrition, incoming_nutrition, capacity)


func _on_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selection_requested.emit()
			get_viewport().set_input_as_handled()
