extends Node3D

const GRID := 36          # cells across, and down
const CELL_SIZE := 4.0    # world units per cell
const BLOCK := 6          # a road every 6 cells

@export var building_scene: PackedScene

var rng := RandomNumberGenerator.new()


func generate(seed_value: int = -1) -> void:
	rng.seed = seed_value if seed_value >= 0 else randi()
	_clear()
	_place_buildings()


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _place_buildings() -> void:
	var blocks := GRID / BLOCK
	var centre := Vector2(blocks - 1, blocks - 1) * 0.5
	var max_dist: float = maxf(centre.length(), 0.001)

	for bx in blocks:
		for bz in blocks:
			# 0.0 = downtown, 1.0 = outskirts
			var dist: float = Vector2(bx, bz).distance_to(centre) / max_dist
			for ox in [1, 3]:
				for oz in [1, 3]:
					if rng.randf() < 0.15:
						continue   # leave a gap, breaks up the grid
					_spawn(bx * BLOCK + ox, bz * BLOCK + oz, dist)


func _spawn(cx: int, cz: int, dist: float) -> void:
	var b := building_scene.instantiate() as Building
	add_child(b)

	var footprint: float = CELL_SIZE * 2.0 * rng.randf_range(0.5, 0.68)
	var tall: float = rng.randf_range(26.0, 48.0)
	var short: float = rng.randf_range(4.0, 10.0)
	var height: float = lerpf(tall, short, pow(dist, 0.7))

	b.setup(footprint, height, rng.randi())
	b.position = _cell_to_world(cx, cz) + Vector3(CELL_SIZE, 0.0, CELL_SIZE)


func _cell_to_world(x: int, z: int) -> Vector3:
	return Vector3(
		(x - GRID * 0.5) * CELL_SIZE,
		0.0,
		(z - GRID * 0.5) * CELL_SIZE
	)
