extends Node3D
class_name Enemy3D

signal reached_goal(enemy: Node)

var path_points: Array[Vector3] = []
var speed := 2.35
var target_index := 1
var reached := false

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
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.24
	body_mesh.height = 0.48
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.34, 0.0)
	body.material_override = _make_material(Color("#fb923c"))
	add_child(body)

	var face := MeshInstance3D.new()
	face.name = "Face"
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.18, 0.1, 0.06)
	face.mesh = face_mesh
	face.position = Vector3(0.0, 0.39, -0.21)
	face.material_override = _make_material(Color("#111827"))
	add_child(face)

	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.28
	shadow_mesh.bottom_radius = 0.28
	shadow_mesh.height = 0.02
	shadow.mesh = shadow_mesh
	shadow.position = Vector3(0.0, 0.01, 0.0)
	shadow.material_override = _make_material(Color(0, 0, 0, 0.35))
	add_child(shadow)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
