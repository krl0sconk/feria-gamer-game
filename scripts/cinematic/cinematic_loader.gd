# Lee un archivo JSON de cinemática y lo convierte en un CinematicData con
# su lista de CinematicStep.
#
# Formato esperado del JSON:
# {
#   "version": 1,
#   "id": "room_intro",
#   "trigger": { "type": "on_scene_ready", "delay": 0.3 },
#   "steps": [
#     { "type": "disable_player" },
#     { "type": "fade_to_black",   "duration": 0.6 },
#     { "type": "dialogue", "path": "res://assets/cinematics/room_intro_dialogue.json", "id": "context" },
#     { "type": "fade_from_black", "duration": 0.6 },
#     { "type": "enable_player" }
#   ]
# }
#
# Tipos de trigger:
#   on_scene_ready   — al entrar a la escena, con "delay" opcional en segundos
#   on_quest_completed — cuando QuestManager emite quest_completed con "quest_id"
#   on_area_entered  — cuando el jugador pisa el Area2D hijo llamado "TriggerArea"
#
# Tipos de paso (patrón Command — cada entrada en _commands de CinematicPlayer
# es el comando correspondiente):
#   fade_to_black / fade_from_black  — fundido a negro y vuelta, "duration" en s
#   wait                             — espera "seconds" segundos
#   dialogue       — reproduce un diálogo: "path" al JSON, "id" del diálogo
#   move_node      — mueve un nodo 2D: "node" (NodePath desde root),
#                    destino vía "to_node", "to_path" (WaypointPath) o "to": [x,y],
#                    "duration" en segundos
#   show_node / hide_node — muestra u oculta un nodo de la escena: "node"
#   disable_player / enable_player   — bloquea/desbloquea el movimiento del jugador
#   walk_to        — camina con animación: "node", destino vía to_node/to_path/to,
#                    "speed" (px/s) o "duration" (s), "animation", "idle_animation",
#                    "face_direction" (bool, default true)
#   walk_path      — recorre un WaypointPath: "node", "to_path", "speed", "wait_per_point"
#   face_direction — mira hacia "look_at_node" o "direction" (left/right/up/down)
#   play_animation — "node", "animation", "wait_finish", "idle_animation"
#   set_collision  — "node" (CollisionShape2D o body), "enabled" (bool)
#   wait_for_player_near — "to_node" o "node", "distance", "timeout" (0 = sin límite)
#   enable_barrier   — activa ScriptedBarrier por "id"
#   disable_barrier  — desactiva ScriptedBarrier por "id"
#   start_battle     — lanza batalla como Interactable: "battle_scene_path", "return_npc_id",
#                      "chart_path" y "music_path" opcionales
#   follower_lead    — NPC guía por WaypointPath: "node", "path_node" (o "to_path"), "speed",
#                      "wait_for_arrival" (bool, default true)
#   follower_follow  — NPC sigue a "target" (NodePath, default "Player"), "speed" opcional
#   follower_stop    — detiene el Follower del "node"
#   camera_focus     — pan/zoom hacia "target" (NodePath), "duration", "zoom" (0 = sin cambio)
#   camera_release   — restaura cámara al player, "duration"
#   shake_camera     — sacudida: "intensity", "duration"
#   letterbox        — barras negras: "enabled", "bar_height", "duration"
#   play_sfx         — one-shot: "stream_path", "bus" (default SFX), "volume_db", "wait_finish"
#
# Uso:
#   var data := CinematicLoader.load_json("res://assets/cinematics/room_intro.json")
#   $CinematicPlayer.play()  # el player carga internamente
class_name CinematicLoader
extends RefCounted


## Paso individual de la cinemática. Patrón Command: encapsula el tipo de acción
## y sus parámetros; CinematicPlayer los ejecuta uno a uno en secuencia.
class CinematicStep:
	var type: String = ""
	## Todos los campos del JSON excepto "type".
	var params: Dictionary = {}


## Resultado de parsear un JSON de cinemática.
class CinematicData:
	var id: String = ""
	var trigger: Dictionary = {}
	var steps: Array[CinematicStep] = []


## Convierte un CinematicData a Dictionary listo para JSON.stringify.
static func data_to_dict(data: CinematicData) -> Dictionary:
	var steps_arr: Array = []
	for step: CinematicStep in data.steps:
		var d: Dictionary = {"type": step.type}
		for key in step.params.keys():
			d[key] = step.params[key]
		steps_arr.append(d)
	return {
		"version": 1,
		"id": data.id,
		"trigger": data.trigger,
		"steps": steps_arr,
	}


## Guarda un CinematicData como JSON tabulado. Devuelve OK o código de error.
static func save_json(path: String, data: CinematicData) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CinematicLoader: no se pudo abrir para escritura: %s" % path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data_to_dict(data), "\t"))
	file.close()
	return OK


## Carga y parsea un archivo JSON de cinemática.
## Devuelve CinematicData vacío si hay un error (nunca null) para que el caller
## no se rompa si el archivo falta.
static func load_json(path: String) -> CinematicData:
	var result := CinematicData.new()

	if not FileAccess.file_exists(path):
		push_error("CinematicLoader: archivo no encontrado: %s" % path)
		return result

	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("CinematicLoader: archivo vacío: %s" % path)
		return result

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("CinematicLoader: error al parsear %s (línea %d): %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return result

	var data: Dictionary = json.data
	result.id      = str(data.get("id", ""))
	result.trigger = data.get("trigger", {})

	for raw in data.get("steps", []):
		var step := CinematicStep.new()
		step.type = str(raw.get("type", ""))
		for key in (raw as Dictionary).keys():
			if key != "type":
				step.params[key] = raw[key]
		result.steps.append(step)

	return result
