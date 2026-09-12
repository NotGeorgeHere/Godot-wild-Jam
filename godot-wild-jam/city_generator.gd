extends Node3D

enum Cell { GRASS, ROAD, WATER, PARK, BRIDGE }

const GRID := 48
const CELL_SIZE := 4.0
const BLOCK := 8
const WATER_Y := -0.45
const BRIDGE_Y := 0.35
const KERB_W := 0.5
const LINE_W := 0.22

const COL_GRASS := Color(0.40, 0.54, 0.31)
const COL_PARK := Color(0.47, 0.62, 0.35)
const COL_ROAD := Color(0.34, 0.34, 0.37)
const COL_WATER := Color(0.31, 0.57, 0.74)
const COL_BANK := Color(0.45, 0.38, 0.29)
const COL_KERB := Color(0.62, 0.62, 0.64)
const COL_LINE := Color(0.88, 0.85, 0.66)
const COL_BRIDGE := Color(0.46, 0.42, 0.38)

@export var building_scene: PackedScene

var grid: Array = []
var river_horizontal := false
var rng := RandomNumberGenerator.new()

var _buildings_root: Node3D
var _ground: MeshInstance3D


func _ready() -> void:
	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	add_child(_buildings_root)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95

	_ground = MeshInstance3D.new()
	_ground.name = "GroundMesh"
	_ground.material_override = mat
	add_child(_ground)


func generate(seed_value: int = -1) -> void:
	rng.seed = seed_value if seed_value >= 0 else randi()
	_blank_grid()
	_carve_river()
	_lay_roads()
	_build_bridges(2)
	_place_parks()
	_clear_buildings()
	_place_buildings()
	_build_ground()


# ---------------------------------------------------------------- grid passes

func _blank_grid() -> void:
	grid = []
	for x in GRID:
		var col := []
		col.resize(GRID)
		col.fill(Cell.GRASS)
		grid.append(col)


func _carve_river() -> void:
	river_horizontal = rng.randf() < 0.5
	var half := rng.randi_range(1, 2)
	var drift_every := rng.randi_range(3, 6)

	var lo_clamp := half + 1
	var hi_clamp := GRID - half - 2
	var pos := rng.randi_range(int(GRID * 0.15), int(GRID * 0.85))
	pos = clampi(pos, lo_clamp, hi_clamp)

	for i in GRID:
		if i % drift_every == 0:
			pos = clampi(pos + rng.randi_range(-1, 1), lo_clamp, hi_clamp)
		for d in range(-half, half + 1):
			if river_horizontal:
				grid[i][pos + d] = Cell.WATER
			else:
				grid[pos + d][i] = Cell.WATER


func _lay_roads() -> void:
	for x in GRID:
		if x % BLOCK <= 1:
			for z in GRID:
				if grid[x][z] != Cell.WATER:
					grid[x][z] = Cell.ROAD
	for z in GRID:
		if z % BLOCK <= 1:
			for x in GRID:
				if grid[x][z] != Cell.WATER:
					grid[x][z] = Cell.ROAD


func _build_bridges(count: int) -> void:
	# a bridge runs along a road line that crosses the river's axis
	var lines: Array[int] = []
	for i in GRID:
		if i % BLOCK == 0:
			lines.append(i)

	for n in count:
		if lines.is_empty():
			break
		var pick: int = lines.pop_at(rng.randi() % lines.size())
		for i in GRID:
			for offset in [0, 1]:
				var line: int = pick + offset
				if line >= GRID:
					continue
				var cx: int = line if river_horizontal else i
				var cz: int = i if river_horizontal else line
				if grid[cx][cz] == Cell.WATER:
					grid[cx][cz] = Cell.BRIDGE


func _place_parks() -> void:
	var blocks := GRID / BLOCK
	for bx in blocks:
		for bz in blocks:
			if rng.randf() > 0.12:
				continue
			for ox in range(2, BLOCK):
				for oz in range(2, BLOCK):
					var cx := bx * BLOCK + ox
					var cz := bz * BLOCK + oz
					if cx < GRID and cz < GRID and grid[cx][cz] == Cell.GRASS:
						grid[cx][cz] = Cell.PARK


