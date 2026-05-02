extends Node3D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const WallbornGridView3DScript := preload("res://scripts/wallborn_grid_view_3d.gd")
const CameraRig3DScript := preload("res://scripts/camera_rig_3d.gd")
const Enemy3DScript := preload("res://scripts/enemy_3d.gd")

const GRID_SIZE := Vector2i(48, 28)
const CELL_SIZE := 1.0
const REROUTE_FLASH_DURATION := 1.10
const NATURE_ASSET_ROOT := "res://assets/external/kenney_nature_isometric_used/"
const TREE_ASSETS := [
	"tree_oak",
	"tree_default",
	"tree_tall",
	"tree_pineRoundA",
	"tree_pineTallB",
]
const ROCK_ASSETS := [
	"rock_largeA",
	"rock_largeC",
	"rock_tallB",
	"stone_largeD",
	"stone_tallA",
]
const PATH_PROP_ASSETS := [
	"path_stone",
	"path_wood",
	"ground_pathStraight",
]

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
var asset_texture_cache: Dictionary = {}

var board_root: Node3D
var marker_root: Node3D
var defense_root: Node3D
var enemy_root: Node3D
var decoration_root: Node3D
var camera_rig: Node3D
var status_label: Label
var core_indicator_label: Label
var enemy_indicator_label: Label
var focus_hint_label: Label
var start_wave_button: Button

func _ready() -> void:
	path = grid.find_path()
	_create_roots()
	_create_light()
	_create_camera()
	_create_hud()
	_rebuild_board()
	_rebuild_decorations()
	_refresh_path_markers()
	_update_status()
	print("Wallborn 3D board boot OK")

func _process(delta: float) -> void:
	_update_wave(delta)
	_update_enemies(delta)
	_update_path_flash(delta)
	_update_focus_indicators()

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

	decoration_root = Node3D.new()
	decoration_root.name = "Landmarks"
	add_child(decoration_root)

func _create_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	light.light_energy = 1.85
	add_child(light)

	var fill := DirectionalLight3D.new()
	fill.name = "SoftFillLight"
	fill.rotation_degrees = Vector3(-72.0, -120.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)

	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#acd8f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff6df")
	env.ambient_light_energy = 0.72
	environment.environment = env
	add_child(environment)

func _create_camera() -> void:
	camera_rig = CameraRig3DScript.new()
	camera_rig.name = "CameraRig3D"
	add_child(camera_rig)
	var core_position: Vector3 = grid_view.cell_to_world(grid.goal_cell)
	camera_rig.focus_on(core_position)
	camera_rig.configure_focus_bounds(grid_view.board_center(grid.size), grid_view.board_size(grid.size), 4.0)
	camera_rig.set_home_position(core_position)

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
	status_label.text = "Wallborn 3D Large Map\nWASD/Arrow: move | Wheel: zoom | Space/Home: reset | Left click: place wall"
	status_label.add_theme_font_size_override("font_size", 16)
	margin.add_child(status_label)

	core_indicator_label = _create_indicator_label("CORE", Color("#fb7185"))
	canvas.add_child(core_indicator_label)

	enemy_indicator_label = _create_indicator_label("ENEMY", Color("#f97316"))
	canvas.add_child(enemy_indicator_label)

	focus_hint_label = _create_indicator_label("SPACE: CORE", Color("#fef3c7"))
	focus_hint_label.position = Vector2(24, 674)
	canvas.add_child(focus_hint_label)

	start_wave_button = Button.new()
	start_wave_button.text = "START 3D WAVE"
	start_wave_button.position = Vector2(24, 122)
	start_wave_button.size = Vector2(180, 44)
	start_wave_button.pressed.connect(start_wave)
	canvas.add_child(start_wave_button)

func _create_indicator_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.visible = false
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _rebuild_board() -> void:
	_clear_children(board_root)
	for cell in grid_view.get_cells_in_draw_order(grid.size):
		board_root.add_child(_create_cell_mesh(cell))

func _rebuild_decorations() -> void:
	_clear_children(decoration_root)
	_add_asset_forest_cluster(Vector2i(6, 5), 16, "NorthWestToyForest")
	_add_asset_forest_cluster(Vector2i(14, 22), 18, "SouthToyForest")
	_add_asset_forest_cluster(Vector2i(38, 7), 15, "CoreSideToyForest")
	_add_asset_rock_field(Vector2i(25, 6), "NorthStoneCut")
	_add_asset_rock_field(Vector2i(32, 20), "SouthStoneCut")
	_add_asset_camp(Vector2i(19, 15), "CentralCampLandmark")
	_add_asset_camp(Vector2i(42, 18), "CoreOutpostLandmark")
	_add_border_cliff_line(0, "NorthCliffEdge")
	_add_border_cliff_line(grid.size.y - 1, "SouthCliffEdge")

