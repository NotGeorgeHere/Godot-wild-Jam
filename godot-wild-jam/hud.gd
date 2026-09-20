extends CanvasLayer

signal continue_pressed
signal intro_dismissed

@onready var flash_rect: ColorRect = $Flash
@onready var top_panel: PanelContainer = $TopPanel
@onready var clock: Label = $TopPanel/Top/Clock
@onready var saved_label: Label = $TopPanel/Top/Saved
@onready var bar: ProgressBar = $TopPanel/Top/Bar
@onready var hotbar: HBoxContainer = $Hotbar
@onready var end_panel: PanelContainer = $EndPanel
@onready var title: Label = $EndPanel/Box/Title
@onready var stats: Label = $EndPanel/Box/Stats
@onready var currency_label: Label = $EndPanel/Box/Currency
@onready var shop: VBoxContainer = $EndPanel/Box/Shop/ShopList
@onready var intro_panel: PanelContainer = $IntroPanel
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var city_name_label: Label = $TopPanel/Top/CityName

var _city_name := ""

func _ready() -> void:
	$EndPanel/Box/Continue.pressed.connect(_on_continue)
	$IntroPanel/Box/Begin.pressed.connect(_on_begin)
	settings_panel.hide()
	$IntroPanel/Box/SettingsBtn.pressed.connect(toggle_settings)
	$SettingsPanel/Box/Close.pressed.connect(toggle_settings)
	_wire_settings()
	end_panel.hide()
	intro_panel.hide()
	flash_rect.color = Color(1.0, 0.42, 0.20, 0.0)

	GameState.saved_changed.connect(_on_saved_changed)
	GameState.day_ended.connect(show_results)
	GameState.inventory_changed.connect(_refresh_all)
	GameState.tool_changed.connect(_on_tool_changed)

	_apply_styles()
	_build_hotbar()