# ------------------------------------------------------------------ buildings

func _clear_buildings() -> void:
	for child in _buildings_root.get_children():
		child.queue_free()


func _place_buildings() -> void:
	var blocks := GRID / BLOCK
	var centre := Vector2(blocks - 1, blocks - 1) * 0.5
	var max_dist: float = maxf(centre.length(), 0.001)

	for bx in blocks:
		for bz in blocks:
			var dist: float = Vector2(bx, bz).distance_to(centre) / max_dist
			for ox in [2, 5]:
				for oz in [2, 5]:
					if rng.randf() < 0.12:
						continue
					_try_spawn(bx * BLOCK + ox, bz * BLOCK + oz, dist)


func _try_spawn(cx: int, cz: int, dist: float) -> void:
	for x in range(cx, cx + 3):
		for z in range(cz, cz + 3):
			if x >= GRID or z >= GRID:
				return
			if grid[x][z] != Cell.GRASS:
				return

	var b := building_scene.instantiate() as Building
	_buildings_root.add_child(b)

	var footprint: float = CELL_SIZE * 3.0 * rng.randf_range(0.5, 0.68)
	var tall: float = rng.randf_range(26.0, 48.0)
	var short: float = rng.randf_range(4.0, 10.0)
	var height: float = lerpf(tall, short, pow(dist, 0.7))

	b.setup(footprint, height, rng.randi())
	b.position = _cell_to_world(cx, cz) + Vector3(CELL_SIZE * 1.5, 0.0, CELL_SIZE * 1.5)


# --------------------------------------------------------------- ground build

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in GRID:
		for z in GRID:
			var type: int = grid[x][z]
			match type:
				Cell.WATER:
					_add_quad(st, x, z, WATER_Y, COL_WATER)
				Cell.BRIDGE:
					_add_quad(st, x, z, BRIDGE_Y, COL_BRIDGE)
					_add_bridge_sides(st, x, z)
				Cell.ROAD:
					_add_quad(st, x, z, 0.0, COL_ROAD)
					_add_banks(st, x, z)
					_add_kerbs(st, x, z)
					_add_markings(st, x, z)
				_:
					_add_quad(st, x, z, 0.0, _colour_for(type))
					_add_banks(st, x, z)

	_ground.mesh = st.commit()


func _colour_for(type: int) -> Color:
	match type:
		Cell.ROAD: return COL_ROAD
		Cell.WATER: return COL_WATER
		Cell.PARK: return COL_PARK
		Cell.BRIDGE: return COL_BRIDGE
		_: return COL_GRASS


# --------------------------------------------------------------- mesh helpers

func _add_quad(st: SurfaceTool, cx: int, cz: int, y: float, colour: Color) -> void:
	var o := _cell_to_world(cx, cz)
	_flat(st, o.x, o.z, o.x + CELL_SIZE, o.z + CELL_SIZE, y, colour)


func _flat(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, y: float, colour: Color) -> void:
	var a := Vector3(x0, y, z0)
	var b := Vector3(x0, y, z1)
	var c := Vector3(x1, y, z1)
	var d := Vector3(x1, y, z0)
	_tri(st, a, b, c, Vector3.UP, colour)
	_tri(st, a, c, d, Vector3.UP, colour)


func _neighbour(cx: int, cz: int, dx: int, dz: int) -> int:
	var nx := cx + dx
	var nz := cz + dz
	if nx < 0 or nx >= GRID or nz < 0 or nz >= GRID:
		return -1
	return grid[nx][nz]


