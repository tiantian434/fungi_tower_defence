extends SceneTree
## 真实场景验证：覆盖边界、失联与重叠、新菌结接入、路径和资源唯一结算。

const LEVEL: PackedScene = preload("res://scenes/levels/level_01.tscn")
const NODE: PackedScene = preload("res://scenes/colony/hypha_node.tscn")
const EDGE: PackedScene = preload("res://scenes/colony/hypha_edge.tscn")
const REMAINS: PackedScene = preload("res://scenes/recycling/enemy_remains.tscn")

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1200, 800)
	await _test_boundary_and_local_collection()
	await _test_disconnect_overlap_and_recovery()
	await _test_new_patch_and_multisegment_transport()
	await _test_alternative_path_and_interruption()
	await _test_input_and_restart()
	print("FUNGAL_FIELD_TEST_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _new_level() -> Node2D:
	var level := LEVEL.instantiate() as Node2D
	level.get_node("Systems/EnemySpawner").auto_start = false
	root.add_child(level)
	current_scene = level
	level.supply_system.get_node("DispatchTimer").stop()
	level.weapon.get_node("FireTimer").stop()
	level.recycling_system.get_node("DispatchTimer").stop()
	await physics_frame
	await process_frame
	return level


func _remove_level(level: Node2D) -> void:
	level.queue_free()
	await process_frame
	await process_frame


func _add_remains(level: Node2D, point: Vector2) -> EnemyRemains:
	var remains := REMAINS.instantiate() as EnemyRemains
	level.get_node("World/Remains").add_child(remains)
	remains.global_position = point
	return remains


func _wait_for_delivery(level: Node2D) -> void:
	for frame in range(900):
		if level.recycling_system.get_in_transit_count() == 0:
			break
		await physics_frame
	await process_frame
	await process_frame
	_check(level.recycling_system.get_in_transit_count() == 0, "Shipment timed out")
	_check(level.get_node("World/RecoveryPackets").get_child_count() == 0, "Finished packet remained")


func _test_boundary_and_local_collection() -> void:
	var level := await _new_level()
	var field: FungalField = level.fungal_field
	var front: Node2D = level.attack_organ.get_parent()
	var point := front.global_position
	_check(field.is_covered(point + Vector2(319, 0)), "Inside horizontal boundary was excluded")
	_check(not field.is_covered(point + Vector2(321, 0)), "Outside horizontal boundary was included")
	_check(field.is_covered(point - Vector2(0, 223)), "Inside ellipse's vertical boundary was excluded")
	_check(not field.is_covered(point - Vector2(0, 225)), "Ellipse was incorrectly treated as a circle")
	var outside := _add_remains(level, point + Vector2(350, 0))
	_check(not level.recycling_system.try_dispatch(), "Outside corpse was collected")
	_check(outside.visible and outside.is_available(), "Outside corpse did not remain waiting")
	_check(level.digestive_organ.incoming_remains == 0, "Outside corpse reserved digestive capacity")
	var rear: Node2D = level.digestive_organ.get_parent()
	var local := _add_remains(level, rear.global_position + Vector2(0, 20))
	_check(field.get_nearest_collector(local.global_position) == rear, "Nearest collector was not selected")
	level.digestive_organ.digest_timer.wait_time = 5.0
	_check(level.recycling_system.try_dispatch(), "Local digestive-node pickup failed")
	_check(not level.recycling_system.try_dispatch(), "Same corpse was claimed twice")
	_check(level.mother_core.nutrition == 72, "Pickup credited nutrition early")
	await _wait_for_delivery(level)
	_check(not is_instance_valid(local) and outside.is_available(), "Local collection removed wrong corpse")
	_check(level.digestive_organ.get_queued_count() == 1, "Zero-edge delivery did not enter digestion")
	_check(level.mother_core.nutrition == 72, "Zero-edge route bypassed digestion")
	# 场景整体平移和缩放后，显示坐标与判定坐标仍属于同一地面空间。
	level.get_node("World").position = Vector2(31, 17)
	level.get_node("World").scale = Vector2(0.85, 0.85)
	field.refresh(0.0)
	point = field.to_local(front.global_position)
	_check(field.is_covered(field.to_global(point + Vector2(319, 0))), "Transform moved coverage off its visual")
	_check(not field.is_covered(field.to_global(point + Vector2(321, 0))), "Transform expanded logical boundary")
	await _remove_level(level)


func _test_disconnect_overlap_and_recovery() -> void:
	var level := await _new_level()
	var field: FungalField = level.fungal_field
	field.set_physics_process(false)
	var front: Node2D = level.attack_organ.get_parent()
	var patch := front.get_node("FungalPatch") as FungalPatch
	patch.disconnect_grace_seconds = 0.5
	patch.recession_seconds = 1.0
	var return_edge := level.get_node("World/Colony/Connections/RecoveryEdge") as HyphaEdge
	level.supply_system.supply_edge.enabled = false
	return_edge.enabled = false
	_check(not field.is_covered(front.global_position), "Severed node collected before visual refresh")
	field.refresh(0.0)
	_check(not patch.connected and is_equal_approx(patch.growth, 1.0), "Disconnection skipped grace period")
	_check(level.hud.field_label.text.contains("2 / 3"), "HUD did not show disconnected region")
	_check(field.is_covered(Vector2(600, 466)), "Offline patch erased overlapping live coverage")
	var remains := _add_remains(level, front.global_position)
	_check(not level.recycling_system.try_dispatch() and remains.is_available(), "Offline field collected corpse")
	field.refresh(0.4)
	_check(is_equal_approx(patch.growth, 1.0), "Field shrank during grace period")
	field.refresh(0.6)
	_check(is_equal_approx(patch.growth, 0.5), "Recession counted grace time as shrink time")
	field.refresh(0.5)
	_check(is_zero_approx(patch.growth), "Offline field failed to disappear")
	return_edge.enabled = true
	field.refresh(0.0)
	_check(patch.connected and is_zero_approx(patch.growth), "Reconnection instantly restored full field")
	_check(not field.is_covered(front.global_position), "Zero-radius field collected resource")
	field.refresh(0.75)
	_check(is_equal_approx(patch.growth, 0.5), "Reconnection failed to unfold progressively")
	_check(field.is_covered(front.global_position), "Restored field did not become active")
	_check(level.recycling_system.try_dispatch(), "Reconnected patch could not collect waiting corpse")
	await _wait_for_delivery(level)
	_check(level.recycling_system.delivered_count == 1, "Recovery duplicated delivery")
	await _remove_level(level)


func _test_new_patch_and_multisegment_transport() -> void:
	var level := await _new_level()
	var front: Node2D = level.attack_organ.get_parent()
	var node := NODE.instantiate() as HyphaNode
	(node.get_node("FungalPatch") as FungalPatch).initial_growth = 0.0
	level.hypha_nodes.add_child(node)
	node.position = Vector2(930, 350)
	var connection := EDGE.instantiate() as HyphaEdge
	connection.start_node = front
	connection.end_node = node
	level.get_node("World/Colony/Connections").add_child(connection)
	var remains := _add_remains(level, node.global_position + Vector2(60, 0))
	level.fungal_field.refresh(0.0)
	_check(not level.recycling_system.try_dispatch(), "Unexpanded field collected early")
	level.fungal_field.refresh(0.9)
	_check(level.fungal_field.get_nearest_collector(remains.global_position) == node,
		"New connected node did not add coverage")
	var path: Array[HyphaEdge] = level.network.find_path(node, level.digestive_organ.get_parent())
	_check(path.size() == 2 and path[0] == connection, "Path did not start with new connecting edge")
	level.digestive_organ.digest_timer.wait_time = 20.0
	_check(level.recycling_system.try_dispatch(), "Expanded field failed to collect waiting corpse")
	_check(not level.recycling_system.try_dispatch(), "Overlapping sources duplicated pickup")
	var packet := level.get_node("World/RecoveryPackets").get_child(0) as RemainsPacket
	var initial_distance := packet.global_position.distance_to(node.global_position)
	for frame in range(12):
		await physics_frame
	_check(packet.global_position.distance_to(node.global_position) < initial_distance,
		"Corpse bypassed nearest collector")
	await _wait_for_delivery(level)
	_check(level.digestive_organ.get_queued_count() == 1 and level.digestive_organ.incoming_remains == 0,
		"Multisegment route lost storage or reservation")
	_check(level.mother_core.nutrition == 72, "Multisegment route credited early income")
	node.queue_free()
	level.fungal_field.refresh(0.0)
	_check(not level.fungal_field.is_covered(Vector2(990, 350)), "Queued-for-deletion node still provided coverage")
	await _remove_level(level)


func _test_alternative_path_and_interruption() -> void:
	var level := await _new_level()
	var front: Node2D = level.attack_organ.get_parent()
	var return_edge := level.get_node("World/Colony/Connections/RecoveryEdge") as HyphaEdge
	return_edge.enabled = false
	var path: Array[HyphaEdge] = level.network.find_path(front, level.digestive_organ.get_parent())
	_check(path.size() == 2, "Cycle did not provide alternative route at dispatch")
	_check(level.network.get_connected_nodes().size() == 3, "Single broken edge disconnected a loop")
	var remains := _add_remains(level, front.global_position)
	_check(level.recycling_system.try_dispatch(), "Available alternative route was ignored")
	for frame in range(12):
		await physics_frame
	var packet := level.get_node("World/RecoveryPackets").get_child(0) as RemainsPacket
	var drop_position := packet.global_position
	level.supply_system.supply_edge.enabled = false
	await _wait_for_delivery(level)
	_check(remains.visible and remains.is_available(), "Interrupted route lost corpse")
	_check(remains.global_position.distance_to(drop_position) < 0.01, "Interrupted corpse dropped at wrong location")
	_check(level.digestive_organ.incoming_remains == 0 and level.mother_core.nutrition == 72,
		"Interrupted route leaked capacity or nutrition")
	return_edge.enabled = true
	level.fungal_field.refresh(0.0)
	_check(level.recycling_system.try_dispatch(), "Restored route failed to recover dropped corpse")
	await _wait_for_delivery(level)
	_check(level.recycling_system.interrupted_count == 1 and level.recycling_system.delivered_count == 1,
		"Interrupted and resumed route settled more than once")
	await _remove_level(level)


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	root.push_input(event)


func _test_input_and_restart() -> void:
	var level := await _new_level()
	_press_key(KEY_C)
	_check(not level.supply_system.supply_edge.enabled, "C did not disconnect frontline")
	_check(not level.fungal_field.is_covered(level.attack_organ.global_position), "C left field active")
	_check(not level.supply_system.request_supply(), "Disabled supply edge dispatched nutrition")
	_press_key(KEY_C)
	_check(level.supply_system.supply_edge.enabled, "Second C did not restore frontline")
	_check(level.supply_system.request_supply(), "Restored supply failed to dispatch")
	_press_key(KEY_C)
	for frame in range(3):
		await physics_frame
	_check(level.mother_core.nutrition == 72 and level.attack_organ.incoming_nutrition == 0,
		"Disabled edge failed to refund travelling supply")
	_press_key(KEY_R)
	await process_frame
	await process_frame
	await physics_frame
	_check(not is_instance_valid(level), "Restart left old field")
	level = current_scene as Node2D
	level.enemy_spawner.stop_spawning()
	_check(level.network.get_connected_nodes().size() == 3 and level.mother_core.nutrition == 72,
		"Restart preserved disconnection or changed balance")
	_check(level.fungal_field.is_covered(level.attack_organ.global_position), "Restart did not restore field")
	await _remove_level(level)
	_check(root.get_child_count() == 0, "Field scene teardown left orphan nodes")
