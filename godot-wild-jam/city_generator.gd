class_name CityGenerator
extends Node3D

enum Cell { GRASS, ROAD, WATER, PARK, BRIDGE }

const GRID := 48
const CELL_SIZE := 4.0
const BLOCK := 8
const WATER_Y := -0.45
const BRIDGE_Y := 0.35
const KERB_W := 0.5
const LINE_W := 0.22

const COL_GRASS := Color(0.4, 0.54, 0.31, 1.0)
const COL_PARK := Color(0.44, 0.59, 0.32)
const COL_ROAD := Color(0.34, 0.34, 0.37)
const COL_WATER := Color(0.31, 0.57, 0.74)
const COL_BANK := Color(0.45, 0.38, 0.29)
const COL_KERB := Color(0.62, 0.62, 0.64)
const COL_LINE := Color(0.88, 0.85, 0.66)
const COL_BRIDGE := Color(0.46, 0.42, 0.38)

const COL_TRUNK := Color(0.32, 0.23, 0.16)
const COL_LEAF := Color(0.22, 0.42, 0.20)
const COL_POLE := Color(0.28, 0.30, 0.33)
const COL_LAMP := Color(1.0, 0.88, 0.62)

const HOUSE_HEIGHT_MAX := 13.0
const ROOF_OVERHANG := 1.12

const ROOF_COLS := [
	Color(0.42, 0.24, 0.20),
	Color(0.31, 0.31, 0.35),
	Color(0.36, 0.28, 0.22),
	Color(0.25, 0.27, 0.30),
]

const TARGET_POPULATION := 1200

@export var building_scene: PackedScene

var grid: Array = []
var river_horizontal := false
var rng := RandomNumberGenerator.new()

var population := 0

var astar := AStarGrid2D.new()
var exit_field: Array = []

var _blocked: Array = []          # cells a building footprint sits on
var _buildings_root: Node3D
var _ground: MeshInstance3D
var _roofs: MeshInstance3D
var _roof_data: Array = []

var _mm_trunk: MultiMeshInstance3D
var _mm_leaf: MultiMeshInstance3D
var _mm_pole: MultiMeshInstance3D
var _mm_lamp: MultiMeshInstance3D
var _mm_hill: MultiMeshInstance3D

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

	_roofs = MeshInstance3D.new()
	_roofs.name = "RoofMesh"
	_roofs.material_override = mat
	add_child(_roofs)

	_mm_trunk = _make_mm("Trunks", _cyl(0.30, 0.38, 2.2), COL_TRUNK, true)
	_mm_leaf = _make_mm("Leaves", _cyl(0.0, 1.5, 3.4), COL_LEAF, true)
	_mm_pole = _make_mm("Poles", _cyl(0.14, 0.18, 6.0), COL_POLE, true)
	_mm_lamp = _make_mm("Lamps", _box(Vector3(0.7, 0.28, 0.7)), COL_LAMP, false)
	_mm_hill = _make_mm("Hills", _hill_mesh(), Color(0.20, 0.28, 0.16), true)


func generate(seed_value: int = -1) -> void:
	rng.seed = seed_value if seed_value >= 0 else randi()
	city_name = _make_name()
	_blank_grid()
	_carve_river()
	_lay_roads()
	_build_bridges(2)
	_place_parks()
	_clear_buildings()
	_place_buildings()
	_build_navigation()
	_normalise_population()
	_build_ground()
	_build_roofs()
	_build_props()

func _blank_grid() -> void:
	grid = []
	_blocked = []
	for x in GRID:
		var col := []
		col.resize(GRID)
		col.fill(Cell.GRASS)
		grid.append(col)

		var bcol := []
		bcol.resize(GRID)
		bcol.fill(false)
		_blocked.append(bcol)


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


