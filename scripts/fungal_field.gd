@tool
class_name FungalField
extends Node2D
## 使用同一组椭圆参数做地表显示与回收判定，重叠区域不叠加亮度。

signal coverage_changed(connected: int, total: int)

# 与 fungal_field.gdshader 的数组长度一致。超过上限的区域不参与显示或回收。
const MAX_PATCHES: int = 64

@export var network: HyphaNetwork
@export_range(0.3, 1.0, 0.05) var ground_ratio: float = 0.7

var _patches: Array[FungalPatch] = []
var _last_connected: int = -1
var _last_total: int = -1
var _capacity_warning_shown: bool = false

@onready var surface: Polygon2D = $Surface


func _ready() -> void:
	# 每个关卡拥有自己的材质参数，测试或并存的关卡不会互相覆盖。
	surface.material = surface.material.duplicate()
	refresh(0.0)


func _physics_process(delta: float) -> void:
	refresh(delta)


func refresh(delta: float) -> void:
	if not is_instance_valid(network) or not is_instance_valid(surface):
		return
	var connected_nodes := network.get_connected_nodes()
	_patches.clear()
	var connected_count := 0
	var data := PackedVector4Array()
	var bounds := Rect2()
	for node in network.get_nodes():
		var patch := node.get_node_or_null("FungalPatch") as FungalPatch
		if patch == null:
			continue
		if _patches.size() >= MAX_PATCHES:
			if not _capacity_warning_shown:
				push_warning("菌域显示达到 64 处上限，额外覆盖暂不参与回收。")
				_capacity_warning_shown = true
			break
		patch.update_connection(node in connected_nodes, delta)
		_patches.append(patch)
		if patch.connected:
			connected_count += 1
		var center := to_local(patch.global_position)
		var radius := patch.get_radius()
		data.append(Vector4(center.x, center.y, radius, 1.0 if patch.connected else 0.0))
		var extent := Vector2(radius, radius * ground_ratio) + Vector2(4, 4)
		var patch_bounds := Rect2(center - extent, extent * 2.0)
		bounds = patch_bounds if data.size() == 1 else bounds.merge(patch_bounds)

	var count := data.size()
	data.resize(MAX_PATCHES)
	surface.material.set_shader_parameter("patch_count", count)
	surface.material.set_shader_parameter("patches", data)
	surface.material.set_shader_parameter("ground_ratio", ground_ratio)
	surface.polygon = PackedVector2Array([
		bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)
	]) if count > 0 else PackedVector2Array()
	if connected_count != _last_connected or count != _last_total:
		_last_connected = connected_count
		_last_total = count
		coverage_changed.emit(connected_count, count)


func get_nearest_collector(world_position: Vector2) -> Node2D:
	if not is_instance_valid(network):
		return null
	# 调度可能发生在边被切断的同一帧，实时检查连通，不能依赖上一帧的颜色。
	var connected_nodes := network.get_connected_nodes()
	var nearest: Node2D = null
	var nearest_distance := INF
	var point := to_local(world_position)
	for patch in _patches:
		if not is_instance_valid(patch) or patch.is_queued_for_deletion():
			continue
		var node := patch.get_parent() as Node2D
		if node not in connected_nodes or patch.get_radius() <= 0.0:
			continue
		var offset := point - to_local(patch.global_position)
		var ground_distance := Vector2(offset.x, offset.y / maxf(ground_ratio, 0.01)).length()
		if ground_distance <= patch.get_radius() and offset.length_squared() < nearest_distance:
			nearest = node
			nearest_distance = offset.length_squared()
	return nearest


func is_covered(world_position: Vector2) -> bool:
	return get_nearest_collector(world_position) != null
