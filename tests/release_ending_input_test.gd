extends SceneTree
## 终局交互夹具：目标移到真实连通区触发结算，以真实鼠标/键盘验证回顾、成画、CG、结算和回看。
## 不代表正常关卡通关；不注入胜利信号或直接调用按钮回调。

var checks: int = 0
var failures: Array[String] = []
var capture_dir: String = ""


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "res://.artifact_work/ending-input-audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0
		elif node is GameDisplayManager:
			node.preferences_path = "res://.artifact_work/ending-input-display.cfg"
		elif node is CampaignNavigator:
			node.progress_store = CampaignProgressStore.new("res://.artifact_work/ending-input-progress.cfg"))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	var navigator: CampaignNavigator = CampaignNavigator.ensure(self)
	navigator.progress_store.start_new_game()
	navigator.progress_store.record_victory(1)
	navigator.progress_store.record_victory(2)
	navigator.active_run = true
	change_scene_to_file(CampaignNavigator.LEVEL_SCENES[2])
	await _frames(5)
	var level: ThirdLevel = current_scene as ThirdLevel
	var fragment_texts: Array[String] = []
	level.fragment_collection.set_process(false)
	for fragment: MemoryFragment in level.get_fragment_targets():
		fragment_texts.append(fragment.memory_text)
		fragment.global_position = level.mother_core.global_position
	level.fungal_field.advance(1)
	level.fragment_collection._process(5)
	await _frames(5)
	var ending: ColonyEndingView = level.flow_hud.ending_view
	_check(bool(level.get_result_snapshot().get("victory", false)), "real collection controller reaches terminal victory")
	_check(ending.visible and ending.painting_button.is_visible_in_tree(), "recap and its next action remain visible after ordinary HUD closes")
	for index: int in fragment_texts.size():
		_check((ending.memories.get_child(index).get_node("Text") as Label).text == fragment_texts[index], "memory %d is fully retained in recap" % index)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(7)
		_check(root.get_visible_rect().encloses(ending.painting_button.get_global_rect()), "recap next button is reachable at %s" % dimensions)
		_check(root.get_visible_rect().encloses(ending.recap_scroll.get_global_rect()), "recap scroll remains on screen at %s" % dimensions)
		_check(not ending.recap_scroll.get_global_rect().intersects(ending.painting_button.get_global_rect()), "recap keeps its primary action outside scrolling text at %s" % dimensions)
		await _capture("memories_%dx%d" % [dimensions.x, dimensions.y])
	# 长文本只用于检查布局韧性；正式剧情仍保留原有三段文字。
	var first_memory: Label = ending.memories.get_child(0).get_node("Text")
	first_memory.text = fragment_texts[0].repeat(25)
	await _frames(6)
	_check(ending.recap_scroll.scroll_vertical == 0, "long recap begins with the first memory rather than the final action")
	var primary_position: Vector2 = ending.painting_button.global_position
	ending.recap_scroll.scroll_vertical = 10000
	await _frames(3)
	_check(ending.recap_scroll.scroll_vertical > 0 and ending.painting_button.global_position == primary_position,
		"reading long memories never moves the continuation button")
	first_memory.text = fragment_texts[0]
	ending.recap_scroll.scroll_vertical = 0
	await _frames(3)
	_click(ending.painting_button.get_global_rect().get_center())
	await _frames(80)
	_check(ending.showcase.is_visible_in_tree() and not ending.recap.visible, "actual recap click opens the player's painting")
	_check(ending.ending_button.is_visible_in_tree() and root.get_visible_rect().encloses(ending.ending_button.get_global_rect()), "painting continuation has an on-screen button")
	_check(level.get_node("World/Colony").is_visible_in_tree() and not level.get_node("World/Enemies").visible, "showcase retains the actual network and removes combat clutter")
	_check(root.get_visible_rect().encloses(level.get_canvas_transform() * level.get_painting_bounds()), "showcase camera fits the actual network")
	await _capture("painting")
	var frozen: Dictionary = level.get_level_snapshot()
	_click(ending.ending_button.get_global_rect().get_center())
	await _frames(4)
	_check(get_nodes_in_group("story_players").size() == 1 and not ending.visible, "actual painting continuation opens exactly one ending CG")
	_key(KEY_ESCAPE)
	await _frames(5)
	_check(level.flow_hud.result_panel.is_visible_in_tree() and get_nodes_in_group("story_players").is_empty(), "CG skip reaches the visible summary with no blocking overlay")
	_check(navigator.progress_store.has_seen_story(4), "ending story status persists when the player finishes or skips")
	await _capture("summary")
	_click(level.flow_hud.result_continue_button.get_global_rect().get_center())
	await _frames(5)
	_check(ending.showcase.is_visible_in_tree() and ending.summary_button.is_visible_in_tree(), "actual summary click reopens this painting")
	_key(KEY_ESCAPE)
	await _frames(5)
	_check(level.flow_hud.result_panel.is_visible_in_tree() and not ending.visible, "Escape returns from painting replay to summary")
	_check(level.elapsed_seconds == frozen.elapsed_seconds and level.fragment_collection.get_snapshot() == frozen.fragments, "ending navigation never resumes the simulation")
	_click(level.compact_hud.level_menu.result_title_button.get_global_rect().get_center())
	await _frames(6)
	_check(current_scene is MainMenu and not paused, "summary returns to title without a remaining ending overlay or pause")
	_check(current_scene.progress_label.text.contains("已通关"), "title exposes the completed campaign")
	print("RELEASE_ENDING_INPUT_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for frame: int in count:
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _capture(filename: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png")) == OK, "saved " + filename)
