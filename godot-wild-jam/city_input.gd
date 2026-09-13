extends Node

const RAY_LENGTH := 2000.0
const KNOCK_EFFECTIVENESS := 0.35

@onready var camera: Camera3D = %Camera3D

var knock_cooldown := 0.5      # upgrades lower this
var hovered: Building = null

var _cooldown_left := 0.0


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_update_hover()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_knock()


func _update_hover() -> void:
	if hovered != null and not is_instance_valid(hovered):
		hovered = null

	var found := _building_under_mouse()
	if found == hovered:
		return

	hovered = found
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW
	)


func _try_knock() -> void:
	if hovered == null:
		return
	if hovered.remaining <= 0:
		return
	if _cooldown_left > 0.0:
		return

	var saved := hovered.knock(KNOCK_EFFECTIVENESS)
	if saved > 0:
		_cooldown_left = knock_cooldown
		print("saved %d — %d left in this building" % [saved, hovered.remaining])


func _building_under_mouse() -> Building:
	# don't pick buildings through UI elements
	if get_viewport().gui_get_hovered_control() != null:
		return null

	var mouse := get_viewport().get_mouse_position()

	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH

	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return null
	return hit.get("collider") as Building
