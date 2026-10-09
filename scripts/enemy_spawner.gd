class_name EnemySpawner
extends Node
## 一轮有限数量的敌人。出生位置和两个计时器都在场景中配置。

signal wave_changed(spawned: int, defeated: int, active: int, total: int)
signal wave_finished

@export var mother_core: MotherCore
@export var enemy_container: Node2D
@export var spawn_points: Node2D
@export var enemy_scene: PackedScene
@export_range(1, 50, 1) var wave_size: int = 6
@export var auto_start: bool = true

var spawned_count: int = 0
var defeated_count: int = 0
var _active_enemies: Dictionary[int, BasicEnemy] = {}
var _started: bool = false
var _stopped: bool = false

@onready var start_timer: Timer = $StartTimer
@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	if auto_start:
		start_timer.start()


func get_active_count() -> int:
	return _active_enemies.size()


func start_wave() -> void:
	if _started or _stopped:
		return
	_started = true
	start_timer.stop()
	_spawn_next_enemy()
	if not _stopped and spawned_count < wave_size:
		spawn_timer.start()


func stop_spawning() -> void:
	_stopped = true
	start_timer.stop()
	spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	_spawn_next_enemy()


func _spawn_next_enemy() -> void:
	if _stopped or spawned_count >= wave_size:
		spawn_timer.stop()
		return
	if not is_instance_valid(mother_core) or mother_core.health <= 0:
		stop_spawning()
		return
	if not is_instance_valid(enemy_container) or not is_instance_valid(spawn_points):
		stop_spawning()
		return
	if enemy_scene == null or spawn_points.get_child_count() == 0:
		stop_spawning()
		return

	var point := spawn_points.get_child(spawned_count % spawn_points.get_child_count()) as Node2D
	if point == null:
		stop_spawning()
		return
	var instance := enemy_scene.instantiate()
	if not instance is BasicEnemy:
		instance.free()
		stop_spawning()
		return

	var enemy := instance as BasicEnemy
	enemy.mother_core = mother_core
	var enemy_id := enemy.get_instance_id()
	_active_enemies[enemy_id] = enemy
	enemy.died.connect(_on_enemy_died)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy_id))
	enemy_container.add_child(enemy)
	enemy.global_position = point.global_position
	spawned_count += 1
	if spawned_count >= wave_size:
		spawn_timer.stop()
	_emit_wave_changed()


func _on_enemy_died(enemy: BasicEnemy) -> void:
	var enemy_id := enemy.get_instance_id()
	if not _active_enemies.has(enemy_id):
		return
	_active_enemies.erase(enemy_id)
	defeated_count += 1
	_emit_wave_changed()
	if defeated_count == wave_size:
		wave_finished.emit()


func _on_enemy_removed(enemy_id: int) -> void:
	if _active_enemies.has(enemy_id):
		_active_enemies.erase(enemy_id)
		_emit_wave_changed()


func _emit_wave_changed() -> void:
	wave_changed.emit(spawned_count, defeated_count, get_active_count(), wave_size)
