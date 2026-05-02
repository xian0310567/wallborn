extends Node3D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const WallbornGridView3DScript := preload("res://scripts/wallborn_grid_view_3d.gd")
const CameraRig3DScript := preload("res://scripts/camera_rig_3d.gd")
const Enemy3DScript := preload("res://scripts/enemy_3d.gd")

const GRID_SIZE := Vector2i(48, 28)
const CELL_SIZE := 1.0
const REROUTE_FLASH_DURATION := 1.10

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
var path_reroute_flash := 0.0
var last_reroute_cell := Vector2i(-1, -1)

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
	_update_path_flash(delta)

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
	env.background_color = Color("#b9e6ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f8fafc")
	env.ambient_light_energy = 0.62
	environment.environment = env
	add_child(environment)

func _create_camera() -> void:
	camera_rig = CameraRig3DScript.new()
	camera_rig.name = "CameraRig3D"
	add_child(camera_rig)
	camera_rig.focus_on(grid_view.board_center(grid.size))
	camera_rig.configure_focus_bounds(grid_view.board_center(grid.size), grid_view.board_size(grid.size), 4.0)

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
	status_label.text = "Wallborn 3D Large Map\nWASD/Arrow: move | Wheel: zoom | Q/E: rotate | Space/Home: reset | Left click: place wall"
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

func _create_cell_mesh(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "DioramaCell_%s_%s" % [cell.x, cell.y]
	root.position = grid_view.cell_to_world(cell)

	var base := MeshInstance3D.new()
	base.name = "TileBase"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(CELL_SIZE * 0.94, 0.16, CELL_SIZE * 0.94)
	base.mesh = base_mesh
	base.position = Vector3(0.0, -0.08, 0.0)
	base.material_override = _make_material(_cell_side_color(cell))
	root.add_child(base)

	var top := MeshInstance3D.new()
	top.name = "TileTop"
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(CELL_SIZE * 0.82, 0.055, CELL_SIZE * 0.82)
	top.mesh = top_mesh
	top.position = Vector3(0.0, 0.025, 0.0)
	top.material_override = _make_material(_cell_top_color(cell))
	root.add_child(top)

	if grid.get_cell_type(cell) == grid.CELL_START:
		root.add_child(_create_tile_icon(Color("#bbf7d0"), 0.27))
	elif grid.get_cell_type(cell) == grid.CELL_GOAL:
		root.add_child(_create_tile_icon(Color("#fecaca"), 0.31))
	return root

func _create_tile_icon(color: Color, radius: float) -> MeshInstance3D:
	var icon := MeshInstance3D.new()
	icon.name = "TileIcon"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.025
	icon.mesh = mesh
	icon.position = Vector3(0.0, 0.072, 0.0)
	icon.material_override = _make_material(color)
	return icon

func _cell_top_color(cell: Vector2i) -> Color:
	match grid.get_cell_type(cell):
		grid.CELL_START:
			return Color("#34d399")
		grid.CELL_GOAL:
			return Color("#fb7185")
		grid.CELL_BLOCKED:
			return Color("#94a3b8")
	var alternate := (cell.x * 3 + cell.y * 5) % 4
	if alternate == 0:
		return Color("#9bd66f")
	if alternate == 1:
		return Color("#8fcb63")
	return Color("#a7d97a")

func _cell_side_color(cell: Vector2i) -> Color:
	match grid.get_cell_type(cell):
		grid.CELL_START:
			return Color("#15803d")
		grid.CELL_GOAL:
			return Color("#be123c")
		grid.CELL_BLOCKED:
			return Color("#64748b")
	return Color("#5f8f4e")

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
	path_reroute_flash = REROUTE_FLASH_DURATION
	last_reroute_cell = cell
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

	for offset in [-0.22, 0.0, 0.22]:
		var block := MeshInstance3D.new()
		block.name = "WallBlock"
		var block_mesh := BoxMesh.new()
		block_mesh.size = Vector3(0.23, 0.52 + absf(offset) * 0.24, 0.58)
		block.mesh = block_mesh
		block.position = Vector3(offset, 0.30 + absf(offset) * 0.12, 0.0)
		block.material_override = _make_material(Color("#8ea3b7"))
		unit.add_child(block)

	var turret := MeshInstance3D.new()
	var turret_mesh := CylinderMesh.new()
	turret_mesh.radial_segments = 8
	turret_mesh.top_radius = 0.24
	turret_mesh.bottom_radius = 0.31
	turret_mesh.height = 0.26
	turret.mesh = turret_mesh
	turret.position = Vector3(0.0, 0.78, 0.0)
	turret.material_override = _make_material(Color("#e2e8f0"))
	unit.add_child(turret)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.16, 0.12, 0.62)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.82, -0.36)
	barrel.material_override = _make_material(Color("#f59e0b"))
	unit.add_child(barrel)

	defense_root.add_child(unit)

