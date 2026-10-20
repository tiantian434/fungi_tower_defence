class_name FirstEventGuide
extends Control
## 首次事件教学。新进展替换过时步骤，短队列自动推进；暂停时保留阅读时间。

signal changed(snapshot: Dictionary)

const EVENT_TEXTS: Dictionary = {
	&"opening": "先按 G，再点击左前方画架附近，花径会自动延伸。\n接通花海后，画架可以回收成继续创作的能量。",
	&"target_placed": "目标已放置，补给会沿花径送往延伸花苞。\n与小画家接通后，花海内的回收物才能运回。",
	&"remains_returned": "回收物已送达碎纸机，正在等待加工。\n补给送回小画家后，创作能量才能再次使用。",
	&"nutrition_returned": "创作能量回来了！旧画也能成为下一笔。\n继续延伸到另一处画架，或在前沿花朵上按 C 建造炮台。",
	&"stage_unlocked": "创作进入新阶段，新的能力已经解锁。\n查看创作阶段；扩张和设施仍需付费建设。",
	&"differentiated": "首次炮台改装已完成。\n橡皮炮台应对重甲花羊，喷漆炮台拦截小涂鸦羊。",
	&"network_broken": "花径中断：失联区域暂停补给与采集。\nF选择受损对象，J付费修复；也可L连接存活花朵。",
}
const MAX_PENDING: int = 3
const PROGRESS_STEPS: Array[StringName] = [&"opening", &"target_placed", &"remains_returned", &"nutrition_returned"]

var is_enabled: bool = true

var _seen: Dictionary[StringName, bool] = {}
var _seen_order: Array[StringName] = []
var _pending: Array[Dictionary] = []
var _current: Dictionary = {}
var _message_panel: Panel
var _message_label: Label
var _dismiss_button: Button
var _toggle_button: Button
var _remaining: float = 0.0
var _presentation_paused: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(750, 60)


func _ready() -> void:
	_build_ui()
	_refresh_view()


func _process(delta: float) -> void:
	advance(delta)


## 由展示层传入菜单、抽屉等阅读遮挡状态；该设置不改变事件记录。
func set_presentation_paused(value: bool) -> void:
	_presentation_paused = value


func advance(delta: float) -> void:
	if _current.is_empty() or _presentation_paused or (is_inside_tree() and get_tree().paused):
		return
	_remaining -= maxf(delta, 0.0)
	if _remaining <= 0.0:
		dismiss_current()


func record_event(event_id: StringName, facts: Dictionary = {}) -> void:
	if _event_text(event_id).is_empty():
		return
	var event_key: StringName = _event_key(event_id, facts)
	if _seen.has(event_key):
		return
	_seen[event_key] = true
	if not _seen_order.has(event_id):
		_seen_order.append(event_id)
	if is_enabled:
		var entry: Dictionary = {"id": event_id, "key": event_key, "text": _message_for(event_id, facts), "order": _seen.size()}
		_remove_obsolete_steps(event_id)
		# 当前发生的危险和成长优先展示，不让旧的放置提示遮住已经发生的回收。
		if not _current.is_empty() and _priority(event_id) > _priority(_current.get("id", &"")):
			if not PROGRESS_STEPS.has(_current.get("id", &"")):
				_pending.push_front(_current.duplicate())
			_current.clear()
		_pending.append(entry)
		_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_priority: int = _priority(a.id)
			var b_priority: int = _priority(b.id)
			return a_priority > b_priority if a_priority != b_priority else int(a.order) < int(b.order))
		if _pending.size() > MAX_PENDING:
			_pending.resize(MAX_PENDING)
		_show_next()
	_publish()


func dismiss_current() -> void:
	if _current.is_empty():
		return
	_current.clear()
	_show_next()
	_publish()


func set_enabled(value: bool) -> void:
	if is_enabled == value:
		return
	is_enabled = value
	if not is_enabled:
		_current.clear()
		_pending.clear()
	_publish()


## 保留当前提示设置，清除旧局的可见提示、待显示项和首次事件记录。
func reset() -> void:
	_seen.clear()
	_seen_order.clear()
	_pending.clear()
	_current.clear()
	_publish()


func get_snapshot() -> Dictionary:
	return {
		"enabled": is_enabled,
		"visible": is_enabled and not _current.is_empty(),
		"current_event": _current.get("id", &""),
		"current_key": _current.get("key", &""),
		"text": String(_current.get("text", "")),
		"seen": _seen_order.duplicate(),
		"remaining": _remaining,
	}


