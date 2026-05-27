# Plan v2 — Cinemáticas Avanzadas con Authoring Visual

> Beat the Bully · Sistema de cinemáticas extendido  
> Estado: Fases 0–8 implementadas ✅

## Resumen

Extender `CinematicPlayer` (patrón Command) para secuencias narrativas complejas: sprites animados, barreras, NPCs guía, triggers múltiples e indicadores `!`. **Principio clave:** referencias por nodo en escena (`Marker2D`, `WaypointPath`), no coordenadas literales en JSON.

## Casos de uso

| Caso | Descripción |
|------|-------------|
| **A. Bullys bloquean pasillo** | Barrera invisible + bully camina, dialoga, batalla; al ganar se abre el pasillo |
| **B. Compañera guía al lab** | NPC recorre `WaypointPath`, espera al jugador, diálogo al llegar |

---

## FASE 0 — Authoring primitives ✅

### Entregables
- `WaypointPath` (`@tool`) — hijos `Marker2D`, líneas numeradas en editor
- `CinematicTargetResolver` — resuelve `to_node` / `to_path` / `to` fallback
- `move_node` actualizado para usar el resolver

### Convención de destino en comandos

| Campo | Significado |
|-------|-------------|
| `to_path` | NodePath a `WaypointPath` → primer waypoint (o lista completa en `walk_path`) |
| `to_node` | NodePath a cualquier nodo 2D → su posición global |
| `to` | `[x, y]` literal — solo fallback/debug |

Prioridad: `to_path` > `to_node` > `to`.

---

## FASE 1 — ScriptedTrigger múltiple ✅

### Entregables
- `ScriptedTrigger` (`@tool`) — Area2D independiente con preview en editor
- `Gamemanager.request_cinematic()` — cola, evita solapamientos
- `CinematicPlayer.play_from()` — reproducción one-shot desde cualquier escena

### Uso
1. Instanciar `scenes/cinematic/ScriptedTrigger.tscn` en el mapa
2. Ajustar `CollisionShape2D` en el editor
3. Asignar `cinematic_json_path`
4. Opcional: `requires_quest`, `blocked_if_quest_completed`, `play_once`

---

## FASE 2 — Comandos de animación ✅

| Comando | Params |
|---------|--------|
| `walk_to` | `node`, `to_node`/`to_path`, `speed`, `duration`, `animation`, `idle_animation`, `face_direction` |
| `walk_path` | `node`, `to_path`, `speed`, `wait_per_point`, `animation`, `idle_animation` |
| `face_direction` | `node`, `look_at_node` o `direction`, `idle_animation` |
| `play_animation` | `node`, `animation`, `wait_finish`, `idle_animation` |
| `set_collision` | `node`, `enabled` |
| `wait_for_player_near` | `to_node`/`node`, `distance`, `timeout` |

Helper: `cinematic_actor.gd`.

---

## FASE 3 — ScriptedBarrier ✅

- `ScriptedBarrier` (`@tool`) — muro invisible con preview rayado
- Comandos: `enable_barrier`, `disable_barrier`, `start_battle`
- Patrón hallway bully (JSON de ejemplo al final)

---

## FASE 4 — Follower / NPC líder ✅

- Componente `Follower` — `lead_along(WaypointPath)`
- Comandos: `follower_lead`, `follower_follow`, `follower_stop`
- Patrón compañera al lab

---

## FASE 5 — Indicador `!` ✅

- `InteractionIndicator` — bob animado sobre NPC/trigger
- Modo `AUTO` según `Interactable` / `ScriptedTrigger`
- Export `show_indicator` en interactables y triggers

---

## FASE 6 — Cámara, SFX, skip ✅

Comandos: `camera_focus`, `camera_release`, `shake_camera`, `letterbox`, `play_sfx`. Skip con `Interact` (E).

---

## FASE 7 — Plugin editor ✅

Toolbar 2D (`addons/cinematic_authoring/`): + Trigger, + Barrier, + Waypoint Path, + Waypoint, + Indicator.
Activar en **Proyecto → Plugins → Cinematic Authoring**.

---

## FASE 8 — Documentación ✅

- `docs/cinematics/AUTHORING_GUIDE.md` — guía completa de autoría
- `DOCUMENTATION.md` §11 — referencia técnica en inglés
- `ai/context/PROJECT_CONTEXT.md` — tabla de clases del sistema

---

## JSON de ejemplo

### hallway_bully_intro.json
```json
{
  "id": "hallway_bully_intro",
  "trigger": { "type": "on_area_entered" },
  "steps": [
    { "type": "disable_player" },
    { "type": "walk_to", "node": "Bullys/HallwayBully", "to_node": "Markers/BullyStopPos", "speed": 120 },
    { "type": "face_direction", "node": "Bullys/HallwayBully", "look_at_node": "Player" },
    { "type": "dialogue", "path": "res://assets/dialogues/hallway_bully.json", "id": "intro" },
    { "type": "start_battle", "chart_path": "res://assets/charts/coolguy.json", "battle_scene_path": "res://scenes/rhythm/cool_battle.tscn", "return_npc_id": "hallway_bully" }
  ]
}
```

### companion_to_lab.json
```json
{
  "id": "companion_to_lab",
  "trigger": { "type": "on_quest_completed", "quest_id": "met_companion" },
  "steps": [
    { "type": "dialogue", "path": "res://assets/dialogues/companion.json", "id": "lets_go" },
    { "type": "follower_lead", "node": "Companion", "path_node": "Companion/RouteToLab", "speed": 110, "wait_for_arrival": true },
    { "type": "dialogue", "path": "res://assets/dialogues/companion.json", "id": "we_are_here" }
  ]
}
```

---

## Orden y tiempos estimados

| Fase | Horas | Estado |
|------|-------|--------|
| 0 Authoring primitives | 3–4 | ✅ |
| 1 ScriptedTrigger | 2–3 | ✅ |
| 2 Animación | 4–5 | ✅ |
| 3 Barreras | 2–3 | ✅ |
| 4 Follower | 4–5 | ✅ |
| 5 Indicador `!` | 3–4 | ✅ |
| 6 Cámara/SFX | 3 | ✅ |
| 7 Plugin editor | 3–4 | ✅ |
| 8 Docs | 2 | ✅ |

**MVP feria:** Fases 0+1+2+3+5 ≈ 14–18 h.

---

## Decisiones de diseño

| Tema | Decisión |
|------|----------|
| Coordenadas | Por nodo (`Marker2D` / `WaypointPath`), no literales |
| WaypointPath | Markers **locales** al path — mover el path mueve la ruta |
| Barreras | Estado derivado de quests, no duplicado en save |
| Skip | Tecla `Interact` (E) |
| Cinemáticas concurrentes | Cola estricta en `Gamemanager` |
