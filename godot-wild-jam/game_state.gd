extends Node

signal saved_changed(saved: int, total: int)
signal day_ended(saved: int, total: int)
signal inventory_changed
signal tool_changed(tool_id: String)

const MEGAPHONE_COST := 40
const MEGAPHONE_UPGRADE_BASE := 120

# resets every loop
var total_population := 0
var saved_today := 0
var day_active := false

# spent and re-bought each loop
var inventory := {"megaphone": 0}

# persists across loops
var currency := 0
var loop_number := 0
var knock_cooldown := 0.5
var knock_effectiveness := 0.35
var upgrade_levels := {"megaphone": 0}

var selected_tool := ""      # "" means the free knock


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


func select_tool(tool_id: String) -> void:
	if tool_id != "" and inventory.get(tool_id, 0) <= 0:
		tool_id = ""
	selected_tool = tool_id
	tool_changed.emit(selected_tool)


func consume(tool_id: String) -> void:
	if inventory.get(tool_id, 0) <= 0:
		return
	inventory[tool_id] -= 1
	inventory_changed.emit()
	if inventory[tool_id] <= 0:
		select_tool("")


func megaphone_radius() -> float:
	return 14.0 + float(upgrade_levels["megaphone"]) * 5.0


func megaphone_effectiveness() -> float:
	return 0.55


func upgrade_cost(tool_id: String) -> int:
	return MEGAPHONE_UPGRADE_BASE * (upgrade_levels[tool_id] + 1)


func buy_consumable(tool_id: String) -> void:
	if currency < MEGAPHONE_COST:
		return
	currency -= MEGAPHONE_COST
	inventory[tool_id] += 1
	inventory_changed.emit()


func buy_upgrade(tool_id: String) -> void:
	var cost := upgrade_cost(tool_id)
	if currency < cost:
		return
	currency -= cost
	upgrade_levels[tool_id] += 1
	inventory_changed.emit()
