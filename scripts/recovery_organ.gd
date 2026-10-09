class_name RecoveryOrgan
extends Node2D
## 回收半径从所属菌结的落点计算；调度由 RecyclingSystem 处理。

signal selection_requested

@export_range(1.0, 800.0, 1.0) var pickup_radius: float = 320.0

var _collect_tween: Tween

@onready var mouth: Polygon2D = $Visuals/Mouth


func play_collect_feedback() -> void:
	if _collect_tween != null and _collect_tween.is_valid():
		_collect_tween.kill()
	mouth.scale = Vector2(1.2, 0.8)
	_collect_tween = create_tween()
	_collect_tween.tween_property(mouth, "scale", Vector2.ONE, 0.25)


func _on_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selection_requested.emit()
			get_viewport().set_input_as_handled()
