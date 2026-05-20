extends Node2D

@export_file("*.tscn") var exit_scene_path: String = "res://scenes/map/map.tscn"
@export var exit_tile_coords: Array[Vector2i] = [Vector2i(-3, -4), Vector2i(-3, -3)]
@export var tilemap_layer_path: NodePath = NodePath("Tilemaps")

var _has_exited: bool = false


func _process(_delta: float) -> void:
	if _has_exited:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var tilemap_root := get_node_or_null(tilemap_layer_path)
	if tilemap_root == null:
		return
	for child in tilemap_root.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			var coords := layer.local_to_map(layer.to_local(player.global_position))
			if exit_tile_coords.has(coords):
				_has_exited = true
				call_deferred("_go_to_map")
				return


func _go_to_map() -> void:
	if exit_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(exit_scene_path)
