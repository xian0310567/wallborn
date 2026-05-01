extends SceneTree

const WallbornGridView3DScript := preload("res://scripts/wallborn_grid_view_3d.gd")

func _initialize() -> void:
	var view = WallbornGridView3DScript.centered(Vector2i(16, 9), 1.0)
	_assert_equal(view.cell_to_world(Vector2i(0, 0)), Vector3(-7.5, 0, -4.0), "centered first cell should be top-left of board")
	_assert_equal(view.cell_to_world(Vector2i(15, 8)), Vector3(7.5, 0, 4.0), "centered last cell should be bottom-right of board")
	_assert_equal(view.board_center(Vector2i(16, 9)), Vector3.ZERO, "centered board should have world origin as center")
	_assert_equal(view.board_size(Vector2i(16, 9)), Vector3(16, 0, 9), "board size should match grid dimensions")

	for cell in [Vector2i(0, 0), Vector2i(3, 2), Vector2i(8, 4), Vector2i(15, 8)]:
		_assert_equal(view.world_to_cell(view.cell_to_world(cell)), cell, "3D world/cell conversion should round-trip cell %s" % cell)

	var cells: Array[Vector2i] = view.get_cells_in_draw_order(Vector2i(2, 2))
	_assert_equal(cells.size(), 4, "3D draw order should include every cell")
	_assert_equal(cells[0], Vector2i(0, 0), "3D draw order should start at first logical cell")
	_assert_equal(cells[3], Vector2i(1, 1), "3D draw order should end at last logical cell")

	print("3D grid view tests passed")
	quit(0)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)
