@tool
class_name HyphaEdge
extends Node2D

@export var start_node: Node2D
@export var end_node: Node2D

@onready var vein: Line2D = $Vein


func _process(_delta: float) -> void:
	if not is_instance_valid(vein):
		return

	if not has_endpoints():
		vein.clear_points()
		return

	var start_point := vein.to_local(start_node.global_position)
	var end_point := vein.to_local(end_node.global_position)

	vein.points = PackedVector2Array([
		start_point,
		end_point
	])


func has_endpoints() -> bool:
	return is_instance_valid(start_node) and is_instance_valid(end_node)


func get_length() -> float:
	if not has_endpoints():
		return 0.0
	return start_node.global_position.distance_to(end_node.global_position)


func connects(first: Node2D, second: Node2D) -> bool:
	return has_endpoints() and (
		(start_node == first and end_node == second) or
		(start_node == second and end_node == first)
	)


func get_point_at(progress: float) -> Vector2:
	if not has_endpoints():
		return global_position
	return start_node.global_position.lerp(end_node.global_position, clampf(progress, 0.0, 1.0))
