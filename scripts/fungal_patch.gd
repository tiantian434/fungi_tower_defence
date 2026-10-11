@tool
class_name FungalPatch
extends Node2D
## 菌结的覆盖参数与展开状态。连通查询、合并显示和领取判定由 FungalField 负责。

@export_range(1.0, 800.0, 1.0) var coverage_radius: float = 110.0
@export_range(0.0, 1.0, 0.05) var initial_growth: float = 1.0
@export_range(0.1, 10.0, 0.1) var expansion_seconds: float = 1.5
@export_range(0.0, 10.0, 0.1) var disconnect_grace_seconds: float = 5.0
@export_range(0.1, 30.0, 0.1) var recession_seconds: float = 10.0

var growth: float = 1.0
var connected: bool = false
var _disconnected_seconds: float = 0.0


func _ready() -> void:
	growth = initial_growth


func update_connection(is_connected: bool, delta: float) -> void:
	connected = is_connected
	if Engine.is_editor_hint():
		growth = initial_growth
		return
	if connected:
		_disconnected_seconds = 0.0
		growth = move_toward(growth, 1.0, delta / maxf(expansion_seconds, 0.1))
	else:
		# 跨过缓冲结束点的一帧，只计算真正处于收缩阶段的时间。
		var previous_recession := maxf(_disconnected_seconds - disconnect_grace_seconds, 0.0)
		_disconnected_seconds += delta
		var recession := maxf(_disconnected_seconds - disconnect_grace_seconds, 0.0)
		growth = move_toward(growth, 0.0, (recession - previous_recession) / maxf(recession_seconds, 0.1))


func get_radius() -> float:
	return maxf(coverage_radius, 0.0) * growth
