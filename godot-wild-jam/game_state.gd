extends Node

signal saved_changed(saved: int, total: int)
signal day_ended(saved: int, total: int)
signal inventory_changed
signal tool_changed(tool_id: String)

const TOOLS := {
	"megaphone": {
		"name": "Megaphone",
		"cost": 30,
		"upgrade_base": 55,
		"upgrade_label": "range",
		"radius": 16.0,
		"radius_per_level": 6.0,
		"effectiveness": 0.55,
		"eff_per_level": 0.0,
		"colour": Color(1.0, 0.78, 0.30),
		"sprites": 4,
	},
	"tv": {
		"name": "TV Alert",
		"cost": 55,
		"upgrade_base": 80,
		"upgrade_label": "reach",
		"radius": 10.0,
		"radius_per_level": 4.0,
		"effectiveness": 0.85,
		"eff_per_level": 0.0,
		"colour": Color(0.72, 0.55, 1.0),
		"sprites": 6,
	},
	"radio": {
		"name": "Radio",
		"cost": 70,
		"upgrade_base": 95,
		"upgrade_label": "listeners",
		"radius": 50.0,
		"radius_per_level": 6.0,
		"effectiveness": 0.20,
		"eff_per_level": 0.07,
		"colour": Color(0.45, 0.80, 1.0),
		"sprites": 2,
	},
	"vehicle": {
		"name": "Vehicle",
		"cost": 45,
		"upgrade_base": 90,
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
		"cost": 80,
		"upgrade_base": 110,
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
	{"name": "Car",     "capacity": 4,   "speed": 17.0, "size": Vector3(2.0, 1.5, 4.2)},
	{"name": "Van",     "capacity": 10,  "speed": 15.5, "size": Vector3(2.3, 2.2, 5.4)},
	{"name": "Minibus", "capacity": 22,  "speed": 14.0, "size": Vector3(2.6, 2.7, 7.0)},
	{"name": "Bus",     "capacity": 45,  "speed": 12.5, "size": Vector3(2.9, 3.2, 9.5)},
]

# upgrades that aren't tied to a buyable item
const EXTRA_UPGRADES := {
	"knock_power": {"name": "Knock persuasion", "base": 45},
	"knock_speed": {"name": "Knock speed", "base": 40},
}

const KNOCK_BASE_EFF := 0.35
const KNOCK_EFF_PER_LEVEL := 0.09
const KNOCK_MAX_EFF := 0.90

const KNOCK_BASE_CD := 0.50
const KNOCK_CD_PER_LEVEL := 0.07
const KNOCK_MIN_CD := 0.12

const WARNING_BASE := 0.10
const WARNING_PER_LEVEL := 0.07

# resets every loop
var total_population := 0
var saved_today := 0
var day_active := false
var active_warning := 0.0

# permanent: what the player owns
var inventory := {}

# per-day: how many of each are still unused today
var uses := {}

# persists across loops
var upgrade_levels := {}
var currency := 0
var loop_number := 0

var selected_tool := ""      # "" means the free knock


func _ready() -> void:
	for id in TOOLS:
		inventory[id] = 0
		uses[id] = 0
		upgrade_levels[id] = 0
	for id in EXTRA_UPGRADES:
		upgrade_levels[id] = 0


func knock_effectiveness() -> float:
	return minf(KNOCK_MAX_EFF,
		KNOCK_BASE_EFF + float(upgrade_levels["knock_power"]) * KNOCK_EFF_PER_LEVEL)


func knock_cooldown() -> float:
	return maxf(KNOCK_MIN_CD,
		KNOCK_BASE_CD - float(upgrade_levels["knock_speed"]) * KNOCK_CD_PER_LEVEL)


func radius_of(id: String) -> float:
	var t: Dictionary = TOOLS[id]
	return t["radius"] + float(upgrade_levels[id]) * t["radius_per_level"]


func effectiveness_of(id: String) -> float:
	var t: Dictionary = TOOLS[id]
	return minf(0.95, t["effectiveness"] + float(upgrade_levels[id]) * t["eff_per_level"])


func cost_of(id: String) -> int:
	return TOOLS[id]["cost"]


func vehicle_tier() -> Dictionary:
	return VEHICLE_TIERS[mini(int(upgrade_levels["vehicle"]), VEHICLE_TIERS.size() - 1)]


func warning_strength() -> float:
	return WARNING_BASE + float(upgrade_levels["warning"]) * WARNING_PER_LEVEL


func upgrade_name(id: String) -> String:
	if EXTRA_UPGRADES.has(id):
		return EXTRA_UPGRADES[id]["name"]
	return "%s %s" % [TOOLS[id]["name"], TOOLS[id]["upgrade_label"]]


func upgrade_cost(id: String) -> int:
	var base: int = EXTRA_UPGRADES[id]["base"] if EXTRA_UPGRADES.has(id) else TOOLS[id]["upgrade_base"]
	return base * (int(upgrade_levels[id]) + 1)


func upgrade_maxed(id: String) -> bool:
	if id == "vehicle":
		return int(upgrade_levels[id]) >= VEHICLE_TIERS.size() - 1
	if id == "knock_power":
		return knock_effectiveness() >= KNOCK_MAX_EFF
	if id == "knock_speed":
		return knock_cooldown() <= KNOCK_MIN_CD
	return false


func upgrade_summary(id: String) -> String:
	match id:
		"knock_power":
			return "%d%% answer" % int(knock_effectiveness() * 100.0)
		"knock_speed":
			return "%.2fs per knock" % knock_cooldown()
		"vehicle":
			var tier := vehicle_tier()
			return "%s, %d seats" % [tier["name"], tier["capacity"]]
		"warning":
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
	uses[id] += 1          # available immediately, and every day after
	inventory_changed.emit()


func buy_upgrade(id: String) -> void:
	if upgrade_maxed(id):
		return
	var cost := upgrade_cost(id)
	if currency < cost:
		return
	currency -= cost
	upgrade_levels[id] += 1
	inventory_changed.emit()


func select_tool(tool_id: String) -> void:
	if tool_id != "":
		if TOOLS[tool_id].get("passive", false) or int(uses.get(tool_id, 0)) <= 0:
			tool_id = ""
	selected_tool = tool_id
	tool_changed.emit(selected_tool)


func consume(tool_id: String) -> void:
	if int(uses.get(tool_id, 0)) <= 0:
		return
	uses[tool_id] -= 1
	inventory_changed.emit()
	if int(uses[tool_id]) <= 0:
		select_tool("")


func begin_day(population: int) -> void:
	loop_number += 1
	total_population = population
	saved_today = 0
	day_active = true

	# everything owned is restocked for the new day
	for id in TOOLS:
		uses[id] = inventory[id]

	active_warning = warning_strength() if int(inventory["warning"]) > 0 else 0.0

	select_tool("")
	inventory_changed.emit()
	saved_changed.emit(saved_today, total_population)


func add_saved(count: int) -> void:
	saved_today += count
	saved_changed.emit(saved_today, total_population)


func end_day() -> void:
	day_active = false
	currency += saved_today
	day_ended.emit(saved_today, total_population)
