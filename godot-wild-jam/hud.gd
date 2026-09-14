extends CanvasLayer

signal continue_pressed

@onready var flash_rect: ColorRect = $Flash
@onready var clock: Label = $Top/Clock
@onready var saved_label: Label = $Top/Saved
@onready var bar: ProgressBar = $Top/Bar
@onready var hotbar: HBoxContainer = $Hotbar
@onready var end_panel: PanelContainer = $EndPanel
@onready var title: Label = $EndPanel/Box/Title
@onready var stats: Label = $EndPanel/Box/Stats
@onready var currency_label: Label = $EndPanel/Box/Currency
@onready var shop: VBoxContainer = $EndPanel/Box/Shop


func _ready() -> void:
	$EndPanel/Box/Continue.pressed.connect(_on_continue)
	end_panel.hide()
	flash_rect.color = Color(1.0, 0.42, 0.20, 0.0)

	GameState.saved_changed.connect(_on_saved_changed)
	GameState.day_ended.connect(show_results)
	GameState.inventory_changed.connect(_refresh_all)
	GameState.tool_changed.connect(_on_tool_changed)

	_build_hotbar()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			GameState.select_tool("")
		KEY_2:
			GameState.select_tool("megaphone")


func _build_hotbar() -> void:
	for c in hotbar.get_children():
		c.queue_free()
	_add_slot("", "1  Knock")
	_add_slot("megaphone", "2  Megaphone")


func _add_slot(tool_id: String, label: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150.0, 46.0)
	b.set_meta("tool_id", tool_id)
	b.pressed.connect(func(): GameState.select_tool(tool_id))
	hotbar.add_child(b)
	_style_slot(b, label)


func _style_slot(b: Button, label: String) -> void:
	var tool_id: String = b.get_meta("tool_id")
	var count: int = GameState.inventory.get(tool_id, 0)

	if tool_id == "":
		b.text = label
		b.disabled = false
	else:
		b.text = "%s  x%d" % [label, count]
		b.disabled = count <= 0

	var selected := GameState.selected_tool == tool_id
	b.modulate = Color(1.0, 0.85, 0.35) if selected else Color(1.0, 1.0, 1.0)


func _refresh_hotbar() -> void:
	for c in hotbar.get_children():
		var b := c as Button
		var tool_id: String = b.get_meta("tool_id")
		_style_slot(b, "1  Knock" if tool_id == "" else "2  Megaphone")


func _on_tool_changed(_tool_id: String) -> void:
	_refresh_hotbar()


func _build_shop() -> void:
	for c in shop.get_children():
		c.queue_free()

	_add_shop_row(
		"Megaphone  (%d owned)" % GameState.inventory["megaphone"],
		GameState.MEGAPHONE_COST,
		func(): GameState.buy_consumable("megaphone")
	)

	var lvl: int = GameState.upgrade_levels["megaphone"]
	_add_shop_row(
		"Upgrade range  (Lv %d — %.0fm)" % [lvl, GameState.megaphone_radius()],
		GameState.upgrade_cost("megaphone"),
		func(): GameState.buy_upgrade("megaphone")
	)


func _add_shop_row(label: String, cost: int, on_buy: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var buy := Button.new()
	buy.text = "Buy  %d" % cost
	buy.custom_minimum_size = Vector2(110.0, 0.0)
	buy.disabled = GameState.currency < cost
	buy.pressed.connect(on_buy)
	row.add_child(buy)

	shop.add_child(row)


func _refresh_all() -> void:
	_refresh_hotbar()
	if end_panel.visible:
		currency_label.text = "%d credits" % GameState.currency
		_build_shop()



func _on_continue() -> void:
	continue_pressed.emit()


func _on_saved_changed(saved: int, total: int) -> void:
	saved_label.text = "%d / %d evacuated" % [saved, total]
	bar.max_value = maxi(total, 1)
	bar.value = saved


func set_clock(hour: float, t: float) -> void:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	clock.text = "%02d:%02d" % [h, m]
	var danger: float = clampf((t - 0.72) / 0.28, 0.0, 1.0)
	clock.modulate = Color.WHITE.lerp(Color(1.0, 0.38, 0.25), danger)


func flash(colour: Color) -> void:
	flash_rect.color = Color(colour.r, colour.g, colour.b, 1.0)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 1.6)


func show_results(saved: int, total: int) -> void:
	title.text = "EVERYONE SAVED" if saved >= total else "THE CITY IS GONE"
	stats.text = "%d of %d evacuated\nDay %d" % [saved, total, GameState.loop_number]
	currency_label.text = "%d credits" % GameState.currency
	_build_shop()
	end_panel.show()


func hide_results() -> void:
	end_panel.hide()
	_refresh_hotbar()
