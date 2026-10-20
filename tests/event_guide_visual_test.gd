extends SceneTree
## 教学卡的真实渲染夹具；直接发教学事件，只验证排版，不作为通关或资源链证据。

var level: FirstLevel
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "user://event_guide_visual_audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	level = load("res://scenes/levels/first_level.tscn").instantiate() as FirstLevel
	root.add_child(level)
	current_scene = level
	await _frames(4)
	level.pause_controller.set_paused(true)
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = dimensions
		for stage_name: String in ["起笔", "铺展", "成形"]:
			level.first_guide.reset()
			if stage_name == "起笔": level.first_guide.record_event(&"opening")
			else: level.first_guide.record_event(&"stage_unlocked", {"stage_name": stage_name})
			await _frames(8)
			var card: EventGuideCard = level.compact_hud._guide_card
			_check(root.get_visible_rect().encloses(card.get_global_rect()), "card remains on screen %s %s" % [dimensions, stage_name])
			_check(card.get_global_rect().encloses(card.message_label.get_global_rect()), "full message fits the card %s %s" % [dimensions, stage_name])
			_check(not card.get_global_rect().intersects(level.compact_hud._toast.get_global_rect()), "ordinary notice stays below the guide %s %s" % [dimensions, stage_name])
			if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var filename: String = "guide_%dx%d_%s.png" % [dimensions.x, dimensions.y, stage_name]
				_check(root.get_texture().get_image().save_png(capture_dir.path_join(filename)) == OK, "saved " + filename)
	level.queue_free()
	await _frames(3)
	print("EVENT_GUIDE_VISUAL_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for frame: int in count: await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
