extends RefCounted
class_name WallbornGrid

const CELL_EMPTY := 0
const CELL_START := 1
const CELL_GOAL := 2
const CELL_BLOCKED := 3

const DIRECTIONS := [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]

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

func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not blocked_cells.has(cell)

func set_blocked(cell: Vector2i, blocked: bool = true) -> bool:
	if not is_buildable(cell) and blocked:
		return false
	if blocked:
		blocked_cells[cell] = true
	else:
		blocked_cells.erase(cell)
	return true

func would_preserve_path_if_blocked(cell: Vector2i) -> bool:
	if not is_buildable(cell):
		return false
	blocked_cells[cell] = true
	var preserves_path := has_valid_path()
	blocked_cells.erase(cell)
	return preserves_path

func try_set_blocked_preserving_path(cell: Vector2i) -> bool:
	if not would_preserve_path_if_blocked(cell):
		return false
	return set_blocked(cell, true)

func clear_blocked() -> void:
	blocked_cells.clear()

func find_path(from_cell: Vector2i = start_cell, to_cell: Vector2i = goal_cell) -> Array[Vector2i]:
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return []

	var frontier: Array[Vector2i] = [from_cell]
	var came_from: Dictionary = {from_cell: from_cell}
	var index := 0

	while index < frontier.size():
		var current := frontier[index]
		index += 1

		if current == to_cell:
			break

		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not is_walkable(next) or came_from.has(next):
				continue
			frontier.append(next)
			came_from[next] = current

	if not came_from.has(to_cell):
		return []

	var path: Array[Vector2i] = []
	var current := to_cell
	while current != from_cell:
		path.push_front(current)
		current = came_from[current]
	path.push_front(from_cell)
	return path

func has_valid_path() -> bool:
	return not find_path().is_empty()