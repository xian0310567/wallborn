extends Node3D
class_name Enemy3D

signal reached_goal(enemy: Node)

var path_points: Array[Vector3] = []
var speed := 2.35
var target_index := 1
var reached := false
var visual_root: Node3D

func _ready() -> void:
	if get_child_count() == 0:
		_create_default_visuals()

func setup(points: Array[Vector3], p_speed: float = speed) -> bool:
	if points.size() < 2:
		return false
	path_points = points.duplicate()
	speed = p_speed
	target_index = 1
	reached = false
	global_position = path_points[0]
	_face_direction(path_points[1] - path_points[0])
	return true

func advance(delta: float) -> bool:
	if reached or path_points.size() < 2:
		return false

	var remaining_distance := speed * delta
	while remaining_distance > 0.0 and not reached:
		var target := path_points[target_index]
		var to_target := target - global_position
		var distance := to_target.length()
		if distance <= remaining_distance or is_zero_approx(distance):
			global_position = target
			remaining_distance -= distance
			target_index += 1
			if target_index >= path_points.size():
				reached = true
				reached_goal.emit(self)
				return true
		else:
			_face_direction(to_target)
			global_position += to_target.normalized() * remaining_distance
			remaining_distance = 0.0
	return false

func update_path_preserving_position(points: Array[Vector3]) -> bool:
	if points.size() < 2:
		return false
	path_points = points.duplicate()
	path_points[0] = global_position
	target_index = 1
	reached = false
	return true

func _create_default_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "LowPolyMonsterVisual"
	add_child(visual_root)

	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.radial_segments = 16
	shadow_mesh.top_radius = 0.34
	shadow_mesh.bottom_radius = 0.34
	shadow_mesh.height = 0.018
	shadow.mesh = shadow_mesh
	shadow.position = Vector3(0.0, 0.012, 0.0)
	shadow.material_override = _make_material(Color(0, 0, 0, 0.35))
	visual_root.add_child(shadow)

	var body := MeshInstance3D.new()
	body.name = "MonsterBody"
	var body_mesh := CylinderMesh.new()
	body_mesh.radial_segments = 7
	body_mesh.top_radius = 0.25
	body_mesh.bottom_radius = 0.31
	body_mesh.height = 0.44
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.34, 0.0)
	body.rotation_degrees.y = 12.0
	body.scale = Vector3(1.05, 1.0, 0.92)
	body.material_override = _make_material(Color("#b4475d"))
	visual_root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "MonsterHead"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.40, 0.30, 0.34)
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.62, -0.11)
	head.rotation_degrees.x = -6.0
	head.material_override = _make_material(Color("#d95d6f"))
	visual_root.add_child(head)

	for x in [-0.12, 0.12]:
		var eye := MeshInstance3D.new()
		eye.name = "MonsterEye"
		var eye_mesh := BoxMesh.new()
		eye_mesh.size = Vector3(0.07, 0.07, 0.035)
		eye.mesh = eye_mesh
		eye.position = Vector3(x, 0.66, -0.295)
		eye.material_override = _make_material(Color("#fff7ed"))
		visual_root.add_child(eye)

	for x in [-0.15, 0.15]:
		var pupil := MeshInstance3D.new()
		pupil.name = "MonsterPupil"
		var pupil_mesh := BoxMesh.new()
		pupil_mesh.size = Vector3(0.028, 0.04, 0.02)
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(x, 0.66, -0.318)
		pupil.material_override = _make_material(Color("#1f2937"))
		visual_root.add_child(pupil)

	for x in [-0.16, 0.16]:
		var horn := MeshInstance3D.new()
		horn.name = "MonsterHorn"
		var horn_mesh := CylinderMesh.new()
		horn_mesh.radial_segments = 5
		horn_mesh.top_radius = 0.0
		horn_mesh.bottom_radius = 0.055
		horn_mesh.height = 0.20
		horn.mesh = horn_mesh
		horn.position = Vector3(x, 0.83, -0.05)
		horn.rotation_degrees = Vector3(18.0, 0.0, -18.0 if x < 0.0 else 18.0)
		horn.material_override = _make_material(Color("#ffd08a"))
		visual_root.add_child(horn)

	for x in [-0.19, 0.19]:
		for z in [-0.14, 0.16]:
			var leg := MeshInstance3D.new()
			leg.name = "MonsterLeg"
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.10, 0.18, 0.12)
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.12, z)
			leg.material_override = _make_material(Color("#8f354d"))
			visual_root.add_child(leg)

	var nose := MeshInstance3D.new()
	nose.name = "ForwardNose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.12, 0.08, 0.09)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 0.58, -0.34)
	nose.material_override = _make_material(Color("#7c2d3f"))
	visual_root.add_child(nose)

func _face_direction(direction: Vector3) -> void:
	if visual_root == null or direction.length() < 0.001:
		return
	visual_root.rotation.y = atan2(direction.x, direction.z)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
