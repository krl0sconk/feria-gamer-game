# Beat The Bully - Explicacion completa del sistema

Fecha: 2026-05-22

## 1. Vision general del sistema
Beat The Bully esta construido en Godot con una arquitectura modular por escenas y scripts especializados.

La aplicacion se organiza en capas:
1. Capa de estado global (autoloads/singletons): manejo de estado entre escenas, progresion, accesibilidad y guardado.
2. Capa de dominio de juego: mapa, interacciones con NPC, sistema de quests, encuentros y combate ritmico.
3. Capa de presentacion: HUD, menus, overlays de opciones/accesibilidad, feedback visual y sonoro.
4. Capa de datos: archivos JSON (dialogos, charts, quests) y Resources (.tres) para reglas parametrizables.

Autoloads principales definidos en project.godot:
- Gamemanager
- QuestManager
- ColorblindOverlay
- SaveManager

## 2. Como interactua el sistema completo (flujo end-to-end)

### 2.1 Inicio y configuracion
1. El juego arranca en main_menu.tscn.
2. Gamemanager aplica ajustes guardados desde settings.cfg antes de renderizar (video, audio, accesibilidad, controles).
3. El usuario puede abrir opciones, ajustar configuraciones y aplicar cambios.

### 2.2 Inicio de partida / carga
1. Desde el menu principal se abre save_slots.tscn.
2. Si el slot esta vacio, pasa a select_pj.tscn para elegir skin.
3. Si el slot tiene datos, se restauran:
- escena
- posicion del jugador
- skin seleccionada
- estado de quests
- world_flags (estado serializado de mundo: bullies/interactuables)

### 2.3 Exploracion en mapa
1. Player se mueve en top-down (CharacterBody2D, input move_up/down/left/right).
2. Room/Map controlan logica de salida entre zonas.
3. Algunas salidas se desbloquean solo al completar quest especifica (exit_unlock_quest_id + QuestManager).

### 2.4 Interaccion con NPC
1. Interactable detecta entrada del jugador en Area2D.
2. Al presionar Interact (E), se reproduce dialogo via DialogueRunner.
3. DialogueBox renderiza lineas con avance manual (ui_accept) y typewriter.
4. Al finalizar intro_dialogue, si el NPC tiene battle_scene, se dispara transicion a batalla.

### 2.5 Batalla ritmica
1. Battle carga chart y musica (incluye override por NPC).
2. Composer agenda notas esperadas por tiempo.
3. PlayerInput captura notas (note_left/down/up/right).
4. Metronome evalua precision temporal (Perfect/Good/Miss).
5. Judge valida accion vs nota esperada.
6. Referee actualiza score/combo/HP del jugador y decide derrota o supervivencia.
7. BattleHUD muestra HP, score, combo, ratings y feedback visual.
8. Al finalizar, se define win/lose y se regresa a escena post-batalla.

### 2.6 Retorno al mapa y continuidad narrativa
1. Gamemanager conserva pending_npc_id, return_scene_path y return_position.
2. Al volver, Map/Room reubican al jugador.
3. Se reproduce dialogo de resultado (win_dialogue_id o lose_dialogue_id).
4. Si hubo victoria, se notifica derrota al QuestManager y a serializadores del mundo.

