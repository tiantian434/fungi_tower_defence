extends SceneTree
## 定向教学夹具：移动一座现有炮台并发出实际成熟信号，仅验证展示与优先目标操作。
## 不注入资源或伤害，也不作为正常建设/通关路线证据。

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "res://.artifact_work/release-guidance-audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0
		elif node is GameDisplayManager:
			node.preferences_path = "res://.artifact_work/release-guidance-display.cfg")
	_run.call_deferred()


func _run() -> void:
	for development: bool in [false, true]:
		var first := load(CampaignNavigator.LEVEL_SCENES[0]).instantiate() as FirstLevel
		first.development_shortcuts_enabled = development
		root.add_child(first)
		await _frames(3)
		_check(_labels_contain(first.compact_hud.pages[&"help"], "F5–F10") == development,
			"manual shows development hotkeys only when explicitly enabled: " + str(development))
		first.queue_free()
		await _frames(3)
	var level := load(CampaignNavigator.LEVEL_SCENES[1]).instantiate() as SecondLevel
	root.add_child(level)
	await _frames(3)
	level.wave_flow.stop(&"guidance_fixture")
	_check(String(level.first_guide.get_snapshot().text).contains("点击评价终端集中火力"),
		"opening explains the priority click after frontline construction")
	_check(_labels_contain(level.compact_hud.pages[&"help"], "再次点击取消优先"),
		"manual retains priority cancellation instructions")
	var host := level.get_node("World/Colony/Nodes/LeftGuard") as HyphaNode
	var organ := host.get_node("AttackOrgan") as AttackOrgan
	var weapon := host.get_node("SporeWeapon") as SporeWeapon
	level.cultivation_system.organ_matured.emit(0, host, organ, weapon)
	_check(not level._frontline_tutorial_shown, "rear turret cannot prematurely show the frontline lesson")
	var target: AIFacility = level.get_facility_targets()[0]
	host.global_position = target.global_position + Vector2(0, 100)
	level.first_guide.record_event(&"stage_unlocked", {"stage_name": "成形"})
	var capital_before: int = level.mother_core.nutrition
	level.construction_coordinator.organ_matured.emit("fixture-frontline", host, organ, weapon)
	var guide: Dictionary = level.first_guide.get_snapshot()
	_check(guide.current_event == &"frontline_ready" and guide.visible,
		"actual maturation signal immediately presents the actionable frontline lesson")
	_check(level.compact_hud._guide_card.is_visible_in_tree()
		and level.compact_hud._guide_card.message_label.text.contains("点击终端集中火力"),
		"frontline lesson is directly visible on the ordinary HUD")
	_check(level.compact_hud._history[0].contains(target.display_name),
		"completion notice identifies the terminal reached by the new turret")
	_check(level.mother_core.nutrition == capital_before, "tutorial presentation never pays or grants gameplay resources")
	level.first_guide.dismiss_current()
	level.cultivation_system.organ_matured.emit(2, host, organ, weapon)
	_check(level.first_guide.get_snapshot().current_event != &"frontline_ready",
		"later mature turrets do not repeat the completed first-frontline lesson")
	_click(level.get_canvas_transform() * (target.global_position + Vector2(0, -30)))
	await _frames(2)
	_check(level.combat_targeting_system.get_priority_target() == target,
		"following the lesson with a real terminal click sets concentrated fire")
	_click(level.get_canvas_transform() * (target.global_position + Vector2(0, -30)))
	await _frames(2)
	_check(level.combat_targeting_system.get_priority_target() == null,
		"clicking again restores automatic target selection")
	var audio: GameAudio = GameAudio.find_for(level)
	var music: GameMusic = audio.get_node("Music")
	var audio_ref: WeakRef = weakref(audio)
	var playback_ref: WeakRef = _music_playback_reference(music)
	level.queue_free()
	await _frames(3)
	_check(audio_ref.get_ref() == null, "fixture disposal frees its scene-owned audio service")
	# MP3 解码器由混音线程异步释放；等待实际释放，避免把测试进程退出误报为关卡泄漏。
	for frame: int in range(120):
		if _reference_is_released(playback_ref):
			break
		await _frames(1)
	_check(_reference_is_released(playback_ref), "fixture disposal releases the battle MP3 playback before test exit")
	print("RELEASE_GUIDANCE_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _labels_contain(node: Node, snippet: String) -> bool:
	for label: Label in node.find_children("*", "Label", true, false):
		if label.text.contains(snippet):
			return true
	return false


func _music_playback_reference(music: GameMusic) -> WeakRef:
	# 单独的调用栈立即释放 get_stream_playback() 的临时强引用；协程只保留弱引用。
	var playback: AudioStreamPlayback = music._current.player.get_stream_playback()
	return weakref(playback) as WeakRef


func _reference_is_released(reference: WeakRef) -> bool:
	# 在这个短调用结束后释放观察用的临时引用，不跨 await 持有正在检查的对象。
	return reference.get_ref() == null


func _frames(count: int) -> void:
	for frame: int in count:
		# 与音乐集成验收一致，给音频线程完成停止的时间，避免只空转几个渲染帧就退出。
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
