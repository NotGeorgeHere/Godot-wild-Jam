extends Node

const KNOCK_COUNT := 4
const POOL_SIZE := 8

const CLOSE_VIEW := 70.0
const FAR_VIEW := 200.0

# per-sound trim, so noisy sources don't need re-exporting
const LEVELS := {
	"knock": -9.0,
	"megaphone": -2.0,
	"radio": -3.0,
	"tv": -3.0,
	"siren": -5.0,
	"car_horn": -6.0,
	"impact": 0.0,
	"win": -3.0,
	"purchase": -6.0,
	"click": -8.0,
}

var _streams := {}
var _knocks: Array[AudioStream] = []
var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _rumble: AudioStreamPlayer
var _crowd: AudioStreamPlayer

var _shop_music: AudioStreamPlayer

func _ready() -> void:
	for i in range(1, KNOCK_COUNT + 1):
		var path := "res://sfx/knock_%d.wav" % i
		if ResourceLoader.exists(path):
			_knocks.append(load(path))

	for id in ["megaphone", "radio", "tv", "siren", "car_horn",
			"impact", "win", "purchase", "click"]:
		var path := "res://sfx/%s.wav" % id
		if ResourceLoader.exists(path):
			_streams[id] = load(path)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	_rumble = _make_loop("res://sfx/rumble_loop.wav", "Ambient", -8.0)
	_crowd = _make_loop("res://sfx/crowd_loop.wav", "Ambient", -12.0)
	_shop_music = _make_loop("res://music/shop_music.ogg", "Ambient", -16.0)


func _make_loop(path: String, bus: String, db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p


func play(id: String, pitch_jitter := 0.0) -> void:
	if not _streams.has(id):
		return
	_fire(_streams[id], pitch_jitter, LEVELS.get(id, 0.0))


func play_knock() -> void:
	if _knocks.is_empty():
		return
	_fire(_knocks[randi() % _knocks.size()], 0.10, LEVELS["knock"])


func click() -> void:
	if not _streams.has("click"):
		return
	# UI gets its own player so a knock can't steal its slot
	var p := AudioStreamPlayer.new()
	p.stream = _streams["click"]
	p.bus = "UI"
	p.volume_db = LEVELS.get("click", 0.0)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _fire(stream: AudioStream, jitter: float, db: float) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = db          # pooled players are reused, so always set this
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()


func start_ambience() -> void:
	if _rumble != null and not _rumble.playing:
		_rumble.play()
	if _crowd != null and not _crowd.playing:
		_crowd.play()


func stop_ambience() -> void:
	if _rumble != null:
		_rumble.stop()
	if _crowd != null:
		_crowd.stop()


func set_doom(t: float) -> void:
	# rumble swells through the day
	if _rumble != null:
		_rumble.volume_db = lerpf(-22.0, -2.0, pow(clampf(t, 0.0, 1.0), 1.8))


func set_zoom(view_size: float) -> void:
	var t: float = clampf(inverse_lerp(CLOSE_VIEW, FAR_VIEW, view_size), 0.0, 1.0)
	_set_bus("SFX", Settings.sfx_db + lerpf(2.0, -9.0, t))
	if _crowd != null:
		_crowd.volume_db = lerpf(-6.0, -26.0, t)


func _set_bus(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func toggle_mute() -> bool:
	var muted := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
	return muted

func start_shop_music() -> void:
	if _shop_music != null and not _shop_music.playing:
		_shop_music.play()


func stop_shop_music() -> void:
	if _shop_music != null:
		_shop_music.stop()
