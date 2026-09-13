extends Node3D

const MAX_ACTIVE := 240
const SPEED := 6.0
const LIFETIME := 13.0
const ROAD_REACH := 7.0

const SHIRTS := [
	Color(0.82, 0.35, 0.30),
	Color(0.30, 0.45, 0.72),
	Color(0.90, 0.72, 0.32),
	Color(0.38, 0.62, 0.45),
	Color(0.68, 0.42, 0.72),
	Color(0.88, 0.88, 0.86),
]
const SKIN := [
	Color(0.96, 0.80, 0.66),
	Color(0.84, 0.64, 0.48),
	Color(0.62, 0.44, 0.32),
	Color(0.42, 0.29, 0.21),
]
const TROUSERS := Color(0.26, 0.28, 0.34)

var _pos: Array[Vector3] = []
var _dir: Array[Vector3] = []
var _age: Array[float] = []
var _walked: Array[float] = []
var _turned: Array[bool] = []

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


func spawn(at: Vector3, dir: Vector3, count: int) -> void:
	for i in count:
		if _pos.size() >= MAX_ACTIVE:
			return
		var jitter := Vector3(randf_range(-0.9, 0.9), 0.0, randf_range(-0.9, 0.9))
		var idx := _pos.size()

		_pos.append(at + jitter)
		_dir.append(dir)
		_age.append(randf() * 2.0)      # desync the walk cycles
		_walked.append(0.0)
		_turned.append(false)

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

		if not _turned[i]:
			_walked[i] += SPEED * delta
			if _walked[i] >= ROAD_REACH:
				_turned[i] = true
				_dir[i] = _follow_road(_dir[i], _pos[i])

		_pos[i] += _dir[i] * SPEED * delta
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
		var yaw := atan2(_dir[i].x, _dir[i].z)

		var base := _pos[i]
		var basis := Basis(Vector3.UP, yaw)
		var sway := basis * Vector3(0.0, 0.0, 1.0) * lean

		_mm_legs.set_instance_transform(i, Transform3D(
			basis, base + Vector3(0.0, 0.36, 0.0)
		))
		_mm_body.set_instance_transform(i, Transform3D(
			basis.rotated(basis.x, lean * 0.35),
			base + Vector3(0.0, 1.11 + bob, 0.0)
		))
		_mm_head.set_instance_transform(i, Transform3D(
			basis, base + Vector3(0.0, 1.68 + bob, 0.0) + sway * 0.25
		))


func _follow_road(dir: Vector3, at: Vector3) -> Vector3:
	var turned := Vector3(dir.z, 0.0, dir.x)
	if absf(dir.x) > 0.5:
		return turned if at.z >= 0.0 else -turned
	return turned if at.x >= 0.0 else -turned


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_dir[i] = _dir[last]
		_age[i] = _age[last]
		_walked[i] = _walked[last]
		_turned[i] = _turned[last]
		_mm_body.set_instance_color(i, _mm_body.get_instance_color(last))
		_mm_head.set_instance_color(i, _mm_head.get_instance_color(last))
	_pos.resize(last)
	_dir.resize(last)
	_age.resize(last)
	_walked.resize(last)
	_turned.resize(last)
