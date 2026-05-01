extends RefCounted
class_name WallbornGridView3D

const DEFAULT_CELL_SIZE := 1.0

var origin: Vector3
var cell_size: float

func _init(p_origin: Vector3 = Vector3.ZERO, p_cell_size: float = DEFAULT_CELL_SIZE) -> void:
	origin = p_origin
	cell_size = p_cell_size

static func centered(grid_size: Vector2i, p_cell_size: float = DEFAULT_CELL_SIZE):
	var board_size := Vector3(float(grid_size.x) * p_cell_size, 0.0, float(grid_size.y) * p_cell_size)
	return load("res://scripts/wallborn_grid_view_3d.gd").new(
		Vector3(-board_size.x * 0.5, 0.0, -board_size.z * 0.5),
		p_cell_size
	)

func cell_to_world(cell: Vector2i) -> Vector3:
	return origin + Vector3(
		(float(cell.x) + 0.5) * cell_size,
		0.0,
		(float(cell.y) + 0.5) * cell_size
	)

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := world_pos - origin
	return Vector2i(floori(local.x / cell_size), floori(local.z / cell_size))

func cell_bounds_center(cell: Vector2i, y: float = 0.0) -> Vector3:
	var center := cell_to_world(cell)
	center.y = y
	return center

func board_center(grid_size: Vector2i) -> Vector3:
	return origin + Vector3(
		float(grid_size.x) * cell_size * 0.5,
		0.0,
		float(grid_size.y) * cell_size * 0.5
	)

func board_size(grid_size: Vector2i) -> Vector3:
	return Vector3(float(grid_size.x) * cell_size, 0.0, float(grid_size.y) * cell_size)

func get_cells_in_draw_order(size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			cells.append(Vector2i(x, y))
	return cells
