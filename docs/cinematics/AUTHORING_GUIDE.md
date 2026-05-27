# Guía de autoría — Sistema de cinemáticas

> Beat the Bully · Godot 4.6 · JSON + escena (sin coords manuales)

**Guía principal con ejemplos paso a paso:** [`GUIA_COMPLETA_CINEMATICAS.md`](GUIA_COMPLETA_CINEMATICAS.md)

Esta guía es la referencia de comandos y triggers. Para el tutorial completo (bully + compañera + plugin), usa la guía principal.

---

## 1. Principios

| Regla | Detalle |
|-------|---------|
| **Destinos por nodo** | Usa `Marker2D`, `WaypointPath` o cualquier `Node2D` en escena. Evita `[x, y]` en JSON. |
| **Triggers en escena** | Preferir `ScriptedTrigger` (Area2D) sobre `"trigger": { "type": "on_area_entered" }` en JSON. |
| **Una cinemática activa** | `Gamemanager.request_cinematic()` encola; no se solapan. |
| **Skip** | Tecla **E** (`Interact`) durante la reproducción (salvo `allow_skip = false`). |
| **NodePath** | Todos los `node` / `target` / `to_node` son rutas **desde la raíz de la escena del mapa**. |

---

## 2. Formato JSON

```json
{
  "version": 1,
  "id": "mi_cinematica",
  "trigger": { "type": "on_scene_ready", "delay": 0.3 },
  "steps": [
    { "type": "disable_player" },
    { "type": "dialogue", "path": "res://assets/dialogues/npc.json", "id": "intro" },
    { "type": "enable_player" }
  ]
}
```

| Campo | Descripción |
|-------|-------------|
| `id` | Identificador único. Usado por `play_once` → `Gamemanager.cinematics_played`. |
| `trigger` | Solo necesario si usas `CinematicPlayer` embebido con `auto_play = true`. Con `ScriptedTrigger`, el trigger es el Area2D. |
| `steps` | Lista ordenada de comandos (patrón Command). |

### Destinos en comandos de movimiento

Prioridad: `to_path` > `to_node` > `to` (fallback debug).

| Campo | Significado |
|-------|-------------|
| `to_path` | `WaypointPath` → primer punto (`move_node`) o ruta completa (`walk_path`) |
| `to_node` | Posición global de cualquier `Node2D` / `Marker2D` |
| `to` | `[x, y]` literal — solo emergencias |

---

## 3. Triggers (JSON embebido)

Usados cuando hay un `CinematicPlayer` en escena con `auto_play = true`.

| Tipo | Campos | Cuándo dispara |
|------|--------|----------------|
| `on_scene_ready` | `delay` (s, opcional) | Al cargar la escena |
| `on_quest_completed` | `quest_id` | Al completar esa quest |
| `on_area_entered` | `requires_quest` (opcional) | Legacy: hijo `TriggerArea` del CinematicPlayer |

**Recomendado:** instanciar `ScriptedTrigger.tscn` y omitir `trigger` en el JSON.

---

## 4. Nodos de escena (plantillas)

| Escena | Uso |
|--------|-----|
| `scenes/cinematic/ScriptedTrigger.tscn` | Disparador independiente → `Gamemanager.request_cinematic()` |
| `scenes/cinematic/ScriptedBarrier.tscn` | Muro invisible activable por `id` |
| `scenes/cinematic/WaypointPath.tscn` | Ruta con hijos `Marker2D` numerados |
| `scenes/cinematic/Follower.tscn` | Hijo del NPC — guía o sigue al jugador |
| `scenes/cinematic/InteractionIndicator.tscn` | `!` flotante (incluido en Interactable / ScriptedTrigger) |
| `scenes/cinematic/CinematicPlayer.tscn` | Reproductor + pantalla negra + diálogo embebido |

---

## 5. Tabla completa de comandos

