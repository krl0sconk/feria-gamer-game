import json
from pathlib import Path
import numpy as np
import librosa


def load_chart(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save_chart(chart: dict, path: Path):
    path.write_text(json.dumps(chart, indent=1, ensure_ascii=False), encoding="utf-8")


def detect_onsets_and_low_energy(audio_path: Path, n_fft=2048, hop_length=512):
    y, sr = librosa.load(str(audio_path), sr=None)
    # onset times (seconds)
    onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units='frames', hop_length=hop_length)
    onset_times = librosa.frames_to_time(onset_frames, sr=sr, hop_length=hop_length)

    # STFT energy by frequency
    S = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop_length))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=n_fft)
    low_mask = freqs <= 200.0
    low_energy = S[low_mask].sum(axis=0)
    total_energy = S.sum(axis=0)
    # avoid div by zero
    ratio = np.zeros_like(low_energy)
    nz = total_energy > 0
    ratio[nz] = low_energy[nz] / total_energy[nz]
    times = librosa.frames_to_time(np.arange(S.shape[1]), sr=sr, hop_length=hop_length)

    return onset_times, times, ratio, y, sr, S, freqs


def low_energy_at(t_sec, times, ratio):
    idx = np.searchsorted(times, t_sec)
    idx = max(0, min(len(ratio)-1, idx))
    return float(ratio[idx])


def detect_bass_regions(times, ratio, threshold=0.35, min_duration_sec=0.25):
    mask = ratio > threshold
    regions = []
    start = None
    for i, m in enumerate(mask):
        if m and start is None:
            start = times[i]
        elif not m and start is not None:
            end = times[i]
            if end - start >= min_duration_sec:
                regions.append((start, end))
            start = None
    if start is not None:
        end = times[-1]
        if end - start >= min_duration_sec:
            regions.append((start, end))
    # convert to ms
    regions_ms = [(s*1000.0, e*1000.0) for s,e in regions]
    return regions_ms


def quantize_with_onsets(notes, phases, onset_times, times, ratio, mode='normal', bass_threshold=0.35, bass_regions=None):
    out = []
    changes = []
    phase = phases[0] if phases else {'start_ms': 0.0, 'bpm': 120.0}
    start_ms = phase.get('start_ms', 0.0)
    bpm = phase.get('bpm', 120.0)
    beat_ms = 60000.0 / bpm

    for n in notes:
        t = n['time_ms']
        t_sec = t / 1000.0
        # find nearest onset
        if len(onset_times) > 0:
            i = int(np.argmin(np.abs(onset_times - t_sec)))
            onset_t = float(onset_times[i]) * 1000.0
            dist = abs(onset_t - t)
        else:
            onset_t = None
            dist = 1e9

        low_ratio = low_energy_at(t_sec, times, ratio)

        # rules:
        # - if in bass-dominant (low_ratio > bass_threshold) prefer beat snapping
        # - otherwise, if onset nearby (<=150ms) snap to onset; else snap to subdivision
        # if note falls inside a detected bass region, force beat snapping
        if bass_regions is not None:
            in_bass_region = any((t >= r0 and t <= r1) for (r0, r1) in bass_regions)
        else:
            in_bass_region = False

        if low_ratio > bass_threshold or in_bass_region:
            prefer_beat = True
        else:
            prefer_beat = False

        if not prefer_beat and onset_t is not None and dist <= 150.0:
            new_t = onset_t
            snapped_to = 'onset'
        else:
            # snap to nearest beat or subdivision depending on mode
            if mode == 'normal':
                subdiv = beat_ms / 2.0
            else:
                subdiv = beat_ms * 2.0  # easier sparser
            tick = round((t - start_ms) / subdiv)
            new_t = start_ms + tick * subdiv
            snapped_to = 'beat'

        changes.append({'orig': t, 'new': new_t, 'action': n.get('action'), 'low_ratio': low_ratio, 'snapped_to': snapped_to})
        out.append({'action': n.get('action'), 'is_fake': n.get('is_fake', False), 'time_ms': float(new_t)})

    out.sort(key=lambda x: x['time_ms'])
    return out, changes


