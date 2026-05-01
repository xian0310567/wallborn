extends Node2D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const GRID_SIZE := Vector2i(16, 9)
const CELL_SIZE := 48
const GRID_ORIGIN := Vector2(64, 64)

var grid := WallbornGridScript.new(GRID_SIZE, CELL_SIZE)
var path: Array[Vector2i] = []
var enemies: Array[Node] = []

func _ready() -> void:
	# Temporary blockers to visually verify rerouting before placement UI exists.
	for cell in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]:
		grid.set_blocked(cell)
	path = grid.find_path()
	print("Wallborn boot OK")
	print("Grid ready: %sx%s cells, cell_size=%s" % [grid.size.x, grid.size.y, grid.cell_size])
	print("Path ready: %s cells" % path.size())
	spawn_enemy()
	queue_redraw()

func spawn_enemy() -> void:
	var path_points := _path_to_world_points(path)
	if path_points.size() < 2:
		push_warning("Cannot spawn enemy: no valid path")
		return
	var enemy = EnemyScript.new()
	enemy.setup(path_points, 120.0)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	enemies.append(enemy)
	add_child(enemy)
	print("Enemy spawned")

func _on_enemy_reached_goal(enemy: Node) -> void:
	print("Enemy reached goal")
	enemies.erase(enemy)
	enemy.queue_free()

func _path_to_world_points(cell_path: Array[Vector2i]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in cell_path:
		points.append(grid.cell_to_world(cell, GRID_ORIGIN))
	return points

func _draw() -> void:
	_draw_background()
	_draw_cells()
	_draw_path()
	_draw_grid_lines()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#111827"), true)

func _draw_cells() -> void:
	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(GRID_ORIGIN + Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			var fill := Color("#1f2937")
			match grid.get_cell_type(cell):
				grid.CELL_START:
					fill = Color("#10b981")
				grid.CELL_GOAL:
					fill = Color("#ef4444")
				grid.CELL_BLOCKED:
					fill = Color("#64748b")
			draw_rect(rect.grow(-2), fill, true)

func _draw_path() -> void:
	if path.size() < 2:
		return
	var points := _path_to_world_points(path)
	draw_polyline(points, Color("#facc15"), 4.0)
	for point in points:
		draw_circle(point, 5.0, Color("#fde68a"))

func _draw_grid_lines() -> void:
	var grid_pixel_size := Vector2(grid.size.x * CELL_SIZE, grid.size.y * CELL_SIZE)
	var line_color := Color("#374151")
	for x in range(grid.size.x + 1):
		var from := GRID_ORIGIN + Vector2(x * CELL_SIZE, 0)
		var to := from + Vector2(0, grid_pixel_size.y)
		draw_line(from, to, line_color, 1.0)
	for y in range(grid.size.y + 1):
		var from := GRID_ORIGIN + Vector2(0, y * CELL_SIZE)
		var to := from + Vector2(grid_pixel_size.x, 0)
		draw_line(from, to, line_color, 1.0)