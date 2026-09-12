extends Node3D

const ROT_STEP := 90.0
const ROT_SPEED := 6.0

const ZOOM_MIN := 60.0
const ZOOM_MAX := 220.0
const ZOOM_STEP := 12.0
const ZOOM_SPEED := 8.0

const PAN_SPEED := 90.0
const PAN_LIMIT := 110.0

@onready var cam: Camera3D = %Camera3D

var _target_yaw := 45.0
var _target_zoom := 125.0


func _ready() -> void:
	_target_yaw = rotation_degrees.y
	_target_zoom = cam.size


func _process(delta: float) -> void:
	_handle_pan(delta)

	# ease toward the target instead of snapping
	var yaw := lerp_angle(
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(_target_yaw),
		1.0 - exp(-ROT_SPEED * delta)
	)
	rotation_degrees.y = rad_to_deg(yaw)

	cam.size = lerpf(cam.size, _target_zoom, 1.0 - exp(-ZOOM_SPEED * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_target_yaw -= ROT_STEP
			KEY_E:
				_target_yaw += ROT_STEP

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func _handle_pan(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0

	if input == Vector2.ZERO:
		return
	input = input.normalized()

	# use the camera's own basis so movement is always screen-relative
	var right := cam.global_transform.basis.x
	var fwd := -cam.global_transform.basis.z

	# flatten to the ground plane — we never want vertical movement
	right.y = 0.0
	fwd.y = 0.0
	right = right.normalized()
	fwd = fwd.normalized()

	var move := right * input.x + fwd * -input.y

	position += move * PAN_SPEED * delta
	position.x = clampf(position.x, -PAN_LIMIT, PAN_LIMIT)
	position.z = clampf(position.z, -PAN_LIMIT, PAN_LIMIT)
