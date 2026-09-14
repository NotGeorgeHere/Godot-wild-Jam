extends Node

signal saved_changed(saved: int, total: int)
signal day_ended(saved: int, total: int)

# resets every loop
var total_population := 0
var saved_today := 0
var day_active := false

# persists across loops
var currency := 0
var loop_number := 0
var knock_cooldown := 0.5
var knock_effectiveness := 0.35


func begin_day(population: int) -> void:
	loop_number += 1
	total_population = population
	saved_today = 0
	day_active = true
	saved_changed.emit(saved_today, total_population)


func add_saved(count: int) -> void:
	saved_today += count
	saved_changed.emit(saved_today, total_population)


func end_day() -> void:
	day_active = false
	day_ended.emit(saved_today, total_population)
