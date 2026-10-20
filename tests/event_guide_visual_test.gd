extends SceneTree
## 教学卡的真实渲染夹具；直接发教学事件，只验证排版，不作为通关或资源链证据。

var level: Node2D
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "user://event_guide_visual_audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0
		elif node is GameDisplayManager:
			node.preferences_path = "res://.artifact_work/guide-visual-display.cfg")
	var display := root.get_node_or_null("GameDisplay") as GameDisplayManager
	if display != null:
		display.preferences_path = "res://.artifact_work/guide-visual-display.cfg"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	for chapter: int in range(1, 4):
		level = load(CampaignNavigator.LEVEL_SCENES[chapter - 1]).instantiate() as Node2D
		root.add_child(level)
		current_scene = level
		await _frames(4)
		level.pause_controller.set_paused(true)
		for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(1200, 920)]:
			root.size = dimensions
			var stages: Array[String] = ["起笔"]
			if chapter == 1:
				stages.append_array(["铺展", "成形"])
			for stage_name: String in stages:
				level.first_guide.reset()
				if stage_name == "起笔": level.first_guide.record_event(&"opening")
				else: level.first_guide.record_event(&"stage_unlocked", {"stage_name": stage_name})
				await _frames(8)
				var card: EventGuideCard = level.compact_hud._guide_card
				var context: String = "chapter %d %s %s" % [chapter, dimensions, stage_name]
				_check(root.get_visible_rect().encloses(card.get_global_rect()), "card remains on screen " + context)
				_check(card.get_global_rect().encloses(card.message_label.get_global_rect()), "full message fits the card " + context)
				_check(not card.get_global_rect().intersects(level.compact_hud._toast.get_global_rect()), "ordinary notice stays separate " + context)
				_check(not card.get_global_rect().intersects(level.compact_hud.dock.get_global_rect()), "card clears the construction dock " + context)
				for target: Dictionary in _protected_art():
					_check(not card.get_global_rect().intersects(target.rect), "guide preserves full target artwork: %s %s" % [target.name, context])
				if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var filename: String = "guide_ch%d_%dx%d_%s.png" % [chapter, dimensions.x, dimensions.y, stage_name]
					_check(root.get_texture().get_image().save_png(capture_dir.path_join(filename)) == OK, "saved " + filename)
			level.growth_input_controller.enter_placement_mode()
			await _frames(4)
			_check(not level.compact_hud._guide_card.visible, "construction preview preserves the battlefield at chapter %d %s" % [chapter, dimensions])
			level.growth_input_controller.exit_placement_mode()
			await _frames(4)
			_check(level.compact_hud._guide_card.visible, "closing preview restores contextual teaching at chapter %d %s" % [chapter, dimensions])
		level.queue_free()
		await _frames(3)
	print("EVENT_GUIDE_VISUAL_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _protected_art() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var targets: Array[Node] = [level.mother_core]
	targets.append_array(level.get_node("World/Remains").get_children())
	for target: Node in targets:
		for sprite: Sprite2D in target.find_children("*", "Sprite2D", true, false):
			if sprite.texture != null and sprite.is_visible_in_tree():
				result.append({"name": str(target.name) + "/" + str(sprite.name),
					"rect": sprite.get_global_transform_with_canvas() * sprite.get_rect()})
	if level.has_method("get_fragment_targets"):
		for fragment: MemoryFragment in level.get_fragment_targets():
			# 保护整张记忆纸页和外圈，不能只检查其世界锚点。
			result.append({"name": str(fragment.name),
				"rect": fragment.get_global_transform_with_canvas() * Rect2(-44, -44, 88, 88)})
	return result


func _frames(count: int) -> void:
	for frame: int in count: await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
