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
	"battle_scene": preload("res://scenes/rhythm/battle.tscn"),
	"battle_chart_path": "res://assets/charts/tutorial.json",
	# Optional alternative chart to use when the player rematches or the
	# NPC was already defeated previously.
	"rematch_battle_chart_path": "",
	"dialogue_voice_path": "res://assets/audio/sfx/dialogue1.wav",
	"despawn_on_win": true,
}

# Map profile_id -> SpriteFrames resource to preserve original sprites
const PROFILE_FRAMES := {
	"easy_bully": preload("res://assets/images/characters/pj1/pj1_idle.tres"),
	"pj2_bully": preload("res://assets/images/characters/pj2/pj2_idle.tres"),
}

@export_range(5, 20, 1) var minimum_active: int = 5
@export_range(5, 20, 1) var maximum_active: int = 5
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


func _exit_tree() -> void:
	_persist_session_state()


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
	var spawned_count: int = 0
	for marker in _get_spawn_markers():
		if not active_map.has(marker.name):
			continue
		if spawned_count >= maximum_active:
			break
		_spawn_bully(marker, str(active_map[marker.name]))
		spawned_count += 1


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
	_persist_session_state()


func _persist_session_state() -> void:
	var gm := get_node_or_null("/root/Gamemanager")
	if gm != null and gm.has_method("set_session_world_slice"):
		gm.set_session_world_slice(SAVE_KEY, serialize_state())


func _apply_saved_or_generate() -> void:
	var gm := get_node_or_null("/root/Gamemanager")
	if gm != null and gm.has_method("consume_loaded_world_state"):
		if gm.has_loaded_world_state:
			var world_state: Dictionary = gm.consume_loaded_world_state()
			var saved_state: Variant = world_state.get(SAVE_KEY, {})
			if typeof(saved_state) == TYPE_DICTIONARY and not (saved_state as Dictionary).is_empty():
				apply_state(saved_state as Dictionary)
				_persist_session_state()
				return
		if gm.has_method("get_session_world_slice"):
			var session_state: Dictionary = gm.get_session_world_slice(SAVE_KEY)
			if not session_state.is_empty():
				apply_state(session_state)
				return
	_generate_fresh_spawn_state()
	_persist_session_state()


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
		if child is Marker2D and child.get("enabled") != false:
			markers.append(child as Marker2D)
	markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.name < b.name
	)
	return markers


func _choose_animation(frames: SpriteFrames, preferred: Array = ["frente", "normal", "Idle", "idle", "default"]) -> String:
	if frames == null:
		return ""
	for p in preferred:
		if frames.has_animation(str(p)):
			return str(p)
	var names: Array = frames.get_animation_names()
	if names.size() > 0:
		return names[0]
	return ""


