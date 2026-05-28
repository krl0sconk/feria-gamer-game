# Utilidad temporal para instrumentar el reloj rítmico (Fase 0 del plan de debug).
class_name RhythmClockDebug
extends RefCounted

static var enabled: bool = false

static var _battle_start_wall_ms: int = 0
static var _last_frame_log_wall_ms: int = -1000
static var _last_mp_log_wall_ms: int = -1000


static func reset() -> void:
	_battle_start_wall_ms = Time.get_ticks_msec()
	_last_frame_log_wall_ms = -1000
	_last_mp_log_wall_ms = -1000


static func elapsed_wall_ms() -> int:
	return Time.get_ticks_msec() - _battle_start_wall_ms


static func log_frame(
	delta_ms: float,
	in_pre_roll: bool,
	pre_roll_elapsed_ms: float,
	pre_roll_total_ms: float,
	fallback_ms: float,
	audio_pos: float,
	current_ms: float,
	using_fallback: bool,
	audio_sync_warmup_ms: float
) -> void:
	if not enabled:
		return
	var wall_ms := elapsed_wall_ms()
	if wall_ms > 4000:
		return
	if wall_ms - _last_frame_log_wall_ms < 100:
		return
	_last_frame_log_wall_ms = wall_ms
	var audio_diff := audio_pos - fallback_ms if not using_fallback else 0.0
	print(
		"[CLOCK] t_wall=%dms delta=%.1fms preroll=%s preroll_elapsed=%.0f preroll_total=%.0f "
		% [wall_ms, delta_ms, in_pre_roll, pre_roll_elapsed_ms, pre_roll_total_ms]
		+ "fallback=%.0f audio=%.0f audio_diff=%.0f current=%.0f warmup=%.0f fallback_mode=%s"
		% [fallback_ms, audio_pos, audio_diff, current_ms, audio_sync_warmup_ms, using_fallback]
	)


static func log_input(
	action: String,
	current_ms: float,
	in_pre_roll: bool,
	queue_size: int,
	front_hit_ms: float
) -> void:
	if not enabled:
		return
	print(
		"[INPUT] action=%s current_ms=%.0f in_preroll=%s queue_size=%d front_hit_ms=%.0f"
		% [action, current_ms, in_pre_roll, queue_size, front_hit_ms]
	)


static func log_input_swallow(reason: String, current_ms: float, hit_ms: float) -> void:
	if not enabled:
		return
	print("[INPUT SWALLOW] reason=%s current_ms=%.0f hit_ms=%.0f delta=%.0fms" % [
		reason, current_ms, hit_ms, current_ms - hit_ms
	])


static func log_automiss(note_time_ms: float, current_ms: float) -> void:
	if not enabled:
		return
	print("[CLOCK AUTOMISS] note.time_ms=%.0f current_ms=%.0f delta=%.0fms" % [
		note_time_ms, current_ms, current_ms - note_time_ms
	])


static func log_music_player(
	playback_s: float,
	since_last_mix_s: float,
	output_latency_s: float,
	result_ms: float
) -> void:
	if not enabled:
		return
	var wall_ms := elapsed_wall_ms()
	if wall_ms - _last_mp_log_wall_ms < 1000:
		return
	_last_mp_log_wall_ms = wall_ms
	print(
		"[MP] t_wall=%dms playback=%.3fs since_last_mix=%.3fs output_latency=%.3fs result=%.0fms"
		% [wall_ms, playback_s, since_last_mix_s, output_latency_s, result_ms]
	)


static func log_hud(
	arrow_travel_ms: float,
	target_y: float,
	spawn_y: float,
	notes_scale: Vector2
) -> void:
	if not enabled:
		return
	print(
		"[HUD] arrow_travel_ms=%.0f target_y=%.1f spawn_y=%.1f notes_scale=%s"
		% [arrow_travel_ms, target_y, spawn_y, notes_scale]
	)