func _apply_styles() -> void:
	UIStyle.outline(clock, 5)
	UIStyle.outline(saved_label, 4)
	UIStyle.style_bar(bar)

	UIStyle.style_panel(end_panel)
	UIStyle.style_panel(intro_panel)

	title.add_theme_color_override("font_color", Color.WHITE)
	stats.add_theme_color_override("font_color", UIStyle.TEXT)
	currency_label.add_theme_color_override("font_color", UIStyle.ACCENT)

	UIStyle.style_button($EndPanel/Box/Continue)
	UIStyle.style_button($IntroPanel/Box/Begin)
	
	var top_style := UIStyle.flat(
		Color(0.055, 0.075, 0.102, 0.82), UIStyle.LINE, 2, 6, 26, 12
	)
	top_panel.add_theme_stylebox_override("panel", top_style)

	clock.add_theme_font_size_override("font_size", 40)
	saved_label.add_theme_font_size_override("font_size", 18)
	UIStyle.outline(clock, 0)
	UIStyle.outline(saved_label, 0)
	UIStyle.style_bar(bar)
	bar.custom_minimum_size = Vector2(0.0, 14.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	city_name_label.add_theme_font_size_override("font_size", 15)
	city_name_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	city_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_M:
		Audio.toggle_mute()
		return

	if event.keycode == KEY_1:
		Audio.click()
		GameState.select_tool("")
		return
	
	if event.keycode == KEY_ESCAPE:
		toggle_settings()
		return
	
	# passives never appear in the hotbar, so they must not consume a number
	var ids: Array = []
	for id in GameState.TOOLS:
		if not GameState.TOOLS[id].get("passive", false):
			ids.append(id)

	var idx: int = event.keycode - KEY_2
	if idx >= 0 and idx < ids.size():
		Audio.click()
		GameState.select_tool(ids[idx])


func show_intro() -> void:
	intro_panel.show()
	Audio.start_shop_music()


func _on_begin() -> void:
	Audio.stop_shop_music()
	Audio.click()
	intro_panel.hide()
	intro_dismissed.emit()


func _build_hotbar() -> void:
	for c in hotbar.get_children():
		c.queue_free()

	_add_slot("", "1  Knock")
	var n := 2
	for id in GameState.TOOLS:
		if GameState.TOOLS[id].get("passive", false):
			continue
		_add_slot(id, "%d  %s" % [n, GameState.TOOLS[id]["name"]])
		n += 1


func _add_slot(tool_id: String, label: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(140.0, 46.0)
	b.set_meta("tool_id", tool_id)
	b.set_meta("label", label)
	b.pressed.connect(func():
		Audio.click()
		GameState.select_tool(tool_id)
	)
	hotbar.add_child(b)
	UIStyle.style_button(b)
	_style_slot(b)


func _style_slot(b: Button) -> void:
	var tool_id: String = b.get_meta("tool_id")
	var label: String = b.get_meta("label")

	if tool_id == "":
		b.text = label
		b.disabled = false
	else:
		var left: int = GameState.uses.get(tool_id, 0)
		b.text = "%s  x%d" % [label, left]
		b.disabled = left <= 0

	# swap the border rather than tinting, so the fill stays readable
	var selected := GameState.selected_tool == tool_id
	if selected:
		b.add_theme_stylebox_override("normal",
			UIStyle.flat(UIStyle.BG_HOVER, UIStyle.ACCENT, 2))
		b.add_theme_color_override("font_color", UIStyle.ACCENT)
	else:
		b.add_theme_stylebox_override("normal",
			UIStyle.flat(UIStyle.BG_BUTTON, UIStyle.LINE, 2))
		b.add_theme_color_override("font_color", UIStyle.TEXT)
	b.modulate = Color.WHITE


func _refresh_hotbar() -> void:
	for c in hotbar.get_children():
		_style_slot(c as Button)


func _on_tool_changed(_tool_id: String) -> void:
	_refresh_hotbar()


func _build_shop() -> void:
	for c in shop.get_children():
		c.queue_free()

	# knock upgrades first — they're the thing everyone always has
	for id in GameState.EXTRA_UPGRADES:
		_add_upgrade_row(id)

	for id in GameState.TOOLS:
		var data: Dictionary = GameState.TOOLS[id]
		var owned: int = GameState.inventory[id]
		_add_shop_row(
			"%s  (own %d)" % [data["name"], owned],
			GameState.cost_of(id),
			func(): GameState.buy_consumable(id)
		)
		_add_upgrade_row(id)


func _add_upgrade_row(id: String) -> void:
	var lvl: int = GameState.upgrade_levels[id]
	var label := "   ↳ %s  Lv%d — %s" % [
		GameState.upgrade_name(id), lvl, GameState.upgrade_summary(id)
	]

	if GameState.upgrade_maxed(id):
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s   (max)" % label
		l.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		shop.add_child(row)
		return

	_add_shop_row(label, GameState.upgrade_cost(id), func(): GameState.buy_upgrade(id))


func _add_shop_row(label: String, cost: int, on_buy: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0.0, 0.0)
	name_label.add_theme_color_override("font_color", UIStyle.TEXT)
	row.add_child(name_label)

	var buy := Button.new()
	buy.text = "Buy  %d" % cost
	buy.custom_minimum_size = Vector2(110.0, 0.0)
	buy.disabled = GameState.currency < cost
	buy.pressed.connect(func():
		on_buy.call()
		Audio.play("purchase")
	)
	row.add_child(buy)
	UIStyle.style_button(buy)

	shop.add_child(row)


func _refresh_all() -> void:
	_refresh_hotbar()
	if end_panel.visible:
		currency_label.text = "%d credits" % GameState.currency
		_build_shop()


func _on_continue() -> void:
	Audio.click()
	continue_pressed.emit()


func _on_saved_changed(saved: int, total: int) -> void:
	var suffix := ""
	if GameState.active_warning > 0.0:
		suffix = "   ⚠ +%d%%" % int(GameState.active_warning * 100.0)
	saved_label.text = "%d / %d evacuated%s" % [saved, total, suffix]

	bar.max_value = maxi(total, 1)
	bar.value = maxf(float(saved), bar.max_value * 0.012) if saved > 0 else 0.0

	# red when you're behind, green as you close in
	var frac: float = float(saved) / float(maxi(total, 1))
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color(0.86, 0.35, 0.28).lerp(Color(0.29, 0.85, 0.55), frac)


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
	var place := _city_name.to_upper() if _city_name != "" else "THE CITY"
	if saved >= total:
		title.text = "%s IS SAFE" % place
		title.modulate = Color(0.45, 1.0, 0.65)
		stats.text = "All %d evacuated — day %d" % [total, GameState.loop_number]
	else:
		title.text = "%s IS GONE" % place
		title.modulate = Color(1.0, 0.45, 0.35)
		stats.text = "%d of %d evacuated\nDay %d" % [saved, total, GameState.loop_number]
	currency_label.text = "%d credits" % GameState.currency
	_build_shop()
	end_panel.show()
	Audio.start_shop_music()


func hide_results() -> void:
	end_panel.hide()
	_refresh_hotbar()
	Audio.stop_shop_music()

func toggle_settings() -> void:
	Audio.click()
	if settings_panel.visible:
		settings_panel.hide()
		Settings.save_settings()
	else:
		settings_panel.show()


func _wire_settings() -> void:
	UIStyle.style_panel(settings_panel)
	UIStyle.style_button($SettingsPanel/Box/Close)
	UIStyle.style_button($IntroPanel/Box/SettingsBtn)

	_wire_slider("SfxRow", "Effects", Settings.sfx_db,
		func(v): Settings.sfx_db = v)
	_wire_slider("AmbientRow", "Music & ambience", Settings.ambient_db,
		func(v): Settings.ambient_db = v)
	_wire_slider("UiRow", "Interface", Settings.ui_db,
		func(v): Settings.ui_db = v)

	var motion_row := $SettingsPanel/Box/MotionRow
	motion_row.get_node("Name").text = "Reduce flashing and shake"
	var check: CheckBox = motion_row.get_node("Check")
	check.button_pressed = Settings.reduce_motion
	check.toggled.connect(func(on):
		Settings.reduce_motion = on
		Settings.save_settings()
	)

	var speed_row := $SettingsPanel/Box/SpeedRow
	speed_row.get_node("Name").text = "Day length"
	var opts: OptionButton = speed_row.get_node("Options")
	opts.clear()
	opts.add_item("Brisk  (45s)")
	opts.add_item("Normal  (60s)")
	opts.add_item("Relaxed  (90s)")
	var lengths := [45.0, 60.0, 90.0]
	opts.selected = lengths.find(Settings.day_length)
	if opts.selected < 0:
		opts.selected = 1
	opts.item_selected.connect(func(i):
		Settings.day_length = lengths[i]
		Settings.save_settings()
	)


func _wire_slider(row_name: String, label: String, value: float, on_set: Callable) -> void:
	var row := $SettingsPanel/Box.get_node(row_name)
	var name_label: Label = row.get_node("Name")
	name_label.text = label
	name_label.custom_minimum_size = Vector2(210.0, 0.0)
	name_label.add_theme_color_override("font_color", UIStyle.TEXT)

	var slider: HSlider = row.get_node("Slider")
	slider.min_value = -40.0
	slider.max_value = 6.0
	slider.step = 1.0
	slider.value = value
	slider.custom_minimum_size = Vector2(240.0, 0.0)
	slider.value_changed.connect(func(v):
		on_set.call(v)
		Settings.apply_audio()
	)

func set_city_name(n: String) -> void:
	_city_name = n
	city_name_label.text = n.to_upper()
