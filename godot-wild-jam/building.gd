class_name Building
extends StaticBody3D

const MAT := preload("res://shader/building_shader.tres")

const TINTS := [
	Color(0.55, 0.55, 0.58),
	Color(0.49, 0.51, 0.53),
	Color(0.58, 0.55, 0.52),
	Color(0.43, 0.45, 0.47),
]
var _door_dir := 0.0

var occupants: int = 0
var remaining: int = 0

var _tint: Color = TINTS[0]
var _fill := 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	mesh.material_override = MAT
	_apply_tint()
	_push_fill()
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
	var responded: int = maxi(1, int(round(remaining * effectiveness)))
	responded = mini(responded, remaining)
	remaining -= responded
	set_process(true)     # animate the fill toward its new target
	return responded


func is_cleared() -> bool:
	return occupants > 0 and remaining <= 0


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
	mesh.set_instance_shader_parameter("fill_level", _fill)


func _apply_tint() -> void:
	mesh.set_instance_shader_parameter("full_color", Vector3(_tint.r, _tint.g, _tint.b))
	mesh.set_instance_shader_parameter("door_dir", _door_dir)
