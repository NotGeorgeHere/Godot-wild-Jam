class_name Building
extends StaticBody3D

const MAT := preload("res://shader/building_shader.tres")

const TINTS := [
	Color(0.55, 0.55, 0.58),
	Color(0.49, 0.51, 0.53),
	Color(0.58, 0.55, 0.52),
	Color(0.43, 0.45, 0.47),
]

var occupants: int = 0
var remaining: int = 0

var _door_dir := 0.0
var _tint: Color = TINTS[0]
var _fill := 0.0
var _mat: ShaderMaterial

var road_cell := Vector2i(-1, -1)

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	# per-building copy: instance shader params are unreliable in
	# the Compatibility renderer, which is what the web build uses
	_mat = MAT.duplicate()
	mesh.material_override = _mat
	_apply_tint()
	_push_fill()
	_set_dim(1.0)
	set_process(false)


func setup(width: float, depth: float, height: float, variant: int, people: int, door_dir: float) -> void:
	scale = Vector3(width, height, depth)
	occupants = people
	remaining = people
	_fill = 0.0
	_tint = TINTS[variant % TINTS.size()]
	_door_dir = door_dir
	if is_node_ready():
		_apply_tint()
		_push_fill()


func knock(effectiveness: float) -> int:
	if remaining <= 0:
		return 0
	var eff: float = minf(0.95, effectiveness + GameState.active_warning)
	var responded: int = maxi(1, int(round(remaining * eff)))
	responded = mini(responded, remaining)
	remaining -= responded
	set_process(true)     # animate the fill toward its new target
	return responded


func is_cleared() -> bool:
	return occupants > 0 and remaining <= 0


func door_point() -> Vector3:
	var d := door_normal()
	var half := (scale.z if absf(d.z) > 0.5 else scale.x) * 0.5
	return global_position + d * (half + 0.6)


func door_normal() -> Vector3:
	match int(_door_dir):
		1: return Vector3(0.0, 0.0, -1.0)
		2: return Vector3(1.0, 0.0, 0.0)
		3: return Vector3(-1.0, 0.0, 0.0)
		_: return Vector3(0.0, 0.0, 1.0)


func _process(delta: float) -> void:
	var target := _target_fill()
	if absf(_fill - target) < 0.002:
		_fill = target
		_push_fill()
		set_process(false)   # settled — stop burning frames
		return

	_fill = lerpf(_fill, target, 1.0 - exp(-8.0 * delta))
	_push_fill()


func _target_fill() -> float:
	if occupants <= 0:
		return 0.0
	return 1.0 - (float(remaining) / float(occupants))


func _push_fill() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("fill_level", _fill)


func _apply_tint() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("full_color", Vector3(_tint.r, _tint.g, _tint.b))
	_mat.set_shader_parameter("door_dir", _door_dir)

func take_people(n: int) -> int:
	if remaining <= 0:
		return 0
	var taken: int = mini(n, remaining)
	remaining -= taken
	set_process(true)
	return taken

func collapse(delay: float) -> void:
	set_process(false)
	if is_cleared():
		return            # evacuated buildings are left standing

	var tilt_x := randf_range(-0.22, 0.22)
	var tilt_z := randf_range(-0.22, 0.22)
	var drop: float = -scale.y * 0.95
	var dur := randf_range(1.1, 1.7)

	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "position:y", drop, dur) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(self, "rotation:x", tilt_x, dur)
	tw.tween_property(self, "rotation:z", tilt_z, dur)
	tw.tween_method(_set_dim, 1.0, 0.16, dur * 0.8)


func _set_dim(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("dim", v)
