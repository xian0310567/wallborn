extends Node3D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const WallbornGridView3DScript := preload("res://scripts/wallborn_grid_view_3d.gd")
const CameraRig3DScript := preload("res://scripts/camera_rig_3d.gd")
const Enemy3DScript := preload("res://scripts/enemy_3d.gd")

const GRID_SIZE := Vector2i(16, 9)
const CELL_SIZE := 1.0

var grid := WallbornGridScript.new(GRID_SIZE, 48)
var grid_view = WallbornGridView3DScript.centered(GRID_SIZE, CELL_SIZE)
var path: Array[Vector2i] = []
var defense_units: Dictionary = {}
var enemies: Array[Node] = []
var wave_active := false
var wave_enemies_to_spawn := 0
var wave_spawned_count := 0
var wave_resolved_count := 0
var wave_spawn_timer := 0.0
var wave_spawn_interval := 0.65

var board_root: Node3D
var marker_root: Node3D
var defense_root: Node3D
var enemy_root: Node3D
var camera_rig: Node3D
var status_label: Label
var start_wave_button: Button

func _ready() -> void:
	path = grid.find_path()
	_create_roots()
	_create_light()
	_create_camera()
	_create_hud()
	_rebuild_board()
	_refresh_path_markers()
	_update_status()
	print("Wallborn 3D board boot OK")

func _process(delta: float) -> void:
	_update_wave(delta)
	_update_enemies(delta)

func _create_roots() -> void:
	board_root = Node3D.new()
	board_root.name = "Board"
	add_child(board_root)

	marker_root = Node3D.new()
	marker_root.name = "PathMarkers"
	add_child(marker_root)

	defense_root = Node3D.new()
	defense_root.name = "DefenseUnits"
	add_child(defense_root)

	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)

func _create_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	light.light_energy = 1.4
	add_child(light)

	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b1020")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#94a3b8")
	env.ambient_light_energy = 0.35
	environment.environment = env
	add_child(environment)

func _create_camera() -> void:
	camera_rig = CameraRig3DScript.new()
	camera_rig.name = "CameraRig3D"
	add_child(camera_rig)
	camera_rig.focus_on(grid_view.board_center(grid.size))
	camera_rig.configure_focus_bounds(grid_view.board_center(grid.size), grid_view.board_size(grid.size), 2.0)

func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	panel.custom_minimum_size = Vector2(470, 90)
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	status_label = Label.new()
	status_label.text = "Wallborn 3D Diorama Camera\nWASD/Arrow: move | Wheel: zoom | Q/E: rotate | Space/Home: reset | Left click: place wall"
	status_label.add_theme_font_size_override("font_size", 16)
	margin.add_child(status_label)

	start_wave_button = Button.new()
	start_wave_button.text = "START 3D WAVE"
	start_wave_button.position = Vector2(24, 122)
	start_wave_button.size = Vector2(180, 44)
	start_wave_button.pressed.connect(start_wave)
	canvas.add_child(start_wave_button)

func _rebuild_board() -> void:
	_clear_children(board_root)
	for cell in grid_view.get_cells_in_draw_order(grid.size):
		board_root.add_child(_create_cell_mesh(cell))

func _create_cell_mesh(cell: Vector2i) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Cell_%s_%s" % [cell.x, cell.y]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE * 0.96, 0.08, CELL_SIZE * 0.96)
	mesh_instance.mesh = mesh
	mesh_instance.position = grid_view.cell_to_world(cell) + Vector3(0.0, -0.04, 0.0)
	mesh_instance.material_override = _material_for_cell(cell)
	return mesh_instance

func _material_for_cell(cell: Vector2i) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#182033")
	match grid.get_cell_type(cell):
		grid.CELL_START:
			material.albedo_color = Color("#14532d")
		grid.CELL_GOAL:
			material.albedo_color = Color("#7f1d1d")
		grid.CELL_BLOCKED:
			material.albedo_color = Color("#475569")
	material.roughness = 0.85
	return material

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ground_point = camera_rig.raycast_to_ground(event.position)
		if ground_point == null:
			return
		try_place_defense_at_world(ground_point)

func try_place_defense_at_world(world_pos: Vector3) -> bool:
	var cell: Vector2i = grid_view.world_to_cell(world_pos)
	if not grid.try_set_blocked_preserving_path(cell):
		print("3D defense placement rejected: %s" % cell)
		return false
	defense_units[cell] = true
	path = grid.find_path()
	_add_defense_unit(cell)
	_rebuild_board()
	_refresh_path_markers()
	_repath_enemies()
	_update_status()
	print("3D defense placed at %s. New path length: %s" % [cell, path.size()])
	return true

