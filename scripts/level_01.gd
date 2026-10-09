extends Node2D
## 关卡只协调输入与信号；库存、运输和界面各自管理自己的职责。

@onready var mother_core: MotherCore = $World/Colony/MotherCore
@onready var hypha_nodes: Node2D = $World/Colony/Nodes
@onready var attack_organ: AttackOrgan = $World/Colony/Nodes/HyphaNode/AttackOrgan
@onready var weapon: SporeWeapon = $World/Colony/Nodes/HyphaNode/SporeWeapon
@onready var supply_system: SupplySystem = $Systems/SupplySystem
@onready var enemy_spawner: EnemySpawner = $Systems/EnemySpawner
@onready var recovery_organ: RecoveryOrgan = $World/Colony/Nodes/HyphaNode/RecoveryOrgan
@onready var digestive_organ: DigestiveOrgan = $World/Colony/Nodes/RearNode/DigestiveOrgan
@onready var recycling_system: RecyclingSystem = $Systems/RecyclingSystem
@onready var hud: ColonyHUD = $HUD

var selected_node: HyphaNode = null


func _ready() -> void:
	mother_core.depleted.connect(_on_mother_core_depleted)
	mother_core.nutrition_changed.connect(hud.show_core_nutrition)
	attack_organ.inventory_changed.connect(hud.show_organ_inventory)
	attack_organ.selection_requested.connect(_on_organ_selection_requested)
	supply_system.transport_changed.connect(hud.show_transport)
	supply_system.notice.connect(hud.show_notice)
	enemy_spawner.wave_changed.connect(hud.show_battle)
	enemy_spawner.wave_finished.connect(_on_wave_finished)
	recovery_organ.selection_requested.connect(_on_recovery_selection_requested)
	digestive_organ.selection_requested.connect(_on_digestive_selection_requested)
	recycling_system.recycling_changed.connect(hud.show_recycling)
	digestive_organ.inventory_changed.connect(hud.show_digestion)
	digestive_organ.digested.connect(_on_remains_digested)
	for child in hypha_nodes.get_children():
		if child is HyphaNode:
			child.selection_requested.connect(_select_node)

	hud.show_core_nutrition(mother_core.nutrition)
	hud.show_organ_inventory(
		attack_organ.nutrition, attack_organ.incoming_nutrition, attack_organ.capacity
	)
	hud.show_transport(supply_system.get_in_transit_count(), 0, 0)
	hud.show_battle(0, 0, 0, enemy_spawner.wave_size)
	hud.show_recycling(0, 0, 0)
	hud.show_digestion(digestive_organ.get_queued_count(), digestive_organ.incoming_remains)
	hud.show_recovery_totals(digestive_organ.digested_count, digestive_organ.total_nutrition_produced)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		_select_node(null)
	elif event.is_action_pressed("debug_damage_core"):
		mother_core.take_damage(30)
	elif event.is_action_pressed("request_supply"):
		supply_system.request_supply()
	elif event.is_action_pressed("debug_consume_nutrition"):
		if attack_organ.consume_nutrition():
			hud.show_notice("器官消耗 1 点营养；库存不足时会自动补给")
		else:
			hud.show_notice("器官库存为空，等待供养")
	elif event.is_action_pressed("restart_level"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _select_node(node: HyphaNode) -> void:
	if is_instance_valid(selected_node):
		selected_node.set_selected(false)

	selected_node = node
	if is_instance_valid(selected_node):
		selected_node.set_selected(true)
		hud.show_selection(selected_node.display_name)
	else:
		hud.show_selection("")
	weapon.set_range_visible(selected_node == attack_organ.get_parent())


func _on_organ_selection_requested() -> void:
	_select_node(attack_organ.get_parent() as HyphaNode)


func _on_mother_core_depleted() -> void:
	enemy_spawner.stop_spawning()
	$World.process_mode = Node.PROCESS_MODE_DISABLED
	supply_system.process_mode = Node.PROCESS_MODE_DISABLED
	recycling_system.process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_battle_result(false)
	hud.show_notice("母核生命值归零；按 R 重新开始")


func _on_wave_finished() -> void:
	if mother_core.health > 0:
		hud.show_battle_result(true)


func _on_recovery_selection_requested() -> void:
	_select_node(recovery_organ.get_parent() as HyphaNode)


func _on_digestive_selection_requested() -> void:
	_select_node(digestive_organ.get_parent() as HyphaNode)


func _on_remains_digested(_nutrition: int) -> void:
	hud.show_recovery_totals(digestive_organ.digested_count, digestive_organ.total_nutrition_produced)