func _spawn_bully(marker: Marker2D, profile_id: String) -> void:
	if marker == null:
		return
	var bully := INTERACTABLE_SCENE.instantiate() as Interactable
	if bully == null:
		return
	bully.name = "%s_bully" % marker.name
	bully.id = marker.name
	bully.position = marker.position
	bully.scale = Vector2(1.5, 1.5)
	var marker_dialogue_json := ""
	var marker_intro_dialogue := ""
	var marker_win_dialogue := ""
	var marker_lose_dialogue := ""
	var marker_battle_scene: PackedScene = null
	var marker_despawn_on_win: bool = bool(DEFAULT_PROFILE["despawn_on_win"])
	var marker_dialogue_voice: AudioStream = null
	if marker != null and marker.has_method("get"):
		var try_dialogue_json = marker.get("dialogue_json_path")
		if try_dialogue_json != null and str(try_dialogue_json).strip_edges() != "":
			marker_dialogue_json = str(try_dialogue_json)
		var try_intro_dialogue = marker.get("intro_dialogue_id")
		if try_intro_dialogue != null and str(try_intro_dialogue).strip_edges() != "":
			marker_intro_dialogue = str(try_intro_dialogue)
		var try_win_dialogue = marker.get("win_dialogue_id")
		if try_win_dialogue != null and str(try_win_dialogue).strip_edges() != "":
			marker_win_dialogue = str(try_win_dialogue)
		var try_lose_dialogue = marker.get("lose_dialogue_id")
		if try_lose_dialogue != null and str(try_lose_dialogue).strip_edges() != "":
			marker_lose_dialogue = str(try_lose_dialogue)
		var try_battle_scene = marker.get("battle_scene")
		if try_battle_scene != null and try_battle_scene is PackedScene:
			marker_battle_scene = try_battle_scene
		var try_despawn = marker.get("despawn_on_win")
		if try_despawn != null:
			marker_despawn_on_win = bool(try_despawn)
		var try_voice = marker.get("dialogue_voice")
		if try_voice != null and try_voice is AudioStream:
			marker_dialogue_voice = try_voice
	bully.dialogue_json_path = marker_dialogue_json if marker_dialogue_json != "" else DEFAULT_PROFILE["dialogue_json_path"]
	bully.intro_dialogue_id = marker_intro_dialogue if marker_intro_dialogue != "" else DEFAULT_PROFILE["intro_dialogue_id"]
	bully.win_dialogue_id = marker_win_dialogue if marker_win_dialogue != "" else DEFAULT_PROFILE["win_dialogue_id"]
	bully.lose_dialogue_id = marker_lose_dialogue if marker_lose_dialogue != "" else DEFAULT_PROFILE["lose_dialogue_id"]
	bully.battle_scene = marker_battle_scene if marker_battle_scene != null else DEFAULT_PROFILE["battle_scene"]
	var marker_chart_override: String = ""
	var marker_music_override: AudioStream = null
	if marker != null and marker.has_method("get"):
		var try_chart = marker.get("battle_chart_path")
		if try_chart != null and str(try_chart).strip_edges() != "":
			marker_chart_override = str(try_chart)
		var try_music = marker.get("battle_music")
		if try_music != null and try_music is AudioStream:
			marker_music_override = try_music
	# Si el spawn point ya figura como derrotado, aplicar chart de rematch
	# cuando esté disponible; si no hay rematch configurado, usar el chart
	# por defecto.
	var spawn_id := marker.name
	if marker_chart_override != "":
		bully.battle_chart_path = marker_chart_override
	elif _defeated_bullies.has(spawn_id):
		var rematch: String = str(DEFAULT_PROFILE.get("rematch_battle_chart_path", ""))
		if rematch != "":
			bully.battle_chart_path = rematch
		else:
			bully.battle_chart_path = DEFAULT_PROFILE["battle_chart_path"]
	else:
		bully.battle_chart_path = DEFAULT_PROFILE["battle_chart_path"]
	bully.battle_music = marker_music_override
	bully.despawn_on_win = marker_despawn_on_win
	var voice_path := str(DEFAULT_PROFILE["dialogue_voice_path"])
	if not voice_path.is_empty():
		if marker_dialogue_voice != null:
			bully.dialogue_voice = marker_dialogue_voice
		else:
			bully.dialogue_voice = load(voice_path) as AudioStream
	# Allow per-marker overrides: if the marker exposes `profile_id` or
	# `sprite_frames` (via SpawnPoint script), prefer them over the
	# `profile_id` parameter.
	if marker != null:
		# marker.profile_id may exist if SpawnPoint.gd is attached.
		var marker_profile := ""
		if marker.has_method("get"):
			var try_prof = marker.get("profile_id")
			if try_prof != null and str(try_prof).strip_edges() != "":
				marker_profile = str(try_prof)
		if marker_profile != "":
			profile_id = marker_profile

	# Ensure the visible sprite uses a SpriteFrames resource (not a raw Texture)
	var sprite_node := bully.get_node_or_null("Sprite2D")
	# Force a proper SpriteFrames resource and play Idle animation to avoid
	# showing the raw spritesheet texture as a single image.
	if sprite_node != null:
		# If the marker provides an explicit SpriteFrames, use it.
		var marker_frames: SpriteFrames = null
		if marker != null and marker.has_method("get"):
			var try_frames = marker.get("sprite_frames")
			if try_frames != null and try_frames is SpriteFrames:
				marker_frames = try_frames
		var default_frames: SpriteFrames = marker_frames if marker_frames != null else PROFILE_FRAMES.get(profile_id, preload("res://assets/images/characters/pj1/pj1_idle.tres")) as SpriteFrames
		if sprite_node is AnimatedSprite2D:
			# Always override the scene's default frames so SpawnPoint settings win.
			sprite_node.sprite_frames = default_frames
			var marker_scale: Vector2 = Vector2(4, 4)
			var marker_anim := ""
			if marker != null and marker.has_method("get"):
				var try_scale = marker.get("sprite_scale")
				if try_scale is Vector2:
					marker_scale = try_scale
				var try_anim = marker.get("preferred_animation")
				if try_anim != null and str(try_anim).strip_edges() != "":
					marker_anim = str(try_anim)
			sprite_node.scale = marker_scale
			var preferred_anims: Array = ["frente", "normal", "Idle", "idle", "default"]
			if marker_anim != "":
				preferred_anims.insert(0, marker_anim)
			var chosen: String = _choose_animation(sprite_node.sprite_frames, preferred_anims)
			if chosen != "":
				sprite_node.animation = chosen
				sprite_node.play()
		elif sprite_node is Sprite2D:
			# If a plain Sprite2D was used and it holds a full spritesheet texture,
			# clear it and add a minimal AnimatedSprite2D to display frames.
			if sprite_node.texture != null:
				# Remove texture to avoid showing the entire sheet.
				sprite_node.texture = null
				var anim := AnimatedSprite2D.new()
				anim.name = "Sprite2D"
				anim.sprite_frames = default_frames
				var chosen2: String = _choose_animation(anim.sprite_frames)
				if chosen2 != "":
					anim.animation = chosen2
				anim.play()
				# Replace the node in the parent
				var parent := sprite_node.get_parent()
				parent.remove_child(sprite_node)
				parent.add_child(anim)

	bully.set_meta("profile_id", profile_id)
	add_child(bully)
	_spawned_by_point[marker.name] = bully


func _clear_spawned_bullies() -> void:
	for spawn_point_id in _spawned_by_point.keys():
		var bully: Interactable = _spawned_by_point[spawn_point_id] as Interactable
		if bully != null and is_instance_valid(bully):
			bully.queue_free()
	_spawned_by_point.clear()