### Presentación

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `fade_to_black` | `duration` | Fundido a negro |
| `fade_from_black` | `duration` | Fundido desde negro |
| `wait` | `seconds` | Espera fija |
| `letterbox` | `enabled`, `bar_height`, `duration` | Barras cinematográficas arriba/abajo |
| `show_node` | `node` | `visible = true` |
| `hide_node` | `node` | `visible = false` |

### Diálogo y jugador

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `dialogue` | `path`, `id` | Reproduce JSON de diálogo vía DialogueRunner embebido |
| `disable_player` | — | Bloquea movimiento (`player.disable_movement()`) |
| `enable_player` | — | Restaura movimiento |

### Movimiento (sin animación / con animación)

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `move_node` | `node`, destino (`to_node`/`to_path`/`to`), `duration` | Tween de posición |
| `walk_to` | `node`, destino, `speed` o `duration`, `animation`, `idle_animation`, `face_direction` | Camina con sprite animado |
| `walk_path` | `node`, `to_path`, `speed`, `wait_per_point`, animaciones | Recorre todos los waypoints |
| `face_direction` | `node`, `look_at_node` o `direction`, `idle_animation` | Gira sprite / `flip_h` |
| `play_animation` | `node`, `animation`, `wait_finish`, `idle_animation` | Reproduce animación puntual |
| `set_collision` | `node`, `enabled` | Activa/desactiva colliders |
| `wait_for_player_near` | `to_node` o `node`, `distance`, `timeout` | Espera proximidad del jugador |

### Barreras y batalla

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `enable_barrier` | `id` | Activa `ScriptedBarrier` con ese `id` |
| `disable_barrier` | `id` | Desactiva barrera |
| `start_battle` | `battle_scene_path`, `return_npc_id`, `chart_path`, `music_path` | Igual que `Interactable._queue_battle_transition()` |

### NPC guía (Follower)

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `follower_lead` | `node`, `path_node` (o `to_path`), `speed`, `wait_for_arrival` | Recorre WaypointPath; espera si el jugador se aleja |
| `follower_follow` | `node`, `target` (default `Player`), `speed` | Sigue a un nodo |
| `follower_stop` | `node` | Detiene el Follower |

### Cámara y audio

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `camera_focus` | `target` (NodePath), `duration`, `zoom` (0 = sin cambio) | Pan/zoom hacia nodo |
| `camera_release` | `duration` | Restaura cámara al player |
| `shake_camera` | `intensity`, `duration` | Sacudida |
| `play_sfx` | `stream_path`, `bus`, `volume_db`, `wait_finish` | One-shot de audio |

### Escena

| Comando | Parámetros | Descripción |
|---------|------------|-------------|
| `change_scene` | `path` | `change_scene_to_file` |

---

## 6. Convención de animaciones NPC

Los helpers prueban nombres flexibles. Recomendado por NPC:

- `idle` / `Idle`
- `walk` / `Walk` (con `flip_h` para izquierda/derecha)
- Opcional direccional: `walk_left`, `walk_right`, `walk_up`, `walk_down`

Si solo hay `walk`, el sistema infiere dirección y aplica `flip_h`.

---

## 7. Grupos de nodos

| Grupo | Quién se registra |
|-------|-------------------|
| `"player"` | `Player` (CharacterBody2D del mapa) |
| `"scripted_barriers"` | Cada `ScriptedBarrier` |
| `"interactables"` | Cada `Interactable` |

---

## 8. Patrón A — Bully bloquea el pasillo

### Escena

1. `ScriptedBarrier` en el pasillo → `id = "hallway_bully"`, `disabled_by_quests = ["bully_hallway_defeated"]`.
2. `Interactable` (bully) con diálogo + batalla.
3. `ScriptedTrigger` delante → `cinematic_json_path = hallway_bully_intro.json`.

### `hallway_bully_intro.json`

