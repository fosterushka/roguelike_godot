#!/usr/bin/env python3
"""Deterministic architecture and test-manifest checks for the Godot project."""
from __future__ import annotations

import ast
from pathlib import Path
import re
import tempfile


TEST_MANIFEST = "tests/run_all.py"
TEST_DIRECTORY = "tests"
MODULE_ROOT = "modules"
FORBIDDEN_TARGET_ROOTS = ("presentation/", "app/")
RESOURCE_PATH = re.compile(r"res://((?:presentation|app)/[^\"']+)")
CAPTURE_HELPER = re.compile(r".+_(?:capture|host|scene|sheets)\.gd$")
DIRECT_HELPERS = {"render_benchmark.gd", "render_reference.gd", "verify_pack.gd"}
EXCLUDED_RENDER_TESTS = {
    "spatial_batches_render_test.gd": "requires a real GPU render route and is intentionally outside the headless manifest",
}

# These are legacy composition edges. Keep this list per source-to-target edge:
# a new edge fails the check until its owner and reason are reviewed here.
LEGACY_MODULE_TO_PRESENTATION = {
    ("modules/caravan/caravan_runtime.gd", "presentation/vehicles/vehicle_view.gd"): "runtime composes the player vehicle view",
    ("modules/crew/crew_runtime.gd", "presentation/crew/crew_view.gd"): "runtime attaches crew actors to the scene",
    ("modules/crew/crew_runtime.gd", "presentation/ui/ui_locale.gd"): "legacy runtime resolves displayed crew names",
    ("modules/session/session_flow.gd", "presentation/ui/ui_locale.gd"): "legacy session flow resolves displayed mission text",
    ("modules/world/generation/authored_monuments.gd", "presentation/world/military_environment_palette.gd"): "legacy authored monument material selection",
    ("modules/world/generation/authored_monuments.gd", "presentation/world/structure_batch.gd"): "legacy authored monument batching",
    ("modules/world/generation/authored_monuments.gd", "presentation/world/world_primitive_catalog.gd"): "legacy authored monument mesh lookup",
    ("modules/world/generation/authored_monuments.gd", "presentation/world/world_quality_models.gd"): "legacy authored monument model lookup",
    ("modules/world/world_runtime.gd", "presentation/world/activity_view.gd"): "runtime composes activity views",
    ("modules/world/world_runtime.gd", "presentation/world/prop_motion_view.gd"): "runtime composes prop motion views",
    ("modules/world/world_runtime.gd", "presentation/world/weather_view.gd"): "runtime composes weather views",
}


def manifest_tests(project: Path) -> list[str]:
    tree = ast.parse((project / TEST_MANIFEST).read_text())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "TESTS" for target in node.targets):
            if not isinstance(node.value, (ast.List, ast.Tuple)) or not all(isinstance(item, ast.Constant) and isinstance(item.value, str) for item in node.value.elts):
                raise ValueError("TESTS must be a literal list of test filenames")
            return [item.value for item in node.value.elts]
    raise ValueError("TESTS manifest was not found")


def is_explicit_helper(name: str) -> bool:
    return bool(CAPTURE_HELPER.fullmatch(name)) or name in DIRECT_HELPERS


def module_edges(project: Path) -> set[tuple[str, str]]:
    edges = set()
    for source in sorted((project / MODULE_ROOT).rglob("*.gd")):
        for target in RESOURCE_PATH.findall(source.read_text()):
            if target.startswith(FORBIDDEN_TARGET_ROOTS):
                edges.add((source.relative_to(project).as_posix(), target))
    return edges


