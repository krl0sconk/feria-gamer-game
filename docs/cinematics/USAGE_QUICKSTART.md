# Guía rápida — Cinemáticas (Fases 0–6)

## WaypointPath (rutas visuales)

1. Instancia `scenes/cinematic/WaypointPath.tscn` en tu mapa.
2. Arrastra los hijos `Marker2D` (Waypoint1, Waypoint2…) donde quieras la ruta.
3. En el Inspector, pulsa **Add Waypoint** para añadir puntos.
4. En JSON usa `"to_node": "Markers/MiMarker"` o `"to_path": "Routes/MiRuta"`.

## ScriptedTrigger (disparador en escena)

1. Instancia `scenes/cinematic/ScriptedTrigger.tscn`.
2. Redimensiona el `CollisionShape2D` en el editor 2D (se ve en amarillo).
3. Asigna `cinematic_json_path` al JSON de la secuencia.
4. Opcional: `requires_quest`, `blocked_if_quest_completed`, `debug_label`.

El JSON **no necesita** `"trigger": { "type": "on_area_entered" }` cuando usas ScriptedTrigger — el trigger es el Area2D en escena.

## move_node con destino por nodo

```json
{
  "type": "move_node",
  "node": "NPCs/Bully",
  "to_node": "Markers/BullyStopPos",
  "duration": 1.2
}
```

## move_node con primer punto de ruta

```json
{
  "type": "move_node",
  "node": "Companion",
  "to_path": "Routes/ToLab",
  "duration": 2.0
}
```

## walk_to (con animación)

```json
{
  "type": "walk_to",
  "node": "NPCs/Bully",
  "to_node": "Markers/BullyStopPos",
  "speed": 120,
  "animation": "walk",
  "idle_animation": "Idle"
}
```

## walk_path (recorrer WaypointPath)

```json
{
  "type": "walk_path",
  "node": "Companion",
  "to_path": "Routes/ToLab",
  "speed": 110,
  "wait_per_point": 0.3
}
```

## face_direction

```json
{
  "type": "face_direction",
  "node": "NPCs/Bully",
  "look_at_node": "Player"
}
```

## wait_for_player_near

```json
{
  "type": "wait_for_player_near",
  "to_node": "Companion",
  "distance": 80,
  "timeout": 0
}
```

## ScriptedBarrier (bloqueo de pasillo)

1. Instancia `scenes/cinematic/ScriptedBarrier.tscn` en el pasillo.
2. Ajusta el `CollisionShape2D` y asigna un `id` único (p. ej. `"hallway_bully"`).
3. Opcional: `disabled_by_quests = ["bully_hallway_defeated"]` para desactivar al completar la quest.

```json
{ "type": "disable_barrier", "id": "hallway_bully" }
{ "type": "enable_barrier", "id": "hallway_bully" }
```

## start_battle (desde cinemática)

```json
{
  "type": "start_battle",
  "battle_scene_path": "res://scenes/rhythm/cool_battle.tscn",
  "chart_path": "res://assets/charts/coolguy.json",
  "return_npc_id": "hallway_bully"
}
```

## Follower (NPC guía)

1. Añade `scenes/cinematic/Follower.tscn` como hijo del NPC (`CharacterBody2D` o `Node2D`).
2. Crea un `WaypointPath` con la ruta (p. ej. `Companion/RouteToLab`).
3. Opcional: asigna `path_node` en el Follower para ver la ruta en el editor.

```json
{
  "type": "follower_lead",
  "node": "Companion",
  "path_node": "Companion/RouteToLab",
  "speed": 110,
  "wait_for_arrival": true
}
```

```json
{ "type": "follower_follow", "node": "Companion", "target": "Player" }
{ "type": "follower_stop", "node": "Companion" }
```

## InteractionIndicator (`!` flotante)

Incluido por defecto en `Interactable.tscn` y `ScriptedTrigger.tscn`.

1. El `!` aparece en modo **AUTO** cuando hay interacción/cinemática pendiente.
2. Desactívalo con `show_indicator = false` en el Inspector del NPC o trigger.
3. Ajusta `symbol` (`!` o `?`), `vertical_offset` y bob en el hijo `InteractionIndicator`.

**Interactable:** se oculta si el bully ya fue derrotado o mientras hay diálogo activo.

**ScriptedTrigger:** se oculta tras disparar (si `play_once`) o si no cumple filtros de quest.

## Cámara, SFX y letterbox

```json
{ "type": "camera_focus", "target": "Bullys/HallwayBully", "duration": 0.8, "zoom": 1.8 }
{ "type": "camera_release", "duration": 0.6 }
{ "type": "shake_camera", "intensity": 8, "duration": 0.35 }
{ "type": "letterbox", "enabled": true, "bar_height": 72, "duration": 0.4 }
{ "type": "play_sfx", "stream_path": "res://assets/audio/sfx/interactionbullie.wav", "volume_db": -3 }
```

## Skip de cinemática

Durante una cinemática activa, pulsa **E** (`Interact`) para saltarla.
Desactivar por instancia: `allow_skip = false` en el `CinematicPlayer`.

## Guía completa

**Empieza aquí:** [`GUIA_COMPLETA_CINEMATICAS.md`](GUIA_COMPLETA_CINEMATICAS.md) — todo lo nuevo, plugin, ejemplos bully + compañera paso a paso.

También: `AUTHORING_GUIDE.md` (tabla de comandos) · `ADVANCED_CINEMATICS_PLAN.md` (plan por fases).
