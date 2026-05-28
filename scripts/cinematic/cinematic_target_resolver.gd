# Resuelve destinos de comandos de cinemática: to_path > to_node > to literal.
class_name CinematicTargetResolver
extends RefCounted


static func resolve_point(params: Dictionary, scene_root: Node) -> Vector2:
	var path_points := resolve_path(params, scene_root)
	if not path_points.is_empty():
		return path_points[0]

	var node_path: String = str(params.get("to_node", ""))
	if not node_path.is_empty() and scene_root != null:
		var node := scene_root.get_node_or_null(node_path) as Node2D
		if node != null:
			return node.global_position
		push_warning("CinematicTargetResolver: to_node '%s' no encontrado." % node_path)

	var to: Variant = params.get("to", null)
	if to is Array and (to as Array).size() >= 2:
		return Vector2(float(to[0]), float(to[1]))

	push_warning("CinematicTargetResolver: sin destino válido (to_path, to_node o to).")
	return Vector2.ZERO


static func resolve_path(params: Dictionary, scene_root: Node) -> Array[Vector2]:
	var path_node_path: String = str(params.get("to_path", ""))
	if path_node_path.is_empty() or scene_root == null:
		return []

	var path_node := scene_root.get_node_or_null(path_node_path)
	if path_node == null:
		push_warning("CinematicTargetResolver: to_path '%s' no encontrado." % path_node_path)
		return []

	if path_node.has_method("get_waypoints"):
		return path_node.call("get_waypoints")

	push_warning("CinematicTargetResolver: to_path '%s' no expone get_waypoints()." % path_node_path)
	return []
