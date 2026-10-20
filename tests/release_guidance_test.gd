extends SceneTree
## 首次事件状态机 + 真实付费生长/回流 + 真实 GUI 点击。阶段跨越夹具不代表正常通关。

const LEVEL: PackedScene = preload("res://scenes/levels/first_level.tscn")
var failures: Array[String] = []
var checks: int = 0
var level: FirstLevel
var capture_dir: String = ""


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "user://release_guidance_audio_test.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0
		elif node is GameDisplayManager:
			node.preferences_path = "res://.artifact_work/release-guidance-display.cfg")
	var display := root.get_node_or_null("GameDisplay") as GameDisplayManager
	if display != null:
		display.preferences_path = "res://.artifact_work/release-guidance-display.cfg"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	_test_event_context()
	level = LEVEL.instantiate() as FirstLevel
	root.add_child(level)
	current_scene = level
	await _frames(4)
	var guide: FirstEventGuide = level.first_guide
	var card: EventGuideCard = level.compact_hud._guide_card
	guide.record_event(&"opening")
	await _frames(3)
	_check(card.is_visible_in_tree() and card.message_label.text.contains("按 G"), "opening has a visible actionable guide")
	_check(level.compact_hud.is_pointer_over_ui(card.get_global_rect().get_center()), "guide card blocks clicks reaching the world")
	var lifetime: float = guide.get_snapshot().remaining
	level.pause_controller.set_paused(true)
	await _frames(90)
	_check(is_equal_approx(guide.get_snapshot().remaining, lifetime), "global pause preserves guide reading time")
	_click(card.dismiss_button.get_global_rect().get_center())
	await _frames(2)
	_check(not guide.get_snapshot().visible, "visible dismiss button works during pause")
	level.pause_controller.set_paused(false)
	guide.reset()
	guide.record_event(&"opening")
	_check(level.growth_input_controller.enter_placement_mode(), "real growth planning starts")
	await _frames(2)
	_check(not card.is_visible_in_tree(), "construction preview clears the teaching card from the map")
	var planning_lifetime: float = guide.get_snapshot().remaining
	await _frames(60)
	_check(is_equal_approx(guide.get_snapshot().remaining, planning_lifetime), "construction preview preserves guide reading time")
	_check(level.growth_input_controller.place_target(Vector2(330, 395)), "real paid target is accepted")
	await _frames(3)
	_check(guide.get_snapshot().current_event == &"target_placed", "placing a real target teaches transport")
	_check(card.is_visible_in_tree(), "accepting the target exits preview and restores its actionable context")
	var highest_visible_gain: int = 0
	var expected_return: int = level.get_node("World/Remains/FirstCarcass").total_nutrition
	for frame: int in range(9000):
		await process_frame
		var effect: Dictionary = level.growth_feedback.get_feedback_snapshot()
		if effect.gain_visible: highest_visible_gain = maxi(highest_visible_gain, effect.gain)
		if level.colony_progress.get_total_recovered() >= expected_return: break
	_check(level.colony_progress.get_total_recovered() == expected_return, "original resource is returned through normal transport and digestion")
	_check(highest_visible_gain > 0, "real nutrition return displays a numeric gain")
	_check((guide.get_snapshot().seen as Array).has(&"nutrition_returned"), "real core delivery advances teaching")
	_check((guide.get_snapshot().seen as Array).has(&"stage_unlocked"), "real growth threshold announces the new ability")
	_check(level.get_combat_resource_snapshot().balanced, "presentation effects preserve resource conservation")
	_check(card.message_label.text.contains("两条花径"), "threshold card explains the concrete new behavior")
	level.pause_controller.set_paused(true)
	await _capture("first_return_and_expanded")
	var saved_lifetime: float = guide.get_snapshot().remaining
	level.compact_hud.open_page(&"help")
	await _frames(2)
	_check(not card.is_visible_in_tree(), "open drawer temporarily clears teaching from the world")
	level.pause_controller.set_paused(false)
	await _frames(120)
	_check(is_equal_approx(guide.get_snapshot().remaining, saved_lifetime), "drawer preserves reading time while simulation runs")
	level.compact_hud.close_drawer()
	await _frames(3)
	_check(card.is_visible_in_tree(), "closing drawer restores the same contextual guide")
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = dimensions
		await _frames(6)
		var screen: Rect2 = root.get_visible_rect()
		_check(screen.encloses(card.get_global_rect()), "guide stays inside viewport at %s" % dimensions)
		_check(not card.get_global_rect().intersects(level.compact_hud.dock.get_global_rect()), "guide never overlaps build dock at %s" % dimensions)
		await _capture("guide_%dx%d" % [dimensions.x, dimensions.y])
	level.queue_free()
	await _frames(3)
	print("RELEASE_GUIDANCE_RESULT ", JSON.stringify({"checks": checks, "failures": failures,
		"normal_rule_return": expected_return, "visible_gain": highest_visible_gain}))
	quit(0 if failures.is_empty() else 1)


