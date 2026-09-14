extends CanvasLayer

signal continue_pressed

@onready var flash_rect: ColorRect = $Flash
@onready var clock: Label = $Top/Clock
@onready var saved_label: Label = $Top/Saved
@onready var bar: ProgressBar = $Top/Bar
@onready var end_panel: PanelContainer = $EndPanel
@onready var title: Label = $EndPanel/Box/Title
@onready var stats: Label = $EndPanel/Box/Stats


func _ready() -> void:
	$EndPanel/Box/Continue.pressed.connect(_on_continue)
	end_panel.hide()
	flash_rect.color = Color(1.0, 0.42, 0.20, 0.0)
	GameState.saved_changed.connect(_on_saved_changed)
	GameState.day_ended.connect(show_results)


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
	end_panel.show()


func hide_results() -> void:
	end_panel.hide()