func _add_asset_forest_cluster(center: Vector2i, count: int, landmark_name: String) -> void:
	var root := Node3D.new()
	root.name = landmark_name
	decoration_root.add_child(root)
	for i in range(count):
		var offset := Vector2i((i * 3) % 7 - 3, int(i / 3) % 5 - 2)
		var cell := center + offset
		if not _can_decorate_cell(cell):
			continue
		var asset_name: String = TREE_ASSETS[i % TREE_ASSETS.size()]
		var jitter := Vector3(float((i * 37) % 9 - 4) * 0.035, 0.0, float((i * 19) % 9 - 4) * 0.035)
		var scale_value := 0.62 + float(i % 4) * 0.08
		root.add_child(_create_nature_asset(asset_name, "TreeAsset", grid_view.cell_to_world(cell) + jitter, Vector3.ONE * scale_value, float((i * 29) % 360)))

func _add_asset_rock_field(center: Vector2i, landmark_name: String) -> void:
	var root := Node3D.new()
	root.name = landmark_name
	decoration_root.add_child(root)
	for i in range(11):
		var offset := Vector2i((i * 5) % 7 - 3, (i * 2) % 5 - 2)
		var cell := center + offset
		if not _can_decorate_cell(cell):
			continue
		var asset_name: String = ROCK_ASSETS[i % ROCK_ASSETS.size()]
		var scale_value := 0.55 + float(i % 3) * 0.10
		root.add_child(_create_nature_asset(asset_name, "RockAsset", grid_view.cell_to_world(cell), Vector3.ONE * scale_value, float((i * 41) % 360)))

func _add_asset_camp(center: Vector2i, landmark_name: String) -> void:
	var root := Node3D.new()
	root.name = landmark_name
	decoration_root.add_child(root)
	var placements := [
		{"asset": "campfire_logs", "offset": Vector2i(0, 0), "scale": 0.72, "yaw": 0.0},
		{"asset": "log_stackLarge", "offset": Vector2i(-1, 1), "scale": 0.62, "yaw": 30.0},
		{"asset": "tent_detailedClosed", "offset": Vector2i(1, -1), "scale": 0.62, "yaw": -35.0},
		{"asset": "fence_simpleLow", "offset": Vector2i(-2, 0), "scale": 0.80, "yaw": 90.0},
		{"asset": "fence_simpleLow", "offset": Vector2i(2, 0), "scale": 0.80, "yaw": 90.0},
	]
	for item in placements:
		var cell: Vector2i = center + item["offset"]
		if not _can_decorate_cell(cell):
			continue
		root.add_child(_create_nature_asset(item["asset"], "LandmarkAsset", grid_view.cell_to_world(cell), Vector3.ONE * float(item["scale"]), float(item["yaw"])))

func _add_border_cliff_line(y: int, landmark_name: String) -> void:
	var root := Node3D.new()
	root.name = landmark_name
	decoration_root.add_child(root)
	for x in range(2, grid.size.x - 2, 4):
		var cell := Vector2i(x, y)
		var asset_name := "cliff_block_rock" if x % 8 == 2 else "cliff_blockHalf_rock"
		var yaw := 0.0 if y == 0 else 180.0
		root.add_child(_create_nature_asset(asset_name, "CliffEdgeAsset", grid_view.cell_to_world(cell), Vector3.ONE * 0.58, yaw))

func _can_decorate_cell(cell: Vector2i) -> bool:
	if not grid.is_in_bounds(cell):
		return false
	if cell == grid.start_cell or cell == grid.goal_cell:
		return false
	if path.has(cell):
		return false
	return true

func _create_nature_asset(asset_name: String, node_name: String, position: Vector3, scale_value: Vector3, yaw_degrees: float) -> Node3D:
	var texture: Texture2D = _load_nature_texture(asset_name)
	if texture != null:
		var sprite := Sprite3D.new()
		sprite.name = "%s_%s" % [node_name, asset_name]
		sprite.texture = texture
		sprite.pixel_size = 0.012
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.position = position + Vector3(0.0, _asset_vertical_offset(asset_name), 0.0)
		sprite.scale = scale_value
		return sprite
	return _create_asset_fallback(node_name, position, scale_value, yaw_degrees)

