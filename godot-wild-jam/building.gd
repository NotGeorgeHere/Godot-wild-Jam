class_name Building
extends StaticBody3D

const MATS_NORMAL := [
	preload("res://materials/building_a.tres"),
	preload("res://materials/building_b.tres"),
	preload("res://materials/building_c.tres"),
	preload("res://materials/building_d.tres"),
]
const MAT_HOVER := preload("res://materials/building_hover.tres")
const MAT_MARKED := preload("res://materials/building_marked.tres")

var is_marked := false

var _normal: Material = MATS_NORMAL[0]
var _hovered := false

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_refresh()


func setup(footprint: float, height: float, variant: int) -> void:
	scale = Vector3(footprint, height, footprint)
	_normal = MATS_NORMAL[variant % MATS_NORMAL.size()]
	if is_node_ready():
		_refresh()


func set_hovered(value: bool) -> void:
	_hovered = value
	_refresh()


func toggle_marked() -> void:
	is_marked = not is_marked
	_refresh()


func _refresh() -> void:
	if is_marked:
		mesh.material_override = MAT_MARKED
	elif _hovered:
		mesh.material_override = MAT_HOVER
	else:
		mesh.material_override = _normal