func _clear_buildings() -> void:
	_roof_data.clear()
	for child in _buildings_root.get_children():
		_buildings_root.remove_child(child)   # immediate, unlike queue_free
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

	var span := CELL_SIZE * 3.0
	var tall: float = rng.randf_range(26.0, 48.0)
	var short: float = rng.randf_range(4.0, 10.0)
	var height: float = lerpf(tall, short, pow(dist, 0.7))

	var is_house := height <= HOUSE_HEIGHT_MAX
	var width: float
	var depth: float

	if is_house:
		# houses are wider and often noticeably rectangular
		width = span * rng.randf_range(0.56, 0.76)
		depth = width * rng.randf_range(0.60, 0.95)
		if rng.randf() < 0.5:
			var swap := width
			width = depth
			depth = swap
	else:
		width = span * rng.randf_range(0.5, 0.68)
		depth = width * rng.randf_range(0.88, 1.14)

	var b := building_scene.instantiate() as Building
	_buildings_root.add_child(b)

	var volume: float = width * depth * height
	var people: int = maxi(2, int(volume * 0.012 * rng.randf_range(0.75, 1.25)))

	var door_dir := _nearest_road_dir(cx, cz)

	var pos := _cell_to_world(cx, cz) + Vector3(CELL_SIZE * 1.5, 0.0, CELL_SIZE * 1.5)
	b.setup(width, depth, height, rng.randi(), people, door_dir)
	b.position = pos
	b.road_cell = nearest_road_cell(Vector2i(cx + 1, cz + 1), 5)

	# mark the footprint so props don't spawn inside it
	for x in range(cx, cx + 3):
		for z in range(cz, cz + 3):
			_blocked[x][z] = true

	if is_house:
		_roof_data.append({
			"pos": pos,
			"w": width,
			"d": depth,
			"h": height,
			"pitch": rng.randf_range(1.4, 2.6),
			"ridge_z": depth >= width,
			"col": ROOF_COLS[rng.randi() % ROOF_COLS.size()],
		})


func _normalise_population() -> void:
	var all := _buildings_root.get_children()
	if all.is_empty():
		return

	var total := 0
	for b in all:
		total += b.occupants
	if total == 0:
		return

	var factor: float = float(TARGET_POPULATION) / float(total)
	var assigned := 0
	for b in all:
		b.occupants = maxi(1, int(round(b.occupants * factor)))
		b.remaining = b.occupants
		assigned += b.occupants

	var drift := TARGET_POPULATION - assigned
	if drift != 0:
		var biggest: Building = all[0]
		for b in all:
			if b.occupants > biggest.occupants:
				biggest = b
		biggest.occupants = maxi(1, biggest.occupants + drift)
		biggest.remaining = biggest.occupants

	# count what's actually there rather than trusting the target
	var real_total := 0
	for b in all:
		real_total += b.occupants
	population = real_total


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


func _build_roofs() -> void:
	_roofs.visible = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in _roof_data:
		_add_roof(st, r["pos"], r["w"], r["d"], r["h"], r["pitch"], r["ridge_z"], r["col"])
	_roofs.mesh = st.commit()


