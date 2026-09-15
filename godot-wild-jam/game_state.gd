extends Node

signal saved_changed(saved: int, total: int)
signal day_ended(saved: int, total: int)
signal inventory_changed
signal tool_changed(tool_id: String)

const TOOLS := {
	"megaphone": {
		"name": "Megaphone",
		"cost": 40,
		"upgrade_base": 120,
		"upgrade_label": "range",
		"radius": 14.0,
		"radius_per_level": 5.0,
		"effectiveness": 0.55,
		"eff_per_level": 0.0,
		"colour": Color(1.0, 0.78, 0.30),
		"sprites": 4,
	},
	"tv": {
		"name": "TV Alert",
		"cost": 70,
		"upgrade_base": 160,
		"upgrade_label": "reach",
		"radius": 9.0,
		"radius_per_level": 3.0,
		"effectiveness": 0.85,
		"eff_per_level": 0.0,
		"colour": Color(0.72, 0.55, 1.0),
		"sprites": 6,
	},
	"radio": {
		"name": "Radio",
		"cost": 90,
		"upgrade_base": 200,
		"upgrade_label": "listeners",
		"radius": 45.0,
		"radius_per_level": 0.0,
		"effectiveness": 0.18,
		"eff_per_level": 0.05,
		"colour": Color(0.45, 0.80, 1.0),
		"sprites": 2,
	},
}

# resets every loop
var total_population := 0
var saved_today := 0
var day_active := false

# spent and re-bought each loop
var inventory := {}

# persists across loops
var upgrade_levels := {}
var currency := 0
var loop_number := 0
var knock_cooldown := 0.5
var knock_effectiveness := 0.35

var selected_tool := ""      # "" means the free knock


func _ready() -> void:
	for id in TOOLS:
		inventory[id] = 0
		upgrade_levels[id] = 0


func radius_of(id: String) -> float:
	var t: Dictionary = TOOLS[id]
	return t["radius"] + float(upgrade_levels[id]) * t["radius_per_level"]


func effectiveness_of(id: String) -> float:
	var t: Dictionary = TOOLS[id]
	return minf(0.95, t["effectiveness"] + float(upgrade_levels[id]) * t["eff_per_level"])


func cost_of(id: String) -> int:
	return TOOLS[id]["cost"]


func upgrade_cost(id: String) -> int:
	return int(TOOLS[id]["upgrade_base"]) * (int(upgrade_levels[id]) + 1)


func upgrade_summary(id: String) -> String:
	var t: Dictionary = TOOLS[id]
	if t["radius_per_level"] > 0.0:
		return "%.0fm" % radius_of(id)
	return "%d%% respond" % int(effectiveness_of(id) * 100.0)


func buy_consumable(id: String) -> void:
	var cost := cost_of(id)
	if currency < cost:
		return
	currency -= cost
	inventory[id] += 1
	inventory_changed.emit()


func buy_upgrade(id: String) -> void:
	var cost := upgrade_cost(id)
	if currency < cost:
		return
	currency -= cost
	upgrade_levels[id] += 1
	inventory_changed.emit()


func select_tool(tool_id: String) -> void:
	if tool_id != "" and int(inventory.get(tool_id, 0)) <= 0:
		tool_id = ""
	selected_tool = tool_id
	tool_changed.emit(selected_tool)


func consume(tool_id: String) -> void:
	if int(inventory.get(tool_id, 0)) <= 0:
		return
	inventory[tool_id] -= 1
	inventory_changed.emit()
	if int(inventory[tool_id]) <= 0:
		select_tool("")



func begin_day(population: int) -> void:
	loop_number += 1
	total_population = population
	saved_today = 0
	day_active = true
	select_tool("")
	saved_changed.emit(saved_today, total_population)


func add_saved(count: int) -> void:
	saved_today += count
	saved_changed.emit(saved_today, total_population)


func end_day() -> void:
	day_active = false
	currency += saved_today
	day_ended.emit(saved_today, total_population)
