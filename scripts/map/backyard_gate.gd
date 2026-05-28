## Agrupa la barricada visual, la barrera física y el cartel interactuable del patio.
extends Node2D

@export var unlock_quest: String = "5.1.1"

@onready var _visuals: Node2D = $BarricadeVisual
@onready var _sign: Node = $GateSign


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if QuestManager.has_signal("quest_activated"):
		QuestManager.quest_activated.connect(_on_quest_changed)
	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_quest_changed)
	if QuestManager.has_signal("active_quests_changed"):
		QuestManager.active_quests_changed.connect(_on_quest_changed)
	call_deferred("_refresh")


func _on_quest_changed(_quest_id: String = "") -> void:
	call_deferred("_refresh")


func _refresh() -> void:
	var unlocked := _is_unlocked()
	if _visuals != null:
		_visuals.visible = not unlocked
	if _sign is Area2D:
		var area := _sign as Area2D
		area.visible = not unlocked
		area.monitoring = not unlocked
		area.monitorable = not unlocked
	elif _sign != null:
		_sign.visible = not unlocked


func _is_unlocked() -> bool:
	var qid := str(unlock_quest).strip_edges()
	if qid.is_empty():
		return true
	return QuestManager.is_active(qid) or QuestManager.is_completed(qid)
