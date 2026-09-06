"""Regenerate the offline loading catalog after adding source assets or data."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
RUNTIME_EXTENSIONS = {".png", ".webp", ".wav", ".ogg", ".glb", ".gdshader", ".gdshaderinc", ".ttf", ".otf"}
resources = [
    "res://" + str(path.relative_to(root))
    for path in (root / "assets").rglob("*")
    if path.is_file() and path.suffix in RUNTIME_EXTENSIONS and "models" not in path.relative_to(root / "assets").parts
]
resources += ["res://" + str(path.relative_to(root)) for path in (root / "presentation").rglob("*") if path.suffix in (".gdshader", ".gdshaderinc")]
data = [
    "res://" + str(path.relative_to(root))
    for path in (root / "data").rglob("*.json")
    if path.name != "asset_manifest.json"
]
(root / "data/asset_manifest.json").write_text(
    json.dumps({"resources": sorted(resources), "data": sorted(data)}, indent=2) + "\n"
)
print(f"Loading manifest: {len(resources)} resources, {len(data)} JSON files")