func _add_roof(st: SurfaceTool, pos: Vector3, w: float, d: float, h: float,
		pitch: float, ridge_z: bool, col: Color) -> void:
	var hw := w * 0.5 * ROOF_OVERHANG
	var hd := d * 0.5 * ROOF_OVERHANG
	var x0 := pos.x - hw
	var x1 := pos.x + hw
	var z0 := pos.z - hd
	var z1 := pos.z + hd
	var y0 := h
	var y1 := h + pitch

	if ridge_z:
		# ridge runs along Z; slopes face -X and +X
		var ra := Vector3(pos.x, y1, z0)
		var rb := Vector3(pos.x, y1, z1)
		var a0 := Vector3(x0, y0, z0)
		var a1 := Vector3(x0, y0, z1)
		var b0 := Vector3(x1, y0, z0)
		var b1 := Vector3(x1, y0, z1)
		var nl := Vector3(-pitch, hw, 0.0).normalized()
		var nr := Vector3(pitch, hw, 0.0).normalized()
		_tri(st, a0, a1, rb, nl, col)
		_tri(st, a0, rb, ra, nl, col)
		_tri(st, b1, b0, ra, nr, col)
		_tri(st, b1, ra, rb, nr, col)
		_tri(st, a0, ra, b0, Vector3(0.0, 0.0, -1.0), col)
		_tri(st, b1, rb, a1, Vector3(0.0, 0.0, 1.0), col)
	else:
		# ridge runs along X; slopes face -Z and +Z
		var ra := Vector3(x0, y1, pos.z)
		var rb := Vector3(x1, y1, pos.z)
		var c0 := Vector3(x0, y0, z0)
		var c1 := Vector3(x1, y0, z0)
		var d0 := Vector3(x0, y0, z1)
		var d1 := Vector3(x1, y0, z1)
		var nf := Vector3(0.0, hd, -pitch).normalized()
		var nb := Vector3(0.0, hd, pitch).normalized()
		_tri(st, c0, c1, rb, nf, col)
		_tri(st, c0, rb, ra, nf, col)
		_tri(st, d1, d0, ra, nb, col)
		_tri(st, d1, ra, rb, nb, col)
		_tri(st, c0, ra, d0, Vector3(-1.0, 0.0, 0.0), col)
		_tri(st, d1, rb, c1, Vector3(1.0, 0.0, 0.0), col)


func _cyl(top: float, bottom: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 7
	m.rings = 1
	return m


func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _make_mm(node_name: String, mesh: Mesh, col: Color, shaded: bool) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	if not shaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.8

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0

	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.material_override = mat
	node.multimesh = mm
	if not shaded:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _build_props() -> void:
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var hills: Array[Transform3D] = []

	for x in GRID:
		for z in GRID:
			if _blocked[x][z]:
				continue
			match grid[x][z]:
				Cell.PARK:
					_scatter_trees(x, z, 2, trunks, leaves)
				Cell.ROAD:
					_maybe_lamp(x, z, poles, lamps)
				Cell.GRASS:
					if rng.randf() < 0.07:
						_scatter_trees(x, z, 1, trunks, leaves)
	
	_scatter_hills(hills)
	_scatter_surround(trunks, leaves)
	
	_fill(_mm_trunk, trunks)
	_fill(_mm_leaf, leaves)
	_fill(_mm_pole, poles)
	_fill(_mm_lamp, lamps)
	_fill(_mm_hill, hills)


func _scatter_trees(cx: int, cz: int, max_count: int,
		trunks: Array[Transform3D], leaves: Array[Transform3D]) -> void:
	var count := rng.randi_range(1, max_count)
	for i in count:
		var o := _cell_to_world(cx, cz)
		var pos := Vector3(
			o.x + rng.randf_range(1.0, CELL_SIZE - 1.0),
			0.0,
			o.z + rng.randf_range(1.0, CELL_SIZE - 1.0)
		)
		var s := rng.randf_range(0.8, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(s, s, s))

		trunks.append(Transform3D(basis, pos + Vector3(0.0, 1.1 * s, 0.0)))
		leaves.append(Transform3D(basis, pos + Vector3(0.0, 3.6 * s, 0.0)))


func _maybe_lamp(cx: int, cz: int,
	poles: Array[Transform3D], lamps: Array[Transform3D]) -> void:
	# one every few cells, on road edges that back onto green
	if (cx + cz) % 6 != 0:
		return

	var green_dir := Vector2i.ZERO
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nb: int = _neighbour(cx, cz, d.x, d.y)
		if nb == Cell.GRASS or nb == Cell.PARK:
			green_dir = d
			break
	if green_dir == Vector2i.ZERO:
		return

	var o := _cell_to_world(cx, cz)
	# sit just inside the kerb on the green side
	var inset := CELL_SIZE * 0.5 - KERB_W * 0.6
	var pos := Vector3(
		o.x + CELL_SIZE * 0.5 + float(green_dir.x) * inset,
		0.0,
		o.z + CELL_SIZE * 0.5 + float(green_dir.y) * inset
	)

	poles.append(Transform3D(Basis(), pos + Vector3(0.0, 3.0, 0.0)))
	var arm := Vector3(float(-green_dir.x), 0.0, float(-green_dir.y)) * 0.9
	lamps.append(Transform3D(Basis(), pos + Vector3(0.0, 6.1, 0.0) + arm))


func _fill(node: MultiMeshInstance3D, items: Array[Transform3D]) -> void:
	var mm := node.multimesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i])


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


