import json
import math
from pathlib import Path


def load_chart(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save_chart(chart: dict, path: Path):
    path.write_text(json.dumps(chart, indent=1, ensure_ascii=False), encoding="utf-8")


def find_phase(phases, t_ms):
    # phases assumed sorted by start_ms
    phase = phases[0]
    for p in phases:
        if t_ms >= p.get("start_ms", 0):
            phase = p
        else:
            break
    return phase


def quantize_notes(notes, phases, mode="normal"):
    out = []
    seen = set()
    for n in notes:
        t = n["time_ms"]
        phase = find_phase(phases, t)
        start = phase.get("start_ms", 0.0)
        bpm = phase.get("bpm", 120.0)
        beat_ms = 60000.0 / bpm

        if mode == "normal":
            subdiv = beat_ms / 2.0  # 8th notes
            tick = round((t - start) / subdiv)
            new_t = start + tick * subdiv
            key = (n["action"], int(round(new_t)))
            if key in seen:
                continue
            seen.add(key)
            out.append({"action": n["action"], "is_fake": n.get("is_fake", False), "time_ms": float(new_t)})

        elif mode == "easy":
            subdiv = beat_ms  # quarter notes
            tick = round((t - start) / subdiv)
            # keep only every 2 quarters (every 2 beats) to reduce density
            if tick % 2 != 0:
                continue
            new_t = start + tick * subdiv
            key = (n["action"], int(round(new_t)))
            if key in seen:
                continue
            seen.add(key)
            out.append({"action": n["action"], "is_fake": n.get("is_fake", False), "time_ms": float(new_t)})

    # sort by time
    out.sort(key=lambda x: x["time_ms"])
    return out


def main():
    root = Path(__file__).resolve().parents[1]
    chart_path = root / "assets" / "charts" / "crossingfield_chart.json"
    if not chart_path.exists():
        print("chart not found:", chart_path)
        return

    chart = load_chart(chart_path)
    notes = chart.get("notes", [])
    phases = sorted(chart.get("phases", []), key=lambda p: p.get("start_ms", 0))

    normal_notes = quantize_notes(notes, phases, mode="normal")
    easy_notes = quantize_notes(notes, phases, mode="easy")

    normal_chart = {"title": chart.get("title", ""), "phases": phases, "notes": normal_notes}
    easy_chart = {"title": chart.get("title", ""), "phases": phases, "notes": easy_notes}

    save_chart(normal_chart, chart_path.parent / "crossingfield_chart_normal.json")
    save_chart(easy_chart, chart_path.parent / "crossingfield_chart_easy.json")
    print("Generated crossingfield_chart_normal.json and crossingfield_chart_easy.json")


if __name__ == "__main__":
    main()
