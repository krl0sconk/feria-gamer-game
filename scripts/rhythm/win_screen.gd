# Pantalla de victoria tras una batalla rítmica.
#
# Flujo:
#  - `Battle` detecta victoria → setea `Gamemanager.pending_dialogue_result = "win"`,
#    vuelca las stats en `Gamemanager.pending_battle_stats` y cambia a esta escena.
#  - Esta pantalla muestra el desglose (perfects/goods/misses + score + highscore)
#    y un botón "Continuar".
#  - "Continuar" → `change_scene_to_file(Gamemanager.return_scene_path)` → el
#    Map reanuda el diálogo de victoria del NPC correspondiente.
#
# Responsabilidad única: vista de "ganaste" + routear al Map.
class_name WinScreen
extends Control

@export_file("*.tscn") var fallback_scene_path: String = "res://scenes/map/map.tscn"
@export var continue_button_path: NodePath = NodePath("Panel/VBox/ContinueButton")
@export var sfx_player_path: NodePath = NodePath("SfxPlayer")
@export var perfects_label_path: NodePath = NodePath("Panel/VBox/Stats/PerfectsLabel")
@export var goods_label_path: NodePath = NodePath("Panel/VBox/Stats/GoodsLabel")
@export var misses_label_path: NodePath = NodePath("Panel/VBox/Stats/MissesLabel")
@export var score_label_path: NodePath = NodePath("Panel/VBox/ScoreLabel")
@export var highscore_label_path: NodePath = NodePath("Panel/VBox/HighscoreLabel")


func _ready() -> void:
	var btn := get_node_or_null(continue_button_path) as Button
	if btn != null:
		btn.pressed.connect(_on_continue_pressed)
		# Focus inicial para que joystick/teclado puedan navegar/confirmar
		# desde el primer frame sin tocar el mouse.
		btn.grab_focus()
	else:
		push_warning("WinScreen: no se encontró el botón en '%s'." % str(continue_button_path))
	var sfx := get_node_or_null(sfx_player_path) as AudioStreamPlayer
	if sfx != null and sfx.stream != null:
		sfx.play()
	_populate_stats()


func _populate_stats() -> void:
	var stats: Dictionary = Gamemanager.pending_battle_stats
	var score: int    = int(stats.get("score", 0))
	var perfects: int = int(stats.get("perfects", 0))
	var goods: int    = int(stats.get("goods", 0))
	var misses: int   = int(stats.get("misses", 0))
	var chart_path: String = str(stats.get("chart_path", ""))

	_set_label(perfects_label_path, "Perfects: %d" % perfects)
	_set_label(goods_label_path,    "Goods: %d"    % goods)
	_set_label(misses_label_path,   "Misses: %d"   % misses)
	_set_label(score_label_path,    "Score: %d"    % score)

	var hs: Dictionary = Gamemanager.record_highscore(chart_path, score)
	var hs_text: String
	if bool(hs.get("is_new", false)):
		hs_text = "¡NUEVO RÉCORD!  %d" % int(hs.get("current", score))
	else:
		hs_text = "Récord: %d" % int(hs.get("current", 0))
	_set_label(highscore_label_path, hs_text)


func _set_label(path: NodePath, text: String) -> void:
	var lbl := get_node_or_null(path) as Label
	if lbl != null:
		lbl.text = text


func _on_continue_pressed() -> void:
	var target: String = Gamemanager.return_scene_path
	if target.is_empty():
		target = fallback_scene_path
	get_tree().change_scene_to_file(target)
