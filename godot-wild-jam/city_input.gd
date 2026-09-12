extends Node

const RAY_LENGTH := 2000.0

@onready var camera: Camera3D = %Camera3D

var hovered: Building = null


func _process(_delta: float) -> void:
	# a regenerated city frees the old buildings under us
	if hovered != null and not is_instance_valid(hovered):
		hovered = null

	var found := _building_under_mouse()
	if found == hovered:
		return

	if hovered != null:
		hovered.set_hovered(false)
	hovered = found
	if hovered != null:
		hovered.set_hovered(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and hovered != null:
			hovered.toggle_marked()


func _building_under_mouse() -> Building:
	var mouse := get_viewport().get_mouse_position()

	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH

	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return null
	return hit.get("collider") as Building