func _nearest_road_dir(cx: int, cz: int) -> float:
	# building occupies cells cx..cx+2, cz..cz+2
	var probes := [
		[2.0, 1, 0, cx + 2, cz + 1],    # +X
		[3.0, -1, 0, cx, cz + 1],       # -X
		[0.0, 0, 1, cx + 1, cz + 2],    # +Z
		[1.0, 0, -1, cx + 1, cz],       # -Z
	]

	var best_dir := 0.0
	var best_dist := 999

	for p in probes:
		var dir: float = p[0]
		var dx: int = p[1]
		var dz: int = p[2]
		var x: int = p[3]
		var z: int = p[4]
		for step in range(1, 6):
			x += dx
			z += dz
			if x < 0 or x >= GRID or z < 0 or z >= GRID:
				break
			var c: int = grid[x][z]
			if c == Cell.ROAD or c == Cell.BRIDGE:
				if step < best_dist:
					best_dist = step
					best_dir = dir
				break

	return best_dir


func buildings_within(point: Vector3, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	for b in _buildings_root.get_children():
		var d: Vector3 = b.global_position - point
		d.y = 0.0
		if d.length_squared() <= r2:
			out.append(b)
	return out


func _drivable(x: int, z: int) -> bool:
	if x < 0 or x >= GRID or z < 0 or z >= GRID:
		return false
	var c: int = grid[x][z]
	return c == Cell.ROAD or c == Cell.BRIDGE


func _build_navigation() -> void:
	astar.region = Rect2i(0, 0, GRID, GRID)
	astar.cell_size = Vector2(1.0, 1.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

	for x in GRID:
		for z in GRID:
			astar.set_point_solid(Vector2i(x, z), not _drivable(x, z))

	_build_exit_field()


func _build_exit_field() -> void:
	# breadth-first outward from every drivable cell on the map border
	exit_field = []
	for x in GRID:
		var col := []
		col.resize(GRID)
		col.fill(-1)
		exit_field.append(col)

	var queue: Array[Vector2i] = []
	for i in GRID:
		for c in [Vector2i(0, i), Vector2i(GRID - 1, i), Vector2i(i, 0), Vector2i(i, GRID - 1)]:
			if _drivable(c.x, c.y) and exit_field[c.x][c.y] == -1:
				exit_field[c.x][c.y] = 0
				queue.append(c)

	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not _drivable(n.x, n.y):
				continue
			if exit_field[n.x][n.y] != -1:
				continue
			exit_field[n.x][n.y] = exit_field[c.x][c.y] + 1
			queue.append(n)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(p.x / CELL_SIZE + GRID * 0.5)),
		int(floor(p.z / CELL_SIZE + GRID * 0.5))
	)


func cell_centre(c: Vector2i) -> Vector3:
	return _cell_to_world(c.x, c.y) + Vector3(CELL_SIZE * 0.5, 0.0, CELL_SIZE * 0.5)


func cell_y(c: Vector2i) -> float:
	if c.x < 0 or c.x >= GRID or c.y < 0 or c.y >= GRID:
		return 0.0
	return BRIDGE_Y if grid[c.x][c.y] == Cell.BRIDGE else 0.0


func flow_next(c: Vector2i) -> Vector2i:
	if not _drivable(c.x, c.y):
		return c
	var best_d: int = exit_field[c.x][c.y]
	if best_d <= 0:
		return c
	var best := c
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = c + d
		if not _drivable(n.x, n.y):
			continue
		var nd: int = exit_field[n.x][n.y]
		if nd >= 0 and nd < best_d:
			best_d = nd
			best = n
	return best


