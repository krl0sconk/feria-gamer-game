extends Node2D

@export_file("*.tscn") var exit_scene_path: String = "res://scenes/map/map.tscn"
@export var exit_tile_coords: Array[Vector2i] = [Vector2i(-3, -4), Vector2i(-3, -3)]
@export var tilemap_layer_path: NodePath = NodePath("Tilemaps")
@export var dialogue_runner_path: NodePath = NodePath("DialogueRunner")
@export var use_area_exit: bool = true
@export var exit_area_size: Vector2 = Vector2(24, 24)
@export var debug_force_create_area: bool = false
@export var debug_exit_area_position: Vector2 = Vector2.ZERO
@export var debug_exit_area_size: Vector2 = Vector2.ZERO
@export var debug_position_is_global: bool = true

var _has_exited: bool = false
var _runner: DialogueRunner = null
var _exit_areas: Array = []

func _ready() -> void:
	_runner = get_node_or_null(dialogue_runner_path) as DialogueRunner
	_resume_post_battle_dialogue_deferred()
	# Connect to QuestManager to enable exit when quest completes
	if QuestManager != null and QuestManager.has_signal("quest_completed"):
		QuestManager.connect("quest_completed", Callable(self, "_on_quest_completed"))
	# If quest already completed, enable area exit immediately
	if use_area_exit and QuestManager != null and QuestManager.is_completed("1.1.0"):
		_enable_area_exit()
	# Debug: force-create an exit area at a specific position/size
	if debug_force_create_area:
		var size = debug_exit_area_size if debug_exit_area_size != Vector2.ZERO else exit_area_size
		_create_exit_area(debug_exit_area_position, size, debug_position_is_global)

func _process(_delta: float) -> void:
	if _has_exited:
		return
	# If area-based exit is used, tile/proximity checks are skipped
	if use_area_exit:
		return
	# Fallback: original tile-based exit (keeps compatibility)
	if QuestManager != null and not (QuestManager.is_completed("1.1.1") or QuestManager.is_completed("1.1.0")):
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

func _on_quest_completed(quest_id: String) -> void:
	if str(quest_id) == "1.1.0":
		_enable_area_exit()


func _enable_area_exit() -> void:
	# First, enable any pre-existing Area2D nodes named "ExitArea"
	for node in get_children():
		if node is Area2D and str(node.name) == "ExitArea":
			_setup_exit_area(node as Area2D)
			# If we found existing exit areas, don't create new ones
			return
	# Otherwise, create area nodes at each configured exit_tile_coords
	var tilemap_root := get_node_or_null(tilemap_layer_path)
	if tilemap_root == null:
		return
	for child in tilemap_root.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			for ec in exit_tile_coords:
				var gp := layer.to_global(layer.map_to_local(ec))
				_create_exit_area(gp)
				# Only create areas on the first matching TileMapLayer
				return


func _setup_exit_area(area: Area2D) -> void:
	if area == null:
		return
	# Avoid double-setup
	if _exit_areas.has(area):
		return
	# Ensure collision shape exists; nothing to change if already configured
	var cs := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		for c in area.get_children():
			if c is CollisionShape2D:
				cs = c as CollisionShape2D
				break
	# Connect to body_entered if not connected and enable monitoring
	if not area.is_connected("body_entered", Callable(self, "_on_exit_area_body_entered")):
		area.connect("body_entered", Callable(self, "_on_exit_area_body_entered"))
	# Enable area monitoring so it detects the player
	area.monitoring = true
	_exit_areas.append(area)


func _create_exit_area(pos: Vector2, size: Vector2 = Vector2.ZERO, pos_is_global: bool = true) -> void:
	var area := Area2D.new()
	area.name = "ExitArea"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var use_size := size if size != Vector2.ZERO else exit_area_size
	# RectangleShape2D in code uses extents
	shape.extents = use_size * 0.5
	cs.shape = shape
	cs.position = Vector2.ZERO
	area.add_child(cs)
	# Set position correctly depending on whether `pos` is global or local
	if pos_is_global:
		area.global_position = pos
	else:
		area.position = pos
	add_child(area)
	_setup_exit_area(area)


func _on_exit_area_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player"):
		_has_exited = true
		call_deferred("_go_to_map")


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
