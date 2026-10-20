class_name ThirdLevelHUD
extends FirstLevelHUD
## 沿用前两关纯显示层；CG4使用共用图片序列播放器，世界停机后仍可操作。

var _objectives: Dictionary = {}
var _ending_snapshot: Dictionary = {}
var _ending_pending: bool = false
var _ending_panel: StoryPlayer
var ending_view: ColonyEndingView
var _showing_painting: bool = false
var _camera_tween: Tween


func _ready() -> void:
	super._ready()
	continue_requested.connect(_show_painting.bind(true))
	get_viewport().size_changed.connect(_on_ending_view_resized)


func show_objectives(snapshot: Dictionary) -> void:
	_objectives = snapshot.duplicate(true)
	if _ui_ready:
		_render_flow()


func _render_flow() -> void:
	wave_label.text = "第三关 · 自我和解"
	progress_label.text = "收集碎片 %d/3 · 连通花海累计收集5秒" % int(_objectives.get("completed", 0))
	var rows: PackedStringArray = []
	for fragment: Dictionary in _objectives.get("fragments", []):
		rows.append("%s：%s" % [fragment.name, "已收集" if fragment.collected else (
			"收集中" if fragment.collecting else "等待有效覆盖") + " %.1f/%.0fs" % [fragment.progress, fragment.duration]])
	counts_label.text = "\n".join(rows)
	var soonest: float = INF
	for source: Dictionary in _flow_snapshot.get("sources", []):
		soonest = minf(soonest, float(source.remaining))
	next_label.text = "下批来袭约 %ds · 压力阶段 %d/3" % [ceili(soonest), int(_flow_snapshot.get("stage", 0)) + 1] \
		if is_finite(soonest) else "准备探索"
	pause_label.text = "已暂停 · 收集、生成与运输冻结" if _paused else "失联保留进度；灰色花海残影不能收集"
	start_button.text = "提前开始防守"
	start_button.disabled = _paused or _has_result or _ending_pending or not bool(_flow_snapshot.get("can_start", false))
	pause_button.text = "恢复 · Space" if _paused else "暂停 · Space"
	pause_button.disabled = _has_result or _ending_pending
	for label: Label in [wave_label, progress_label, counts_label, next_label, pause_label]:
		label.tooltip_text = label.text


func _render_result() -> void:
	result_panel.visible = _has_result
	if not _has_result:
		return
	var won: bool = bool(_result_snapshot.get("victory", false))
	result_title.text = "自我和解 · 通关" if won else "小画家倒下了 · 本次挑战失败"
	result_subtitle.text = "三个碎片已经完整收集" if won else "保护探索路线，再次出发"
	result_left_label.text = "收集碎片：%d / 3\n累计回收：%d 创作能量" % [
		int(_result_snapshot.get("objective", {}).get("completed", 0)), int(_result_snapshot.get("total_recovered", 0))]
	result_right_label.text = "小画家生命：%s\n本局用时：%s" % [
		_health_text(float(_result_snapshot.get("core_health", 0))), _time_text(float(_result_snapshot.get("elapsed_seconds", 0)))]


func show_ending(snapshot: Dictionary) -> void:
	if _ending_pending or _has_result:
		return
	_ending_pending = true
	_ending_snapshot = snapshot.duplicate(true)
	_render_flow()
	ending_view = preload("res://scenes/ui/colony_ending_view.tscn").instantiate() as ColonyEndingView
	add_child(ending_view)
	ending_view.painting_requested.connect(_show_painting.bind(false))
	ending_view.ending_requested.connect(_open_ending)
	ending_view.summary_requested.connect(_return_to_summary)
	ending_view.show_memories((get_parent() as ThirdLevel).get_fragment_targets())
	# 结算已经冻结敌人、运输和计时；最后一段记忆保留到玩家主动继续。
	(get_parent() as ThirdLevel).prepare_painting_view()
	_zoom_to_painting(false)


func _show_painting(replay: bool) -> void:
	if not is_instance_valid(ending_view):
		return
	_showing_painting = true
	result_panel.hide()
	ending_view.show_painting(replay)
	_zoom_to_painting(true)


func _zoom_to_painting(animated: bool) -> void:
	var level := get_parent() as ThirdLevel
	var camera: ColonyCamera = level.colony_camera
	var frame: Rect2 = level.get_painting_bounds()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var usable: Vector2 = Vector2(viewport_size.x - 100, viewport_size.y - 230)
	var target_zoom: float = clampf(minf(usable.x / frame.size.x, usable.y / frame.size.y), 0.45, 1.0)
	# 下方保留题字空间；让成画居中在剩余区域。
	var target_position: Vector2 = frame.get_center() + Vector2(0, 75.0 / target_zoom)
	if _camera_tween != null:
		_camera_tween.kill()
	if animated:
		_camera_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var start_position: Vector2 = camera.global_position
		var start_zoom: Vector2 = camera.zoom
		_camera_tween.tween_method(func(weight: float) -> void:
			camera.global_position = start_position.lerp(target_position, weight)
			camera.zoom = start_zoom.lerp(Vector2.ONE * target_zoom, weight)
			camera.force_update_scroll()
			level._on_camera_view_changed(), 0.0, 1.0, 1.1)
	else:
		# 回顾卡片期间沿用玩家最后的视野，让拉远动作在点击后发生。
		camera.clear_input_state()


func _on_ending_view_resized() -> void:
	if _showing_painting and is_instance_valid(ending_view) and ending_view.visible:
		_zoom_to_painting(true)


func _open_ending() -> void:
	if not is_inside_tree() or not _ending_pending:
		return
	_showing_painting = false
	ending_view.hide()
	_ending_panel = StoryPlayer.open(self, 4)
	_ending_panel.finished.connect(finish_ending)


func finish_ending() -> void:
	if not _ending_pending:
		return
	_ending_pending = false
	_showing_painting = false
	if is_instance_valid(_ending_panel):
		_ending_panel.queue_free()
	if is_instance_valid(ending_view):
		ending_view.hide()
	var navigator := get_node_or_null("/root/CampaignFlow") as CampaignNavigator
	if is_instance_valid(navigator) and navigator.active_run:
		navigator.progress_store.record_story_seen(4)
	show_result(_ending_snapshot)
	# 结尾按钮使用真实文案，不复用写着“进入下一关”的位图。
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		result_continue_button.remove_theme_stylebox_override(state)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		result_continue_button.remove_theme_color_override(state)
	result_continue_button.set_meta("art_bitmap", false)
	result_continue_button.focus_mode = Control.FOCUS_ALL
	show_continue("看看这幅画")
	result_continue_button.tooltip_text = "回到这次亲手长出的花海"


func _return_to_summary() -> void:
	_showing_painting = false
	ending_view.hide()
	result_panel.show()
	result_continue_button.grab_focus()


func _exit_tree() -> void:
	if _camera_tween != null:
		_camera_tween.kill()
