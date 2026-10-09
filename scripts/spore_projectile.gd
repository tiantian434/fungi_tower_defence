class_name SporeProjectile
extends Node2D
## 一发孢子追踪发射时选定的目标；目标消失则消散，不重新寻找目标。

@export_range(1.0, 1200.0, 1.0) var speed: float = 360.0

var target: BasicEnemy
var _damage: int = 0
var _launched: bool = false
var _finished: bool = false


func launch(enemy: BasicEnemy, damage: int) -> void:
	if _launched or _finished:
		return
	target = enemy
	_damage = damage
	_launched = true


func _physics_process(delta: float) -> void:
	if not _launched or _finished:
		return
	if not is_instance_valid(target) or not target.is_alive():
		_finish()
		return

	var aim := target.get_aim_position()
	var movement := maxf(speed, 0.0) * delta
	global_rotation = (aim - global_position).angle()
	if global_position.distance_to(aim) <= movement:
		target.take_damage(_damage)
		_finish()
	else:
		global_position = global_position.move_toward(aim, movement)


func _on_lifetime_timer_timeout() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	queue_free()
