extends Node3D
class_name CameraRig3D

@export var move_speed := 15.0
@export var drag_speed := 0.018
@export var default_ortho_size := 14.0
@export var min_ortho_size := 8.0
@export var max_ortho_size := 24.0
@export var zoom_step := 1.2
@export var yaw_step_degrees := 90.0
@export var camera_distance := 10.5
@export var camera_height := 7.4
@export var bounds_margin := 4.0

var yaw_degrees := 45.0
var camera: Camera3D
var home_position := Vector3.ZERO
var home_yaw_degrees := 45.0
var has_focus_bounds := false
var focus_min := Vector3.ZERO
var focus_max := Vector3.ZERO

func _ready() -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = default_ortho_size
	camera.current = true
	_apply_camera_transform()

func focus_on(target: Vector3) -> void:
	global_position = target
	home_position = target
	_apply_camera_transform()

func configure_focus_bounds(center: Vector3, board_size: Vector3, margin: float = bounds_margin) -> void:
	home_position = center
	var half_size := board_size * 0.5
	focus_min = center - Vector3(half_size.x + margin, 0.0, half_size.z + margin)
	focus_max = center + Vector3(half_size.x + margin, 0.0, half_size.z + margin)
	has_focus_bounds = true
	clamp_to_focus_bounds()
	_apply_camera_transform()

func reset_home() -> void:
	global_position = home_position
	yaw_degrees = home_yaw_degrees
	if camera != null:
		camera.size = default_ortho_size
	clamp_to_focus_bounds()
	_apply_camera_transform()

func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0

	if input != Vector2.ZERO:
		input = input.normalized()
		var yaw := deg_to_rad(home_yaw_degrees)
		var screen_up := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var screen_right := Vector3(cos(yaw), 0.0, -sin(yaw))
		global_position += (screen_right * input.x - screen_up * input.y) * move_speed * delta
		clamp_to_focus_bounds()
		_apply_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = maxf(min_ortho_size, camera.size - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = minf(max_ortho_size, camera.size + zoom_step)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_HOME:
			reset_home()

func _apply_camera_transform() -> void:
	if camera == null:
		return
	var yaw := deg_to_rad(yaw_degrees)
	var offset := Vector3(sin(yaw) * camera_distance, camera_height, cos(yaw) * camera_distance)
	camera.global_position = global_position + offset
	camera.look_at(global_position, Vector3.UP)

func raycast_to_ground(screen_position: Vector2, ground_y: float = 0.0) -> Variant:
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if is_zero_approx(ray_direction.y):
		return null
	var distance := (ground_y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return null
	return ray_origin + ray_direction * distance

func clamp_to_focus_bounds() -> void:
	if not has_focus_bounds:
		return
	global_position.x = clampf(global_position.x, focus_min.x, focus_max.x)
	global_position.z = clampf(global_position.z, focus_min.z, focus_max.z)