def validate(project: Path, legacy_edges: set[tuple[str, str]] | None = None) -> list[str]:
    legacy_edges = set(LEGACY_MODULE_TO_PRESENTATION) if legacy_edges is None else legacy_edges
    failures = []
    try:
        tests = manifest_tests(project)
    except (OSError, SyntaxError, ValueError) as error:
        return [f"invalid test manifest: {error}"]
    duplicates = sorted({name for name in tests if tests.count(name) > 1})
    if duplicates:
        failures.append("duplicate TESTS entries: " + ", ".join(duplicates))
    missing = sorted(name for name in tests if not (project / TEST_DIRECTORY / name).is_file())
    if missing:
        failures.append("TESTS entries without files: " + ", ".join(missing))
    test_files = {path.name for path in (project / TEST_DIRECTORY).glob("*.gd")}
    unregistered = sorted(name for name in test_files if name.endswith("_test.gd") and name not in tests and name not in EXCLUDED_RENDER_TESTS)
    if unregistered:
        failures.append("test scripts absent from TESTS: " + ", ".join(unregistered))
    unknown_helpers = sorted(name for name in test_files if not name.endswith("_test.gd") and name not in tests and not is_explicit_helper(name))
    if unknown_helpers:
        failures.append("test scripts need a _test.gd name, manifest entry, or documented helper convention: " + ", ".join(unknown_helpers))
    actual_edges = module_edges(project)
    unexpected_edges = sorted(actual_edges - legacy_edges)
    if unexpected_edges:
        failures.append("new modules-to-presentation/app dependencies: " + ", ".join(f"{source} -> {target}" for source, target in unexpected_edges))
    stale_edges = sorted(legacy_edges - actual_edges)
    if stale_edges:
        failures.append("stale legacy dependency entries must be removed: " + ", ".join(f"{source} -> {target}" for source, target in stale_edges))
    return failures


def self_check() -> list[str]:
    failures = []
    with tempfile.TemporaryDirectory(prefix="architecture-guard-") as directory:
        project = Path(directory)

        def write_manifest(entries: list[str]) -> None:
            tests = project / TEST_DIRECTORY
            tests.mkdir(parents=True, exist_ok=True)
            (tests / "run_all.py").write_text("TESTS = " + repr(entries) + "\n")

        def write(relative_path: str, content: str = "") -> None:
            path = project / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)

        write_manifest(["clean_test.gd"])
        write("tests/clean_test.gd")
        no_legacy_edges: set[tuple[str, str]] = set()
        if validate(project, no_legacy_edges):
            failures.append("clean fixture unexpectedly fails")

        write("modules/example.gd", 'const View = preload("res://presentation/ui/example.gd")\n')
        if not any("new modules-to-presentation/app dependencies" in failure for failure in validate(project, no_legacy_edges)):
            failures.append("forbidden dependency fixture passes")
        (project / "modules/example.gd").unlink()

        write("tests/unregistered_test.gd")
        if not any("test scripts absent from TESTS" in failure for failure in validate(project, no_legacy_edges)):
            failures.append("unregistered test fixture passes")
        (project / "tests/unregistered_test.gd").unlink()

        write_manifest(["clean_test.gd", "clean_test.gd"])
        if not any("duplicate TESTS entries" in failure for failure in validate(project, no_legacy_edges)):
            failures.append("duplicate manifest fixture passes")

        write_manifest(["missing_test.gd"])
        if not any("TESTS entries without files" in failure for failure in validate(project, no_legacy_edges)):
            failures.append("missing manifest file fixture passes")

        (project / "tests/clean_test.gd").unlink()
        write_manifest([])
        write("tests/spatial_batches_render_test.gd")
        if validate(project, no_legacy_edges):
            failures.append("documented render-only test fixture fails")
        stale_edge = {("modules/example.gd", "presentation/ui/example.gd")}
        if not any("stale legacy dependency entries" in failure for failure in validate(project, stale_edge)):
            failures.append("stale legacy dependency fixture passes")
    return failures


def main() -> int:
    project = Path(__file__).resolve().parent.parent
    failures = self_check() + validate(project)
    if failures:
        print("ARCHITECTURE_GUARD_FAIL")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1
    print("ARCHITECTURE_GUARD_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