func is_exit_cell(c: Vector2i) -> bool:
	if not _drivable(c.x, c.y):
		return true
	return exit_field[c.x][c.y] <= 0


func nearest_road_cell(from: Vector2i, max_r: int = 6) -> Vector2i:
	for r in range(0, max_r + 1):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := from + Vector2i(dx, dz)
				if _drivable(c.x, c.y):
					return c
	return Vector2i(-1, -1)


func road_path(from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return []
	if not _drivable(from.x, from.y) or not _drivable(to.x, to.y):
		return []
	return astar.get_id_path(from, to)


func occupied_buildings() -> Array:
	var out: Array = []
	for b in _buildings_root.get_children():
		if b.remaining > 0 and b.road_cell.x >= 0:
			out.append(b)
	return out


func all_buildings() -> Array:
	return _buildings_root.get_children()


func _scatter_surround(trunks: Array[Transform3D], leaves: Array[Transform3D]) -> void:
	# forest beyond the map edge, so the city doesn't end in a hard line
	var inner := GRID * CELL_SIZE * 0.5          # 96 — the city's half-width
	var band := 85.0
	var outer := inner + band

	for i in 2600:
		var pos := Vector3(
			rng.randf_range(-outer, outer),
			0.0,
			rng.randf_range(-outer, outer)
		)

		# how far outside the city square this point sits
		var beyond: float = maxf(absf(pos.x), absf(pos.z)) - inner
		if beyond < 2.0:
			continue                              # inside the city, skip

		# thin out with distance so it fades rather than stopping dead
		var falloff: float = 1.0 - clampf(beyond / band, 0.0, 1.0)
		if rng.randf() > 0.35 + falloff * 0.65:
			continue

		var s := rng.randf_range(0.9, 1.9)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(s, s, s))
		trunks.append(Transform3D(basis, pos + Vector3(0.0, 1.1 * s, 0.0)))
		leaves.append(Transform3D(basis, pos + Vector3(0.0, 3.6 * s, 0.0)))

func _scatter_hills(hills: Array[Transform3D]) -> void:
	var inner := GRID * CELL_SIZE * 0.5
	var band := 100.0
	var outer := inner + band

	for i in 22:
		var pos := Vector3(
			rng.randf_range(-outer, outer),
			0.0,
			rng.randf_range(-outer, outer)
		)
		var beyond: float = maxf(absf(pos.x), absf(pos.z)) - inner
		if beyond < 25.0:
			continue          # keep them well clear of the city edge

		var w := rng.randf_range(12.0, 24.0)
		var h := rng.randf_range(2.5, 5.0)
		hills.append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(w, h, w)),
			pos + Vector3(0.0, -2.0, 0.0)      # sunk so they rise out of the ground
		))

func _hill_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 1.0          # squashed dome
	m.radial_segments = 10
	m.rings = 4
	m.is_hemisphere = true
	return m

# in city_generator.gd
const NAME_PRE := ["Ash", "Bram", "Cald", "Dun", "East", "Fen", "Grim", "Hal",
	"Kirk", "Lang", "Marl", "North", "Oak", "Pel", "Red", "Stan", "Thorn",
	"Ved", "West", "Yar"]
const NAME_MID := ["", "", "", "bor", "dal", "ling", "mer", "ton", "wick"]
const NAME_SUF := ["bridge", "burgh", "by", "cliff", "combe", "ford", "gate",
	"haven", "holm", "mouth", "port", "stead", "thorpe", "vale", "wold"]

var city_name := ""


func _make_name() -> String:
	var n: String = NAME_PRE[rng.randi() % NAME_PRE.size()]
	n += NAME_MID[rng.randi() % NAME_MID.size()]
	n += NAME_SUF[rng.randi() % NAME_SUF.size()]
	return n

func hide_roofs() -> void:
	_roofs.visible = false