func _refresh_path_markers() -> void:
	_clear_children(marker_root)
	if path.is_empty():
		return

	var flash_ratio := clampf(path_reroute_flash / REROUTE_FLASH_DURATION, 0.0, 1.0)
	var flow_progress := 1.0 - flash_ratio
	var active_flow_index := clampi(roundi(flow_progress * float(maxi(path.size() - 1, 0))), 0, maxi(path.size() - 1, 0))
	var path_color := Color("#b98250").lerp(Color("#f3c16f"), flash_ratio * 0.35)
	var segment_color := Color("#8b5e34").lerp(Color("#dba85b"), flash_ratio * 0.45)
	var pulse_color := Color("#f59e0b").lerp(Color("#fff7ad"), flash_ratio)
	var flow_color := Color("#fef3c7").lerp(Color("#38bdf8"), 0.28)

	for i in range(path.size()):
		var cell := path[i]
		var important_cell := i == 0 or i == path.size() - 1 or i % 2 == 0
		if not important_cell:
			continue
		var marker := MeshInstance3D.new()
		marker.name = "PathTile_%s_%s" % [cell.x, cell.y]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.52, 0.03, 0.52)
		marker.mesh = mesh
		marker.position = grid_view.cell_to_world(cell) + Vector3(0.0, 0.082 + flash_ratio * 0.018, 0.0)
		marker.material_override = _make_material(path_color)
		marker_root.add_child(marker)

		if path_reroute_flash > 0.0 and abs(i - active_flow_index) <= 1:
			var pulse := MeshInstance3D.new()
			pulse.name = "RerouteFlow_%s_%s" % [cell.x, cell.y]
			var pulse_mesh := CylinderMesh.new()
			pulse_mesh.top_radius = 0.22 + sin(flow_progress * PI) * 0.18
			pulse_mesh.bottom_radius = pulse_mesh.top_radius
			pulse_mesh.height = 0.025
			pulse.mesh = pulse_mesh
			pulse.position = grid_view.cell_to_world(cell) + Vector3(0.0, 0.12, 0.0)
			pulse.material_override = _make_material(flow_color)
			marker_root.add_child(pulse)

	if path_reroute_flash > 0.0 and last_reroute_cell.x >= 0:
		var origin_pulse := MeshInstance3D.new()
		origin_pulse.name = "RerouteOrigin"
		var origin_mesh := CylinderMesh.new()
		origin_mesh.top_radius = 0.34 + (1.0 - flash_ratio) * 0.36
		origin_mesh.bottom_radius = origin_mesh.top_radius
		origin_mesh.height = 0.03
		origin_pulse.mesh = origin_mesh
		origin_pulse.position = grid_view.cell_to_world(last_reroute_cell) + Vector3(0.0, 0.13, 0.0)
		origin_pulse.material_override = _make_material(pulse_color)
		marker_root.add_child(origin_pulse)

	for i in range(path.size() - 1):
		var from_pos: Vector3 = grid_view.cell_to_world(path[i]) + Vector3(0.0, 0.095, 0.0)
		var to_pos: Vector3 = grid_view.cell_to_world(path[i + 1]) + Vector3(0.0, 0.095, 0.0)
		var segment := _create_path_segment(from_pos, to_pos, segment_color)
		marker_root.add_child(segment)

func _create_path_segment(from_pos: Vector3, to_pos: Vector3, color: Color) -> MeshInstance3D:
	var delta := to_pos - from_pos
	var length := Vector2(delta.x, delta.z).length()
	var segment := MeshInstance3D.new()
	segment.name = "PathSegment"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.24, 0.03, maxf(length, 0.01))
	segment.mesh = mesh
	segment.position = (from_pos + to_pos) * 0.5
	segment.rotation.y = atan2(delta.x, delta.z)
	segment.material_override = _make_material(color)
	return segment

func _update_path_flash(delta: float) -> void:
	if path_reroute_flash <= 0.0:
		return
	path_reroute_flash = maxf(path_reroute_flash - delta, 0.0)
	_refresh_path_markers()

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
	var camera_center := Vector3.ZERO
	if camera_rig != null:
		camera_center = camera_rig.global_position
	var goal_direction := _direction_label(grid_view.cell_to_world(grid.goal_cell) - camera_center)
	var enemy_direction := "-"
	if not enemies.is_empty() and is_instance_valid(enemies[0]):
		enemy_direction = _direction_label(enemies[0].global_position - camera_center)
	status_label.text = "Wallborn 3D Large Map | %s\nMap: %sx%s | Walls: %s | Enemies: %s | Path: %s | Core: %s | Enemy: %s\nWASD/Arrow: move | Wheel: zoom | Q/E: rotate | Space/Home: reset | Left click: place wall" % [
		wave_text,
		grid.size.x,
		grid.size.y,
		defense_units.size(),
		enemies.size(),
		path.size(),
		goal_direction,
		enemy_direction,
	]

func _direction_label(delta: Vector3) -> String:
	var planar := Vector2(delta.x, delta.z)
	if planar.length() < 0.75:
		return "HERE"
	var horizontal := "E" if planar.x > 0.0 else "W"
	var vertical := "S" if planar.y > 0.0 else "N"
	if absf(planar.x) > absf(planar.y) * 1.8:
		return horizontal
	if absf(planar.y) > absf(planar.x) * 1.8:
		return vertical
	return vertical + horizontal

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
