class_name ColonyEndingView
extends CanvasLayer
## 记忆回顾与成画展示只读取结算后的世界；切换由玩家确认，不使用倒计时跳过。

signal painting_requested
signal ending_requested
signal summary_requested

@onready var overlay: Control = $Overlay
@onready var recap: CenterContainer = $Overlay/Recap
@onready var recap_panel: PanelContainer = $Overlay/Recap/Paper
@onready var recap_scroll: ScrollContainer = $Overlay/Recap/Paper/Content/Scroll
@onready var memories: VBoxContainer = $Overlay/Recap/Paper/Content/Scroll/Memories
@onready var painting_button: Button = $Overlay/Recap/Paper/Content/PaintingButton
@onready var showcase: VBoxContainer = $Overlay/Showcase
@onready var ending_button: Button = $Overlay/Showcase/Actions/EndingButton
@onready var summary_button: Button = $Overlay/Showcase/Actions/SummaryButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	overlay.theme = ArtUI.theme(22)
	recap_panel.add_theme_stylebox_override("panel", ArtUI.paper(ArtUI.UI + "框底(1).png", 26))
	ArtUI.typography($Overlay/Recap/Paper/Content/Title, 32, true)
	ArtUI.typography($Overlay/Showcase/Title, 34, true)
	painting_button.pressed.connect(func() -> void: painting_requested.emit())
	ending_button.pressed.connect(func() -> void: ending_requested.emit())
	summary_button.pressed.connect(func() -> void: summary_requested.emit())
	summary_button.tooltip_text = "Esc 返回通关记录"
	get_viewport().size_changed.connect(_layout)
	_layout()


func show_memories(fragments: Array[MemoryFragment]) -> void:
	for index: int in range(mini(fragments.size(), memories.get_child_count())):
		var row: VBoxContainer = memories.get_child(index)
		(row.get_node("Name") as Label).text = fragments[index].display_name
		(row.get_node("Text") as Label).text = fragments[index].memory_text
	recap.show()
	showcase.hide()
	show()
	painting_button.grab_focus()
	recap_scroll.scroll_vertical = 0
	_layout.call_deferred()


func show_painting(replay: bool = false) -> void:
	recap.hide()
	showcase.show()
	ending_button.visible = not replay
	summary_button.visible = replay
	show()
	(summary_button if replay else ending_button).grab_focus()
	_layout.call_deferred()


func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	recap_panel.custom_minimum_size = Vector2(minf(720, viewport_size.x - 64), 0)
	# 只有记忆正文滚动。主操作始终留在纸张底部，阅读长文本也无需找回按钮。
	recap_scroll.custom_minimum_size.y = minf(360, maxf(160, viewport_size.y - 320))


func _input(event: InputEvent) -> void:
	if not visible or GameDisplayManager.is_display_shortcut(event):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and showcase.visible and summary_button.visible:
			# 回看不会重新进入 CG；Esc 与可见的返回按钮使用同一条路径。
			summary_requested.emit()
			get_viewport().set_input_as_handled()
