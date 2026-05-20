class_name BullySpawnManager
extends Node2D

const SAVE_KEY := "random_bullies"
const INTERACTABLE_SCENE: PackedScene = preload("res://scenes/dialogue/interactable.tscn")
const CIRCULAR_LINKED_LIST := preload("res://scripts/encounters/circular_linked_list.gd")
const DEFAULT_PROFILE := {
	"profile_id": "easy_bully",
	"dialogue_json_path": "res://assets/dialogues/bully_01.json",
	"intro_dialogue_id": "intro",
	"win_dialogue_id": "victory",
	"lose_dialogue_id": "defeat",
	"battle_scene_path": "res://scenes/rhythm/battle.tscn",
	"battle_chart_path": "res://assets/charts/tutorial.json",
	# Optional alternative chart to use when the player rematches or the
	# NPC was already defeated previously.
	"rematch_battle_chart_path": "",
	"dialogue_voice_path": "res://assets/audio/sfx/dialogue1.wav",
	"despawn_on_win": true,
}

@export_range(5, 20, 1) var minimum_active: int = 5
@export_range(5, 20, 1) var maximum_active: int = 10
@export var allow_full_spawn: bool = false

var _rng := RandomNumberGenerator.new()
var _spawn_points: CircularLinkedList = CIRCULAR_LINKED_LIST.new()
var _spawned_by_point: Dictionary = {}
var _seed: int = 0
var _cursor_index: int = 0
var _defeated_bullies: Dictionary = {}


func _ready() -> void:
	add_to_group("world_state_serializers")
	_rebuild_spawn_points()
	_apply_saved_or_generate()


func get_save_state_key() -> String:
	return SAVE_KEY


func serialize_state() -> Dictionary:
	var active_spawns: Array = []
	for spawn_point_id in _spawned_by_point.keys():
		var bully: Interactable = _spawned_by_point[spawn_point_id] as Interactable
		if bully == null or not is_instance_valid(bully):
			continue
		active_spawns.append({
			"spawn_point_id": str(spawn_point_id),
			"profile_id": str(bully.get_meta("profile_id", DEFAULT_PROFILE["profile_id"])),
		})
	active_spawns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("spawn_point_id", "")) < str(b.get("spawn_point_id", ""))
	)
	return {
		"version": 1,
		"seed": _seed,
		"cursor_index": _cursor_index,
		"active_bullies": active_spawns,
		"defeated": _defeated_bullies.keys(),
	}


func apply_state(state: Dictionary) -> void:
	_clear_spawned_bullies()
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		_generate_fresh_spawn_state()
		return
	_seed = int(state.get("seed", 0))
	_cursor_index = int(state.get("cursor_index", 0))
	if _seed == 0:
		_seed = int(Time.get_unix_time_from_system())
	_rng.seed = _seed
	var active_spawns: Variant = state.get("active_bullies", [])
	var defeated_list: Variant = state.get("defeated", [])
	_defeated_bullies.clear()
	if typeof(defeated_list) == TYPE_ARRAY:
		for d in defeated_list:
			_defeated_bullies[str(d)] = true
	if typeof(active_spawns) != TYPE_ARRAY or (active_spawns as Array).is_empty():
		_generate_fresh_spawn_state()
		return
	var active_map: Dictionary = {}
	for item in active_spawns:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_dict: Dictionary = item
		var spawn_point_id := str(item_dict.get("spawn_point_id", "")).strip_edges()
		if spawn_point_id.is_empty():
			continue
		active_map[spawn_point_id] = str(item_dict.get("profile_id", DEFAULT_PROFILE["profile_id"]))
	for marker in _get_spawn_markers():
		if not active_map.has(marker.name):
			continue
		_spawn_bully(marker, str(active_map[marker.name]))


func on_npc_defeated(npc_id: String) -> void:
	if npc_id == null or npc_id == "":
		return
	_defeated_bullies[str(npc_id)] = true
	# If the NPC instance exists, update its chart for rematches.
	if _spawned_by_point.has(npc_id):
		var inst: Interactable = _spawned_by_point[npc_id] as Interactable
		if inst != null and is_instance_valid(inst):
			var rem: String = str(DEFAULT_PROFILE.get("rematch_battle_chart_path", ""))
			if rem != "":
				inst.battle_chart_path = rem