```json
{
  "id": "hallway_bully_intro",
  "steps": [
    { "type": "disable_player" },
    { "type": "camera_focus", "target": "Bullys/HallwayBully", "duration": 0.8, "zoom": 1.8 },
    { "type": "walk_to", "node": "Bullys/HallwayBully", "to_node": "Markers/BullyStopPos", "speed": 120 },
    { "type": "face_direction", "node": "Bullys/HallwayBully", "look_at_node": "Player" },
    { "type": "dialogue", "path": "res://assets/dialogues/hallway_bully.json", "id": "intro" },
    { "type": "start_battle", "chart_path": "res://assets/charts/coolguy.json", "battle_scene_path": "res://scenes/rhythm/cool_battle.tscn", "return_npc_id": "hallway_bully" }
  ]
}
```

### Tras ganar — `hallway_bully_outro.json` (trigger `on_quest_completed`)

```json
{
  "id": "hallway_bully_outro",
  "trigger": { "type": "on_quest_completed", "quest_id": "bully_hallway_defeated" },
  "steps": [
    { "type": "walk_to", "node": "Bullys/HallwayBully", "to_node": "Markers/BullyExit", "speed": 180 },
    { "type": "hide_node", "node": "Bullys/HallwayBully" },
    { "type": "disable_barrier", "id": "hallway_bully" },
    { "type": "camera_release", "duration": 0.5 },
    { "type": "enable_player" }
  ]
}
```

---

## 9. Patrón B — Compañera guía al lab

### Escena

1. NPC con hijo `Follower.tscn`.
2. `WaypointPath` hijo o en la escena → p. ej. `Companion/RouteToLab`.
3. `ScriptedTrigger` o `CinematicPlayer` con trigger `on_quest_completed`.

### `companion_to_lab.json`

```json
{
  "id": "companion_to_lab",
  "trigger": { "type": "on_quest_completed", "quest_id": "met_companion" },
  "steps": [
    { "type": "dialogue", "path": "res://assets/dialogues/companion.json", "id": "lets_go" },
    { "type": "enable_player" },
    { "type": "follower_lead", "node": "Companion", "path_node": "Companion/RouteToLab", "speed": 110, "wait_for_arrival": true },
    { "type": "follower_stop", "node": "Companion" },
    { "type": "dialogue", "path": "res://assets/dialogues/companion.json", "id": "we_are_here" }
  ]
}
```

El Follower espera automáticamente si el jugador supera `wait_distance` (96 px por defecto).

---

## 10. Indicador `!`

- Modo **AUTO**: visible cuando hay interacción/cinemática pendiente.
- `show_indicator = false` en `Interactable` o `ScriptedTrigger` para ocultar.
- Hijo `InteractionIndicator`: ajusta `symbol`, `vertical_offset`, bob.

---

## 11. Skip y señales

| Señal | Cuándo |
|-------|--------|
| `cinematic_started(id)` | Al iniciar |
| `cinematic_finished(id)` | Al terminar (normal o skip) |
| `cinematic_skipped(id)` | Solo si el jugador saltó con E |

`CinematicPlayer.allow_skip` (default `true`).

---

## 12. Archivos del sistema

```
scripts/cinematic/
├── cinematic_loader.gd
├── cinematic_player.gd
├── cinematic_actor.gd
├── cinematic_camera.gd
├── cinematic_target_resolver.gd
├── waypoint_path.gd
├── scripted_trigger.gd
├── scripted_barrier.gd
├── follower.gd
└── interaction_indicator.gd

assets/cinematics/     ← JSON de secuencias (convención)
docs/cinematics/       ← esta guía + plan + quickstart
```

---

## 13. Checklist antes de probar

- [ ] Rutas `node` / `target` existen desde la raíz de la escena del mapa
- [ ] Waypoints colocados en el editor (no coords en JSON)
- [ ] `ScriptedBarrier.id` único en la escena
- [ ] `return_npc_id` coincide con `Interactable.id` si hay batalla
- [ ] JSON de diálogo referenciado existe
- [ ] Quest IDs en triggers/filtros coinciden con `QuestManager`

---

*Beat the Bully — V Feria Gamer 2026 · Universidad del Norte*
