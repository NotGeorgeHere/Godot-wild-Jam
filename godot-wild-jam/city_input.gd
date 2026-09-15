extends Node

const RAY_LENGTH := 2000.0

@onready var camera: Camera3D = %Camera3D
@onready var citizens := %Citizens
@onready var city := %City
@onready var ring: MeshInstance3D = %AOERing
@onready var vehicles := %Vehicles

var hovered: Building = null

var _cooldown_left := 0.0
var _ground_point := Vector3.ZERO
var _was_pressed := false
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		_use_tool(GameState.selected_tool)


func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


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
	var id := GameState.selected_tool
	var active := id != "" and GameState.day_active
	ring.visible = active
	if not active:
		return

	var col: Color = GameState.TOOLS[id]["colour"]
	_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.7)

	var r := GameState.radius_of(id)
	ring.position = _ground_point + Vector3(0.0, 0.25, 0.0)
	ring.scale = Vector3(r, 1.0, r)

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
		citizens.spawn(hovered.door_point(), hovered.road_cell, mini(saved, 6))


func _use_tool(id: String) -> void:
	if not GameState.day_active:
		return

	var data: Dictionary = GameState.TOOLS[id]
	if data.get("deploy", false):
		_deploy_vehicle()
		return

	var targets: Array = city.buildings_within(_ground_point, GameState.radius_of(id))
	var eff := GameState.effectiveness_of(id)
	var per_building: int = data["sprites"]

	var total := 0
	for b in targets:
		var got: int = b.knock(eff)
		if got > 0:
			total += got
			citizens.spawn(b.door_point(), b.road_cell, mini(got, per_building))

	if total > 0:
		GameState.add_saved(total)
		GameState.consume(id)


func _deploy_vehicle() -> void:
	var cell: Vector2i = city.world_to_cell(_ground_point)
	var road: Vector2i = city.nearest_road_cell(cell, 4)
	if road.x < 0:
		return
	if vehicles.deploy(road):
		GameState.consume("vehicle")