func _test_event_context() -> void:
	var guide := FirstEventGuide.new()
	root.add_child(guide)
	guide.record_event(&"opening")
	guide.record_event(&"target_placed")
	guide.record_event(&"remains_returned")
	guide.record_event(&"nutrition_returned")
	_check(guide.get_snapshot().current_event == &"nutrition_returned" and guide._pending.is_empty(), "new progress replaces obsolete placement and transport instructions")
	guide.record_event(&"stage_unlocked", {"stage": "铺展"})
	guide.record_event(&"stage_unlocked", {"stage_name": "成形"})
	_check(guide.get_snapshot().text.contains("两条花径"), "expanded stage explains dual growth using legacy facts")
	guide.record_event(&"armored")
	guide.record_event(&"network_broken")
	_check(guide.get_snapshot().current_event == &"network_broken", "urgent connection loss preempts an older ability lesson")
	guide.dismiss_current()
	_check(guide.get_snapshot().text.contains("两条花径"), "preempted lesson keeps its full snapshot instead of an emptied dictionary")
	guide.dismiss_current()
	_check(guide.get_snapshot().text.contains("炮台改装"), "mature stage announces independently from expanded stage")
	guide.advance(30.0)
	_check(not guide.get_snapshot().visible, "teaching automatically advances without opening help")
	guide.record_event(&"differentiated")
	var before: Dictionary = guide.get_snapshot()
	guide.record_event(&"stage_unlocked", {"stage_name": "成形"})
	_check(guide.get_snapshot().current_key == before.current_key and guide._pending.is_empty(), "repeat stage events never replay or disturb the current context")
	guide.reset()
	guide.set_enabled(false)
	guide.record_event(&"differentiated")
	guide.set_enabled(true)
	_check(not guide.get_snapshot().visible, "disabled teaching does not queue historical notices")
	guide.free()
	var busy_guide := SecondLevelGuide.new()
	root.add_child(busy_guide)
	busy_guide.record_event(&"stage_unlocked", {"stage_name": "铺展"})
	for event_id: StringName in [&"armored", &"swarm", &"silk_gnawer", &"junction_gnawer"]:
		busy_guide.record_event(event_id)
	busy_guide.record_event(&"network_broken")
	busy_guide.record_event(&"stage_unlocked", {"stage_name": "成形"})
	busy_guide.dismiss_current()
	_check(busy_guide.get_snapshot().text.contains("两条花径"), "busy enemy burst cannot discard the earlier ability lesson")
	busy_guide.dismiss_current()
	_check(busy_guide.get_snapshot().text.contains("炮台改装"), "both stage lessons survive a full danger queue in chronological order")
	busy_guide.free()


func _capture(filename: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png")) == OK, "captured " + filename)


func _frames(count: int) -> void:
	for index: int in count: await process_frame


func _click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
