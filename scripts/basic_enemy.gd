class_name BasicEnemy
extends Node2D
## 普通敌人只负责移动、攻击母核、受伤与死亡反馈。

signal died(enemy: BasicEnemy)

@export var mother_core: MotherCore
@export_range(1, 200, 1) var max_health: int = 24
@export_range(0.0, 200.0, 1.0) var move_speed: float = 52.0
@export_range(1, 100, 1) var attack_damage: int = 12
@export_range(1.0, 100.0, 1.0) var contact_range: float = 28.0
@export_range(1, 100, 1) var remains_nutrition: int = 4

var health: int = 0
var _hit_tween: Tween

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/Sprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var attack_timer: Timer = $AttackTimer


func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health


func is_alive() -> bool:
	return health > 0 and not is_queued_for_deletion()


func get_aim_position() -> Vector2:
	return sprite.global_position


func _physics_process(delta: float) -> void:
	if not is_alive() or not is_instance_valid(mother_core) or mother_core.health <= 0:
		attack_timer.stop()
		return

	var distance := global_position.distance_to(mother_core.global_position)
	if distance > contact_range:
		var step := minf(move_speed * delta, distance - contact_range)
		global_position = global_position.move_toward(mother_core.global_position, step)
		sprite.play("walk")
		attack_timer.stop()
	else:
		sprite.play("idle")
		if attack_timer.is_stopped():
			attack_timer.start()


func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	health = maxi(health - amount, 0)
	health_bar.value = health
	if health == 0:
		_die()
	else:
		_play_hit_feedback()


func _on_attack_timer_timeout() -> void:
	if not is_alive() or not is_instance_valid(mother_core) or mother_core.health <= 0:
		return
	if global_position.distance_to(mother_core.global_position) <= contact_range + 0.01:
		mother_core.take_damage(attack_damage)


func _play_hit_feedback() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	sprite.modulate = Color(2.0, 1.3, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)


func _die() -> void:
	attack_timer.stop()
	health_bar.hide()
	sprite.stop()
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	sprite.modulate = Color.WHITE
	died.emit(self)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(visuals, "modulate:a", 0.0, 0.2)
	fade.tween_property(visuals, "scale", Vector2(1.15, 0.6), 0.2)
	fade.chain().tween_callback(queue_free)
