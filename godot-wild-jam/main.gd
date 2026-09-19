extends Node3D

const DAY_LENGTH := 60.0
const START_HOUR := 8.0
const END_HOUR := 20.0
const DOOM_BEGINS := 0.72      # sky starts reddening here

@onready var city := $City
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var hud := $HUD
@onready var cam: Camera3D = %Camera3D
@onready var vehicles := $Vehicles
@onready var meteor := %Meteor

var _elapsed := 0.0
var _running := false
var _shake := 0.0

var _sun_yaw := 0.0
var _ambient_base := Color.WHITE
var _ambient_energy := 0.35


func _ready() -> void:
	_sun_yaw = sun.rotation_degrees.y

	var env := world_env.environment
	if env != null:
		_ambient_base = env.ambient_light_color
		_ambient_energy = env.ambient_light_energy

	GameState.all_saved.connect(_on_all_saved)
	hud.continue_pressed.connect(_start_day)
	hud.intro_dismissed.connect(_begin_running)

	# build the city behind the intro so there's something to look at
	_prepare_day()
	hud.show_intro()


func _prepare_day() -> void:
	vehicles.clear_all()
	city.generate()
	GameState.begin_day(city.population)
	_elapsed = 0.0
	_running = false           # frozen until the player is ready
	meteor.set_progress(0.0, cam.size)
	hud.hide_results()


func _begin_running() -> void:
	_running = true
	Audio.start_ambience()
	if GameState.active_warning > 0.0:
		Audio.play("siren")


func _start_day() -> void:
	_prepare_day()
	_begin_running()


func _process(delta: float) -> void:
	if _running:
		_elapsed += delta
		var t: float = clampf(_elapsed / DAY_LENGTH, 0.0, 1.0)
		_update_sky(t)
		hud.set_clock(START_HOUR + t * (END_HOUR - START_HOUR), t)
		if _elapsed >= DAY_LENGTH:
			_end_day()

	_update_shake(delta)


func _update_sky(t: float) -> void:
	meteor.set_progress(t, cam.size)

	var arc := sin(t * PI)                 # 0 at dawn, 1 at noon, 0 at dusk
	var doom: float = clampf((t - DOOM_BEGINS) / (1.0 - DOOM_BEGINS), 0.0, 1.0)

	sun.rotation_degrees = Vector3(-lerpf(12.0, 55.0, arc), _sun_yaw, 0.0)

	var warm := Color(1.0, 0.82, 0.62)
	var noon := Color(1.0, 0.97, 0.92)
	sun.light_color = warm.lerp(noon, arc).lerp(Color(1.0, 0.30, 0.16), doom)
	sun.light_energy = lerpf(1.3, 2.0, arc) * lerpf(1.0, 0.55, doom)

	var env := world_env.environment
	if env != null:
		env.ambient_light_color = _ambient_base.lerp(Color(0.85, 0.28, 0.20), doom)
		env.ambient_light_energy = _ambient_energy * lerpf(1.0, 1.5, doom)

	Audio.set_doom(t)
	Audio.set_zoom(cam.size)


func _end_day() -> void:
	_running = false
	_shake = 1.0
	meteor.hide_meteor()
	hud.flash(Color(1.0, 0.42, 0.20))
	Audio.play("impact")
	Audio.stop_ambience()
	_collapse_city()
	await get_tree().create_timer(2.6).timeout
	GameState.end_day()


func _on_all_saved() -> void:
	if not _running:
		return
	_running = false
	meteor.hide_meteor()
	hud.flash(Color(0.45, 1.0, 0.65))     # green, not the disaster orange
	Audio.play("win")
	Audio.stop_ambience()
	await get_tree().create_timer(0.8).timeout
	GameState.end_day()


func _collapse_city() -> void:
	var impact := Vector3.ZERO
	for b in city.all_buildings():
		var d: float = Vector3(b.global_position.x, 0.0, b.global_position.z).distance_to(impact)
		# shockwave travels outward at ~90 units/sec
		b.collapse(d / 90.0 + randf_range(0.0, 0.12))


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 0.7)
	var amt: float = _shake * _shake * 7.0
	cam.h_offset = randf_range(-amt, amt)
	cam.v_offset = randf_range(-amt, amt)
	if _shake <= 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# debug reroll — only between days
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not _running:
			_start_day()
