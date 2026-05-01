extends RefCounted
class_name WallbornGridView

const DEFAULT_CELL_SIZE := 48.0

var origin: Vector2
var basis_x: Vector2
var basis_y: Vector2

func _init(p_origin: Vector2 = Vector2.ZERO, p_cell_size: float = DEFAULT_CELL_SIZE, p_basis_x: Vector2 = Vector2.ZERO, p_basis_y: Vector2 = Vector2.ZERO) -> void:
	origin = p_origin
	if p_basis_x == Vector2.ZERO:
		basis_x = Vector2(p_cell_size, 0.0)
	else:
		basis_x = p_basis_x
	if p_basis_y == Vector2.ZERO:
		basis_y = Vector2(0.0, p_cell_size)
	else:
		basis_y = p_basis_y

static func top_down(p_origin: Vector2 = Vector2.ZERO, p_cell_size: float = DEFAULT_CELL_SIZE):
	return load("res://scripts/wallborn_grid_view.gd").new(p_origin, p_cell_size)

static func dimetric_2_5d(p_origin: Vector2 = Vector2.ZERO, p_tile_width: float = 64.0, p_tile_height: float = 32.0):
	return load("res://scripts/wallborn_grid_view.gd").new(
		p_origin,
		p_tile_width,
		Vector2(p_tile_width * 0.5, p_tile_height * 0.5),
		Vector2(-p_tile_width * 0.5, p_tile_height * 0.5)
	)

func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + basis_x * (float(cell.x) + 0.5) + basis_y * (float(cell.y) + 0.5)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - origin
	var determinant := basis_x.x * basis_y.y - basis_x.y * basis_y.x
	if is_zero_approx(determinant):
		push_error("WallbornGridView basis is not invertible")
		return Vector2i.ZERO
	var grid_x := (local.x * basis_y.y - local.y * basis_y.x) / determinant
	var grid_y := (basis_x.x * local.y - basis_x.y * local.x) / determinant
	return Vector2i(floori(grid_x), floori(grid_y))

func cell_corners(cell: Vector2i) -> PackedVector2Array:
	var base := origin + basis_x * float(cell.x) + basis_y * float(cell.y)
	return PackedVector2Array([
		base,
		base + basis_x,
		base + basis_x + basis_y,
		base + basis_y,
	])

func cell_sort_key(cell: Vector2i) -> int:
	return cell.x + cell.y

func get_cells_in_draw_order(size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var key_a := cell_sort_key(a)
		var key_b := cell_sort_key(b)
		if key_a == key_b:
			return a.y < b.y
		return key_a < key_b
	)
	return cells

