# Guía completa — Sistema de cinemáticas (Beat the Bully)

> Todo lo implementado en las Fases 0–7 · Cómo usarlo · Ejemplos paso a paso  
> Godot 4.6 · Feria Gamer 2026

---

## Índice

1. [Resumen de lo nuevo](#1-resumen-de-lo-nuevo)
2. [Activar el plugin de editor](#2-activar-el-plugin-de-editor)
3. [Nodos de escena](#3-nodos-de-escena)
4. [JSON de cinemática](#4-json-de-cinemática)
5. [Comandos disponibles](#5-comandos-disponibles)
6. [Ejemplo A — Bully bloquea el pasillo](#6-ejemplo-a--bully-bloquea-el-pasillo)
7. [Ejemplo B — Compañera guía al laboratorio](#7-ejemplo-b--compañera-guía-al-laboratorio)
8. [Probar y depurar](#8-probar-y-depurar)
9. [Referencias](#9-referencias)

---

## 1. Resumen de lo nuevo

| Fase | Qué aporta |
|------|------------|
| **0** | `WaypointPath`, destinos por nodo (`to_node` / `to_path`), sin coords en JSON |
| **1** | `ScriptedTrigger` múltiple, cola en `Gamemanager.request_cinematic()` |
| **2** | Caminar animado: `walk_to`, `walk_path`, `face_direction`, etc. |
| **3** | `ScriptedBarrier` + `enable_barrier` / `disable_barrier` / `start_battle` |
| **4** | `Follower` — NPC guía que espera al jugador en las esquinas |
| **5** | `InteractionIndicator` — `!` flotante sobre NPCs/triggers pendientes |
| **6** | Cámara, letterbox, SFX, **skip con E** |
| **7** | **Plugin editor** — barra 2D: Trigger, Barrier, Path, Waypoint, ! |

**Principio clave:** coloca `Marker2D` y `WaypointPath` en el editor; el JSON solo referencia rutas de nodos (`"node": "Bullys/HallwayBully"`, `"to_node": "Markers/BullyStopPos"`).

---

## 2. Activar el plugin de editor

1. Abre el proyecto en Godot.
2. Ve a **Proyecto → Configuración del proyecto → Plugins**.
3. Activa **Cinematic Authoring** (ya viene habilitado en `project.godot`).
4. Abre cualquier escena de mapa en el **editor 2D**.
5. En la barra superior del viewport 2D verás:

| Botón | Acción |
|-------|--------|
| **+ Trigger** | Instancia `ScriptedTrigger` en la posición del ratón |
| **+ Barrier** | Instancia `ScriptedBarrier` |
| **+ Path** | Instancia `WaypointPath` |
| **+ Waypoint** | Añade un `Marker2D` al `WaypointPath` **seleccionado** |
| **+ !** | Instancia `InteractionIndicator` como hijo del nodo seleccionado (o en la raíz) |

Todos los cambios soportan **Undo** (Ctrl+Z).

---

## 3. Nodos de escena

Plantillas en `scenes/cinematic/`:

| Escena | Para qué |
|--------|----------|
| `ScriptedTrigger.tscn` | Dispara un JSON al entrar el jugador |
| `ScriptedBarrier.tscn` | Muro invisible; se activa/desactiva por `id` |
| `WaypointPath.tscn` | Ruta con waypoints numerados |
| `Follower.tscn` | Hijo del NPC — modo guía o seguidor |
| `InteractionIndicator.tscn` | `!` bob (incluido en Interactable/Trigger) |
| `CinematicPlayer.tscn` | Reproductor embebido (triggers JSON legacy) |

### ScriptedTrigger — Inspector

| Export | Uso |
|--------|-----|
| `cinematic_json_path` | JSON de la secuencia |
| `requires_quest` | Solo dispara si esa quest está completa |
| `blocked_if_quest_completed` | No dispara si esa quest ya se completó |
| `play_once` | Consulta `Gamemanager.cinematics_played` |
| `show_indicator` | Muestra `!` mientras esté pendiente |

### ScriptedBarrier — Inspector

| Export | Uso |
|--------|-----|
| `id` | Identificador único (p. ej. `"hallway_bully"`) |
| `active_by_default` | Estado inicial |
| `disabled_by_quests` | Se desactiva al cargar si **todas** esas quests están completas |

Preview en editor: **rojo rayado** = activa, **gris** = inactiva.

### Follower — Inspector

| Export | Uso |
|--------|-----|
| `path_node` | Preview de ruta en editor |
| `wait_distance` | Si el jugador se aleja más (default 96 px), el NPC espera |
| `speed` | Velocidad de marcha |

---

## 4. JSON de cinemática

Ubicación recomendada: `assets/cinematics/*.json`

```json
{
  "version": 1,
  "id": "mi_evento",
  "trigger": { "type": "on_quest_completed", "quest_id": "alguna_quest" },
  "steps": [
    { "type": "disable_player" },
    { "type": "dialogue", "path": "res://assets/dialogues/npc.json", "id": "intro" },
    { "type": "enable_player" }
  ]
}
```

- **`id`**: único; usado por `play_once`.
- **`trigger`**: solo si usas `CinematicPlayer` con `auto_play`. Con `ScriptedTrigger`, **omítelo** — el trigger es el Area2D.
- **`steps`**: lista ordenada de comandos.

### Destinos (movimiento)

| Campo | Significado |
|-------|-------------|
| `to_node` | Posición de un `Marker2D` o cualquier `Node2D` |
| `to_path` | Ruta `WaypointPath` (primer punto o ruta completa) |
| `to` | `[x,y]` — solo debug, evitar en producción |

Prioridad: `to_path` > `to_node` > `to`.

---

## 5. Comandos disponibles

### Presentación
`fade_to_black`, `fade_from_black`, `wait`, `letterbox`, `show_node`, `hide_node`

### Jugador y diálogo
`dialogue`, `disable_player`, `enable_player`

### Movimiento y animación
`move_node`, `walk_to`, `walk_path`, `face_direction`, `play_animation`, `set_collision`, `wait_for_player_near`

### Barreras y batalla
`enable_barrier`, `disable_barrier`, `start_battle`

### NPC guía
`follower_lead`, `follower_follow`, `follower_stop`

### Cámara y audio
`camera_focus`, `camera_release`, `shake_camera`, `play_sfx`

### Escena
`change_scene`

### Skip
Durante la cinemática: pulsa **E** (`Interact`). Desactivar: `allow_skip = false` en `CinematicPlayer`.

Tabla detallada de parámetros: `AUTHORING_GUIDE.md` §5.

---

## 6. Ejemplo A — Bully bloquea el pasillo

**Historia:** el jugador sale del salón; un bully bloquea el pasillo, dialoga, batalla; al ganar se abre el camino.

### Archivos de ejemplo (ya en el repo)

| Archivo | Rol |
|---------|-----|
| `assets/cinematics/hallway_bully_intro.json` | Cinemática al acercarse |
| `assets/cinematics/hallway_bully_outro.json` | Tras completar quest de victoria |
| `assets/dialogues/hallway_bully.json` | Diálogos intro / victory / defeat |

### Paso 1 — Escena del mapa (editor 2D)

Crea esta jerarquía (nombres exactos para que el JSON funcione sin edits):

```
TuMapa (Node2D root)
├── Player
├── Markers/
│   ├── BullyStopPos      (Marker2D — donde para el bully)
│   └── BullyExit         (Marker2D — hacia donde se va al perder el pasillo)
├── Bullys/
│   └── HallwayBully      (Interactable: id = "hallway_bully", battle_scene, diálogos)
├── Barriers/
│   └── HallwayBarrier    (ScriptedBarrier: id = "hallway_bully")
└── Triggers/
    └── HallwayIntro      (ScriptedTrigger)
```

**Con el plugin:**
1. **+ Barrier** → colócalo tapando el pasillo → `id = hallway_bully` → `disabled_by_quests = ["3.1.1"]`.
2. **+ Trigger** justo delante → `cinematic_json_path = res://assets/cinematics/hallway_bully_intro.json`.
3. **+ Path** no hace falta aquí; usa **Marker2D** manual bajo `Markers/`.

### Paso 2 — Interactable del bully

En `HallwayBully` (Interactable):

| Campo | Valor sugerido |
|-------|----------------|
| `id` | `hallway_bully` |
| `dialogue_json_path` | `res://assets/dialogues/hallway_bully.json` |
| `intro_dialogue_id` | `intro` |
| `win_dialogue_id` | `victory` |
| `lose_dialogue_id` | `defeat` |
| `battle_scene` | `cool_battle.tscn` (o la batalla que uses) |
| `mission_id` / quest | vincula a `3.1.1` y `complete_mission_on_win = true` |

### Paso 3 — Trigger de intro

`ScriptedTrigger` (`HallwayIntro`):

- `cinematic_json_path` → `res://assets/cinematics/hallway_bully_intro.json`
- `play_once` → true
- `blocked_if_quest_completed` → `"3.1.1"` (no repite intro tras ganar)
- Redimensiona el `CollisionShape2D` para que el jugador lo pise al salir del salón.

### Paso 4 — Cinemática de cierre (outro)

Añade un **`CinematicPlayer`** hijo del mapa (o segundo trigger con quest):

- `cinematic_json_path` → `res://assets/cinematics/hallway_bully_outro.json`
- `auto_play` → true  
  (trigger interno: `on_quest_completed` → `3.1.1`)

### Flujo en runtime

```
Jugador pisa Trigger
  → intro: bully camina a BullyStopPos, dialoga, start_battle
  → batalla rhythm
  → vuelta al mapa, win_dialogue del Interactable
  → quest 3.1.1 completada
  → outro: bully camina a BullyExit, hide_node, disable_barrier
  → pasillo libre
```

### JSON intro (referencia)

```json
{
  "id": "hallway_bully_intro",
  "steps": [
    { "type": "disable_player" },
    { "type": "camera_focus", "target": "Bullys/HallwayBully", "duration": 0.8, "zoom": 1.8 },
    { "type": "walk_to", "node": "Bullys/HallwayBully", "to_node": "Markers/BullyStopPos", "speed": 120 },
    { "type": "face_direction", "node": "Bullys/HallwayBully", "look_at_node": "Player" },
    { "type": "dialogue", "path": "res://assets/dialogues/hallway_bully.json", "id": "intro" },
    { "type": "start_battle", "battle_scene_path": "res://scenes/rhythm/cool_battle.tscn", "return_npc_id": "hallway_bully" }
  ]
}
```

---

## 7. Ejemplo B — Compañera guía al laboratorio

**Historia:** tras conocer a la compañera, te guía por el pasillo hasta el lab, esperándote en las esquinas.

### Archivos de ejemplo

| Archivo | Rol |
|---------|-----|
| `assets/cinematics/companion_to_lab.json` | Secuencia completa |
| `assets/dialogues/companion.json` | `lets_go` y `we_are_here` |

### Paso 1 — Escena

```
TuMapa
├── Player
├── NPCs/
│   └── Companion           (CharacterBody2D o Node2D + AnimatedSprite2D)
│       ├── Follower        (+ Follower.tscn como hijo)
│       └── RouteToLab      (+ WaypointPath.tscn)
│           ├── Waypoint1
│           ├── Waypoint2
│           └── Waypoint3
└── CinematicPlayer         (opcional, para trigger on_quest_completed)
```

**Con el plugin:**
1. Coloca el NPC `Companion`.
2. **+ Path** como hijo → renombra a `RouteToLab`.
3. Selecciona `RouteToLab` → pulsa **+ Waypoint** varias veces → arrastra los markers en el pasillo.
4. Instancia `Follower.tscn` como hijo de `Companion`.
5. En Follower, asigna `path_node` → `RouteToLab` (preview cyan en editor).

### Paso 2 — Quest y cinemática

1. Crea quest `met_companion` (se completa cuando hables con la NPC la primera vez).
2. Añade `CinematicPlayer` al mapa:
   - `cinematic_json_path` → `res://assets/cinematics/companion_to_lab.json`
   - `auto_play` → true

O usa `ScriptedTrigger` si prefieres disparar al pisar una zona tras la quest (`requires_quest = met_companion`).

### Paso 3 — Ajustar rutas en JSON

Si tu jerarquía difiere, cambia solo los NodePath:

```json
"node": "NPCs/Companion",
"path_node": "NPCs/Companion/RouteToLab"
```

### Flujo en runtime

```
Quest met_companion completada
  → diálogo lets_go
  → jugador puede moverse
  → Follower recorre RouteToLab; espera si te quedas atrás (>96 px)
  → al llegar: diálogo we_are_here
```

### JSON (referencia)

```json
{
  "id": "companion_to_lab",
  "trigger": { "type": "on_quest_completed", "quest_id": "met_companion" },
  "steps": [
    { "type": "dialogue", "path": "res://assets/dialogues/companion.json", "id": "lets_go" },
    { "type": "enable_player" },
    { "type": "follower_lead", "node": "NPCs/Companion", "path_node": "NPCs/Companion/RouteToLab", "speed": 110, "wait_for_arrival": true },
    { "type": "follower_stop", "node": "NPCs/Companion" },
    { "type": "dialogue", "path": "res://assets/dialogues/companion.json", "id": "we_are_here" }
  ]
}
```

---

## 8. Probar y depurar

### Checklist

- [ ] NodePaths del JSON existen desde la **raíz de la escena**
- [ ] `ScriptedBarrier.id` único y coincide con `enable_barrier` / `disable_barrier`
- [ ] `return_npc_id` = `Interactable.id` si hay batalla
- [ ] Quest IDs en triggers/filtros existen en `QuestManager`
- [ ] Plugin **Cinematic Authoring** activo
- [ ] Pulsa **E** para skip si una cinemática se queda colgada (salvo `allow_skip = false`)

### Señales útiles

| Señal | Cuándo |
|-------|--------|
| `cinematic_started(id)` | Inicio |
| `cinematic_finished(id)` | Fin normal o skip |
| `cinematic_skipped(id)` | Solo si saltaste con E |

### Errores frecuentes

| Síntoma | Causa probable |
|---------|----------------|
| NPC no se mueve | `node` mal escrito o sin `AnimatedSprite2D` |
| Barrera no cae | `id` distinto o quest de `disabled_by_quests` no completada |
| Trigger no dispara | Quest filter, `play_once` ya consumido, o collision mal puesta |
| Follower no espera | Jugador siempre cerca; sube `wait_distance` |
| Cambiar un NPC cambia todos | Varios `Interactable` comparten `SpriteFrames` o `Shape2D` del `.tscn` base; el script duplica ambos al cargar. Tras abrir el mapa una vez, guarda la escena. También: clic derecho → **Hacer único** |
| Dos bullies en el pasillo | `HallwayBully` + `HallwayBully2` (`CinematicNpc` con `Follower`); en JSON: `follower_follow` → `walk_to` del líder → `follower_stop` |
| Debug de barrera raro | Rayas diagonales fuera del rectángulo con `scale` alto; el preview ahora recorta al polígono de colisión |

---

## 9. Referencias

| Documento | Contenido |
|-----------|-----------|
| **Esta guía** | Overview + ejemplos A y B paso a paso |
| `docs/cinematics/AUTHORING_GUIDE.md` | Tabla completa de comandos y triggers |
| `docs/cinematics/USAGE_QUICKSTART.md` | Snippets JSON rápidos |
| `docs/cinematics/ADVANCED_CINEMATICS_PLAN.md` | Plan técnico por fases |
| `DOCUMENTATION.md` §11 | Referencia en inglés (clases, arquitectura) |

### Scripts principales

```
scripts/cinematic/
├── cinematic_player.gd      # Ejecutor de pasos
├── cinematic_loader.gd      # Parser JSON
├── cinematic_actor.gd       # Animación / caminar
├── cinematic_camera.gd      # Pan, zoom, shake
├── scripted_trigger.gd
├── scripted_barrier.gd
├── waypoint_path.gd
├── follower.gd
└── interaction_indicator.gd

addons/cinematic_authoring/  # Plugin barra 2D
```

---

*Beat the Bully — V Feria Gamer 2026 · Universidad del Norte*
