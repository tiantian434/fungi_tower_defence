class_name EnemyRemains
extends Node2D
## 尸体保存尚未消化的营养价值。领取后隐藏，运输中断则回到地面。

@export_range(1, 100, 1) var nutrition_value: int = 4

var _claimed: bool = false


func is_available() -> bool:
	return not _claimed and not is_queued_for_deletion()


func try_claim() -> bool:
	if not is_available():
		return false
	_claimed = true
	hide()
	return true


func release_claim(drop_position: Vector2) -> void:
	_claimed = false
	global_position = drop_position
	show()
