extends Node3D

const MAX_ACTIVE := 360
const SPEED := 6.0
const LIFETIME := 26.0
const ARRIVE := 1.3

const SHIRTS := [
	Color(0.82, 0.35, 0.30), Color(0.30, 0.45, 0.72),
	Color(0.90, 0.72, 0.32), Color(0.38, 0.62, 0.45),
	Color(0.68, 0.42, 0.72), Color(0.88, 0.88, 0.86),
]
const SKIN := [
	Color(0.96, 0.80, 0.66), Color(0.84, 0.64, 0.48),
	Color(0.62, 0.44, 0.32), Color(0.42, 0.29, 0.21),
]
const TROUSERS := Color(0.26, 0.28, 0.34)

@onready var city := %City

var _pos: Array[Vector3] = []
var _dest: Array[Vector3] = []
var _cell: Array[Vector2i] = []
var _age: Array[float] = []
var _jitter: Array[Vector3] = []

var _mm_body: MultiMesh
var _mm_head: MultiMesh
var _mm_legs: MultiMesh


func _ready() -> void:
	_mm_body = _make_layer("Bodies", Vector3(0.62, 0.78, 0.40), true)
	_mm_head = _make_layer("Heads", Vector3(0.44, 0.42, 0.42), true)
	_mm_legs = _make_layer("Legs", Vector3(0.52, 0.72, 0.34), false)
	set_process(false)


func _make_layer(node_name: String, size: Vector3, tinted: bool) -> MultiMesh:
	var mesh := BoxMesh.new()
	mesh.size = size

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	if tinted:
		mat.vertex_color_use_as_albedo = true
	else:
		mat.albedo_color = TROUSERS

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = tinted
	mm.mesh = mesh
	mm.instance_count = MAX_ACTIVE
	mm.visible_instance_count = 0

	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.multimesh = mm
	add_child(node)
	return mm


func spawn(at: Vector3, road_cell: Vector2i, count: int) -> void:
	if road_cell.x < 0:
		return
	for i in count:
		if _pos.size() >= MAX_ACTIVE:
			return
		var idx := _pos.size()
		var j := Vector3(randf_range(-1.1, 1.1), 0.0, randf_range(-1.1, 1.1))

		_pos.append(at + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7)))
		_jitter.append(j)
		_cell.append(road_cell)
		_dest.append(city.cell_centre(road_cell) + j)
		_age.append(randf() * 2.0)

		_mm_body.set_instance_color(idx, SHIRTS[randi() % SHIRTS.size()])
		_mm_head.set_instance_color(idx, SKIN[randi() % SKIN.size()])

	set_process(true)


func _process(delta: float) -> void:
	var i := 0
	while i < _pos.size():
		_age[i] += delta
		if _age[i] >= LIFETIME:
			_remove(i)
			continue

		var to_dest: Vector3 = _dest[i] - _pos[i]
		to_dest.y = 0.0

		if to_dest.length() < ARRIVE:
			if city.is_exit_cell(_cell[i]):
				_remove(i)
				continue
			var nxt: Vector2i = city.flow_next(_cell[i])
			if nxt == _cell[i]:
				_remove(i)
				continue
			_cell[i] = nxt
			_dest[i] = city.cell_centre(nxt) + _jitter[i]
			_dest[i].y = city.cell_y(nxt)
			i += 1
			continue

		var dir := to_dest.normalized()
		_pos[i] += dir * SPEED * delta
		_pos[i].y = lerpf(_pos[i].y, _dest[i].y, 1.0 - exp(-6.0 * delta))
		i += 1

	_push()

	if _pos.is_empty():
		_mm_body.visible_instance_count = 0
		_mm_head.visible_instance_count = 0
		_mm_legs.visible_instance_count = 0
		set_process(false)


func _push() -> void:
	var n := _pos.size()
	_mm_body.visible_instance_count = n
	_mm_head.visible_instance_count = n
	_mm_legs.visible_instance_count = n

	for i in n:
		var t := _age[i] * 9.0
		var bob := sin(t * 2.0) * 0.055
		var lean := sin(t) * 0.09

		var face: Vector3 = _dest[i] - _pos[i]
		var yaw := atan2(face.x, face.z)
		var basis := Basis(Vector3.UP, yaw)
		var base: Vector3 = _pos[i]

		_mm_legs.set_instance_transform(i, Transform3D(basis, base + Vector3(0.0, 0.36, 0.0)))
		_mm_body.set_instance_transform(i, Transform3D(
			basis.rotated(basis.x, lean * 0.35), base + Vector3(0.0, 1.11 + bob, 0.0)))
		_mm_head.set_instance_transform(i, Transform3D(
			basis, base + Vector3(0.0, 1.68 + bob, 0.0)))


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_dest[i] = _dest[last]
		_cell[i] = _cell[last]
		_age[i] = _age[last]
		_jitter[i] = _jitter[last]
		_mm_body.set_instance_color(i, _mm_body.get_instance_color(last))
		_mm_head.set_instance_color(i, _mm_head.get_instance_color(last))
	_pos.resize(last)
	_dest.resize(last)
	_cell.resize(last)
	_age.resize(last)
	_jitter.resize(last)
