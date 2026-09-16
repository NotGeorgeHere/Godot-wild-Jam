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
	"vehicle": {
		"name": "Vehicle",
		"cost": 110,
		"upgrade_base": 260,
		"upgrade_label": "size",
		"deploy": true,
		"radius": 3.0,
		"radius_per_level": 0.0,
		"effectiveness": 0.0,
		"eff_per_level": 0.0,
		"colour": Color(0.98, 0.58, 0.32),
		"sprites": 6,
	},
	"warning": {
		"name": "Early Warning",
		"cost": 130,
		"upgrade_base": 220,
		"upgrade_label": "coverage",
		"passive": true,
		"radius": 0.0,
		"radius_per_level": 0.0,
		"effectiveness": 0.0,
		"eff_per_level": 0.0,
		"colour": Color(1.0, 0.45, 0.45),
		"sprites": 0,
	},
}

const VEHICLE_TIERS := [
	{"name": "Car",     "capacity": 2,   "speed": 17.0, "size": Vector3(2.0, 1.5, 4.2)},
	{"name": "Van",     "capacity": 5,   "speed": 15.5, "size": Vector3(2.3, 2.2, 5.4)},
	{"name": "Minibus", "capacity": 12,  "speed": 14.0, "size": Vector3(2.6, 2.7, 7.0)},
	{"name": "Bus",     "capacity": 20,  "speed": 12.5, "size": Vector3(2.9, 3.2, 9.5)},
]

const WARNING_BASE := 0.08
const WARNING_PER_LEVEL := 0.06

# resets every loop
var total_population := 0
var saved_today := 0
var day_active := false
var active_warning := 0.0

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


func vehicle_tier() -> Dictionary:
	return VEHICLE_TIERS[mini(int(upgrade_levels["vehicle"]), VEHICLE_TIERS.size() - 1)]


func warning_strength() -> float:
	return WARNING_BASE + float(upgrade_levels["warning"]) * WARNING_PER_LEVEL


func upgrade_summary(id: String) -> String:
	if id == "vehicle":
		var tier := vehicle_tier()
		return "%s, %d seats" % [tier["name"], tier["capacity"]]

	if id == "warning":
		return "+%d%% response" % int(warning_strength() * 100.0)

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
	if id == "vehicle" and int(upgrade_levels[id]) >= VEHICLE_TIERS.size() - 1:
		return
	var cost := upgrade_cost(id)
	if currency < cost:
		return
	currency -= cost
	upgrade_levels[id] += 1
	inventory_changed.emit()


func select_tool(tool_id: String) -> void:
	if tool_id != "" and int(inventory.get(tool_id, 0)) <= 0:
		tool_id = ""
	if tool_id != "" and TOOLS[tool_id].get("passive", false):
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

	# an armed warning is spent as the day starts
	if int(inventory["warning"]) > 0:
		active_warning = warning_strength()
		inventory["warning"] -= 1
		inventory_changed.emit()
	else:
		active_warning = 0.0

	select_tool("")
	saved_changed.emit(saved_today, total_population)


func add_saved(count: int) -> void:
	saved_today += count
	saved_changed.emit(saved_today, total_population)


func end_day() -> void:
	day_active = false
	currency += saved_today
	day_ended.emit(saved_today, total_population)
