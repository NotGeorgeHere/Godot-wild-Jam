extends Node3D

@onready var city := $City


func _ready() -> void:
	city.generate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			city.generate()
