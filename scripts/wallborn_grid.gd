extends RefCounted
class_name WallbornGrid

const CELL_EMPTY := 0
const CELL_START := 1
const CELL_GOAL := 2
const CELL_BLOCKED := 3

var size: Vector2i
var cell_size: int
var start_cell: Vector2i
var goal_cell: Vector2i
var blocked_cells: Dictionary = {}

func _init(p_size: Vector2i = Vector2i(16, 9), p_cell_size: int = 48) -> void:
	size = p_size
	cell_size = p_cell_size
	start_cell = Vector2i(0, int(size.y / 2))
	goal_cell = Vector2i(size.x - 1, int(size.y / 2))

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func cell_to_world(cell: Vector2i, origin: Vector2 = Vector2.ZERO) -> Vector2:
	return origin + Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)

func world_to_cell(world_pos: Vector2, origin: Vector2 = Vector2.ZERO) -> Vector2i:
	var local := world_pos - origin
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))

func get_cell_type(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return CELL_BLOCKED
	if cell == start_cell:
		return CELL_START
	if cell == goal_cell:
		return CELL_GOAL
	if blocked_cells.has(cell):
		return CELL_BLOCKED
	return CELL_EMPTY

func is_buildable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and get_cell_type(cell) == CELL_EMPTY

func set_blocked(cell: Vector2i, blocked: bool = true) -> bool:
	if not is_buildable(cell) and blocked:
		return false
	if blocked:
		blocked_cells[cell] = true
	else:
		blocked_cells.erase(cell)
	return true