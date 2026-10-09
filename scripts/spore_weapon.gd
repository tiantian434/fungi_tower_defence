class_name SporeWeapon
extends Node2D
## 武器负责选敌和发射，向器官申请消耗营养；弹丸负责移动与命中。

signal shot_fired(target: BasicEnemy)

const SHOT_NUTRITION: int = 1
const RANGE_SEGMENTS: int = 64

@export var inventory_owner: AttackOrgan
@export var enemy_container: Node2D
@export var projectile_container: Node2D
@export var projectile_scene: PackedScene
@export_range(1.0, 800.0, 1.0) var attack_range: float = 300.0
@export_range(1, 100, 1) var damage: int = 12

@onready var range_outline: Line2D = $RangeOutline
@onready var muzzle: Polygon2D = $Muzzle

var _flash_tween: Tween


func _ready() -> void:
	# 只更新场景里已有的线条，射程和选敌都使用地面落点的距离。
	var points := PackedVector2Array()
	for index in range(RANGE_SEGMENTS):
		points.append(Vector2.from_angle(TAU * index / RANGE_SEGMENTS) * attack_range)
	range_outline.points = points


func set_range_visible(is_visible: bool) -> void:
	range_outline.visible = is_visible


func _on_fire_timer_timeout() -> void:
	if not is_instance_valid(inventory_owner) or inventory_owner.nutrition < SHOT_NUTRITION:
		return
	if not is_instance_valid(projectile_container) or projectile_scene == null:
		return
	var enemy := _find_nearest_target()
	if enemy == null:
		return

	var instance := projectile_scene.instantiate()
	if not instance is SporeProjectile:
		instance.free()
		return
	var projectile := instance as SporeProjectile
	if not inventory_owner.consume_nutrition(SHOT_NUTRITION):
		projectile.free()
		return

	projectile_container.add_child(projectile)
	projectile.global_position = global_position
	projectile.launch(enemy, damage)
	inventory_owner.play_fire_feedback()
	_play_muzzle_flash()
	shot_fired.emit(enemy)


func _find_nearest_target() -> BasicEnemy:
	if not is_instance_valid(enemy_container):
		return null
	var nearest: BasicEnemy = null
	var nearest_distance := attack_range * attack_range
	for child in enemy_container.get_children():
		if child is BasicEnemy and child.is_alive():
			var distance := inventory_owner.global_position.distance_squared_to(child.global_position)
			if distance <= nearest_distance:
				nearest = child
				nearest_distance = distance
	return nearest


func _play_muzzle_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	muzzle.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(muzzle, "modulate:a", 0.0, 0.14)
