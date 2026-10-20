class_name ColonyGrowthFeedback
extends Node2D
## 只观察真实回流与阶段事件。合并连续数字、复用一个标签，不生成粒子或修改玩法。

const RETURN_SECONDS: float = 1.8
const STAGE_SECONDS: float = 2.8
const MAX_PULSE_NODES: int = 64

@onready var gain_label: Label = $EnergyGain

var _core: MotherCore
var _network: NetworkSystem
var _return_remaining: float = 0.0
var _return_pulse: float = 0.0
var _stage_remaining: float = 0.0
var _gain_total: int = 0
var _pulse_points: Array[Vector2] = []


func _ready() -> void:
	gain_label.theme = ArtUI.theme(23)
	gain_label.add_theme_color_override("font_color", Color("586e42"))
	gain_label.add_theme_color_override("font_outline_color", Color("fff8e9"))
	gain_label.add_theme_constant_override("outline_size", 5)
	gain_label.hide()
	set_process(false)


func configure(core: MotherCore, network: NetworkSystem, progress: ColonyProgress) -> void:
	_core = core
	_network = network
	core.digestion_product_arrived.connect(_on_energy_returned)
	progress.stage_unlocked.connect(_on_stage_unlocked)


func _on_energy_returned(_product_id: String, amount: int) -> void:
	if amount <= 0: return
	if _return_remaining <= 0.0:
		_gain_total = 0
	_gain_total += amount
	_return_remaining = RETURN_SECONDS
	if _return_pulse <= 0.0:
		_return_pulse = 0.75
	gain_label.text = "+ %d 创作能量" % _gain_total
	gain_label.show()
	set_process(true)


func _on_stage_unlocked(_stage: ColonyProgress.Stage) -> void:
	_stage_remaining = STAGE_SECONDS
	_pulse_points.clear()
	for node: Node2D in _network.get_registered_nodes():
		if _network.is_available_connected_to_core(node):
			_pulse_points.append(to_local(node.global_position))
		if _pulse_points.size() >= MAX_PULSE_NODES: break
	set_process(true)


func _process(delta: float) -> void:
	_return_remaining = maxf(0.0, _return_remaining - delta)
	_return_pulse = maxf(0.0, _return_pulse - delta)
	_stage_remaining = maxf(0.0, _stage_remaining - delta)
	if is_instance_valid(_core):
		gain_label.position = to_local(_core.global_position) + Vector2(-150, -174 - (RETURN_SECONDS - _return_remaining) * 12.0)
	gain_label.modulate.a = clampf(_return_remaining / 0.45, 0.0, 1.0)
	gain_label.visible = _return_remaining > 0.0
	queue_redraw()
	if _return_remaining <= 0.0 and _stage_remaining <= 0.0:
		_pulse_points.clear()
		set_process(false)


func _draw() -> void:
	if _return_pulse > 0.0 and is_instance_valid(_core):
		var part: float = 1.0 - _return_pulse / 0.75
		draw_arc(to_local(_core.global_position), 32.0 + part * 55.0, 0.0, TAU, 40,
			Color(0.47, 0.58, 0.31, (1.0 - part) * 0.75), 2.0, true)
	if _stage_remaining > 0.0:
		var part: float = 1.0 - _stage_remaining / STAGE_SECONDS
		for point: Vector2 in _pulse_points:
			var radius: float = 16.0 + part * 90.0
			draw_arc(point, radius, 0.0, TAU, 40, Color(0.75, 0.51, 0.28, (1.0 - part) * 0.65), 2.0, true)


func get_feedback_snapshot() -> Dictionary:
	return {"gain": _gain_total, "gain_visible": _return_remaining > 0.0,
		"stage_visible": _stage_remaining > 0.0, "pulse_nodes": _pulse_points.size()}