def make_easy_from_changes(changes, start_ms=0.0, bpm=176.0):
    # keep only downbeats every 4 beats (one per bar) using real BPM
    beat_ms = 60000.0 / bpm
    easy = []
    kept_beats = set()
    for c in changes:
        t = c['new']
        beat_idx = int(round((t - start_ms) / beat_ms))
        if beat_idx % 4 == 0 and beat_idx not in kept_beats:
            easy.append({'action': c['action'], 'is_fake': False, 'time_ms': float(c['new'])})
            kept_beats.add(beat_idx)
    easy.sort(key=lambda x: x['time_ms'])
    return easy


def main():
    root = Path(__file__).resolve().parents[1]
    candidates = [
        root / 'assets' / 'charts' / 'crossingfield_chart.json',
        root / 'assets' / 'charts' / 'crossingfield_chart_normal.json',
        root / 'assets' / 'charts' / 'crossingfield_chart_easy.json',
        root / 'assets' / 'charts' / 'CROSSINGFIELDS.json',
    ]
    chart_path = None
    for c in candidates:
        if c.exists():
            chart_path = c
            break
    if chart_path is None:
        print('chart not found among candidates')
        return
    else:
        print('Using chart:', chart_path)

    chart = load_chart(chart_path)
    notes = chart.get('notes', [])
    phases = sorted(chart.get('phases', []), key=lambda p: p.get('start_ms', 0))
    audio_path = None
    if phases and phases[0].get('audio'):
        audio_path = Path(phases[0]['audio'])

    if not audio_path or not audio_path.exists():
        print('audio file missing in phases or not found')
        return

    onset_times, times, ratio, y, sr, S, freqs = detect_onsets_and_low_energy(audio_path)
    bass_regions = detect_bass_regions(times, ratio, threshold=0.30, min_duration_sec=0.15)

    # determine start and bpm from first phase
    first_phase = phases[0] if phases else {'start_ms': 0.0, 'bpm': 176.0}
    start_ms = first_phase.get('start_ms', 0.0)
    bpm = first_phase.get('bpm', 176.0)

    normal_notes, changes = quantize_with_onsets(notes, phases, onset_times, times, ratio, mode='normal', bass_threshold=0.30, bass_regions=bass_regions)
    easy_notes = make_easy_from_changes(changes, start_ms=start_ms, bpm=bpm)

    normal_chart = {'title': chart.get('title', ''), 'phases': phases, 'notes': normal_notes}
    easy_chart = {'title': chart.get('title', ''), 'phases': phases, 'notes': easy_notes}

    save_chart(normal_chart, chart_path.parent / 'crossingfield_chart_aligned_normal.json')
    save_chart(easy_chart, chart_path.parent / 'crossingfield_chart_aligned_easy.json')
    save_chart({'changes': changes}, chart_path.parent / 'crossingfield_chart_changes.json')

    print('Wrote aligned charts and changes report')

    # generate spectrogram and overlay
    try:
        import matplotlib.pyplot as plt
        import librosa.display

        fig, ax = plt.subplots(figsize=(12, 6))
        S_db = librosa.amplitude_to_db(np.abs(S), ref=np.max)
        img = librosa.display.specshow(S_db, sr=sr, hop_length=512, x_axis='time', y_axis='hz', ax=ax)
        ax.set(title='Spectrogram with onsets and note alignments')
        # plot onsets
        for ot in onset_times:
            ax.axvline(ot, color='cyan', alpha=0.6, linewidth=0.8)
        # original notes (few as red)
        for n in notes[::max(1, len(notes)//200)]:
            ax.plot(n['time_ms']/1000.0, 50, marker='x', color='red')
        # new notes (green)
        for n in normal_notes[::max(1, len(normal_notes)//200)]:
            ax.plot(n['time_ms']/1000.0, 20, marker='o', color='lime')

        fig.colorbar(img, ax=ax, format='%+2.0f dB')
        out_img = chart_path.parent / 'crossingfield_alignment.png'
        fig.savefig(out_img, dpi=150, bbox_inches='tight')
        plt.close(fig)
        print('wrote spectrogram to', out_img)
    except Exception as e:
        print('could not generate spectrogram:', e)


if __name__ == '__main__':
    main()