func _apply_saved_or_generate() -> void:
	var gm := get_node_or_null("/root/Gamemanager")
	if gm != null and gm.has_method("consume_loaded_world_state"):
		var world_state: Dictionary = gm.consume_loaded_world_state()
		var saved_state: Variant = world_state.get(SAVE_KEY, {})
		if typeof(saved_state) == TYPE_DICTIONARY and not (saved_state as Dictionary).is_empty():
			apply_state(saved_state as Dictionary)
			return
	_generate_fresh_spawn_state()


func _generate_fresh_spawn_state() -> void:
	_clear_spawned_bullies()
	var markers: Array[Marker2D] = _get_spawn_markers()
	if markers.is_empty():
		return
	_seed = int(Time.get_unix_time_from_system()) ^ int(randi())
	_rng.seed = _seed
	# Selección aleatoria: mezclamos los markers y tomamos los primeros N.
	# Determinar máximo efectivo para evitar spawnear en todos los puntos
	var effective_max: int = int(min(maximum_active, markers.size()))
	if not allow_full_spawn and markers.size() > 1:
		effective_max = min(effective_max, markers.size() - 1)
	# Asegurar que effective_max >= minimum_active
	if effective_max < minimum_active:
		effective_max = minimum_active
	var target_count: int = _rng.randi_range(minimum_active, effective_max)
	target_count = clamp(target_count, 1, markers.size())
	# Mezclar usando el RNG local para reproducibilidad por seed
	for i in range(markers.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Marker2D = markers[i]
		markers[i] = markers[j]
		markers[j] = tmp

	for i in range(target_count):
		_spawn_bully(markers[i], DEFAULT_PROFILE["profile_id"])

	# Guardar cursor como índice de la última selección (para reproducibilidad)
	_cursor_index = _rng.randi_range(0, markers.size() - 1)


func _rebuild_spawn_points() -> void:
	_spawn_points.clear()
	for marker in _get_spawn_markers():
		_spawn_points.append(marker)


func _get_spawn_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)
	markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.name < b.name
	)
	return markers


func _spawn_bully(marker: Marker2D, profile_id: String) -> void:
	if marker == null:
		return
	var bully := INTERACTABLE_SCENE.instantiate() as Interactable
	if bully == null:
		return
	bully.name = "%s_bully" % marker.name
	bully.id = marker.name
	bully.position = marker.position
	bully.dialogue_json_path = DEFAULT_PROFILE["dialogue_json_path"]
	bully.intro_dialogue_id = DEFAULT_PROFILE["intro_dialogue_id"]
	bully.win_dialogue_id = DEFAULT_PROFILE["win_dialogue_id"]
	bully.lose_dialogue_id = DEFAULT_PROFILE["lose_dialogue_id"]
	bully.battle_scene_path = DEFAULT_PROFILE["battle_scene_path"]
	# Si el spawn point ya figura como derrotado, aplicar chart de rematch
	# cuando esté disponible; si no hay rematch configurado, usar el chart
	# por defecto.
	var spawn_id := marker.name
	if _defeated_bullies.has(spawn_id):
		var rematch: String = str(DEFAULT_PROFILE.get("rematch_battle_chart_path", ""))
		if rematch != "":
			bully.battle_chart_path = rematch
		else:
			bully.battle_chart_path = DEFAULT_PROFILE["battle_chart_path"]
	else:
		bully.battle_chart_path = DEFAULT_PROFILE["battle_chart_path"]
	bully.despawn_on_win = bool(DEFAULT_PROFILE["despawn_on_win"])
	var voice_path := str(DEFAULT_PROFILE["dialogue_voice_path"])
	if not voice_path.is_empty():
		bully.dialogue_voice = load(voice_path) as AudioStream
	bully.set_meta("profile_id", profile_id)
	add_child(bully)
	_spawned_by_point[marker.name] = bully


func _clear_spawned_bullies() -> void:
	for spawn_point_id in _spawned_by_point.keys():
		var bully: Interactable = _spawned_by_point[spawn_point_id] as Interactable
		if bully != null and is_instance_valid(bully):
			bully.queue_free()
	_spawned_by_point.clear()
