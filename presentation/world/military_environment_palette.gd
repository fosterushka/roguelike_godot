extends RefCounted

# Shared muted field palette.  Runtime meshes use vertex colors; generated
# structures use these cached material overrides without changing their IDs.
const COLORS := {
	"olive": Color("566044"), "olive_light": Color("788052"),
	"foliage_dark": Color("303c2c"), "bark": Color("4c4030"),
	"sand": Color("a49572"), "sand_dark": Color("746a51"),
	"stone": Color("706d60"), "stone_light": Color("8b8370"),
	"iron": Color("3d4640"), "metal": Color("697066"),
	"rust": Color("7d4b32"), "signal": Color("b47a3b"),
}
static var _materials: Dictionary = {}

static func material_for(role: String) -> StandardMaterial3D:
	if _materials.has(role):
		return _materials[role]
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS.get(role, COLORS.metal)
	material.roughness = 0.92
	material.metallic = 0.32 if role in ["iron", "metal"] else 0.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_materials[role] = material
	return material

static func role_for(source: String) -> String:
	match source:
		"iron", "ironStructure", "metal", "metalStructure": return "iron" if source.begins_with("iron") else "metal"
		"wood", "woodDark", "woodStructure": return "bark"
		"stoneDark", "stone", "ruinStructure", "scarStructure": return "stone"
		"earth", "earthStructure": return "sand_dark"
		"enemyRed", "redStructure", "clothRed": return "rust"
		"clothBlue": return "olive"
		"sheep": return "sand"
		"gold", "goldBright": return "signal"
		_: return "metal"