func _message_for(event_id: StringName, facts: Dictionary) -> String:
	var message: String = _event_text(event_id)
	var raw_stage: Variant = facts.get("stage_name", facts.get("stage", ""))
	if event_id == &"stage_unlocked" and (raw_stage is String or raw_stage is StringName):
		var stage_name: String = String(raw_stage).strip_edges().replace("\n", " ")
		if not stage_name.is_empty() and stage_name.length() <= 12:
			if stage_name == "铺展":
				message = "进入「铺展」：现在能同时延伸两条花径。\n按 G 在另一方向放下目标，试着双线生长。"
			elif stage_name == "成形":
				message = "进入「成形」：炮台改装与双路加工已解锁。\n选中炮台，点左下「详情 → 炮台改装」选择类型。"
			else:
				message = "进入「%s」：新的创作能力已解锁。\n点击左上角创作能量，查看这次成长带来的变化。" % stage_name
	return message


func _event_text(event_id: StringName) -> String:
	return String(EVENT_TEXTS.get(event_id, ""))


func _event_key(event_id: StringName, facts: Dictionary) -> StringName:
	if event_id == &"stage_unlocked":
		return StringName("stage_unlocked:%s" % str(facts.get("stage_name", facts.get("stage", "new"))))
	return event_id


func _priority(event_id: StringName) -> int:
	if event_id == &"network_broken": return 100
	# 能力提示不能被一批不同敌人的首次出现挤出短队列；断路危险仍可立即抢占。
	if event_id == &"stage_unlocked": return 95
	if event_id in [&"armored", &"swarm", &"silk_gnawer", &"junction_gnawer"]: return 90
	if event_id in [&"fragment_collected", &"facility_destroyed", &"differentiated"]: return 60
	return 20 + PROGRESS_STEPS.find(event_id)


func _remove_obsolete_steps(event_id: StringName) -> void:
	var step: int = PROGRESS_STEPS.find(event_id)
	if step < 0: return
	for index: int in range(_pending.size() - 1, -1, -1):
		var earlier: int = PROGRESS_STEPS.find(_pending[index].id)
		if earlier >= 0 and earlier < step:
			_pending.remove_at(index)
	var current_step: int = PROGRESS_STEPS.find(_current.get("id", &""))
	if current_step >= 0 and current_step < step:
		_current.clear()


func _show_next() -> void:
	if is_enabled and _current.is_empty() and not _pending.is_empty():
		_current = _pending.pop_front()
		_remaining = clampf(String(_current.text).length() / 5.0, 9.0, 16.0)


func _publish() -> void:
	_refresh_view()
	changed.emit(get_snapshot())


func _build_ui() -> void:
	if is_instance_valid(_message_panel):
		return
	var guide_theme: Theme = ArtUI.theme(20)
	theme = guide_theme
	_message_panel = Panel.new()
	_message_panel.name = "MessagePanel"
	_message_panel.size = Vector2(636, 60)
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: StyleBoxTexture = ArtUI.paper(ArtUI.UI + "对话框.png", 8)
	_message_panel.add_theme_stylebox_override("panel", background)
	add_child(_message_panel)
	_message_label = Label.new()
	_message_label.name = "Message"
	_message_label.position = Vector2(12, 7)
	_message_label.size = Vector2(526, 46)
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.add_theme_color_override("font_color", ArtUI.INK)
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message_label)
	_dismiss_button = Button.new()
	_dismiss_button.name = "Dismiss"
	_dismiss_button.text = "知道了"
	_dismiss_button.position = Vector2(548, 14)
	_dismiss_button.size = Vector2(76, 32)
	_dismiss_button.focus_mode = Control.FOCUS_NONE
	_dismiss_button.pressed.connect(dismiss_current)
	_message_panel.add_child(_dismiss_button)
	_toggle_button = Button.new()
	_toggle_button.name = "Toggle"
	_toggle_button.position = Vector2(648, 14)
	_toggle_button.size = Vector2(102, 32)
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.toggle_mode = true
	_toggle_button.tooltip_text = "开启或关闭本局首次事件提示"
	_toggle_button.toggled.connect(set_enabled)
	add_child(_toggle_button)


func _refresh_view() -> void:
	if not is_instance_valid(_message_panel):
		return
	var snapshot: Dictionary = get_snapshot()
	_message_panel.visible = bool(snapshot["visible"])
	_message_label.text = String(snapshot["text"])
	_toggle_button.set_pressed_no_signal(is_enabled)
	_toggle_button.text = "引导 开" if is_enabled else "引导 关"
