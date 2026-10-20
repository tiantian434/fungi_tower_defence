class_name MemoryFragment
extends Node2D
## 目标保存身份、收集进度和记忆画页；有效覆盖由关卡目标控制器判断。

@export var fragment_id: StringName = &""
@export var display_name: String = "记忆碎片"
@export_multiline var memory_text: String = ""
@export_range(0.1, 60.0) var collection_seconds: float = 5.0
@export var memory_image: Texture2D
@export var accent: Color = Color("d7ac62")

var progress_seconds: float = 0.0
var collected: bool = false
var collecting: bool = false
var _paper: StyleBoxTexture = ArtUI.paper(ArtUI.UI + "框底(1).png", 0)
@onready var _label: Label = get_node_or_null("Caption") as Label
@onready var _picture: Sprite2D = get_node_or_null("Picture") as Sprite2D


func _ready() -> void:
	if is_instance_valid(_label):
		_label.theme = ArtUI.theme(18)
	if is_instance_valid(_picture) and memory_image != null:
		_picture.texture = memory_image
		_picture.scale = Vector2.ONE * 62.0 / maxf(memory_image.get_width(), memory_image.get_height())
	refresh_view()


func refresh_view() -> void:
	if is_instance_valid(_label):
		_label.text = "%s\n%s" % [display_name, "已收集" if collected else (
			"收集中 %.1f / %.0fs" % [progress_seconds, collection_seconds] if collecting else (
				"收集暂停 %.1f / %.0fs" % [progress_seconds, collection_seconds] if progress_seconds > 0 else "连通花海后收集"))]
	if is_instance_valid(_picture):
		_picture.modulate = Color.WHITE if collected else Color(1, 1, 1, 0.76)
	queue_redraw()


func get_snapshot() -> Dictionary:
	return {"id": fragment_id, "name": display_name, "text": memory_text,
		"progress": progress_seconds, "duration": collection_seconds,
		"collected": collected, "collecting": collecting}


func _draw() -> void:
	var color := Color("8ba978") if collected else accent
	# 纸页和手绘画面替代纯色菱形，未收集的目标仍有清晰轮廓。
	draw_style_box(_paper, Rect2(-39, -37, 78, 74))
	draw_arc(Vector2.ZERO, 43, 0, TAU, 48, Color(color, 0.55), 2, true)
	if progress_seconds > 0:
		draw_arc(Vector2.ZERO, 43, -PI / 2, -PI / 2 + TAU * clampf(progress_seconds / collection_seconds, 0, 1),
			48, color, 4, true)
	if collected:
		draw_polyline(PackedVector2Array([Vector2(21, 22), Vector2(27, 29), Vector2(39, 15)]), color, 4, true)