func _add_banks(st: SurfaceTool, cx: int, cz: int) -> void:
	var o := _cell_to_world(cx, cz)
	var s := CELL_SIZE
	var edges := [
		[-1, 0, Vector3(o.x, 0.0, o.z), Vector3(o.x, 0.0, o.z + s)],
		[1, 0, Vector3(o.x + s, 0.0, o.z + s), Vector3(o.x + s, 0.0, o.z)],
		[0, -1, Vector3(o.x + s, 0.0, o.z), Vector3(o.x, 0.0, o.z)],
		[0, 1, Vector3(o.x, 0.0, o.z + s), Vector3(o.x + s, 0.0, o.z + s)],
	]
	for e in edges:
		if _neighbour(cx, cz, e[0], e[1]) != Cell.WATER:
			continue
		var top_a: Vector3 = e[2]
		var top_b: Vector3 = e[3]
		var bot_a := Vector3(top_a.x, WATER_Y, top_a.z)
		var bot_b := Vector3(top_b.x, WATER_Y, top_b.z)
		var n := Vector3(e[0], 0.0, e[1])
		_tri(st, top_a, bot_a, bot_b, n, COL_BANK)
		_tri(st, top_a, bot_b, top_b, n, COL_BANK)


func _add_bridge_sides(st: SurfaceTool, cx: int, cz: int) -> void:
	var o := _cell_to_world(cx, cz)
	var s := CELL_SIZE
	var edges := [
		[-1, 0, Vector3(o.x, BRIDGE_Y, o.z), Vector3(o.x, BRIDGE_Y, o.z + s)],
		[1, 0, Vector3(o.x + s, BRIDGE_Y, o.z + s), Vector3(o.x + s, BRIDGE_Y, o.z)],
		[0, -1, Vector3(o.x + s, BRIDGE_Y, o.z), Vector3(o.x, BRIDGE_Y, o.z)],
		[0, 1, Vector3(o.x, BRIDGE_Y, o.z + s), Vector3(o.x + s, BRIDGE_Y, o.z + s)],
	]
	for e in edges:
		var nb: int = _neighbour(cx, cz, e[0], e[1])
		if nb != Cell.WATER and nb != -1:
			continue
		var top_a: Vector3 = e[2]
		var top_b: Vector3 = e[3]
		var bot_a := Vector3(top_a.x, WATER_Y, top_a.z)
		var bot_b := Vector3(top_b.x, WATER_Y, top_b.z)
		var n := Vector3(e[0], 0.0, e[1])
		_tri(st, top_a, bot_a, bot_b, n, COL_BRIDGE)
		_tri(st, top_a, bot_b, top_b, n, COL_BRIDGE)


func _add_kerbs(st: SurfaceTool, cx: int, cz: int) -> void:
	var o := _cell_to_world(cx, cz)
	var s := CELL_SIZE
	var y := 0.03
	var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d in dirs:
		var nb: int = _neighbour(cx, cz, d.x, d.y)
		if nb != Cell.GRASS and nb != Cell.PARK:
			continue
		if d == Vector2i(-1, 0):
			_flat(st, o.x, o.z, o.x + KERB_W, o.z + s, y, COL_KERB)
		elif d == Vector2i(1, 0):
			_flat(st, o.x + s - KERB_W, o.z, o.x + s, o.z + s, y, COL_KERB)
		elif d == Vector2i(0, -1):
			_flat(st, o.x, o.z, o.x + s, o.z + KERB_W, y, COL_KERB)
		else:
			_flat(st, o.x, o.z + s - KERB_W, o.x + s, o.z + s, y, COL_KERB)


func _add_markings(st: SurfaceTool, cx: int, cz: int) -> void:
	var o := _cell_to_world(cx, cz)
	var s := CELL_SIZE
	var y := 0.05
	var inset := s * 0.22

	if cx % BLOCK == 0 and cz % BLOCK > 1 and cz % 2 == 0:
		var seam_x := o.x + s
		_flat(st, seam_x - LINE_W, o.z + inset, seam_x + LINE_W, o.z + s - inset, y, COL_LINE)

	if cz % BLOCK == 0 and cx % BLOCK > 1 and cx % 2 == 0:
		var seam_z := o.z + s
		_flat(st, o.x + inset, seam_z - LINE_W, o.x + s - inset, seam_z + LINE_W, y, COL_LINE)


func _tri(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, colour: Color) -> void:
	for p in [p1, p2, p3]:
		st.set_color(colour)
		st.set_normal(n)
		st.add_vertex(p)


func _cell_to_world(x: int, z: int) -> Vector3:
	return Vector3(
		(x - GRID * 0.5) * CELL_SIZE,
		0.0,
		(z - GRID * 0.5) * CELL_SIZE
	)
