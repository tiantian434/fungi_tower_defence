class_name DigestiveOrgan
extends Node2D
## 管理待消化尸体和在途预留。消化完成才向母核收入营养。

signal inventory_changed(queued: int, incoming: int)
signal digested(nutrition: int)
signal selection_requested

@export var mother_core: MotherCore
@export var core_edge: HyphaEdge
@export_range(1, 10, 1) var capacity: int = 4

var incoming_remains: int = 0
var digested_count: int = 0
var total_nutrition_produced: int = 0
var _queue: Array[int] = []
var _gain_tween: Tween

@onready var digest_timer: Timer = $DigestTimer
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var gain_feedback: Node2D = $GainFeedback
@onready var gain_label: Label = $GainFeedback/Label
@onready var queue_label: Label = $QueueLabel


func _ready() -> void:
	_emit_inventory_changed()


func get_queued_count() -> int:
	return _queue.size()


func get_queued_nutrition() -> int:
	var total: int = 0
	for value in _queue:
		total += value
	return total


func reserve_remains() -> bool:
	if _queue.size() + incoming_remains >= capacity:
		return false
	incoming_remains += 1
	_emit_inventory_changed()
	return true


func complete_delivery(nutrition: int) -> bool:
	if nutrition <= 0 or incoming_remains <= 0 or _queue.size() >= capacity:
		return false
	incoming_remains -= 1
	_queue.append(nutrition)
	_emit_inventory_changed()
	if digest_timer.is_stopped():
		digest_timer.start()
	return true


func cancel_reservation() -> bool:
	if incoming_remains <= 0:
		return false
	incoming_remains -= 1
	_emit_inventory_changed()
	return true


func _process(_delta: float) -> void:
	progress_bar.value = 0.0 if _queue.is_empty() or not _has_core_connection() else (
		1.0 - digest_timer.time_left / digest_timer.wait_time
	)


func _has_core_connection() -> bool:
	return is_instance_valid(mother_core) and mother_core.health > 0 and (
		is_instance_valid(core_edge) and core_edge.connects(mother_core, get_parent())
	)


func _on_digest_timer_timeout() -> void:
	if _queue.is_empty():
		return
	if not _has_core_connection():
		digest_timer.start()
		return

	var nutrition: int = _queue.pop_front()
	mother_core.add_nutrition(nutrition)
	digested_count += 1
	total_nutrition_produced += nutrition
	_emit_inventory_changed()
	digested.emit(nutrition)
	_play_gain_feedback(nutrition)
	if not _queue.is_empty():
		digest_timer.start()


func _emit_inventory_changed() -> void:
	queue_label.text = "%d (+%d)/%d" % [get_queued_count(), incoming_remains, capacity]
	inventory_changed.emit(get_queued_count(), incoming_remains)


func _play_gain_feedback(nutrition: int) -> void:
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	gain_label.text = "+%d 营养" % nutrition
	gain_feedback.position = Vector2(0, -66)
	gain_feedback.modulate.a = 1.0
	gain_feedback.show()
	_gain_tween = create_tween().set_parallel(true)
	_gain_tween.tween_property(gain_feedback, "position:y", -88.0, 0.8)
	_gain_tween.tween_property(gain_feedback, "modulate:a", 0.0, 0.8)
	_gain_tween.chain().tween_callback(gain_feedback.hide)


func _on_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selection_requested.emit()
			get_viewport().set_input_as_handled()
