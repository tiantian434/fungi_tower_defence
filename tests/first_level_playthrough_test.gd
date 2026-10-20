extends SceneTree
## 正常规则首关路线：只调用玩家可用的生长、建造和改装；不注入伤害、营养或生命。
## 省略隐藏观察面板刷新，保留所有运输、成长、敌人和弹丸处理。它不替代真人首次试玩。

const LEVEL: PackedScene = preload("res://scenes/levels/first_level.tscn")
const LEFT: Vector2 = Vector2(330, 395)
const RIGHT: Vector2 = Vector2(925, 390)

class QuietFirstLevel:
	extends FirstLevel
	func _refresh_formal_hud() -> void:
		pass

var level: FirstLevel
var failures: Array[String] = []
var _last_sample: float = 0.0
var _piercing_started: bool = false
var _scatter_started: bool = false
var _completed_upgrades: Array[int] = []


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "res://.artifact_work/first-playthrough-audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0
		elif node is GameDisplayManager:
			node.preferences_path = "res://.artifact_work/first-playthrough-display.cfg"
		elif node is CampaignNavigator:
			node.progress_store = CampaignProgressStore.new("res://.artifact_work/first-playthrough-progress.cfg"))
	_run.call_deferred()


func _frames(count: int = 1) -> void:
	for _index: int in range(count):
		await physics_frame
		await process_frame
		if is_instance_valid(level) and level.elapsed_seconds >= _last_sample + 30.0:
			_last_sample = level.elapsed_seconds
			print("FIRST_LEVEL_ROUTE_SAMPLE ", JSON.stringify(_summary()))


func _run() -> void:
	level = LEVEL.instantiate() as FirstLevel
	var exported: Dictionary = {}
	for property: Dictionary in level.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_STORAGE:
			exported[property.name] = level.get(property.name)
	level.set_script(QuietFirstLevel)
	for property_name: String in exported:
		level.set(property_name, exported[property_name])
	root.add_child(level)
	current_scene = level
	await _frames(3)
	level.differentiation_system.organ_differentiated.connect(func(_task: int, _organ: AttackOrgan, direction: int) -> void:
		_completed_upgrades.append(direction))
	level.growth_input_controller.enter_placement_mode()
	_check(level.growth_input_controller.place_target(LEFT), "paid route reaches the first resource")
	while level.colony_progress.get_total_recovered() < 60 and level.elapsed_seconds < 90:
		await _frames()
	_check(level.colony_progress.get_total_recovered() == 60, "first resource opens the second worker through real returned products")
	_check(not level.colony_capabilities.can_differentiate_attack_organs(), "the opening does not unlock all capabilities before battle")
	_check(level.start_next_wave(), "player starts the first encounter after the first recovery")
	var host := _host_near(LEFT)
	level.choose_organ(&"attack")
	level.cultivation_input_controller.select_node(host)
	_check(host != null and level.cultivation_input_controller.request_cultivation(), "C builds on the existing left flower")
	level.cultivation_input_controller.enter_remote_placement_mode()
	_check(level.cultivation_input_controller.place_remote_target(RIGHT), "B grows a protected second-resource frontier")
	while level.get_result_snapshot().is_empty() and level.elapsed_seconds < 360:
		_try_specialize()
		await _frames()
	await _frames(3)
	var result: Dictionary = level.get_result_snapshot()
	_check(bool(result.get("victory", false)), "real-resource growth, construction and upgrades win the complete first chapter")
	_check(int(result.get("completed_waves", 0)) == FirstLevelFlow.WAVE_TOTAL, "all three encounters were cleared")
	_check(int(result.get("total_defeated", 0)) == level.wave_flow.get_planned_total(), "all configured enemies died through real combat")
	_check(bool(result.get("resources", {}).get("balanced", false)), "every consumed or recovered resource reconciles at victory")
	_check(_piercing_started and _scatter_started, "the route actually uses both unlocked upgrade behaviours")
	_check(_completed_upgrades.has(WeaponProfile.DamageType.ARMOR_PIERCING) \
			and _completed_upgrades.has(WeaponProfile.DamageType.SCATTER), "both upgrades complete through their real paid supply")
	print("FIRST_LEVEL_PLAYTHROUGH_RESULT ", JSON.stringify({"failures": failures, "route": _summary(),
		"actions": "G left; start; C left; B right; J starting left; K starting right; no maintenance or granted resources"}))
	level.queue_free()
	await _frames(3)
	quit(0 if failures.is_empty() else 1)


func _host_near(point: Vector2) -> HyphaNode:
	for host: Node2D in level.network_system.get_registered_nodes():
		if host is HyphaNode and host.is_functional() and host.global_position.distance_to(point) <= CultivationInputController.OVERLAP_RADIUS:
			return host as HyphaNode
	return null


func _try_specialize() -> void:
	if not level.colony_capabilities.can_differentiate_attack_organs() or level.differentiation_system.has_active_task():
		return
	var input := level.differentiation_input_controller
	if not _piercing_started:
		input.select_node(level.get_node("World/Colony/Nodes/HyphaNode") as HyphaNode)
		_piercing_started = input.request_start(WeaponProfile.DamageType.ARMOR_PIERCING)
	elif not _scatter_started:
		input.select_node(level.get_node("World/Colony/Nodes/RightNode") as HyphaNode)
		_scatter_started = input.request_start(WeaponProfile.DamageType.SCATTER)


func _summary() -> Dictionary:
	return {"elapsed": level.elapsed_seconds, "core": level.mother_core.health,
		"capital": level.mother_core.nutrition, "recovered": level.colony_progress.get_total_recovered(),
		"completed_upgrades": _completed_upgrades,
		"weapons": level.get_weapons().size(), "flow": level.wave_flow.get_snapshot(),
		"result": level.get_result_snapshot()}


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
