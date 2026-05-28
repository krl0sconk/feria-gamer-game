# Herramientas de alineación y cuantización de charts

Este directorio contiene scripts para ajustar y generar charts (JSON) sincronizados con el audio.

Scripts principales

- `quantize_crossingfield.py`
  - Qué hace: lee `assets/charts/crossingfield_chart.json`, cuantiza las notas a una rejilla rítmica y genera dos archivos:
    - `crossingfield_chart_normal.json` — cuantización a corcheas (8th notes)
    - `crossingfield_chart_easy.json` — cuantización más esparcida (cuartos / reducción de densidad)
  - Uso:
    - En el workspace raíz ejecutar: `python tools/quantize_crossingfield.py`
  - Salida: archivos JSON en `assets/charts/`.

- `align_crossingfield.py`
  - Qué hace: analiza el WAV definido en la primera `phase` del chart, detecta onsets y energía en frecuencias bajas, detecta regiones dominadas por bajos y:
    - en regiones de bajos fuerza el `snap` a la rejilla de beats;
    - fuera de regiones de bajos, hace snap a onsets cercanos cuando aplicable;
    - genera dos charts alineados: `crossingfield_chart_aligned_normal.json` y `crossingfield_chart_aligned_easy.json`;
    - guarda un informe `crossingfield_chart_changes.json` con los cambios por nota (original → nuevo tiempo, razón de energía baja, método de snap);
    - genera un espectrograma visual `crossingfield_alignment.png` con onsets y marcas de notas.
  - Parámetros importantes:
    - `bass_threshold` (interno): umbral de proporción de energía baja para detectar zonas de bajos (por defecto se usa 0.30 en la ejecución actual).
    - `min_duration_sec`: duración mínima para considerar una región de bajos (por defecto 0.15s en la ejecución actual).
  - Uso:
    - En el workspace raíz ejecutar: `python tools/align_crossingfield.py`
  - Salida: archivos JSON y PNG en `assets/charts/`.

Notas y recomendaciones

- Asegúrate de tener el audio referenciado en `phases[0].audio` del chart apuntando al WAV correcto (p. ej. `assets/audio/music/CROSSINGFIELDS.wav`).
- Los scripts usan `librosa`, `soundfile` y `matplotlib`. Si estás en el entorno virtual del proyecto, instala dependencias con:

```bash
pip install -r requirements.txt
# o en su defecto
pip install librosa soundfile matplotlib
```

- Si quieres ajustar el comportamiento (umbral de graves, subdivisión para `normal`/`easy`), abre los scripts y modifica los parámetros en las funciones `quantize_notes` / `quantize_with_onsets`.

Resultados generados (ejemplos)

- `assets/charts/crossingfield_chart_aligned_normal.json`
- `assets/charts/crossingfield_chart_aligned_easy.json`
- `assets/charts/crossingfield_chart_changes.json`
- `assets/charts/crossingfield_alignment.png`

Si quieres que integre uno de los charts como el chart activo del juego, dímelo y lo actualizo.
