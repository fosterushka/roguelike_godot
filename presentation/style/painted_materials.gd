extends RefCounted

const INK_SHADER = preload("res://presentation/style/ink_outline.gdshader")
const PALETTE := {
	"leaf": "6c915f", "leaf2": "92ad68", "grassDark": "647b4b",
	"wood": "967052", "stone": "b1aa93",
	"dirt": "b39469", "flower": "efc279"
}
static var _ink: ShaderMaterial

static func apply(material: StandardMaterial3D, data: Dictionary) -> void:
	if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = maxf(material.roughness, 0.78)
	material.metallic = minf(material.metallic, 0.22)
	if PALETTE.has(str(data.get("name", ""))):
		material.albedo_color = Color(PALETTE[str(data.name)])
	if bool(data.get("painted_outline", false)) and material.cull_mode == BaseMaterial3D.CULL_BACK:
		if _ink == null:
			_ink = ShaderMaterial.new()
			_ink.shader = INK_SHADER
		material.next_pass = _ink
