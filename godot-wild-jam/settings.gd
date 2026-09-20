extends Node

signal changed

const CONFIG_PATH := "user://settings.cfg"

var sfx_db := 0.0
var ambient_db := 0.0
var ui_db := 0.0
var reduce_motion := false
var day_length := 60.0


func _ready() -> void:
	load_settings()
	apply_audio()


func apply_audio() -> void:
	_set_bus("SFX", sfx_db)
	_set_bus("Ambient", ambient_db)
	_set_bus("UI", ui_db)


func _set_bus(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, db <= -39.0)      # slider at the bottom = off


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_db)
	cfg.set_value("audio", "ambient", ambient_db)
	cfg.set_value("audio", "ui", ui_db)
	cfg.set_value("access", "reduce_motion", reduce_motion)
	cfg.set_value("game", "day_length", day_length)
	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	sfx_db = cfg.get_value("audio", "sfx", 0.0)
	ambient_db = cfg.get_value("audio", "ambient", 0.0)
	ui_db = cfg.get_value("audio", "ui", 0.0)
	reduce_motion = cfg.get_value("access", "reduce_motion", false)
	day_length = cfg.get_value("game", "day_length", 60.0)
	changed.emit()
