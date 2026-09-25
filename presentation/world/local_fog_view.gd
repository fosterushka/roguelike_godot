extends MeshInstance3D

const Customization = preload("res://modules/caravan/vehicle_customization.gd")
const Visibility = preload("res://modules/combat/visibility_rules.gd")
const FOG_PRIORITY := 100
const CULL_MARGIN := 16384.0
var _environment: Environment

func setup(environment: Environment) -> void:
	_environment = environment
	name = "DirectionalFog"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = CULL_MARGIN
	material_override = ShaderMaterial.new()
	material_override.shader = preload("res://presentation/world/local_fog.gdshader")
	material_override.render_priority = FOG_PRIORITY
	visible = false

func apply_state(player: Dictionary) -> void:
	visible = bool(player.get("customization", {}).get("fog_lamps", false))
	# Native depth fog cannot be removed locally. Equipped lamps use the same
	# weather density in one depth-aware pass, leaving the native path otherwise intact.
	_environment.fog_enabled = not visible
	if not visible:
		return
	material_override.set_shader_parameter("fog_density", _environment.fog_density)
	material_override.set_shader_parameter("fog_color", _environment.fog_light_color)
	configure_beam(material_override, player)

static func configure_beam(material: ShaderMaterial, player: Dictionary) -> void:
	var definition: Dictionary = Customization.FOG_LAMPS
	var point: Vector3 = player.get("position", Vector3.ZERO)
	var heading := float(player.get("heading", 0.0))
	material.set_shader_parameter("lamp_position", Vector2(point.x, point.z))
	material.set_shader_parameter("lamp_direction", Vector2(sin(heading), cos(heading)))
	material.set_shader_parameter("lamp_range", definition.range)
	material.set_shader_parameter("lamp_near_radius", definition.near_radius)
	material.set_shader_parameter("lamp_half_angle", deg_to_rad(float(definition.half_angle_deg)))
	material.set_shader_parameter("lamp_strength", definition.strength if player.get("customization", {}).get("fog_lamps", false) else 0.0)
	material.set_shader_parameter("lamp_angle_edge", Visibility.BEAM_EDGE_RATIO)
	material.set_shader_parameter("lamp_range_edge", Visibility.RANGE_EDGE_RATIO)
