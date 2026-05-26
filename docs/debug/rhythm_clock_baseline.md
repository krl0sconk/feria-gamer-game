# Rhythm Clock Debug — Baseline

Instrumentación opcional para diagnosticar desincronización entre input, reloj de batalla y audio.

**Estado:** desactivada por defecto (`rhythm_clock_debug = false`). Solo activar al investigar bugs de timing.

## Activación

1. Abrir la escena de batalla (p. ej. `scenes/rhythm/tutorial.tscn`).
2. Nodo raíz `Battle` → **Debug** → `rhythm_clock_debug = true`.
3. Opcional: `debug_skip_enabled = true` para saltar con F5.

## Captura de logs (Desktop)

```bash
godot --path . res://scenes/rhythm/tutorial.tscn 2>&1 | tee docs/debug/clock_desktop_1.log
```

## Captura de logs (Web)

1. Exportar HTML5 con `rhythm_clock_debug = true` en la escena de prueba.
2. DevTools → Console → filtrar `CLOCK`, `INPUT`, `MP`, `HUD`.
3. Guardar salida en `docs/debug/clock_web_1.log`.

## Prefijos de log

| Prefijo | Origen | Qué indica |
|---------|--------|------------|
| `[CLOCK]` | `battle.gd` | Estado del reloj cada ~100 ms (primeros 4 s) |
| `[INPUT]` | `battle.gd` | Cada pulsación del jugador |
| `[INPUT SWALLOW]` | `battle.gd` | Pulsación descartada (demasiado pronto) |
| `[CLOCK AUTOMISS]` | `battle.gd` | Nota auto-expirada como Miss |
| `[MP]` | `music_player.gd` | Componentes del reloj de audio (1×/s) |
| `[HUD]` | `battle_hud.gd` | `arrow_travel_ms` y layout al iniciar |
| `[RHYTHM]` | `battle.gd` | Resultado de juicio |

## Qué buscar

**Auto-miss al inicio en web (resuelto 2026-05-26):**
- `[CLOCK AUTOMISS] delta ≈ +120…140 ms` con `presionada=` vacío.
- Causa: reloj de audio adelantado vs flechas por `delta`.
- Fix: `_using_fallback = true` en web — ver `ai/decisions/DESIGN_DECISIONS.md`.

**Pulsar durante pre-roll (UX, no bug de reloj):**
- `[INPUT SWALLOW] reason=too_early` con `current_ms` negativo.
- El jugador pulsa antes de que arranque la música; la nota expira ~2 s después.

## Referencia

Decisión de diseño: `ai/decisions/DESIGN_DECISIONS.md` → *Reloj rítmico: frame clock en web*.

Documentación técnica: `DOCUMENTATION.md` §7.3 (MusicPlayer) y §7.7 (Battle).
