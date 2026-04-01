class_name BattleHUD
extends CanvasLayer

const ARROW_SCENE: PackedScene = preload("res://scenes/rhythm/NoteArrow.tscn")
const SPAWN_Y: float = -500.0
const ACTION_TO_DIRECTION: Dictionary = {
	"note_left": NoteArrow.Direction.LEFT,
	"note_down": NoteArrow.Direction.DOWN,
	"note_up": NoteArrow.Direction.UP,
	"note_right": NoteArrow.Direction.RIGHT,
}

@export var notes_container: NodePath = NodePath("")

var _arrow_queues: Dictionary = {
	"note_left": [], "note_down": [], "note_up": [], "note_right": [],
}
var _notes_node: Node2D
var _targets: Dictionary = {}
var _lane_x: Dictionary = {}
var _target_y: float = 0.0
var arrow_travel_ms: float = 0.0


func _ready() -> void:
	_notes_node = get_node(notes_container) as Node2D


func setup_targets(left: NoteTarget, down: NoteTarget, up: NoteTarget, right: NoteTarget) -> void:
	_targets = {
		"note_left": left, "note_down": down, "note_up": up, "note_right": right,
	}
	# Global → local del contenedor de flechas
	_lane_x = {
		"note_left":  _notes_node.to_local(left.global_position).x,
		"note_down":  _notes_node.to_local(down.global_position).x,
		"note_up":    _notes_node.to_local(up.global_position).x,
		"note_right": _notes_node.to_local(right.global_position).x,
	}
	_target_y = _notes_node.to_local(left.global_position).y
	arrow_travel_ms = (_target_y - SPAWN_Y) / 400.0 * 1000.0


func _on_composer_note_expected(note: NoteData) -> void:
	if not _lane_x.has(note.action):
		return
	var arrow: NoteArrow = ARROW_SCENE.instantiate() as NoteArrow
	arrow.direction = ACTION_TO_DIRECTION[note.action]
	arrow.target_y = _target_y
	arrow.position = Vector2(_lane_x[note.action], SPAWN_Y)
	arrow.expired.connect(_on_arrow_expired.bind(note.action, arrow))
	_notes_node.add_child(arrow)
	_arrow_queues[note.action].append(arrow)


func _on_judge_note_result(player_action: String, expected_action: String, _timing: String, success: bool) -> void:
	var flash_action: String = player_action if _targets.has(player_action) else expected_action
	if not _targets.has(flash_action):
		return
	if success:
		_targets[flash_action].flash_hit()
		_consume_oldest_arrow(expected_action)
	else:
		_targets[flash_action].flash_miss()


func _on_arrow_expired(action: String, arrow: NoteArrow) -> void:
	_arrow_queues[action].erase(arrow)


func _consume_oldest_arrow(action: String) -> void:
	var queue: Array = _arrow_queues[action]
	if queue.is_empty():
		return
	var obj = queue.pop_front()
	if is_instance_valid(obj):
		(obj as NoteArrow).destroy()