func _load_nature_texture(asset_name: String) -> Texture2D:
	var texture_name := "%s_NE.png" % asset_name
	if asset_texture_cache.has(texture_name):
		return asset_texture_cache[texture_name]
	var path := NATURE_ASSET_ROOT + texture_name
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		push_warning("Nature texture failed to load: %s" % path)
	asset_texture_cache[texture_name] = texture
	return texture

func _asset_vertical_offset(asset_name: String) -> float:
	if asset_name.begins_with("ground_") or asset_name.begins_with("path_"):
		return 0.12
	if asset_name.begins_with("rock_") or asset_name.begins_with("stone_"):
		return 0.34
	if asset_name.begins_with("fence_") or asset_name.begins_with("campfire_") or asset_name.begins_with("log_"):
		return 0.32
	if asset_name.begins_with("cliff_"):
		return 0.42
	return 0.62

func _create_asset_fallback(node_name: String, position: Vector3, scale_value: Vector3, yaw_degrees: float) -> Node3D:
	var fallback := Node3D.new()
	fallback.name = "%s_Fallback" % node_name
	fallback.position = position
	fallback.scale = scale_value
	fallback.rotation_degrees.y = yaw_degrees
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.55, 0.55)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.28
	mesh_instance.material_override = _make_material(Color("#6b8f54"))
	fallback.add_child(mesh_instance)
	return fallback

func _create_world_base() -> MeshInstance3D:
	var base := MeshInstance3D.new()
	base.name = "DioramaGroundBase"
	var mesh := BoxMesh.new()
	var board_size: Vector2 = grid_view.board_size(grid.size)
	mesh.size = Vector3(board_size.x + 2.4, 0.18, board_size.y + 2.4)
	base.mesh = mesh
	base.position = grid_view.board_center(grid.size) + Vector3(0.0, -0.16, 0.0)
	base.material_override = _make_material(Color("#6fa457"))
	return base

func _create_cell_mesh(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainCell_%s_%s" % [cell.x, cell.y]
	root.position = grid_view.cell_to_world(cell)

	var top := MeshInstance3D.new()
	top.name = "TerrainPatch"
	var top_mesh := BoxMesh.new()
	var patch_size := 0.96 if path.has(cell) else 0.90 + float((cell.x * 7 + cell.y * 3) % 4) * 0.015
	top_mesh.size = Vector3(CELL_SIZE * patch_size, 0.035, CELL_SIZE * patch_size)
	top.mesh = top_mesh
	top.position = Vector3(0.0, _cell_height_offset(cell), 0.0)
	top.rotation_degrees.y = float((cell.x * 11 + cell.y * 17) % 4) * 1.5
	top.material_override = _make_material(_cell_top_color(cell))
	root.add_child(top)

	if _should_add_grass_blade(cell):
		root.add_child(_create_grass_chip(cell))

	if grid.get_cell_type(cell) == grid.CELL_START:
		root.add_child(_create_tile_icon(Color("#bbf7d0"), 0.24))
	elif grid.get_cell_type(cell) == grid.CELL_GOAL:
		root.add_child(_create_tile_icon(Color("#fecaca"), 0.28))
	return root

func _create_grass_chip(cell: Vector2i) -> MeshInstance3D:
	var chip := MeshInstance3D.new()
	chip.name = "GrassChip"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.018, 0.05)
	chip.mesh = mesh
	chip.position = Vector3(float((cell.x * 13) % 7 - 3) * 0.06, 0.044, float((cell.y * 17) % 7 - 3) * 0.055)
	chip.rotation_degrees.y = float((cell.x * 31 + cell.y * 19) % 360)
	chip.material_override = _make_material(Color("#c7e37a"))
	return chip

func _should_add_grass_blade(cell: Vector2i) -> bool:
	if path.has(cell):
		return false
	if grid.get_cell_type(cell) != grid.CELL_EMPTY:
		return false
	return (cell.x * 5 + cell.y * 7) % 9 == 0

func _create_tile_icon(color: Color, radius: float) -> MeshInstance3D:
	var icon := MeshInstance3D.new()
	icon.name = "TileIcon"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.025
	icon.mesh = mesh
	icon.position = Vector3(0.0, 0.075, 0.0)
	icon.material_override = _make_material(color)
	return icon

func _cell_height_offset(cell: Vector2i) -> float:
	if path.has(cell):
		return 0.005
	return 0.018 + float((cell.x * 13 + cell.y * 29) % 5) * 0.004

