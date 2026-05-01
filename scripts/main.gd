extends Node2D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const GRID_SIZE := Vector2i(16, 9)
const CELL_SIZE := 48
const GRID_ORIGIN := Vector2(64, 64)

var grid := WallbornGridScript.new(GRID_SIZE, CELL_SIZE)

func _ready() -> void:
	print("Wallborn boot OK")
	print("Grid ready: %sx%s cells, cell_size=%s" % [grid.size.x, grid.size.y, grid.cell_size])
	queue_redraw()

func _draw() -> void:
	_draw_background()
	_draw_cells()
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