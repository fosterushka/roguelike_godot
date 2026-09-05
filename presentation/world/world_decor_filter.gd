extends RefCounted

const COLORS := ["454941", "d59c72", "34383a", "30261f", "30261f", "30261f", "30261f", "4f7285"]
const OFFSETS := [Vector3.ZERO, Vector3(0, 0.55, 0.05), Vector3(0, 0.76, 0.05), Vector3(-0.16, -0.72, -0.12), Vector3(-0.16, -0.72, 0.12), Vector3(0.16, -0.72, -0.12), Vector3(0.16, -0.72, 0.12), Vector3(-0.24, -0.02, 0)]

static func hide_reference_figures(source_world: Node3D) -> int:
	var hidden := 0
	for index in source_world.get_child_count() - COLORS.size() + 1:
		if not _matches_figure(source_world, index):
			continue
		for part in COLORS.size():
			source_world.get_child(index + part).visible = false
			hidden += 1
	return hidden

static func _matches_figure(world: Node3D, start: int) -> bool:
	var origin := Vector3.ZERO
	for offset in COLORS.size():
		var visual := world.get_child(start + offset) as MeshInstance3D
		if visual == null or not visual.has_meta("source_part"):
			return false
		var part: Dictionary = visual.get_meta("source_part")
		if part.name != "part" or part.instances != null or not part.bindings.is_empty():
			return false
		var material := visual.mesh.surface_get_material(0) as StandardMaterial3D
		if material == null or material.albedo_color.to_html(false) != COLORS[offset]:
			return false
		if offset == 0:
			origin = visual.position
		if not visual.basis.is_equal_approx(Basis.from_scale(Vector3.ONE * 0.95)) or visual.position.distance_to(origin + OFFSETS[offset] * 0.95) > 0.0002:
			return false
	return true