func _cell_top_color(cell: Vector2i) -> Color:
	match grid.get_cell_type(cell):
		grid.CELL_START:
			return Color("#4ade80")
		grid.CELL_GOAL:
			return Color("#fb7185")
		grid.CELL_BLOCKED:
			return Color("#8fa2ae")
	if path.has(cell):
		return _path_ground_color(cell)
	if _is_forest_zone(cell):
		return _variant_color(cell, Color("#6faa52"), Color("#83bd5d"), Color("#5f9949"))
	if _is_stone_zone(cell):
		return _variant_color(cell, Color("#94a68d"), Color("#879b84"), Color("#a4b49a"))
	return _variant_color(cell, Color("#8fc65f"), Color("#a8d66e"), Color("#7eb656"))

func _path_ground_color(cell: Vector2i) -> Color:
	return _variant_color(cell, Color("#b98555"), Color("#c99562"), Color("#a8764d"))

func _variant_color(cell: Vector2i, a: Color, b: Color, c: Color) -> Color:
	var value := (cell.x * 3 + cell.y * 5) % 6
	if value <= 1:
		return a
	if value <= 3:
		return b
	return c

func _is_forest_zone(cell: Vector2i) -> bool:
	return cell.distance_to(Vector2i(6, 5)) < 8.0 or cell.distance_to(Vector2i(14, 22)) < 8.5 or cell.distance_to(Vector2i(38, 7)) < 7.5

func _is_stone_zone(cell: Vector2i) -> bool:
	return cell.distance_to(Vector2i(25, 6)) < 6.5 or cell.distance_to(Vector2i(32, 20)) < 6.5 or cell.y <= 1 or cell.y >= grid.size.y - 2

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
	_update_focus_indicators()

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
	var path_color := Color("#8b5e3c").lerp(Color("#c98f55"), flash_ratio * 0.24)
	var segment_color := Color("#6f4a31").lerp(Color("#b67a49"), flash_ratio * 0.30)
	var pulse_color := Color("#f59e0b").lerp(Color("#fff7ad"), flash_ratio)
	var flow_color := Color("#fef3c7").lerp(Color("#38bdf8"), 0.28)

	for i in range(path.size()):
		var cell := path[i]
		var world: Vector3 = grid_view.cell_to_world(cell)

		var underlay := MeshInstance3D.new()
		underlay.name = "PathTile_%s_%s" % [cell.x, cell.y]
		var underlay_mesh := BoxMesh.new()
		underlay_mesh.size = Vector3(0.54, 0.018, 0.54)
		underlay.mesh = underlay_mesh
		underlay.position = world + Vector3(0.0, 0.076 + flash_ratio * 0.01, 0.0)
		underlay.material_override = _make_material(path_color)
		marker_root.add_child(underlay)

		var ground_asset := _create_nature_asset("ground_pathStraight", "PathGround", world + Vector3(0.0, 0.08, 0.0), Vector3.ONE * (0.44 + flash_ratio * 0.03), _path_asset_yaw(i))
		marker_root.add_child(ground_asset)

		if i % 6 == 0 and i > 0 and i < path.size() - 1:
			var prop_asset: String = PATH_PROP_ASSETS[int(i / 6) % PATH_PROP_ASSETS.size()]
			var prop := _create_nature_asset(prop_asset, "PathProp", world + Vector3(0.0, 0.095, 0.0), Vector3.ONE * 0.44, float((i * 23) % 360))
			marker_root.add_child(prop)

		if path_reroute_flash > 0.0 and abs(i - active_flow_index) <= 1:
			var pulse := MeshInstance3D.new()
			pulse.name = "RerouteFlow_%s_%s" % [cell.x, cell.y]
			var pulse_mesh := CylinderMesh.new()
			pulse_mesh.top_radius = 0.18 + sin(flow_progress * PI) * 0.14
			pulse_mesh.bottom_radius = pulse_mesh.top_radius
			pulse_mesh.height = 0.022
			pulse.mesh = pulse_mesh
			pulse.position = world + Vector3(0.0, 0.14, 0.0)
			pulse.material_override = _make_material(flow_color)
			marker_root.add_child(pulse)

	if path_reroute_flash > 0.0 and last_reroute_cell.x >= 0:
		var origin_pulse := MeshInstance3D.new()
		origin_pulse.name = "RerouteOrigin"
		var origin_mesh := CylinderMesh.new()
		origin_mesh.top_radius = 0.28 + (1.0 - flash_ratio) * 0.28
		origin_mesh.bottom_radius = origin_mesh.top_radius
		origin_mesh.height = 0.026
		origin_pulse.mesh = origin_mesh
		origin_pulse.position = grid_view.cell_to_world(last_reroute_cell) + Vector3(0.0, 0.145, 0.0)
		origin_pulse.material_override = _make_material(pulse_color)
		marker_root.add_child(origin_pulse)

	for i in range(path.size() - 1):
		var from_pos: Vector3 = grid_view.cell_to_world(path[i]) + Vector3(0.0, 0.092, 0.0)
		var to_pos: Vector3 = grid_view.cell_to_world(path[i + 1]) + Vector3(0.0, 0.092, 0.0)
		var segment := _create_path_segment(from_pos, to_pos, segment_color)
		marker_root.add_child(segment)

