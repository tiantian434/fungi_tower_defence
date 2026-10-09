class_name MotherCore
extends Node2D

## 母核管理生命值和可用营养。所有余额变化经过这里结算。

signal health_changed(current: int, maximum: int)
signal nutrition_changed(current: int)
signal depleted

@export var max_health: int = 240
@export var initial_nutrition: int = 72

var health: int = 0
var nutrition: int = 0

@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	health = max_health
	nutrition = maxi(initial_nutrition, 0)
	health_bar.max_value = max_health
	_update_health_bar()


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return

	health = maxi(health - amount, 0)
	_update_health_bar()
	health_changed.emit(health, max_health)

	if health == 0:
		depleted.emit()


func try_spend_nutrition(amount: int) -> bool:
	if amount <= 0 or nutrition < amount or health <= 0:
		return false

	nutrition -= amount
	nutrition_changed.emit(nutrition)
	return true


func add_nutrition(amount: int) -> void:
	if amount <= 0:
		return

	nutrition += amount
	nutrition_changed.emit(nutrition)


func _update_health_bar() -> void:
	health_bar.value = health
