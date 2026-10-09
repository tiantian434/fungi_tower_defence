class_name ColonyHUD
extends CanvasLayer
## 只显示模型数据，不参与扣款、运输或库存结算。

@onready var selection_label: Label = $SelectionLabel
@onready var stock_label: Label = $StockLabel
@onready var transport_label: Label = $TransportLabel
@onready var notice_label: Label = $NoticeLabel
@onready var battle_label: Label = $BattleLabel
@onready var recovery_label: Label = $RecoveryLabel

var _core_nutrition: int = 0
var _organ_nutrition: int = 0
var _incoming_nutrition: int = 0
var _organ_capacity: int = 0
var _battle_result: String = ""
var _recycling_in_transit: int = 0
var _recycling_delivered: int = 0
var _recycling_interrupted: int = 0
var _digestive_queued: int = 0
var _digestive_incoming: int = 0
var _digested_count: int = 0
var _recovered_nutrition: int = 0


func show_selection(display_name: String) -> void:
	selection_label.text = "未选择菌结" if display_name.is_empty() else "已选择：%s" % display_name


func show_core_nutrition(current: int) -> void:
	_core_nutrition = current
	_update_stock_label()


func show_organ_inventory(stored: int, incoming: int, capacity: int) -> void:
	_organ_nutrition = stored
	_incoming_nutrition = incoming
	_organ_capacity = capacity
	_update_stock_label()


func show_transport(in_transit: int, delivered: int, interrupted: int) -> void:
	transport_label.text = "营养包：在途 %d · 已到达 %d · 中止 %d" % [
		in_transit, delivered, interrupted
	]


func show_notice(message: String) -> void:
	notice_label.text = message


func show_battle(spawned: int, defeated: int, active: int, total: int) -> void:
	if not _battle_result.is_empty():
		return
	battle_label.text = "本轮敌人：%d/%d · 场上：%d\n已击败：%d" % [
		spawned, total, active, defeated
	]


func show_battle_result(won: bool) -> void:
	_battle_result = "本轮防守成功" if won else "母核已被摧毁"
	battle_label.text = _battle_result + "\n按 R 重新开始"
	battle_label.modulate = Color("c2dc9a") if won else Color("e6a099")


func show_recycling(in_transit: int, delivered: int, interrupted: int) -> void:
	_recycling_in_transit = in_transit
	_recycling_delivered = delivered
	_recycling_interrupted = interrupted
	_update_recovery_label()


func show_digestion(queued: int, incoming: int) -> void:
	_digestive_queued = queued
	_digestive_incoming = incoming
	_update_recovery_label()


func show_recovery_totals(digested_count: int, nutrition: int) -> void:
	_digested_count = digested_count
	_recovered_nutrition = nutrition
	_update_recovery_label()


func _update_recovery_label() -> void:
	recovery_label.text = (
		"回收：在途 %d · 已送达 %d · 中断 %d\n" +
		"消化：排队 %d · 待送达 %d · 已消化 %d\n营养回收：+%d"
	) % [
		_recycling_in_transit, _recycling_delivered, _recycling_interrupted,
		_digestive_queued, _digestive_incoming, _digested_count, _recovered_nutrition
	]


func _update_stock_label() -> void:
	stock_label.text = "母核营养：%d · 器官库存：%d/%d · 在途供养：%d" % [
		_core_nutrition, _organ_nutrition, _organ_capacity, _incoming_nutrition
	]