func start_wave() -> bool:
	if wave_active or path.size() < 2:
		return false
	wave_active = true
	wave_enemies_to_spawn = 5
	wave_spawned_count = 0
	wave_resolved_count = 0
	wave_spawn_timer = 0.0
	start_wave_button.disabled = true
	_update_status()
	return true

func _update_wave(delta: float) -> void:
	if not wave_active:
		return
	if wave_spawned_count >= wave_enemies_to_spawn:
		return
	wave_spawn_timer -= delta
	if wave_spawn_timer <= 0.0:
		if spawn_enemy():
			wave_spawned_count += 1
			wave_spawn_timer = wave_spawn_interval
	_update_status()

func spawn_enemy() -> bool:
	var path_points := _path_to_world_points_3d(path)
	if path_points.size() < 2:
		return false
	var enemy = Enemy3DScript.new()
	enemy.name = "Enemy3D_%s" % wave_spawned_count
	enemy.setup(path_points, 2.35)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	enemies.append(enemy)
	enemy_root.add_child(enemy)
	return true

func _update_enemies(delta: float) -> void:
	if enemies.is_empty():
		return
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			enemies.erase(enemy)
			continue
		if enemy.has_method("advance"):
			enemy.advance(delta)

func _on_enemy_reached_goal(enemy: Node) -> void:
	enemies.erase(enemy)
	wave_resolved_count += 1
	enemy.queue_free()
	if wave_active and wave_spawned_count >= wave_enemies_to_spawn and wave_resolved_count >= wave_enemies_to_spawn:
		wave_active = false
		start_wave_button.disabled = false
	_update_status()

func _repath_enemies() -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_cell: Vector2i = grid_view.world_to_cell(enemy.global_position)
		var enemy_path: Array[Vector2i] = grid.find_path(enemy_cell, grid.goal_cell)
		if enemy_path.size() < 2:
			continue
		if enemy.has_method("update_path_preserving_position"):
			enemy.update_path_preserving_position(_path_to_world_points_3d(enemy_path))

func _path_to_world_points_3d(cell_path: Array[Vector2i]) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for cell in cell_path:
		points.append(grid_view.cell_to_world(cell))
	return points

func _add_defense_unit(cell: Vector2i) -> void:
	var unit := Node3D.new()
	unit.name = "WallTurret_%s_%s" % [cell.x, cell.y]
	unit.position = grid_view.cell_to_world(cell)

	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.78, 0.72, 0.78)
	wall.mesh = wall_mesh
	wall.position = Vector3(0.0, 0.36, 0.0)
	wall.material_override = _make_material(Color("#64748b"))
	unit.add_child(wall)

	var turret := MeshInstance3D.new()
	var turret_mesh := CylinderMesh.new()
	turret_mesh.top_radius = 0.22
	turret_mesh.bottom_radius = 0.28
	turret_mesh.height = 0.24
	turret.mesh = turret_mesh
	turret.position = Vector3(0.0, 0.86, 0.0)
	turret.material_override = _make_material(Color("#cbd5e1"))
	unit.add_child(turret)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.16, 0.12, 0.56)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.9, -0.32)
	barrel.material_override = _make_material(Color("#f97316"))
	unit.add_child(barrel)

	defense_root.add_child(unit)

func _refresh_path_markers() -> void:
	_clear_children(marker_root)
	for cell in path:
		var marker := MeshInstance3D.new()
		marker.name = "Path_%s_%s" % [cell.x, cell.y]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.34, 0.035, 0.34)
		marker.mesh = mesh
		marker.position = grid_view.cell_to_world(cell) + Vector3(0.0, 0.035, 0.0)
		marker.material_override = _make_material(Color("#facc15"))
		marker_root.add_child(marker)

func _update_status() -> void:
	if status_label == null:
		return
	var wave_text := "READY"
	if wave_active:
		wave_text = "WAVE %s/%s resolved %s/%s" % [
			wave_spawned_count,
			wave_enemies_to_spawn,
			wave_resolved_count,
			wave_enemies_to_spawn,
		]
	status_label.text = "Wallborn 3D Diorama Camera | %s\nWalls: %s | Enemies: %s | Path cells: %s\nWASD/Arrow: move | Wheel: zoom | Q/E: rotate | Space/Home: reset | Left click: place wall" % [
		wave_text,
		defense_units.size(),
		enemies.size(),
		path.size(),
	]

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
