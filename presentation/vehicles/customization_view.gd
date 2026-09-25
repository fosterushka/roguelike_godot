extends RefCounted

const Catalog = preload("res://modules/caravan/vehicle_customization.gd")
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const LAMP_COLOR := Color("ffe3aa")
const LAMP_ENERGY := 2.2
const PAINT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec4 paint : source_color;
uniform float roughness_value = 0.82;
uniform float metallic_value = 0.0;
void fragment() {
	vec3 original = texture(palette, UV).rgb;
	float match_distance = distance(original, texture(palette, vec2(0.125, 0.125)).rgb);
	match_distance = min(match_distance, distance(original, texture(palette, vec2(0.125, 0.375)).rgb));
	match_distance = min(match_distance, distance(original, texture(palette, vec2(0.125, 0.875)).rgb));
	match_distance = min(match_distance, distance(original, texture(palette, vec2(0.375, 0.875)).rgb));
	match_distance = min(match_distance, distance(original, texture(palette, vec2(0.625, 0.875)).rgb));
	match_distance = min(match_distance, distance(original, texture(palette, vec2(0.875, 0.875)).rgb));
	float luminance = dot(original, vec3(0.2126, 0.7152, 0.0722));
	vec3 painted = paint.rgb * clamp(luminance / 0.35, 0.2, 1.35);
	ALBEDO = mix(original, painted, 1.0 - step(0.001, match_distance));
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
"""
static var _paint_shader: Shader

static func apply(rig: Node3D, selected: Dictionary, box: Callable, cylinder: Callable) -> void:
	var config := {"paint": str(selected.get("paint", "field")), "emblem": str(selected.get("emblem", "none")), "tires": str(selected.get("tires", "standard")), "fog_lamps": bool(selected.get("fog_lamps", false))}
	if rig.get_meta("customization", {}) == config:
		return
	rig.set_meta("customization", config)
	_paint(rig, config.paint)
	var previous := rig.get_node_or_null("Customization")
	if previous != null:
		previous.free()
	var parts := Node3D.new()
	parts.name = "Customization"
	rig.add_child(parts)
	var scale_value := Dimensions.MODEL_SCALE
	if config.emblem != "none" and Catalog.EMBLEMS.has(config.emblem):
		box.call(parts, "HoodEmblem", Vector3(0.22, 0.018, 0.7) * scale_value, Vector3(0, 1.612, 2.0) * scale_value, "eee3c5")
		if config.emblem == "cross":
			box.call(parts, "HoodEmblemCrossbar", Vector3(0.68, 0.018, 0.2) * scale_value, Vector3(0, 1.614, 2.0) * scale_value, "eee3c5")
	if config.fog_lamps:
		for side in [-1, 1]:
			var center := Vector3(side * 0.78, 1.0, 3.34) * scale_value
			cylinder.call(parts, "FogLampHousing", 0.22 * scale_value, 0.18 * scale_value, center, "242a29", Vector3(PI * 0.5, 0, 0))
			box.call(parts, "FogLampLens", Vector3(0.29, 0.25, 0.025) * scale_value, center + Vector3(0, 0, 0.105) * scale_value, "ffe3aa", Vector3.ZERO, true)
			var light := SpotLight3D.new()
			light.name = "FogBeamLeft" if side < 0 else "FogBeamRight"
			light.position = center + Vector3(0, 0, 0.14) * scale_value
			light.rotation.y = PI
			light.spot_range = float(Catalog.FOG_LAMPS.range)
			light.spot_angle = float(Catalog.FOG_LAMPS.half_angle_deg)
			light.spot_attenuation = 0.75
			light.light_color = LAMP_COLOR
			light.light_energy = LAMP_ENERGY
			light.shadow_enabled = false
			parts.add_child(light)
	for wheel: Node3D in rig.get_meta("wheels", []):
		var spin: Node3D = wheel.get_child(0)
		var old := spin.get_node_or_null("TireCustomization")
		if old != null:
			old.free()
		if config.tires == "standard":
			continue
		var trim := Node3D.new()
		trim.name = "TireCustomization"
		spin.add_child(trim)
		if config.tires == "road_tires":
			# Thin hub rings rotate with the original wheel; the imported tire stays shared.
			cylinder.call(trim, "RoadHub", 0.31, 0.026, Vector3(signf(wheel.position.x) * 0.43, 0, 0), "b9b7a0", Vector3(0, 0, PI * 0.5))
		elif config.tires == "mud_tires":
			for index in 12:
				var angle := TAU * index / 12.0
				box.call(trim, "MudTread%d" % index, Vector3(0.58, 0.12, 0.23), Vector3(0, sin(angle), cos(angle)) * 0.86, "272923", Vector3(-angle, 0, 0))

static func _paint(rig: Node3D, id: String) -> void:
	# GLB inspection: PICKUP_BODY has one palette material; wheels have separate nodes.
	var body := rig.get_meta("model").find_child("PICKUP_BODY", true, false) as MeshInstance3D
	if not body.has_meta("original_material"):
		body.set_meta("original_material", body.get_active_material(0))
	if id == "field" or not Catalog.PAINTS.has(id):
		body.material_override = null
		return
	if _paint_shader == null:
		_paint_shader = Shader.new()
		_paint_shader.code = PAINT_SHADER
	var original := body.get_meta("original_material") as BaseMaterial3D
	var material := ShaderMaterial.new()
	material.shader = _paint_shader
	material.set_shader_parameter("palette", original.albedo_texture)
	material.set_shader_parameter("paint", Catalog.PAINTS[id].color)
	material.set_shader_parameter("roughness_value", original.roughness)
	material.set_shader_parameter("metallic_value", original.metallic)
	body.material_override = material
