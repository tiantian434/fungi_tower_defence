class_name HyphaNode
extends Node2D

signal selection_requested(node: HyphaNode)

@export var display_name: String = "菌结"

@onready var selection_ring: Line2D = $SelectionRing


func set_selected(is_selected: bool) -> void:
	selection_ring.visible = is_selected


func _on_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selection_requested.emit(self)
			get_viewport().set_input_as_handled()
