extends Node

const RAY_LENGTH := 2000.0

@onready var camera: Camera3D = %Camera3D
@onready var citizens := %Citizens
@onready var city := %City
@onready var ring: MeshInstance3D = %AOERing

var hovered: Building = null

var _cooldown_left := 0.0
var _ground_point := Vector3.ZERO
var _was_pressed := false


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_ground_point = _mouse_ground_point()
	_update_hover()
	_update_ring()

	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _over_ui()
	var just_pressed := pressed and not _was_pressed
	_was_pressed = pressed

	if GameState.selected_tool == "":
		if pressed:
			_try_knock()
	elif just_pressed:
		_use_megaphone()


func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# ------------------------------------------------------------------ targeting

func _mouse_ground_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	return from + dir * (-from.y / dir.y)


func _building_under_mouse() -> Building:
	if _over_ui():
		return null

	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH

	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return null
	return hit.get("collider") as Building


func _update_hover() -> void:
	if hovered != null and not is_instance_valid(hovered):
		hovered = null

	var found := _building_under_mouse() if GameState.selected_tool == "" else null
	if found == hovered:
		return

	hovered = found
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if hovered != null else Input.CURSOR_ARROW
	)


func _update_ring() -> void:
	var active := GameState.selected_tool == "megaphone" and GameState.day_active
	ring.visible = active
	if not active:
		return
	var r := GameState.megaphone_radius()
	ring.position = _ground_point + Vector3(0.0, 0.25, 0.0)
	ring.scale = Vector3(r, 1.0, r)


# --------------------------------------------------------------------- actions

func _try_knock() -> void:
	if not GameState.day_active:
		return
	if hovered == null or hovered.remaining <= 0:
		return
	if _cooldown_left > 0.0:
		return

	var saved := hovered.knock(GameState.knock_effectiveness)
	if saved > 0:
		_cooldown_left = GameState.knock_cooldown
		GameState.add_saved(saved)
		citizens.spawn(hovered.door_point(), hovered.door_normal(), mini(saved, 6))


func _use_megaphone() -> void:
	if not GameState.day_active:
		return

	var targets: Array = city.buildings_within(_ground_point, GameState.megaphone_radius())
	var total := 0
	for b in targets:
		var got: int = b.knock(GameState.megaphone_effectiveness())
		if got > 0:
			total += got
			citizens.spawn(b.door_point(), b.door_normal(), mini(got, 4))

	if total > 0:
		GameState.add_saved(total)
		GameState.consume("megaphone")