func _path_asset_yaw(path_index: int) -> float:
	if path.size() < 2:
		return 0.0
	var from_cell: Vector2i = path[maxi(path_index - 1, 0)]
	var to_cell: Vector2i = path[mini(path_index + 1, path.size() - 1)]
	var direction: Vector2i = to_cell - from_cell
	if abs(direction.x) >= abs(direction.y):
		return 90.0
	return 0.0

func _create_path_segment(from_pos: Vector3, to_pos: Vector3, color: Color) -> MeshInstance3D:
	var delta := to_pos - from_pos
	var length := Vector2(delta.x, delta.z).length()
	var segment := MeshInstance3D.new()
	segment.name = "PathSegment"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.022, maxf(length, 0.01))
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
	var goal_direction: String = _direction_label(grid_view.cell_to_world(grid.goal_cell) - camera_center)
	var enemy_direction := "-"
	if not enemies.is_empty() and is_instance_valid(enemies[0]):
		enemy_direction = _direction_label(enemies[0].global_position - camera_center)
	status_label.text = "Wallborn 3D Large Map | %s\nMap: %sx%s | Walls: %s | Enemies: %s | Path: %s | Core: %s | Enemy: %s\nWASD/Arrow: move | Wheel: zoom | Space/Home: reset | Left click: place wall" % [
		wave_text,
		grid.size.x,
		grid.size.y,
		defense_units.size(),
		enemies.size(),
		path.size(),
		goal_direction,
		enemy_direction,
	]

func _update_focus_indicators() -> void:
	if camera_rig == null:
		return
	var camera: Camera3D = camera_rig.get("camera") as Camera3D
	if camera == null:
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var core_world: Vector3 = grid_view.cell_to_world(grid.goal_cell) + Vector3(0.0, 0.8, 0.0)
	_place_edge_indicator(core_indicator_label, camera, core_world, viewport_rect, "CORE")

	var danger_enemy: Node = _get_focus_enemy()
	if danger_enemy != null:
		var enemy_world: Vector3 = danger_enemy.global_position + Vector3(0.0, 0.8, 0.0)
		var distance_to_core: float = danger_enemy.global_position.distance_to(grid_view.cell_to_world(grid.goal_cell))
		var label_text := "DANGER" if distance_to_core < 8.0 else "ENEMY"
		_place_edge_indicator(enemy_indicator_label, camera, enemy_world, viewport_rect, label_text)
	else:
		enemy_indicator_label.visible = false

	if focus_hint_label != null:
		focus_hint_label.visible = true

func _get_focus_enemy() -> Node:
	var best_enemy: Node = null
	var best_distance := INF
	var core_pos: Vector3 = grid_view.cell_to_world(grid.goal_cell)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(core_pos)
		if distance < best_distance:
			best_enemy = enemy
			best_distance = distance
	return best_enemy

func _place_edge_indicator(label: Label, camera: Camera3D, world_position: Vector3, viewport_rect: Rect2, text: String) -> void:
	if label == null:
		return
	var screen_pos: Vector2 = camera.unproject_position(world_position)
	var margin := 28.0
	var max_pos := viewport_rect.size - Vector2(margin, margin)
	var min_pos := Vector2(margin, margin)
	var inside := screen_pos.x >= min_pos.x and screen_pos.y >= min_pos.y and screen_pos.x <= max_pos.x and screen_pos.y <= max_pos.y
	label.visible = not inside
	if not label.visible:
		return
	var clamped_pos := Vector2(
		clampf(screen_pos.x, min_pos.x, max_pos.x),
		clampf(screen_pos.y, min_pos.y, max_pos.y)
	)
	var center := viewport_rect.size * 0.5
	var direction := _screen_direction_label(screen_pos - center)
	label.text = "%s %s" % [direction, text]
	label.position = clamped_pos - Vector2(40, 14)

func _screen_direction_label(delta: Vector2) -> String:
	if delta.length() < 0.01:
		return "CENTER"
	var horizontal := "RIGHT" if delta.x > 0.0 else "LEFT"
	var vertical := "DOWN" if delta.y > 0.0 else "UP"
	if absf(delta.x) > absf(delta.y) * 1.6:
		return horizontal
	if absf(delta.y) > absf(delta.x) * 1.6:
		return vertical
	return vertical + horizontal

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



