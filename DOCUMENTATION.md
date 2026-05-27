# Beat the Bully — Technical Documentation

> Proyecto Final — Programación Orientada a Objetos (2026-10)
> Universidad del Norte · Barranquilla, Colombia
> V Feria Gamer — 28 de mayo de 2026
>
> Engine: Godot 4.6.1 · Language: GDScript (static typing) · Renderer: GL Compatibility · Resolution: 1280×720

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Global State — Gamemanager](#2-global-state--gamemanager)
3. [Navigation & Menu](#3-navigation--menu)
4. [World & Player](#4-world--player)
5. [Dialogue System](#5-dialogue-system)
6. [Quest System](#6-quest-system)
7. [Rhythm Battle System](#7-rhythm-battle-system)
8. [UI Components](#8-ui-components)
9. [Developer Tools](#9-developer-tools)
10. [Design Pattern: Strategy](#10-design-pattern-strategy)
11. [Cinematic System](#11-cinematic-system)

---

## 1. Architecture Overview

The game is divided into five top-level systems that communicate through Godot signals and a single shared singleton (`Gamemanager`). No system directly imports another system's nodes — coupling is kept to the signal boundary.

```
┌──────────────────────────────────────────────────────────┐
│                      AUTOLOADS                           │
│   Gamemanager   ·   QuestManager   ·   ColorblindOverlay │
└────────────────────────┬─────────────────────────────────┘
                         │ read/write cross-scene state
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌─────────┐   ┌──────────────┐  ┌─────────────┐
   │  Menu   │   │ Map / World  │  │   Rhythm    │
   │ System  │──▶│   + Player   │──▶│   Battle    │
   └─────────┘   │ + Dialogue   │  │   System    │
                 │ + Quests     │  └─────────────┘
                 └──────────────┘
```

**Scene flow:**

```
main_menu.tscn
    │ Start pressed
    ▼
select_pj.tscn  (character selection)
    │ skin chosen
    ▼
map.tscn  ◀──────────────────────────────────────────┐
    │ Player touches Interactable (E key)             │
    │ Dialogue plays                                  │
    │ battle_scene_path set → change_scene            │
    ▼                                                 │
battle.tscn                                           │
    │ Player wins                                     │
    ▼                                                 │
win_screen.tscn ─── Continue ──── return_scene_path ─┘
    │ Player loses
    ▼
(falls back directly to return_scene_path / map)
```

---

## 2. Global State — Gamemanager

**File:** `scripts/gamemanager.gd`
**Type:** Node (Autoload singleton)

The only piece of state that must survive scene changes lives here. It is intentionally minimal.

| Property | Type | Purpose |
|----------|------|---------|
| `selectedskin` | String | Skin key chosen in `select_pj.tscn`. Read by `Player._ready()`. |
| `return_scene_path` | String | Path of the Map scene to return to after a battle. Set by `Interactable` before transitioning. |
| `return_position` | Vector2 | Player world position at the moment the battle started. Used by Map to restore position. |
| `pending_npc_id` | String | ID of the NPC whose dialogue should resume on return. |
| `pending_dialogue_result` | String | `"win"`, `"lose"`, or `""`. Read by Map on re-entry to pick which dialogue branch to play. |

**`_ready()`** applies saved settings (`OptionsSettings.apply_saved()`) before the first scene renders.

**`clear_pending_dialogue()`** resets all battle-return fields. Called by Map after the result dialogue finishes.

---

## 3. Navigation & Menu

### 3.1 MainMenu

**File:** `scripts/main_menu.gd` · **Scene:** `scenes/menu/main_menu.tscn`

Entry point of the game (`run/main_scene`). Manages three buttons: Start, Options, Exit.

- **Options overlay**: instantiated from `scenes/menu/options.tscn` as an overlay child. A guard (`_options_overlay != null`) prevents double-instantiation on rapid clicks. While open, all menu buttons are set to `FOCUS_NONE` so joystick navigation cannot escape the panel.
- **`_on_options_closed()`**: nullifies the reference, restores button focus, and returns focus to the Options button as a visual confirmation.

### 3.2 Character Select (select_pj)

**File:** `scripts/select_pj.gd` · **Scene:** `scenes/menu/select_pj.tscn`

Two-button screen. Each button calls `selectedskin(skinname)` which writes to `Gamemanager.selectedskin` then transitions to the Map.

Available skins: `"idle (1)"` (button 1), `"idle pj2"` (button 2).

### 3.3 Options & OptionsSettings

**Files:** `scripts/menu/options.gd`, `scripts/menu/options_settings.gd`
**Scene:** `scenes/menu/options.tscn`

Split into two layers by responsibility:

**`options.gd`** — View layer. Populates UI controls from `OptionsSettings` data on open, reads UI state on Apply, emits `closed` signal when dismissed. Never touches files directly.

**`OptionsSettings`** — Data + persistence layer. Reads/writes `user://settings.cfg` via `ConfigFile`. Applies settings at runtime (resolution, window mode, audio bus volumes, colorblind shader).

| Setting | Options | Default |
|---------|---------|---------|
| Resolution | 1280×720, 1366×768, 1600×900, 1920×1080 | 1280×720 (index 0) |
| Window mode | Windowed, Borderless, Fullscreen | Windowed |
| Master volume | 0–100% | 80% |
| SFX volume | 0–100% | 80% |
| Colorblind mode | None, Protanopia, Deuteranopia, Tritanopia | None |

`apply_saved()` is called from `Gamemanager._ready()` so settings take effect before the first frame of any scene.

---

## 4. World & Player

### 4.1 Map

**File:** `scripts/map.gd` · **Scene:** `scenes/map/map.tscn`

Root of the overworld. Responsibilities:

1. **Wires `DialogueRunner` ↔ `Player`**: on `dialogue_started`, disables player movement; on `dialogue_finished`, re-enables it.
2. **Post-battle resumption**: on `_ready()`, checks `Gamemanager.pending_dialogue_result`. If non-empty, finds the NPC (`pending_npc_id`) in the `"interactables"` group, restores the player's position from `Gamemanager.return_position`, and calls `interactable.play_result_dialogue(result)` to trigger the win/lose dialogue branch. Then calls `Gamemanager.clear_pending_dialogue()`.

### 4.2 Player

**File:** `scripts/player.gd` · **Scene:** `scenes/map/player.tscn`

`CharacterBody2D` with top-down four-directional movement.

- **`SPEED`**: 300 px/s.
- **`movement_enabled`**: toggled by Map during dialogue. When `false`, `_physics_process` is a no-op.
- **Skin swapping**: on `_ready()`, reads `Gamemanager.selectedskin` and calls `set_animation(skin)` on its `AnimatedSprite2D` child.

---

## 5. Dialogue System

Four classes with strict separation of concerns. None of them know about gameplay state.

```
DialogueLoader          (static parser: JSON → DialogueData)
       │
       ▼
DialogueRunner          (sequencer: DialogueData → line-by-line playback)
       │  signals: dialogue_started, line_started, dialogue_finished
       ▼
DialogueBox             (view: renders one line with typewriter effect)
       │  signal: advance_requested
       ▲
Interactable            (trigger: wires NPC interaction → runner → battle)
```

### 5.1 DialogueLoader

**File:** `scripts/dialogue/dialogue_loader.gd`

Static class. Parses a JSON file into typed inner classes:

- **`DialogueLine`**: `speaker: String`, `text: String`.
- **`DialogueData`**: `version: String`, `dialogues: Dictionary` (id → Array[DialogueLine]).

`load_json(path)` handles file-not-found, empty-file, parse errors, and missing fields gracefully — always returns a valid (possibly empty) `DialogueData`.

### 5.2 DialogueBox

**File:** `scripts/dialogue/dialogue_box.gd` · **Scene:** `scenes/dialogue/dialogue_box.tscn`

Renders a single `DialogueLine` with a typewriter effect.

**Key exports:**

| Export | Default | Description |
|--------|---------|-------------|
| `chars_per_second` | 30.0 | Reveal speed |
| `sound_every_n_chars` | 2 | Voice blip frequency |
| `pitch_jitter` | 0.1 | Random pitch variation per blip |
| `dialogue_voice` | null | AudioStream for this line's speaker |

**Typewriter state**: `_chars_revealed` (int), `_accumulator` (float), `_typing_complete` (bool). Driven by `_process(delta)`.

Silent characters (punctuation) are skipped for voice blips via a regex constant `_SILENT_CHARS`.

**Input** (handled in `_unhandled_input`): first press while typing → `complete_line()` (reveal all instantly); second press when complete → emit `advance_requested`.

**Signal emitted:** `advance_requested` — consumed by `DialogueRunner`.

### 5.3 DialogueRunner

**File:** `scripts/dialogue/dialogue_runner.gd` · **Scene:** `scenes/dialogue/dialogue_runner.tscn`

Sequences lines from a `DialogueData` object.

**State:** `_current_lines: Array`, `_index: int`, `_active: bool`.

**Signals:**

| Signal | When |
|--------|------|
| `dialogue_started(id)` | `play()` is called |
| `line_started(line)` | Each new `DialogueLine` is sent to DialogueBox |
| `dialogue_finished(id)` | All lines exhausted |

**Flow:** `play(data, id, voice)` → `_advance()` (shows line N) → DialogueBox emits `advance_requested` → `_advance()` again → ... → `_finish()`.

### 5.4 Interactable

**File:** `scripts/dialogue/interactable.gd` · **Scene:** `scenes/dialogue/interactable.tscn`

`Area2D` placed on NPCs and interactive objects in the Map.

**Key exports:**

| Export | Description |
|--------|-------------|
| `id` | Unique string within this Map scene |
| `dialogue_json_path` | JSON file with all dialogues for this NPC |
| `intro_dialogue_id` | Dialogue to play on first interaction |
| `win_dialogue_id` | Dialogue to play when returning after winning |
| `lose_dialogue_id` | Dialogue to play when returning after losing |
| `battle_scene_path` | If set, triggers a battle after `intro` completes |
| `dialogue_voice` | AudioStream for this NPC's voice |

**Interaction flow:**
1. Player enters Area2D → `_player_in_range = true`.
2. Player presses `Interact` (E) → `_start_intro()` → `DialogueRunner.play(data, intro_dialogue_id)`.
3. On `dialogue_finished`: if `battle_scene_path` is set, calls `_queue_battle_transition()`.
4. `_queue_battle_transition()` writes `Gamemanager.return_scene_path`, `.return_position`, `.pending_npc_id`, then calls `change_scene_to_file(battle_scene_path)`.

**`play_result_dialogue(result)`** is called by Map on return to play `win_dialogue_id` or `lose_dialogue_id`.

---

## 6. Quest System

### 6.1 Quest (Resource)

**File:** `scripts/quests/quest.gd`

A `Resource` subclass representing a single quest entry.

**Enums:**

```gdscript
enum QuestVisibility { DESACTIVADA, OCULTA, VISIBLE }
enum QuestState      { ACTIVADA, EN_CURSO, COMPLETADA }
```

**Exports:** `id`, `title`, `description`, `requires_ids: Array[String]` (prerequisite quest IDs), `visibility`, `state`.

Emits `changed` signal when `state` is modified, allowing reactive UI updates.

### 6.2 QuestManager (Autoload)

**File:** `scripts/quests/quest_manager.gd`

Singleton that loads quests from a JSON file and manages progression.

**Signals:** `quest_activated(id)`, `quest_completed(id)`, `active_quests_changed`.

**`_refresh_unlocks()`**: called after any state change. Iterates all quests, checks if all entries in `requires_ids` are `COMPLETADA`, and activates quests whose prerequisites are met.

Quest state persists in a JSON save file at `user://`.

---

## 7. Rhythm Battle System

The battle system is composed of 14 classes with clearly separated roles. The data flows through a one-way pipeline: chart data → timing engine → input/judgment → state → visuals.

### 7.1 Full Data Flow

```
[chart JSON]
     │
     ▼
ChartLoader.load_json()
     │  ChartData { title, bpm, notes: Array[NoteData] }
     ▼
Composer.load_chart(notes)
     │  emits note_expected(NoteData)  ← anticipation_ms before hit time
     │
     ├──▶ BattleHUD._on_composer_note_expected()   → spawns NoteArrow
     └──▶ Battle._on_note_expected()               → queues note

MusicPlayer / FallbackTimer
     │  current time in ms
     ▼
Metronome.update_time(ms)   →   beat_hit signal (visual feedback)
Metronome.evaluate_timing() →   "Perfect" / "Good" / "Miss"

PlayerInput.button_pressed(action)
     │
     ▼
Battle._on_button_pressed()
     │  calls Metronome.evaluate_timing()
     ▼
Judge.evaluate(action, note, timing)
     │  emits note_result(player_action, expected_action, timing, success)
     │
     ├──▶ Referee.on_note_result()     → updates HP, score, combo (Strategy)
     └──▶ BattleHUD._on_judge_note_result() → flashes target, shows rating

Referee
     │  emits level_ended(player_won)
     ▼
Battle._on_level_ended()
     │  writes Gamemanager.pending_dialogue_result
     ▼
WinScreen.tscn  OR  fallback to Map
```

### 7.2 Data Layer

#### NoteData

**File:** `scripts/rhythm/note_data.gd`

Minimal `Resource` holding one note:

| Field | Type | Values |
|-------|------|--------|
| `time_ms` | float | Millisecond timestamp of the note |
| `action` | String | `"note_left"`, `"note_down"`, `"note_up"`, `"note_right"` |

#### ChartLoader / ChartData

**File:** `scripts/rhythm/chart_loader.gd`

Static class. `load_json(path)` returns a `ChartData` inner class:
- `title: String`, `bpm: float` (default 120.0), `notes: Array[NoteData]`.
- Notes are **sorted by `time_ms`** after parsing.

`save_json(path, data)` is provided for the in-editor chart tool.

#### HealthRules *(Strategy object — see §10)*

**File:** `scripts/rhythm/health_rules.gd`

`Resource` subclass. Configures HP behaviour. Assigned to `Referee` in the Inspector.

| Export | Default | Meaning |
|--------|---------|---------|
| `max_player_hp` | 100 | Starting and maximum HP |
| `miss_damage` | 10 | HP lost per Miss |
| `perfect_heal` | 0 | HP gained per Perfect (0 = disabled) |
| `good_heal` | 0 | HP gained per Good (0 = disabled) |

**Strategy method:**

```gdscript
func get_hp_delta(timing: String) -> int:
    match timing:
        "Perfect": return perfect_heal
        "Good":    return good_heal
        _:         return -miss_damage
```

Returns a signed delta: positive = heal, negative = damage.

#### ScoreRules *(Strategy object — see §10)*

**File:** `scripts/rhythm/score_rules.gd`

`Resource` subclass. Configures scoring. Assigned to `Referee` in the Inspector.

| Export | Default | Meaning |
|--------|---------|---------|
| `perfect_points` | 300 | Base points for Perfect |
| `good_points` | 100 | Base points for Good |
| `miss_points` | -50 | Points delta for Miss (negative) |
| `combo_bonus_per_hit` | 10 | Added per hit × current combo |
| `min_score` | 0 | Score floor — never goes negative |

**Strategy method:**

```gdscript
func calculate_points(timing: String, combo: int) -> int:
    match timing:
        "Perfect": return perfect_points + combo * combo_bonus_per_hit
        "Good":    return good_points    + combo * combo_bonus_per_hit
        _:         return miss_points
```

Combo bonus applies only on successful hits. Miss resets combo before this is called, so `combo` is always 0 on a miss.

### 7.3 Timing Engine

#### Metronome

**File:** `scripts/rhythm/metronome.gd`

Tracks song time and classifies timing accuracy.

| Export | Default | Description |
|--------|---------|-------------|
| `bpm` | — | Beats per minute (set from chart) |
| `window_perfect` | 50 ms | Max delta for a Perfect rating |
| `window_good` | 120 ms | Max delta for a Good rating |

**`evaluate_timing(current_ms, hit_ms) → String`**: returns `"Perfect"` if `|current_ms - hit_ms| ≤ window_perfect`, `"Good"` if `≤ window_good`, otherwise `"Miss"`.

**`update_time(current_ms)`**: tracks beat crossings and emits `beat_hit` signal for visual feedback.

#### Composer

**File:** `scripts/rhythm/composer.gd`

Iterates the sorted notes array and emits `note_expected(NoteData)` exactly `anticipation_ms` before each note's `time_ms`. This gives the BattleHUD time to spawn a falling arrow that arrives at the target at the right moment.

`anticipation_ms` is computed by BattleHUD from the arrow's travel distance and speed (400 px/s).

#### MusicPlayer

**File:** `scripts/rhythm/music_player.gd`

Thin wrapper over `AudioStreamPlayer`. Adds:
- `bpm` export (forwarded to Metronome).
- `get_position_ms() → float`: song position in milliseconds.
- Signals: `music_started`, `time_updated(ms)`.

**Platform behaviour for `get_position_ms()`:**
- **Desktop:** `get_playback_position() + AudioServer.get_time_since_last_mix()`, minus `AudioServer.get_output_latency()`.
- **Web (HTML5):** `get_playback_position()` only. On web, stream position often runs ahead of heard audio; Battle does not use it as the authoritative clock (see §7.7).

### 7.4 Input & Judgment

#### PlayerInput

**File:** `scripts/rhythm/player_input.gd`

Listens in `_process` for any of the four note actions and emits `button_pressed(action: String)`. It never touches note queues or timing — pure input relay.

Valid actions: `"note_left"`, `"note_down"`, `"note_up"`, `"note_right"`.

#### Judge

**File:** `scripts/rhythm/judge.gd`

Single `evaluate(player_action, expected_note, timing)` method. Succeeds if `player_action == expected_note.action` AND `timing != "Miss"`. Always emits `note_result(player_action, expected_action, timing, success)` regardless of outcome.

### 7.5 Game State

#### Referee *(Strategy context — see §10)*

**File:** `scripts/rhythm/referee.gd`

Maintains the authoritative game state: `_player_hp`, `_score`, `_combo`, `_max_combo`, `_level_over`.

**Signals:**

| Signal | Payload | When |
|--------|---------|------|
| `score_updated` | `score: int` | After every note result |
| `player_hp_updated` | `hp, max_hp: int` | After every note result |
| `combo_updated` | `combo, max_combo: int` | After every note result |
| `level_ended` | `player_won: bool` | HP hits 0 (false) or song ends alive (true) |

**`on_note_result(…)`** — core logic (delegates to strategies):
```
1. Normalize timing: if !success, treat as "Miss"
2. Update combo counter (increment on hit, reset on miss)
3. _score  += score_rules.calculate_points(t, _combo)   ← Strategy
4. _player_hp += health_rules.get_hp_delta(t)           ← Strategy
5. Apply floor/ceiling clamps
6. Emit all signals → check for defeat
```

**`declare_survival()`**: called by `Battle` when the last note has passed and the player is still alive. Emits `level_ended(true)`.

#### EnemyGauge

**File:** `scripts/rhythm/enemy_gauge.gd`

Visual-only. Receives `update_song_progress(ratio: float)` from `Battle._process()` and drains a progress bar from full to empty as the song plays. `enemy_hp_updated(hp, max_hp)` is emitted so BattleHUD can display it. Has no effect on win/loss logic.

### 7.6 Visuals

#### NoteArrow

**File:** `scripts/rhythm/note_arrow.gd` · **Scene:** `scenes/rhythm/note_arrow.tscn`

`Node2D` that falls downward at `speed` px/s (default 400.0). Rotated in `_ready()` based on `direction` (LEFT = −90°, DOWN = 180°, UP = 0°, RIGHT = 90°).

Emits `expired()` and calls `queue_free()` when it passes `target_y + 100`. `destroy()` is called by BattleHUD on a successful hit to remove it early.

#### NoteTarget

**File:** `scripts/rhythm/note_target.gd` · **Scene:** `scenes/rhythm/note_target.tscn`

Static indicator showing where arrows must be hit. Has four flash states: idle, press (player pressed), hit (successful), miss.

Flash duration is `flash_seconds` (default 0.1s). Uses a monotonic integer token to cancel in-flight coroutines if a new flash is requested before the previous one finishes — preventing visual race conditions.

#### BattleHUD

**File:** `scripts/rhythm/battle_hud.gd` · **Scene:** `scenes/rhythm/battle_hud.tscn`

`CanvasLayer` orchestrating all runtime visuals. Responsibilities:

- **Arrow spawning**: on `note_expected` → instantiates `NoteArrow`, sets its `target_y` and lane X position, tracks it in `_arrow_queues`.
- **Target flashing**: on `note_result` → calls `flash_hit()`, `flash_miss()`, or `flash_press()` on the corresponding `NoteTarget`.
- **HUD labels**: updates HP bars, score label, combo label. Combo label gets a pop-scale animation (1.5× for 0.18s) on each hit.
- **Rating feedback**: forwards note results to `RatingFeedback`.
- **Viewport scaling**: `_fit_root_to_viewport()` scales the HUD root to fill any viewport while maintaining the 1280×720 design layout.

`arrow_travel_ms` is computed from `(target_y - SPAWN_Y) / 400.0 * 1000.0` and forwarded to `Composer.anticipation_ms` so arrows arrive exactly on time.

#### RatingFeedback

**File:** `scripts/rhythm/rating_feedback.gd`

Popup showing "Perfect", "Good", or "Miss" text with a scale animation. Uses a `hide_token` (monotonic int) to cancel pending hide coroutines safely. Exports control appearance timing (`display_seconds = 0.55`, `pop_scale = 1.25`, `base_scale = 2.5`).

### 7.7 Orchestrator — Battle

**File:** `scripts/rhythm/battle.gd` · **Scene:** `scenes/rhythm/battle.tscn`

Root `Node2D` of the battle scene. Wires all subsystems together — it knows about all nodes but delegates all domain logic to them.

**Key exports:**

| Export | Default | Description |
|--------|---------|-------------|
| `chart_path` | test_chart.json | Chart to load |
| `lose_scene_path` | `""` | Scene on loss (empty = fallback to map) |
| `win_scene_path` | win_screen.tscn | Scene on win |
| `fallback_map_scene_path` | map.tscn | Ultimate fallback if other paths empty |
| `intro_delay_s` | 0.0 | Extra pause before music starts (on top of technical pre-roll) |
| `rhythm_clock_debug` | false | Verbose `[CLOCK]` / `[INPUT]` logs for timing diagnosis |

**Wiring in `_ready()`:**

```
Composer.note_expected → Battle._on_note_expected  (queues note)
                       → BattleHUD._on_composer_note_expected  (spawns arrow)
PlayerInput.button_pressed → Battle._on_button_pressed
                           → BattleHUD.on_player_pressed
Judge.note_result → Referee.on_note_result
                  → BattleHUD._on_judge_note_result
Referee.player_hp_updated → BattleHUD.on_player_hp_updated
Referee.score_updated     → BattleHUD.on_score_updated
Referee.combo_updated     → BattleHUD.on_combo_updated
EnemyGauge.enemy_hp_updated → BattleHUD.on_enemy_hp_updated
Referee.level_ended → Battle._on_level_ended
```

**Pending notes queues:** a `Dictionary` keyed by action string holds arrays of upcoming notes. `_process()` pops notes from these queues whose window has expired and calls `Judge.evaluate("", note, "Miss")` to register them as misses.

**Pre-roll:** before music starts, `current_ms` runs from `−arrow_travel_ms` up to `0`. The Composer spawns early notes so arrows have time to reach the target when the song begins. `anticipation_ms` equals `arrow_travel_ms` (computed by BattleHUD from spawn distance and arrow speed).

**Song clock (`current_ms`):**
- During pre-roll: driven by elapsed pre-roll time.
- **Desktop (with audio):** `_fallback_ms` advances each frame and is gently corrected toward `MusicPlayer.get_position_ms()` after a short warmup.
- **Web (HTML5):** `_using_fallback = true` after pre-roll — clock stays frame-based so it stays aligned with arrows (which also move by `delta`). Web audio position is not used as the authoritative clock because it can run ~130 ms ahead of visuals.
- **No audio stream:** same frame-based fallback as web; useful for chart testing without music.

**Survival detection:** once `current_ms ≥ _last_note_ms + window_good` and all queues are empty, `Referee.declare_survival()` is called — triggering `level_ended(true)`.

**Timing debug:** set `rhythm_clock_debug = true` on the Battle node and see `docs/debug/rhythm_clock_baseline.md`.

### 7.8 Battle Actors

**File:** `scenes/rhythm/battle_actors/player_battle.gd`
**Scenes:** `scenes/rhythm/battle_actors/player_battle.tscn`, `enemy_battle.tscn`

Simple `CharacterBody2D` for the battle background characters. Responds to arrow directional inputs (`ui_left`, `ui_down`, `ui_up`, `ui_right`) and plays the corresponding animation, returning to `"idle"` when it finishes.

### 7.9 Post-Battle Flow — WinScreen

**File:** `scripts/rhythm/win_screen.gd` · **Scene:** `scenes/rhythm/win_screen.tscn`

Shown after a win. A single "Continue" button calls `get_tree().change_scene_to_file(target)` where `target` is `Gamemanager.return_scene_path` (the Map scene), falling back to `fallback_scene_path` if that is empty.

On loss, `Battle._go_to_post_battle` routes to `lose_scene_path` (configurable per-battle in the Inspector) or directly to the Map if empty.

---

## 8. UI Components

### 8.1 ColorblindOverlay

**File:** `scripts/ui/colorblind_overlay.gd` · **Scene:** `scenes/ui/colorblind_overlay.tscn`

`CanvasLayer` autoload. Applies a full-screen GLSL shader simulating colour vision deficiency.

```gdscript
enum Mode { NONE, PROTANOPIA, DEUTERANOPIA, TRITANOPIA }
```

`set_mode(mode)` sets the `"mode"` uniform on the shader. `OptionsSettings` calls this when the player changes the accessibility setting.

### 8.2 KeychainButton

**File:** `scripts/ui/keychain_button.gd` · **Scene:** `scenes/ui/keychain_button.tscn`

Custom animated button. On highlight (mouse hover or keyboard focus), plays a pendulum swing through `swing_angles_deg` keyframes. On unhighlight, tweens back to `rest_angle_deg` (−3°).

| Export | Default | Description |
|--------|---------|-------------|
| `swing_angles_deg` | Array | Rotation keyframes for the swing |
| `rest_angle_deg` | −3.0 | Resting rotation |
| `swing_step_seconds` | 0.09 | Duration per keyframe |
| `recover_seconds` | 0.18 | Tween-back duration |

Tracks two independent highlight sources (`_mouse_over`, `_focus_in`) to avoid starting/stopping the animation when only one source changes while the other is still active.

Supports an optional hover SFX routed to a configurable audio bus.

---

## 9. Developer Tools

### 9.1 ChartEditor

**File:** `scripts/editor/chart_editor.gd` · **Scene:** `scenes/editor/chart_editor.tscn`

In-engine chart authoring tool. Allows loading audio, placing/deleting notes, and saving/loading JSON charts.

**Controls:**

| Key | Action |
|-----|--------|
| `P` | Toggle playback |
| `A` / `D` | Seek ±100 ms (±1000 ms with Shift) |
| `Arrow keys` | Place note in that lane at current time |
| `Delete` | Remove nearest note to playhead |
| `Ctrl+S` | Save chart |
| `−` / `=` | Decrease / increase playback speed |

Speed presets: 0.25×, 0.5×, 0.75×, 1.0×.

Visual layout: notes scroll vertically at `PX_PER_MS = 0.4` px/ms (400 px/s), matching the in-game arrow speed so the chart appears exactly as it will play.

### 9.2 QuestEditor

**File:** `scripts/editor/quest_editor.gd` · **Scene:** `scenes/editor/quest_editor.tscn`

In-engine quest authoring tool. Left panel: list of quests with New, Delete, Duplicate, and reorder buttons. Right panel: all fields for the selected quest (id, title, visibility, progress state, description, prerequisites list).

Includes DFS cycle detection when prerequisite IDs are modified — prevents circular dependency chains. Saves/loads the quest JSON file.

---

## 10. Design Pattern: Strategy

### 10.1 What is the Strategy Pattern?

The **Strategy** pattern (GoF, *Design Patterns*, 1994) defines a family of algorithms, encapsulates each one, and makes them interchangeable. It lets the algorithm vary independently from the clients that use it.

Three roles:
- **Context**: holds a reference to a strategy and delegates algorithm decisions to it.
- **Strategy interface**: declares the method(s) that every concrete strategy must implement.
- **Concrete strategies**: different implementations of the algorithm.

In a statically-typed language this is enforced via an interface or abstract class. In GDScript (duck-typed), the contract is enforced by convention — any Resource assigned to `Referee` as `score_rules` must expose `calculate_points(timing, combo)`, and any Resource assigned as `health_rules` must expose `get_hp_delta(timing)`.

### 10.2 Where It Is Applied

The pattern lives in three files:

| Role | Class | File |
|------|-------|------|
| Context | `Referee` | `scripts/rhythm/referee.gd` |
| Concrete strategy | `ScoreRules` | `scripts/rhythm/score_rules.gd` |
| Concrete strategy | `HealthRules` | `scripts/rhythm/health_rules.gd` |

### 10.3 The Problem It Solves

Before the pattern was applied, `Referee` contained the scoring and HP formulas inline:

```gdscript
# Before — Referee knew the formula
func on_note_result(…, timing, success):
    if success and timing == "Perfect":
        _apply_hit(score_rules.perfect_points, health_rules.perfect_heal)
    elif success and timing == "Good":
        _apply_hit(score_rules.good_points, health_rules.good_heal)
    else:
        _apply_miss()

func _apply_hit(base_points, heal):
    _combo += 1
    _score = max(_score + base_points + _combo * score_rules.combo_bonus_per_hit, …)
    if heal > 0: _player_hp = min(_player_hp + heal, …)

func _apply_miss():
    _combo = 0
    _score = max(_score + score_rules.miss_points, …)
    _player_hp = max(_player_hp - health_rules.miss_damage, 0)
```

**Problems:**
- `Referee` had to know that "Perfect" maps to `perfect_points` and "Good" maps to `good_points` — knowledge that belongs to `ScoreRules`.
- Adding a new timing grade (e.g. `"Flawless"`) required editing `Referee`, not just the rules object.
- `HealthRules` and `ScoreRules` were pure data containers with no behaviour — they could not be subclassed to provide a different formula.
- The Open/Closed Principle was violated: to change the scoring algorithm you had to open `Referee`.

### 10.4 The Solution

**Strategy methods were added to the rules classes:**

```gdscript
# ScoreRules — now owns the scoring formula
func calculate_points(timing: String, combo: int) -> int:
    match timing:
        "Perfect": return perfect_points + combo * combo_bonus_per_hit
        "Good":    return good_points    + combo * combo_bonus_per_hit
        _:         return miss_points

# HealthRules — now owns the HP formula
func get_hp_delta(timing: String) -> int:
    match timing:
        "Perfect": return perfect_heal
        "Good":    return good_heal
        _:         return -miss_damage
```

**Referee was simplified to delegate:**

```gdscript
# After — Referee only tracks state and asks strategies for values
func on_note_result(…, timing, success):
    var t := timing if success else "Miss"
    if t != "Miss":
        _combo += 1
        if _combo > _max_combo: _max_combo = _combo
    else:
        _combo = 0
    _score    = max(_score    + score_rules.calculate_points(t, _combo), score_rules.min_score)
    _player_hp = clamp(_player_hp + health_rules.get_hp_delta(t), 0, health_rules.max_player_hp)
    _emit_all()
    _check_defeat()
```

`Referee` no longer knows any formula. It only knows *when* to ask.

### 10.5 Mathematical Equivalence

Both implementations produce identical results:

| Event | Old path | New path |
|-------|----------|----------|
| Perfect hit | `_apply_hit(perfect_points, perfect_heal)` → combo++, score += perfect_points + combo×bonus, hp += perfect_heal | combo++, score += `calculate_points("Perfect", combo)` = perfect_points + combo×bonus, hp += `get_hp_delta("Perfect")` = perfect_heal |
| Good hit | `_apply_hit(good_points, good_heal)` | combo++, score += good_points + combo×bonus, hp += good_heal |
| Miss | `_apply_miss()` → combo=0, score += miss_points, hp -= miss_damage | combo=0, score += `calculate_points("Miss", 0)` = miss_points, hp += `get_hp_delta("Miss")` = −miss_damage |

### 10.6 Why Strategy over the Other Candidates

Four patterns were evaluated against the codebase:

| Pattern | Location | Verdict |
|---------|----------|---------|
| **Strategy** ✓ | `ScoreRules` + `HealthRules` → `Referee` | Best fit. Infrastructure already in place (injected Resources). Pure additive refactor — no new files, no structural changes. Moves formula knowledge to the right owner. |
| State | `battle.gd` lifecycle flags, `dialogue_box.gd` `_typing_complete` | Would require new state classes and restructuring of both files. Higher risk, more invasive. |
| Adapter | Audio vs. fallback timer in `battle.gd` | Valid candidate — would wrap `MusicPlayer` and the delta-accumulator behind a unified `TimeProvider`. But requires new files and rewiring `Battle._process()`. |
| Command | `PlayerInput` note actions | Adds `NoteCommand` objects for each button press. Enables replay/undo in theory, but those features are not needed in a rhythm game. Over-engineering. |

The **Strategy** fit was chosen because:
1. The scaffolding was already present (Resources injected via the Inspector — a built-in dependency injection mechanism).
2. The refactor was purely additive: methods moved, nothing removed from the public API.
3. It enforces the **Open/Closed Principle**: to change scoring (e.g. exponential combo multiplier instead of linear), you create a new `.tres` file and assign it in the Inspector — `Referee` is never touched.
4. It is the most immediately demonstrable pattern: a new difficulty preset requires only a new `.tres` asset.

### 10.7 Extensibility Demonstration

To add a "Hard Mode" with no healing and double miss damage:

```gdscript
# hard_health_rules.gd  (new file)
class_name HardHealthRules
extends HealthRules

func get_hp_delta(timing: String) -> int:
    if timing == "Miss":
        return -miss_damage * 2   # double penalty
    return 0                      # no healing regardless of perfect_heal
```

Assign `hard_health_rules.tres` to the `Referee.health_rules` slot in the Inspector. `Referee` needs zero changes.

---

## 11. Cinematic System

JSON-driven cutscenes for the Map. Uses the **Command pattern**: each step in a cinematic JSON maps to a handler in `CinematicPlayer._commands`. Scene references (`Marker2D`, `WaypointPath`, node paths) replace hard-coded coordinates.

**Authoring guide (Spanish, full reference):** `docs/cinematics/GUIA_COMPLETA_CINEMATICAS.md`  
**Command tables:** `docs/cinematics/AUTHORING_GUIDE.md`  
**Quick examples:** `docs/cinematics/USAGE_QUICKSTART.md`

```
CinematicLoader          (static parser: JSON → CinematicData + CinematicStep)
       │
       ▼
CinematicPlayer          (CanvasLayer: Command executor, fade, letterbox, skip)
       │  uses helpers: CinematicActor, CinematicCamera, CinematicTargetResolver
       │  signals: cinematic_started, cinematic_finished, cinematic_skipped
       ▼
Scene authoring nodes: ScriptedTrigger, ScriptedBarrier, WaypointPath,
                       Follower, InteractionIndicator
```

### 11.1 Core Classes

| File | Class | Base | Role |
|------|-------|------|------|
| `cinematic_loader.gd` | CinematicLoader + CinematicStep + CinematicData | RefCounted | Parses cinematic JSON |
| `cinematic_player.gd` | CinematicPlayer | CanvasLayer | Executes steps sequentially; embedded DialogueRunner |
| `cinematic_actor.gd` | CinematicActor | RefCounted | Walk/face/animation helpers for NPC sprites |
| `cinematic_camera.gd` | CinematicCamera | RefCounted | Pan, zoom, shake, restore player camera |
| `cinematic_target_resolver.gd` | CinematicTargetResolver | RefCounted | Resolves `to_path` / `to_node` / `to` |
| `waypoint_path.gd` | WaypointPath | Node2D | Editable route (`@tool`); child Marker2D nodes |
| `scripted_trigger.gd` | ScriptedTrigger | Area2D | Independent trigger → `Gamemanager.request_cinematic()` |
| `scripted_barrier.gd` | ScriptedBarrier | StaticBody2D | Toggleable invisible wall by `id` |
| `follower.gd` | Follower | Node2D | NPC lead/follow along WaypointPath |
| `interaction_indicator.gd` | InteractionIndicator | Node2D | Floating `!` bob over pending interactions |

Template scenes live in `scenes/cinematic/`.

### 11.2 Triggers

**In-scene (recommended):** place `ScriptedTrigger.tscn`, resize its `CollisionShape2D`, assign `cinematic_json_path`. Optional: `requires_quest`, `blocked_if_quest_completed`, `play_once`, `show_indicator`.

**Embedded in JSON** (when using `CinematicPlayer` with `auto_play = true`):

| Trigger type | Fields | Fires when |
|--------------|--------|------------|
| `on_scene_ready` | `delay` (optional seconds) | Scene loads |
| `on_quest_completed` | `quest_id` | Quest completes |
| `on_area_entered` | `requires_quest` (optional) | Legacy `TriggerArea` child entered by player |

### 11.3 Destination Convention

Priority: **`to_path`** > **`to_node`** > **`to`** (literal `[x,y]` debug fallback only).

| Field | Resolves to |
|-------|-------------|
| `to_path` | First waypoint or full path from a `WaypointPath` node |
| `to_node` | Global position of any `Node2D` / `Marker2D` |
| `to` | Raw coordinates (avoid in production) |

### 11.4 Command Reference

**Presentation:** `fade_to_black`, `fade_from_black`, `wait`, `letterbox`, `show_node`, `hide_node`

**Dialogue / player:** `dialogue`, `disable_player`, `enable_player`

**Movement:** `move_node`, `walk_to`, `walk_path`, `face_direction`, `play_animation`, `set_collision`, `wait_for_player_near`

**Barriers / battle:** `enable_barrier`, `disable_barrier`, `start_battle`

**Follower:** `follower_lead`, `follower_follow`, `follower_stop`

**Camera / audio:** `camera_focus`, `camera_release`, `shake_camera`, `play_sfx`

**Scene:** `change_scene`

Full parameter tables: `docs/cinematics/AUTHORING_GUIDE.md` §5.

### 11.5 Gamemanager Integration

| API / field | Purpose |
|-------------|---------|
| `request_cinematic(path, options)` | Enqueues playback; strict queue, no overlap |
| `cinematics_played: Dictionary` | Tracks one-shot cinematics by JSON `id` |
| `active_cinematic_id: String` | Currently playing cinematic id |
| `CinematicPlayer.play_from(path, parent, once)` | One-shot player instance (used by ScriptedTrigger) |

`start_battle` step mirrors `Interactable._queue_battle_transition()`: sets `return_scene_path`, `return_position`, `pending_npc_id`, chart/music overrides, then changes to the battle scene.

### 11.6 Skip

While `_is_playing`, pressing **`Interact` (E)** calls `CinematicPlayer.stop()` when `allow_skip = true` (default). Emits `cinematic_skipped` then `cinematic_finished`. Aborts embedded dialogue via `DialogueRunner.abort()`, kills tweens, resets camera and letterbox.

### 11.7 NPC Animation Convention

Flexible name resolution in `CinematicActor`: tries `walk`, `Walk`, `walk_left`, `Idle`, etc. Recommended per NPC: `idle` + `walk` (with `flip_h` for horizontal facing).

### 11.8 Node Groups

| Group | Members |
|-------|---------|
| `"player"` | Map Player CharacterBody2D |
| `"scripted_barriers"` | All ScriptedBarrier instances |
| `"interactables"` | All Interactable instances |

---

*Document generated for Beat the Bully — V Feria Gamer 2026 · Universidad del Norte.*
