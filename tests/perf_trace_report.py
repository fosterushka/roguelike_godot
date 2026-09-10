#!/usr/bin/env python3
"""Report combat_performance_capture runs.

Reads `<run>/sustained.json` plus the per-phase `<phase>-frames.json[.gz]` traces written by
`--frame-trace` and prints either per-phase detail or one markdown table across runs.

    python3 tests/perf_trace_report.py docs/validation/claude-perf/npc-scaling-01
    python3 tests/perf_trace_report.py --table docs/validation/claude-perf/*

1% low is `1000 / mean(slowest ceil(N * 0.01) frame times in ms)`, the same formula the F3
panel uses. "tick frame" and "free frame" separate rendered frames that carried a physics
tick from those that did not; their gap is the frame pacing the player actually sees.
"""
import argparse
import gzip
import json
import math
import os
import statistics


def load_trace(run_dir, phase_name):
    base = os.path.join(run_dir, phase_name + '-frames.json')
    for path, opener in ((base, open), (base + '.gz', gzip.open)):
        if os.path.exists(path):
            with opener(path) as handle:
                return json.load(handle)
    return None


def percentile(sorted_ms, quantile):
    index = min(len(sorted_ms) - 1, max(0, math.ceil(quantile * len(sorted_ms)) - 1))
    return sorted_ms[index]


def low_fps(sorted_ms, fraction):
    count = max(1, math.ceil(len(sorted_ms) * fraction))
    worst = sorted_ms[-count:]
    return 1000.0 / (sum(worst) / len(worst))


def phase_rows(run_dir):
    with open(os.path.join(run_dir, 'sustained.json')) as handle:
        run = json.load(handle)
    rows = []
    for phase in run['phases']:
        row = {
            'run': os.path.basename(run_dir.rstrip('/')), 'phase': phase['name'],
            'npc': phase.get('spawned_npc', phase.get('npc_end')),
            'kinds': phase.get('npc_kinds', {}),
            'disabled': phase.get('ui_disabled') or '-', 'ui_mode': phase.get('ui_mode', ''),
            'ui_gate_corrections': phase.get('ui_gate_corrections'),
            'ui_hidden_at_draw': phase.get('ui_hidden_at_draw'),
            'cap': phase.get('fps_limit'), 'window': phase.get('window_size'),
            'viewport': phase.get('viewport_size'), 'scale': phase.get('render_scale'),
            'msaa': phase.get('msaa'), 'vsync': phase.get('vsync'),
            'avg_fps': phase['frames']['average_fps'], 'low_1': phase['frames']['low_1'],
            'low_01': phase['frames'].get('low_01'),
            'engine_physics': phase.get('engine_physics_ms_per_tick'),
            'draw_calls': phase.get('draw_calls'), 'rendered': phase.get('rendered_objects'),
            'sections': {name: round(value['ms_per_frame'], 3) for name, value in
                         sorted(phase['sections'].items(), key=lambda item: -item[1]['ms_per_frame'])},
        }
        trace = load_trace(run_dir, phase['name'])
        if trace:
            frame_ms = [frame['ms'] for frame in trace]
            ordered = sorted(frame_ms)
            count = len(frame_ms)
            worst_count = max(1, math.ceil(count * 0.01))
            slowest = sorted(trace, key=lambda frame: -frame['ms'])[:worst_count]
            slow_sections = {}
            for frame in slowest:
                for name, value in frame['sections'].items():
                    slow_sections[name] = slow_sections.get(name, 0.0) + value['usec'] / 1000.0
            ticked = [frame['ms'] for frame in trace if frame['physics_ticks'] > 0]
            free = [frame['ms'] for frame in trace if frame['physics_ticks'] == 0]
            by_ticks = {}
            for frame in slowest:
                by_ticks.setdefault(frame['physics_ticks'], []).append(frame['ms'])
            row.update({
                'frames': count, 'seconds': round(sum(frame_ms) / 1000.0, 2),
                'trace_avg_fps': round(1000.0 * count / sum(frame_ms), 2),
                'avg_ms': round(sum(frame_ms) / count, 3),
                'trace_low_1': round(low_fps(ordered, 0.01), 2),
                'trace_low_01': round(low_fps(ordered, 0.001), 2),
                'p95_ms': round(percentile(ordered, 0.95), 2),
                'p99_ms': round(percentile(ordered, 0.99), 2), 'worst_ms': round(ordered[-1], 2),
                'over_16_7': sum(1 for value in frame_ms if value > 16.67),
                'over_33_3': sum(1 for value in frame_ms if value > 33.33),
                'pacing_ms': round(statistics.mean(
                    abs(frame_ms[i] - frame_ms[i - 1]) for i in range(1, count)), 2),
                'tick_frame_ms': round(sum(ticked) / len(ticked), 2) if ticked else None,
                'free_frame_ms': round(sum(free) / len(free), 2) if free else None,
                'tick_frames': len(ticked), 'free_frames': len(free),
                'slow_by_ticks': {ticks: [len(values), round(sum(values) / len(values), 2)]
                                  for ticks, values in sorted(by_ticks.items())},
                'slow_sections_ms': {name: round(total / worst_count, 3) for name, total in
                                     sorted(slow_sections.items(), key=lambda item: -item[1])},
            })
        rows.append(row)
    return run, rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('runs', nargs='+', help='run directories holding sustained.json')
    parser.add_argument('--table', action='store_true', help='one markdown row per phase')
    arguments = parser.parse_args()
    if arguments.table:
        print('| run | phase | NPC | disabled | fps cap | avg FPS | 1% low | 0.1% low | pacing ms | tick frame ms | free frame ms | physics ms/tick | draw calls | rendered |')
        print('| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |')
    for run_dir in arguments.runs:
        if not os.path.exists(os.path.join(run_dir, 'sustained.json')):
            continue
        run, rows = phase_rows(run_dir)
        if not arguments.table:
            print('#', run_dir, '|', run.get('adapter'), '| seed', run.get('seed'))
        for row in rows:
            if arguments.table:
                def cell(key, digits=2):
                    value = row.get(key)
                    return '' if value is None else ('%.*f' % (digits, value) if isinstance(value, float) else str(value))
                print('| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (
                    row['run'], row['phase'], row['npc'], row['disabled'], cell('cap', 0),
                    cell('avg_fps'), cell('low_1'), cell('low_01'), cell('pacing_ms'),
                    cell('tick_frame_ms'), cell('free_frame_ms'), cell('engine_physics'),
                    cell('draw_calls', 0), cell('rendered', 0)))
            else:
                print(json.dumps(row, ensure_ascii=False))
        if not arguments.table:
            print()


if __name__ == '__main__':
    main()
