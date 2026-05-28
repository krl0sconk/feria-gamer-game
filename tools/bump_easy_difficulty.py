import json
from pathlib import Path
import math


def load(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def save(obj, path: Path):
    path.write_text(json.dumps(obj, indent=1, ensure_ascii=False), encoding='utf-8')


def notes_in_bar(notes, start_ms, bpm, bar_idx, beats_per_bar=4):
    beat_ms = 60000.0 / bpm
    bar_start = start_ms + bar_idx * beats_per_bar * beat_ms
    bar_end = bar_start + beats_per_bar * beat_ms
    return [n for n in notes if n['time_ms'] >= bar_start and n['time_ms'] < bar_end], bar_start, bar_end


def increase_easy(easy_notes, normal_notes, start_ms, bpm):
    # create lookup by bar
    beat_ms = 60000.0 / bpm
    # determine total bars from normal
    if not normal_notes:
        return easy_notes
    last_time = max(n['time_ms'] for n in normal_notes)
    total_bars = int(math.ceil((last_time - start_ms) / (beat_ms * 4)))

    easy_by_time = list(easy_notes)

    for bar in range(total_bars):
        normal_bar, bs, be = notes_in_bar(normal_notes, start_ms, bpm, bar)
        easy_bar, _, _ = notes_in_bar(easy_by_time, start_ms, bpm, bar)
        n_norm = len(normal_bar)
        n_easy = len(easy_bar)
        if n_norm <= n_easy:
            continue
        # allowed new notes: half the gap (ceil)
        gap = n_norm - n_easy
        to_add = (gap + 1) // 2

        # pick candidate notes from normal that are not already close to any easy note
        candidates = []
        for nn in normal_bar:
            # consider candidate if no easy note within 100ms
            if all(abs(nn['time_ms'] - ee['time_ms']) > 100.0 for ee in easy_bar):
                candidates.append(nn)

        # sort candidates by proximity to bar center (prefer central pulses)
        candidates.sort(key=lambda x: abs((bs+be)/2 - x['time_ms']))
        add = candidates[:to_add]
        easy_by_time.extend(add)

    # sort and deduplicate very close notes
    easy_by_time.sort(key=lambda x: x['time_ms'])
    out = []
    last_t = -1e9
    for n in easy_by_time:
        if abs(n['time_ms'] - last_t) < 20.0:
            continue
        out.append(n)
        last_t = n['time_ms']
    return out


def main():
    root = Path(__file__).resolve().parents[1]
    chart_dir = root / 'assets' / 'charts'
    easy_path = chart_dir / 'crossingfield_chart_aligned_easy.json'
    normal_path = chart_dir / 'crossingfield_chart_aligned_normal.json'
    if not easy_path.exists() or not normal_path.exists():
        print('required charts missing')
        return

    easy_chart = load(easy_path)
    normal_chart = load(normal_path)

    phases = sorted(normal_chart.get('phases', []), key=lambda p: p.get('start_ms', 0))
    first_phase = phases[0] if phases else {'start_ms': 0.0, 'bpm': 176.0}
    start_ms = first_phase.get('start_ms', 0.0)
    bpm = first_phase.get('bpm', 176.0)

    easy_notes = easy_chart.get('notes', [])
    normal_notes = normal_chart.get('notes', [])

    new_easy = increase_easy(easy_notes, normal_notes, start_ms, bpm)

    out_chart = {'title': easy_chart.get('title', ''), 'phases': phases, 'notes': new_easy}
    save(out_chart, chart_dir / 'crossingfield_chart_easy_plus.json')
    print('wrote crossingfield_chart_easy_plus.json (increased difficulty slightly)')


if __name__ == '__main__':
    main()
