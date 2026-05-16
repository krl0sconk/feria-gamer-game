extends Node

const SLOTS: int = 3
const SLOT_PATH_FMT: String = "user://save_slot_%d.json"
const TEMP_SUFFIX: String = ".tmp"

func _ready() -> void:
    pass

func _slot_path(idx: int) -> String:
    return SLOT_PATH_FMT % idx

func save_slot(slot_idx: int, payload: Dictionary = {}) -> bool:
    if slot_idx < 1 or slot_idx > SLOTS:
        push_error("SaveManager.save_slot: slot fuera de rango: %d" % slot_idx)
        return false

    if typeof(payload) == TYPE_DICTIONARY and payload.size() == 0:
        payload = _build_default_payload(slot_idx)

    var path: String = _slot_path(slot_idx)
    var tmp: String = path + TEMP_SUFFIX
    var json_text: String = JSON.stringify(payload, "\t")

    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_error("SaveManager: no pudo abrir temp %s" % tmp)
        return false
    f.store_string(json_text)
    f.close()

    if FileAccess.file_exists(path):
        var dir_rm := DirAccess.open("user://")
        if dir_rm == null:
            push_error("SaveManager: no pudo abrir user:// para eliminar archivo previo")
            return false
        var prev_name := path.get_file()
        var rem_res := dir_rm.remove(prev_name)
        if rem_res != OK:
            push_error("SaveManager: fallo eliminando %s (err=%s)" % [prev_name, str(rem_res)])
            return false

    # Intentamos renombrar el archivo temp al destino final usando DirAccess
    var dir := DirAccess.open("user://")
    if dir == null:
        push_error("SaveManager: no pudo abrir user:// para renombrar")
        return false
    var tmp_name := tmp.get_file()
    var final_name := path.get_file()
    var rename_res := dir.rename(tmp_name, final_name)
    if rename_res != OK:
        push_error("SaveManager: fallo renombrando %s -> %s (err=%s)" % [tmp_name, final_name, str(rename_res)])
        return false
    return true


func load_slot(slot_idx: int) -> Dictionary:
    var path: String = _slot_path(slot_idx)
    if not FileAccess.file_exists(path):
        return {}
    var text: String = FileAccess.get_file_as_string(path)
    var json := JSON.new()
    if json.parse(text) != OK:
        push_error("SaveManager: JSON invalido en %s" % path)
        return {}
    if typeof(json.data) != TYPE_DICTIONARY:
        return {}
    return json.data


func delete_slot(slot_idx: int) -> bool:
    var path: String = _slot_path(slot_idx)
    if FileAccess.file_exists(path):
        var dir_rm := DirAccess.open("user://")
        if dir_rm == null:
            return false
        var fname := path.get_file()
        var res := dir_rm.remove(fname)
        return res == OK
    return false


func list_slots() -> Array:
    var out: Array = []
    for i in range(1, SLOTS + 1):
        var p := _slot_path(i)
        out.append({"slot": i, "path": p, "exists": FileAccess.file_exists(p)})
    return out


func _build_default_payload(slot_idx: int) -> Dictionary:
    var meta := {"slot_id": slot_idx, "updated_at": 0}
    var player_data := {"scene_path": "", "position": {"x": 0.0, "y": 0.0}, "selected_skin": ""}
    var gm_node := get_node_or_null("/root/Gamemanager")
    if gm_node != null:
        player_data["selected_skin"] = gm_node.selectedskin
    var scene := get_tree().current_scene
    if scene != null:
        # `scene_file_path` existe en instancias de escena; si está vacío no pasa nada
        player_data["scene_path"] = str(scene.scene_file_path)
    var player := get_tree().get_first_node_in_group("player")
    if player != null and player is Node2D:
        var gp: Vector2 = (player as Node2D).global_position
        player_data["position"] = {"x": float(gp.x), "y": float(gp.y)}

    var quests_data: Array = []
    var qm_node := get_node_or_null("/root/QuestManager")
    if qm_node != null and qm_node.has_method("serialize_state"):
        quests_data = qm_node.serialize_state()

    var out := {
        "save_version": 1,
        "metadata": meta,
        "player": player_data,
        "quests": quests_data,
        "scores": {},
        "world_flags": {}
    }
    return out
