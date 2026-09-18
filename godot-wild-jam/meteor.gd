extends Node3D

const IMPACT := Vector3(0.0, 0.0, 0.0)
const FROM := Vector3(-34.0, 78.0, -26.0)  # world offset from impact, at base zoom
const BASE_VIEW := 180.0                   # camera size these numbers were tuned at

const SCALE_FROM := 2.0
const SCALE_TO := 26.0
const TRAIL_LEN := 13.0
const EASE := 2.3

var _rock: MeshInstance3D
var _trail: MeshInstance3D
var _sparks: CPUParticles3D
var _rock_mat: StandardMaterial3D
var _trail_mat: StandardMaterial3D
var _spin := 0.0


func _ready() -> void:
	_build_rock()
	_build_trail()
	_build_sparks()
	_orient_trail()
	set_progress(0.0, BASE_VIEW)


func _build_rock() -> void:
	_rock_mat = StandardMaterial3D.new()
	_rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rock_mat.albedo_color = Color(1.0, 0.62, 0.22)

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 6

	_rock = MeshInstance3D.new()
	_rock.name = "Rock"
	_rock.mesh = sphere
	_rock.material_override = _rock_mat
	_rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rock)


func _build_trail() -> void:
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.albedo_color = Color(1.0, 0.45, 0.18, 0.30)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.42
	cone.height = TRAIL_LEN
	cone.radial_segments = 8

	_trail = MeshInstance3D.new()
	_trail.name = "Trail"
	_trail.mesh = cone
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


func _build_sparks() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var back := (FROM - IMPACT).normalized()

	_sparks = CPUParticles3D.new()
	_sparks.name = "Sparks"
	_sparks.mesh = quad
	_sparks.amount = 90
	_sparks.lifetime = 0.9
	_sparks.local_coords = true          # ride with the emitter, no world smear
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.45
	_sparks.direction = back             # thrown backwards up the path
	_sparks.spread = 22.0
	_sparks.initial_velocity_min = 5.0
	_sparks.initial_velocity_max = 11.0
	_sparks.gravity = Vector3.ZERO
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.5
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.60, 1.0))
	ramp.set_color(1, Color(0.95, 0.25, 0.08, 0.0))
	_sparks.color_ramp = ramp

	var sizes := Curve.new()
	sizes.add_point(Vector2(0.0, 1.0))
	sizes.add_point(Vector2(1.0, 0.0))
	_sparks.scale_amount_curve = sizes

	add_child(_sparks)


func _orient_trail() -> void:
	# the cone's local +Y must point back along the flight path
	var back := (FROM - IMPACT).normalized()
	var axis := Vector3.UP.cross(back)
	if axis.length_squared() > 0.0001:
		_trail.basis = Basis(axis.normalized(), Vector3.UP.angle_to(back))
	_trail.position = back * (TRAIL_LEN * 0.5)


func set_progress(t: float, _view_size: float = 0.0) -> void:
	visible = true
	if _sparks != null:
		_sparks.emitting = true

	var travel: float = pow(clampf(t, 0.0, 1.0), EASE)

	position = IMPACT + FROM * (1.0 - travel)

	var s: float = lerpf(SCALE_FROM, SCALE_TO, travel)
	scale = Vector3(s, s, s)

	_rock_mat.albedo_color = Color(1.0, 0.62, 0.22).lerp(Color(1.0, 0.96, 0.82), travel)
	_trail_mat.albedo_color = Color(1.0, 0.45, 0.18, lerpf(0.16, 0.52, travel))


func _process(delta: float) -> void:
	_spin += delta * 1.4
	_rock.rotation.y = _spin
	_rock.rotation.x = _spin * 0.6


func hide_meteor() -> void:
	visible = false
	if _sparks != null:
		_sparks.emitting = false
