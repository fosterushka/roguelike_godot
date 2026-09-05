#!/usr/bin/env python3
"""Explicit offline Godot test manifest. A zero exit code with engine errors is a failure."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

TESTS = [
    'meta_economy_test.gd', 'combo_rewards_test.gd', 'expedition_flow_test.gd',
    'vehicle_motion_test.gd', 'offline_session_test.gd', 'combat_test.gd',
    'advanced_combat_test.gd', 'enemy_ai_test.gd', 'progression_test.gd',
    'world_generation_test.gd', 'natural_props_test.gd', 'authored_props_test.gd',
    'world_builder_test.gd', 'world_gameplay_test.gd', 'world_activities_test.gd',
    'ambient_test.gd', 'world_rebuild_test.gd', 'world_result_test.gd',
    'presentation_test.gd', 'visual_smoke.gd', 'ui_flow_test.gd',
    'integration_test.gd', 'composed_world_seed_test.gd', 'full_run_test.gd',
    'combat_soak_test.gd', 'combat_presentation_test.gd', 'source_fx_test.gd', 'world_presentation_test.gd', 'run_clock_test.gd', 'session_flow_test.gd',
    'presentation_details_test.gd', 'loading_test.gd', 'minimap_test.gd', 'ui_menu_regression_test.gd', 'ui_language_flow_test.gd',
    'hud_layout_test.gd', 'ground_effect_depth_test.gd', 'countdown_ui_test.gd', 'reward_radar_mount_test.gd', 'armory_tiles_test.gd', 'ground_surface_test.gd', 'wheel_vehicle_test.gd', 'radar_progression_test.gd', 'radar_armory_test.gd', 'vehicle_response_test.gd', 'vehicle_render_runtime_test.gd', 'tire_trails_test.gd', 'road_speed_test.gd', 'enemy_factory_test.gd', 'weather_transition_test.gd', 'support_feedback_test.gd', 'support_wave_test.gd', 'jammer_gameplay_test.gd', 'jammer_feedback_test.gd', 'mine_hacking_module_test.gd', 'village_destruction_test.gd', 'village_decoration_test.gd',
]
ERROR = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|WARNING:.*(?:leaked|not freed)|.*(?:Assertion failed|ObjectDB instances leaked))')
SUCCESS = re.compile(r'(?i)(?:\b0 failures\b|\bVISUAL_SMOKE_OK\b)')

def has_success(output):
    if SUCCESS.search(output):
        return True
    return any(int(a) > 0 and int(a) == int(b) for a, b in re.findall(r'(?im)^(?:[^\n]*tests|Combat presentation|Source combat VFX):\s*(\d+)/(\d+)(?:\s+passed)?\s*$', output))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', '/Users/fosterushka/Downloads/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--only', nargs='+', choices=TESTS)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    directory = args.output or Path(tempfile.mkdtemp(prefix='iron-godot-tests-'))
    directory.mkdir(parents=True, exist_ok=True)
    results = []
    for test in args.only or TESTS:
        log = directory / (test + '.engine.log')
        command = [args.godot, '--headless', '--path', str(project), '--log-file', str(log), '--script', 'res://tests/' + test]
        start = time.monotonic()
        try:
            process = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
            output = process.stdout + process.stderr
            (directory / (test + '.stdout.log')).write_text(output)
            combined = output + ('\n' + log.read_text() if log.exists() else '')
            errors = ERROR.findall(combined)
            passed = process.returncode == 0 and not errors and has_success(combined)
            reason = 'clean completion' if passed else 'engine/script errors' if errors else 'missing success summary' if process.returncode == 0 else f'exit {process.returncode}'
        except subprocess.TimeoutExpired as exc:
            passed, reason = False, f'timeout after {args.timeout}s'
            (directory / (test + '.stdout.log')).write_text((exc.stdout or b'').decode(errors='replace') if isinstance(exc.stdout, bytes) else exc.stdout or '')
        entry = {'test': test, 'passed': passed, 'reason': reason, 'seconds': round(time.monotonic() - start, 2)}
        results.append(entry)
        print(f"{'PASS' if passed else 'FAIL'} {test}: {reason} ({entry['seconds']}s)", flush=True)
    report = {'mode': 'headless automated; no GPU rendering, listening or balance-playthrough claim', 'project': str(project), 'results': results}
    (directory / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"{sum(r['passed'] for r in results)}/{len(results)} tests clean; logs {directory}")
    return 0 if all(r['passed'] for r in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
