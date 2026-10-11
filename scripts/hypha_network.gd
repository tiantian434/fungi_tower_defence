@tool
class_name HyphaNetwork
extends Node
## 查询当前连通关系和最少边数的路径；暂不处理容量、拥堵和运输中改道。

@export var mother_core: MotherCore
@export var nodes_container: Node2D
@export var connections_container: Node2D


func get_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	if is_instance_valid(mother_core) and not mother_core.is_queued_for_deletion():
		nodes.append(mother_core)
	if is_instance_valid(nodes_container):
		for child in nodes_container.get_children():
			if child is HyphaNode and not child.is_queued_for_deletion():
				nodes.append(child)
	return nodes


func get_edges() -> Array[HyphaEdge]:
	var edges: Array[HyphaEdge] = []
	if is_instance_valid(connections_container):
		for child in connections_container.get_children():
			if child is HyphaEdge and child.is_usable():
				edges.append(child)
	return edges


func get_connected_nodes() -> Array[Node2D]:
	var connected: Array[Node2D] = []
	if not is_instance_valid(mother_core) or mother_core.is_queued_for_deletion():
		return connected
	if not Engine.is_editor_hint() and mother_core.health <= 0:
		return connected
	var nodes := get_nodes()
	var edges := get_edges()
	connected.append(mother_core)
	var cursor := 0
	while cursor < connected.size():
		var current := connected[cursor]
		cursor += 1
		for edge in edges:
			var neighbor := _other_end(edge, current)
			if neighbor != null and neighbor in nodes and neighbor not in connected:
				connected.append(neighbor)
	return connected


func find_path(source: Node2D, destination: Node2D) -> Array[HyphaEdge]:
	var path: Array[HyphaEdge] = []
	var nodes := get_nodes()
	if source not in nodes or destination not in nodes or source == destination:
		return path
	var edges := get_edges()
	var visited: Array[Node2D] = [source]
	var previous_nodes: Dictionary[Node2D, Node2D] = {}
	var previous_edges: Dictionary[Node2D, HyphaEdge] = {}
	var cursor := 0
	while cursor < visited.size():
		var current := visited[cursor]
		cursor += 1
		for edge in edges:
			var neighbor := _other_end(edge, current)
			if neighbor == null or neighbor not in nodes or neighbor in visited:
				continue
			visited.append(neighbor)
			previous_nodes[neighbor] = current
			previous_edges[neighbor] = edge
			if neighbor == destination:
				var step := destination
				while step != source:
					path.push_front(previous_edges[step])
					step = previous_nodes[step]
				return path
	return path


func _other_end(edge: HyphaEdge, node: Node2D) -> Node2D:
	if edge.start_node == node:
		return edge.end_node
	if edge.end_node == node:
		return edge.start_node
	return null
