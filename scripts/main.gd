extends Node2D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const WallbornGridViewScript := preload("res://scripts/wallborn_grid_view.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const GRID_SIZE := Vector2i(16, 9)
const CELL_SIZE := 48
const GRID_ORIGIN := Vector2(64, 64)

var grid := WallbornGridScript.new(GRID_SIZE, CELL_SIZE)
var grid_view = WallbornGridViewScript.top_down(GRID_ORIGIN, CELL_SIZE)
var path: Array[Vector2i] = []
var enemies: Array[Node] = []
var defense_units: Dictionary = {}
var attack_effects: Array[Dictionary] = []

func _ready() -> void:
	path = grid.find_path()
	print("Wallborn boot OK")
	print("Grid ready: %sx%s cells, cell_size=%s" % [grid.size.x, grid.size.y, grid.cell_size])
	print("Path ready: %s cells" % path.size())
	spawn_enemy()
	queue_redraw()

func _process(delta: float) -> void:
	_update_defenses(delta)
	_update_attack_effects(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_place_defense_at(event.position)

func try_place_defense_at(world_pos: Vector2) -> bool:
	var cell: Vector2i = grid_view.world_to_cell(world_pos)
	if not grid.try_set_blocked_preserving_path(cell):
		print("Defense placement rejected: %s" % cell)
		return false
	defense_units[cell] = _create_defense_unit()
	path = grid.find_path()
	_repath_enemies()
	print("Defense placed at %s. New path length: %s" % [cell, path.size()])
	queue_redraw()
	return true

func spawn_enemy() -> void:
	var path_points := _path_to_world_points(path)
	if path_points.size() < 2:
		push_warning("Cannot spawn enemy: no valid path")
		return
	var enemy = EnemyScript.new()
	enemy.setup(path_points, 120.0)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	add_child(enemy)
	print("Enemy spawned")

func _on_enemy_reached_goal(enemy: Node) -> void:
	print("Enemy reached goal")
	enemies.erase(enemy)
	enemy.queue_free()

func _on_enemy_died(enemy: Node) -> void:
	print("Enemy defeated")
	enemies.erase(enemy)
	enemy.queue_free()


func _create_defense_unit() -> Dictionary:
	return {
		"range": CELL_SIZE * 2.5,
		"damage": 10.0,
		"cooldown": 0.0,
		"cooldown_duration": 0.6,
	}

func _update_defenses(delta: float) -> void:
	if defense_units.is_empty() or enemies.is_empty():
		return
	var did_attack := false
	for cell in defense_units.keys():
		var unit: Dictionary = defense_units[cell]
		var cooldown: float = maxf(float(unit.get("cooldown", 0.0)) - delta, 0.0)
		if cooldown <= 0.0:
			var target: Node = _find_target_for_defense(cell, float(unit["range"]))
			if target != null and target.has_method("take_damage"):
				var from_pos: Vector2 = grid_view.cell_to_world(cell)
				var to_pos: Vector2 = target.position
				target.take_damage(float(unit["damage"]))
				attack_effects.append({"from": from_pos, "to": to_pos, "time": 0.12})
				cooldown = float(unit["cooldown_duration"])
				did_attack = true
		unit["cooldown"] = cooldown
		defense_units[cell] = unit
	if did_attack:
		queue_redraw()

func _find_target_for_defense(cell: Vector2i, attack_range: float) -> Node:
	var origin: Vector2 = grid_view.cell_to_world(cell)
	var best_enemy: Node = null
	var best_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = origin.distance_to(enemy.position)
		if distance <= attack_range and distance < best_distance:
			best_enemy = enemy
			best_distance = distance
	return best_enemy

func _update_attack_effects(delta: float) -> void:
	if attack_effects.is_empty():
		return
	var remaining_effects: Array[Dictionary] = []
	for effect in attack_effects:
		var next_time: float = float(effect["time"]) - delta
		if next_time > 0.0:
			effect["time"] = next_time
			remaining_effects.append(effect)
	attack_effects = remaining_effects
	queue_redraw()

func _repath_enemies() -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_cell: Vector2i = grid_view.world_to_cell(enemy.position)
		var enemy_path: Array[Vector2i] = grid.find_path(enemy_cell, grid.goal_cell)
		if enemy_path.size() < 2:
			push_warning("Cannot repath enemy from cell %s" % enemy_cell)
			continue
		if enemy.has_method("update_path_preserving_position"):
			enemy.update_path_preserving_position(_path_to_world_points(enemy_path))

func _path_to_world_points(cell_path: Array[Vector2i]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in cell_path:
		points.append(grid_view.cell_to_world(cell))
	return points

func _draw() -> void:
	_draw_background()
	_draw_cells()
	_draw_path()
	_draw_attack_effects()
	_draw_grid_lines()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111827"), true)

func _draw_cells() -> void:
	for cell in grid_view.get_cells_in_draw_order(grid.size):
		var corners: PackedVector2Array = grid_view.cell_corners(cell)
		var fill := Color("#1f2937")
		match grid.get_cell_type(cell):
			grid.CELL_START:
				fill = Color("#10b981")
			grid.CELL_GOAL:
				fill = Color("#ef4444")
			grid.CELL_BLOCKED:
				fill = Color("#64748b")
		draw_colored_polygon(corners, fill)
		draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), Color("#374151"), 1.0)
		if grid.get_cell_type(cell) == grid.CELL_BLOCKED:
			_draw_defense_unit(cell)

func _draw_defense_unit(cell: Vector2i) -> void:
	var center: Vector2 = grid_view.cell_to_world(cell)
	var half: float = minf(grid_view.basis_x.length(), grid_view.basis_y.length()) * 0.28
	var points := PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])
	draw_colored_polygon(points, Color("#94a3b8"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("#e2e8f0"), 2.0)

func _draw_attack_effects() -> void:
	for effect in attack_effects:
		draw_line(effect["from"], effect["to"], Color("#f97316"), 3.0)

func _draw_path() -> void:
	if path.size() < 2:
		return
	var points := _path_to_world_points(path)
	draw_polyline(points, Color("#facc15"), 4.0)
	for point in points:
		draw_circle(point, 5.0, Color("#fde68a"))

func _draw_grid_lines() -> void:
	# Cell outlines are drawn in _draw_cells(). Keeping this hook makes future
	# projection-specific overlays possible without coupling gameplay to rendering.
	pass



