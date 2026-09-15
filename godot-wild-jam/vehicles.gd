extends Node3D

const MAX_ACTIVE := 12
const ARRIVE := 1.6
const LOAD_TIME := 1.1
const UNLOAD_TIME := 0.8

const STATE_TO_BUILDING := 0
const STATE_LOADING := 1
const STATE_TO_EXIT := 2
const STATE_UNLOADING := 3

const BODY_COLS := [
	Color(0.90, 0.32, 0.28), Color(0.26, 0.52, 0.82),
	Color(0.95, 0.72, 0.25), Color(0.34, 0.68, 0.46),
]
const GLASS := Color(0.12, 0.16, 0.22)

@onready var city := %City
@onready var citizens := %Citizens

var _pos: Array[Vector3] = []
var _yaw: Array[float] = []
var _target_yaw: Array[float] = []
var _cell: Array[Vector2i] = []
var _dest: Array[Vector3] = []
var _state: Array[int] = []
var _path: Array = []
var _path_i: Array[int] = []
var _target: Array = []
var _timer: Array[float] = []
var _size: Array[Vector3] = []
var _speed: Array[float] = []
var _capacity: Array[int] = []

var _mm_body: MultiMesh
var _mm_cab: MultiMesh


func _ready() -> void:
	_mm_body = _make_layer("Bodies", true)
	_mm_cab = _make_layer("Cabins", false)
	set_process(false)


func _make_layer(node_name: String, tinted: bool) -> MultiMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.6
	if tinted:
		mat.vertex_color_use_as_albedo = true
	else:
		mat.albedo_color = GLASS

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = tinted
	mm.mesh = mesh
	mm.instance_count = MAX_ACTIVE
	mm.visible_instance_count = 0

	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.material_override = mat
	node.multimesh = mm
	add_child(node)
	return mm


func clear_all() -> void:
	_pos.clear(); _yaw.clear(); _target_yaw.clear(); _cell.clear(); _dest.clear()
	_state.clear(); _path.clear(); _path_i.clear(); _target.clear()
	_timer.clear(); _size.clear(); _speed.clear(); _capacity.clear()
	_mm_body.visible_instance_count = 0
	_mm_cab.visible_instance_count = 0
	set_process(false)


func deploy(cell: Vector2i) -> bool:
	if _pos.size() >= MAX_ACTIVE:
		return false

	var tier: Dictionary = GameState.vehicle_tier()
	var idx := _pos.size()
	var start: Vector3 = city.cell_centre(cell)
	start.y = city.cell_y(cell)

	_pos.append(start)
	_yaw.append(0.0)
	_target_yaw.append(0.0)
	_cell.append(cell)
	_dest.append(start)
	_state.append(STATE_TO_BUILDING)
	_path.append([])
	_path_i.append(0)
	_target.append(null)
	_timer.append(0.0)
	_size.append(tier["size"])
	_speed.append(tier["speed"])
	_capacity.append(tier["capacity"])

	_mm_body.set_instance_color(idx, BODY_COLS[randi() % BODY_COLS.size()])
	_pick_target(idx)
	set_process(true)
	return true


func _process(delta: float) -> void:
	for i in _pos.size():
		match _state[i]:
			STATE_LOADING, STATE_UNLOADING:
				_timer[i] -= delta
				if _timer[i] <= 0.0:
					_finish_stop(i)
			_:
				_drive(i, delta)
	_push()


func _drive(i: int, delta: float) -> void:
	var to_dest: Vector3 = _dest[i] - _pos[i]
	to_dest.y = 0.0

	if to_dest.length() < ARRIVE:
		_next_waypoint(i)
		return

	var dir := to_dest.normalized()
	_pos[i] += dir * _speed[i] * delta
	_pos[i].y = lerpf(_pos[i].y, _dest[i].y, 1.0 - exp(-6.0 * delta))
	_yaw[i] = lerp_angle(_yaw[i], _target_yaw[i], 1.0 - exp(-11.0 * delta))


func _next_waypoint(i: int) -> void:
	if _state[i] == STATE_TO_BUILDING:
		var p: Array = _path[i]
		if _path_i[i] < p.size():
			_set_dest(i, p[_path_i[i]])
			_path_i[i] += 1
			return
		# arrived at the building's road cell
		_state[i] = STATE_LOADING
		_timer[i] = LOAD_TIME
		return

	# heading for the edge
	if city.is_exit_cell(_cell[i]):
		_state[i] = STATE_UNLOADING
		_timer[i] = UNLOAD_TIME
		return

	var nxt: Vector2i = city.flow_next(_cell[i])
	if nxt == _cell[i]:
		_state[i] = STATE_UNLOADING
		_timer[i] = UNLOAD_TIME
		return
	_set_dest(i, nxt)


func _set_dest(i: int, cell: Vector2i) -> void:
	_cell[i] = cell
	var d: Vector3 = city.cell_centre(cell)
	d.y = city.cell_y(cell)
	_dest[i] = d

	# aim at the new waypoint immediately, so corners don't chase a stale angle
	var face: Vector3 = d - _pos[i]
	face.y = 0.0
	if face.length_squared() > 0.001:
		_target_yaw[i] = atan2(face.x, face.z)


func _finish_stop(i: int) -> void:
	if _state[i] == STATE_LOADING:
		var b = _target[i]
		if is_instance_valid(b) and b.remaining > 0:
			var got: int = b.take_people(_capacity[i])
			if got > 0:
				GameState.add_saved(got)
				citizens.spawn(b.door_point(), b.road_cell, mini(got, 5))
		_state[i] = STATE_TO_EXIT
		_next_waypoint(i)
		return

	# unloaded at the edge, go again
	_pick_target(i)


func _pick_target(i: int) -> void:
	var best = null
	var best_d := INF
	var here: Vector3 = _pos[i]

	for b in city.occupied_buildings():
		var d: float = here.distance_squared_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b

	if best == null:
		_state[i] = STATE_TO_EXIT
		_next_waypoint(i)
		return

	var p: Array = city.road_path(_cell[i], best.road_cell)
	if p.is_empty():
		_state[i] = STATE_TO_EXIT
		_next_waypoint(i)
		return

	_target[i] = best
	_path[i] = p
	_path_i[i] = 0
	_state[i] = STATE_TO_BUILDING
	_next_waypoint(i)


func _push() -> void:
	var n := _pos.size()
	_mm_body.visible_instance_count = n
	_mm_cab.visible_instance_count = n

	for i in n:
		var s: Vector3 = _size[i]
		var basis := Basis(Vector3.UP, _yaw[i])
		var base: Vector3 = _pos[i]

		# chassis: full length, sits low
		var body := Transform3D(
			basis.scaled_local(Vector3(s.x, s.y * 0.45, s.z)),
			base + Vector3(0.0, s.y * 0.30, 0.0)
		)
		_mm_body.set_instance_transform(i, body)

		# cabin: narrower, shorter, set back from the nose
		var cab := Transform3D(
			basis.scaled_local(Vector3(s.x * 0.80, s.y * 0.42, s.z * 0.42)),
			base + Vector3(0.0, s.y * 0.72, 0.0) + basis * Vector3(0.0, 0.0, -s.z * 0.12)
		)
		_mm_cab.set_instance_transform(i, cab)
