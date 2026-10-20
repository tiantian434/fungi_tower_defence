class_name EventGuideCard
extends PanelContainer
## 只展示教学快照，事件状态保留在 FirstEventGuide；节点在场景中可直接编辑。

signal dismissed

@onready var message_label: Label = $Content/Message
@onready var dismiss_button: Button = $Content/Header/Dismiss


func _ready() -> void:
	theme = ArtUI.theme(19)
	var paper := ArtUI.paper(ArtUI.UI + "对话框.png", 18)
	paper.content_margin_bottom = 24
	add_theme_stylebox_override("panel", paper)
	ArtUI.typography($Content/Header/Title, 20, true)
	dismiss_button.pressed.connect(func() -> void: dismissed.emit())
	hide()


func show_snapshot(snapshot: Dictionary) -> void:
	visible = bool(snapshot.get("visible", false))
	message_label.text = String(snapshot.get("text", ""))