### 2.7 Guardado y persistencia
1. Guardado principal en 3 slots JSON (user://savesgames/save_slot_X.json).
2. El guardado se ejecuta al salir al menu desde pausa (Exit en pause_menu).
3. SaveManager serializa player, quests, score y world_flags.
4. La carga rehidrata el estado via Gamemanager + QuestManager + sistemas world_state_serializers.

## 3. Patron de diseno y principios usados

### 3.1 Singleton (Autoload)
Se usa para servicios transversales:
- Gamemanager: estado de ejecucion entre escenas.
- QuestManager: progresion global.
- SaveManager: persistencia de slots.
- ColorblindOverlay: filtro global de accesibilidad visual.

### 3.2 Observer / Event-Driven (senales)
El juego desacopla componentes con signals:
- dialogue_started/dialogue_finished
- note_expected/note_result
- score_updated/player_hp_updated/combo_updated
- quest_completed/quest_activated

Esto evita acoplamiento fuerte entre UI, logica y datos.

### 3.3 SRP (Single Responsibility Principle)
Cada script tiene responsabilidad concreta:
- DialogueLoader carga/parsea JSON.
- DialogueRunner secuencia dialogos.
- DialogueBox renderiza dialogo y typewriter.
- Metronome mide timing.
- Judge evalua entrada.
- Referee decide estado de partida.

### 3.4 Data-Driven Design
Contenido y reglas viven fuera del codigo duro:
- Dialogos en JSON.
- Charts ritmicos en JSON.
- Quests en JSON.
- Reglas de score/vida en Resources.

### 3.5 Composicion por componentes
Escenas Godot ensamblan nodos especializados:
Battle = PlayerInput + Metronome + Judge + Referee + HUD + Composer + MusicPlayer.

## 4. Estructuras de datos usadas

1. Dictionary
- Estado global y payloads de guardado.
- Mapeos action -> cola de notas pendientes.
- Estados de quests activas/completadas.
- world_flags por clave de serializador.

2. Array
- Listas de quests, lineas de dialogo, notas del chart.
- Requisitos de desbloqueo (requires_ids).
- Slots y metadatos de guardado.

3. Queue (con Array + pop_front)
- Colas por carril en batalla para evaluar hits/miss en orden temporal.

4. CircularLinkedList personalizada
- Usada por BullySpawnManager para gestionar puntos de spawn ciclicos.

5. Resource tipado (ScoreRules, HealthRules)
- Encapsula reglas configurables sin tocar logica central.

## 5. Estructura general del proyecto
Carpetas clave:
- scripts/map: movimiento, exploracion, cambio de zonas.
- scripts/dialogue: interaccion NPC y sistema de dialogos.
- scripts/rhythm: pipeline de combate ritmico.
- scripts/quests: progresion y desbloqueos.
- scripts/menu + scripts/ui: menu principal, pausa, opciones, slots.
- scripts/save: persistencia por slots.
- scenes/*: ensamblaje visual y runtime de cada sistema.
- assets/charts, assets/dialogues, resources/data: contenido data-driven.

## 6. Verificacion de requerimientos funcionales (1 al 10)

1) Exploracion libre top-down con zonas desbloqueables por narrativa.
- Estado: CUMPLIDO.
- Evidencia: player.gd (movimiento libre), room.gd (salida condicionada por quest), quest_manager.gd (progresion y unlocks).

2) Interaccion con NPC y dialogos contextuales con avance manual.
- Estado: CUMPLIDO.
- Evidencia: interactable.gd + dialogue_runner.gd + dialogue_box.gd.

3) Batallas ritmicas al encontrar bullies con patrones musicales.
- Estado: CUMPLIDO.
- Evidencia: interactable.gd dispara battle_scene; battle.gd carga chart/musica y ejecuta pipeline ritmico.

4) Evaluacion de entradas Perfect/Good/Miss con impacto.
- Estado: CUMPLIDO.
- Evidencia: metronome.gd (timing), judge.gd (validacion), referee.gd + health_rules.gd (impacto en HP).

5) Indicador HP jugador/enemigos y condicion de victoria/derrota.
- Estado: PARCIAL.
- Evidencia: HP jugador y derrota real si HP <= 0 estan implementados (referee.gd, battle_hud.gd).
- Observacion: HP enemigo en enemy_gauge.gd es visual y no define la victoria; la victoria real se declara por supervivencia al final de cancion.

6) Progreso por capitulos con desbloqueo de zonas/enemigos/narrativa.
- Estado: CUMPLIDO (modelo por misiones/capitulo).
- Evidencia: quest_manager.gd (requires_ids y refresh unlocks), interactable.gd (mision por NPC), room.gd (unlock de salida por quest).

7) Menus de inicio, pausa, opciones y ayuda.
- Estado: PARCIAL.
- Evidencia: main_menu.gd, pause_menu.gd, options.gd (inicio/pausa/opciones).
- Observacion: existe boton Help en main_menu.tscn pero no se observa conexion funcional en runtime a una pantalla de ayuda.

8) Guardado semi-automatico al salir al menu, con accion manual del usuario.
- Estado: CUMPLIDO.
- Evidencia: pause_menu.gd (Exit guarda slot activo y vuelve al menu), save_manager.gd (persistencia robusta con temp+rename).
- Nota: coincide con politica definida: sin autosave continuo; guardado al salir.

9) Personalizacion visual con skins desbloqueables.
- Estado: PARCIAL.
- Evidencia: select_pj.gd y player.gd permiten seleccionar/aplicar skin y persistirla.
- Observacion: hay seleccion de skins, pero el desbloqueo progresivo no esta claramente automatizado por progreso; hay una opcion marcada como bloqueada fija en UI.

10) Accesibilidad (daltonismo, discapacidad visual, contraste).
- Estado: PARCIAL.
- Evidencia: daltonismo e intensidad del filtro implementados (colorblind_overlay.gd, options_settings.gd, options.tscn), ademas de modo dislexico.
- Observacion: no se identifica ajuste explicito de contraste general independiente del filtro de daltonismo.

## 7. Conclusiones para exposicion
1. El sistema esta bien modularizado y orientado a componentes.
2. El flujo principal exploracion -> dialogo -> batalla -> retorno -> guardado esta claramente implementado.
3. El proyecto cumple la mayoria de requerimientos funcionales clave.
4. Los puntos a defender como "parcial" son HP enemigo funcional, ayuda formal y contraste explicito.

## 8. 10 preguntas que podria hacer el profesor (con respuesta)

1. Pregunta: Como desacoplaron dialogo, combate y mapa para que no sea un bloque monolitico?
Respuesta: Separamos responsabilidades por scripts y usamos senales. Interactable solo decide el flujo, DialogueRunner secuencia texto, Battle resuelve combate y Gamemanager conserva el estado entre escenas.

2. Pregunta: Donde queda la logica de progresion narrativa?
Respuesta: En QuestManager. Carga quests desde JSON, activa segun prerequisitos (requires_ids), marca completadas y emite senales para desbloquear contenido.

3. Pregunta: Como garantizan persistencia sin corromper guardados?
Respuesta: SaveManager escribe primero en archivo temporal (.tmp) y luego renombra al definitivo. Ademas valida rango de slots y estructura minima.

4. Pregunta: Cual es la diferencia entre Judge y Referee?
Respuesta: Judge valida la entrada puntual (si pego o fallo la nota). Referee administra estado global de combate (HP, score, combo, victoria/derrota).

5. Pregunta: Como controlan precision ritmica?
Respuesta: Metronome compara tiempo de entrada con tiempo objetivo de nota usando ventanas en ms (window_perfect y window_good), devolviendo Perfect/Good/Miss.

6. Pregunta: Que estructura usan para notas pendientes?
Respuesta: Un Dictionary de colas (Array) por accion de nota. Cada carril consume en orden con pop_front para mantener coherencia temporal.

7. Pregunta: Como vuelven al NPC correcto despues de una batalla?
Respuesta: Interactable guarda pending_npc_id y return_position en Gamemanager antes de cambiar de escena. Al regresar, Map/Room buscan ese NPC y ejecutan el dialogo de resultado.

8. Pregunta: Como implementaron accesibilidad?
Respuesta: Con un overlay global de shader para daltonismo (modo + intensidad) y opcion de fuente para modo dislexico aplicada por OptionsSettings.

9. Pregunta: Donde se ve el patron data-driven?
Respuesta: Dialogos, charts y quests estan en JSON; reglas de puntuacion/vida estan en Resources editables. Asi cambiamos contenido y dificultad sin reescribir logica.

10. Pregunta: Que mejorarian si les dieran una iteracion mas?
Respuesta: Convertir HP enemigo visual en HP funcional real para condicion de victoria, implementar pantalla de ayuda conectada al menu principal y agregar control de contraste global independiente.

## 9. Guion corto para defender la arquitectura (1 minuto)
"Nuestro sistema esta organizado por capas: estado global en autoloads, logica de dominio en scripts de mapa/dialogo/ritmo/quests y presentacion en HUD y menus. El flujo principal es: explorar mapa, interactuar con NPC, disparar batalla ritmica, resolver resultado y persistir estado al salir al menu. Usamos senales para desacoplar modulos, JSON/Resources para enfoque data-driven y componentes pequenos por SRP. Con esto logramos mantenibilidad, escalabilidad de contenido y trazabilidad clara para cada requerimiento funcional."