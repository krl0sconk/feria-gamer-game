extends Node2D

@export_file("*.tscn") var exit_scene_path: String = "res://scenes/map/map.tscn"
@export var exit_tile_coords: Array[Vector2i] = [Vector2i(-3, -4), Vector2i(-3, -3)]
@export var tilemap_layer_path: NodePath = NodePath("Tilemaps")
@export var dialogue_runner_path: NodePath = NodePath("DialogueRunner")

var _has_exited: bool = false
var _runner: DialogueRunner = null


func _ready() -> void:
	_runner = get_node_or_null(dialogue_runner_path) as DialogueRunner
	_resume_post_battle_dialogue_deferred()


func _process(_delta: float) -> void:
	if _has_exited:
		return
	if QuestManager != null and not QuestManager.is_completed("1.1.1"):
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


func _resume_post_battle_dialogue_deferred() -> void:
	call_deferred("_resume_post_battle_dialogue")


func _resume_post_battle_dialogue() -> void:
	var result: String = Gamemanager.pending_dialogue_result
	var npc_id: String = Gamemanager.pending_npc_id
	if result.is_empty() or npc_id.is_empty():
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and Gamemanager.return_position != Vector2.ZERO:
		player.global_position = Gamemanager.return_position

	var target := _find_interactable_by_id(npc_id)
	if target == null:
		Gamemanager.clear_pending_dialogue()
		return
	target.play_result_dialogue(result)
	Gamemanager.clear_pending_dialogue()


func _find_interactable_by_id(npc_id: String) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Interactable and (node as Interactable).id == npc_id:
			return node
	return null
