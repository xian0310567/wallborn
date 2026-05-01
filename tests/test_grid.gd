extends SceneTree

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")

func _initialize() -> void:
	var grid = WallbornGridScript.new(Vector2i(16, 9), 48)
	_assert_true(grid.is_in_bounds(Vector2i(0, 0)), "origin cell should be in bounds")
	_assert_true(not grid.is_in_bounds(Vector2i(-1, 0)), "negative x should be out of bounds")
	_assert_true(not grid.is_in_bounds(Vector2i(16, 0)), "x=size should be out of bounds")
	_assert_equal(grid.start_cell, Vector2i(0, 4), "start cell should be left middle")
	_assert_equal(grid.goal_cell, Vector2i(15, 4), "goal cell should be right middle")
	_assert_true(not grid.is_buildable(grid.start_cell), "start cell should not be buildable")
	_assert_true(not grid.is_buildable(grid.goal_cell), "goal cell should not be buildable")
	_assert_true(grid.is_buildable(Vector2i(3, 3)), "empty cell should be buildable")
	_assert_true(not grid.set_blocked(grid.start_cell), "start cell should reject defense placement")
	_assert_true(not grid.set_blocked(grid.goal_cell), "goal cell should reject defense placement")
	_assert_true(grid.set_blocked(Vector2i(3, 3)), "empty cell should be blockable")
	_assert_true(not grid.is_buildable(Vector2i(3, 3)), "blocked cell should not be buildable")
	_assert_true(not grid.set_blocked(Vector2i(3, 3)), "occupied cell should reject duplicate placement")
	_assert_equal(grid.world_to_cell(grid.cell_to_world(Vector2i(2, 2))), Vector2i(2, 2), "cell/world conversion should round-trip")

	grid.clear_blocked()
	var direct_path: Array[Vector2i] = grid.find_path()
	_assert_true(not direct_path.is_empty(), "empty grid should have a path")
	_assert_equal(direct_path.front(), grid.start_cell, "path should start at start cell")
	_assert_equal(direct_path.back(), grid.goal_cell, "path should end at goal cell")

	for cell in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]:
		_assert_true(grid.set_blocked(cell), "blocker should be placeable")
	var rerouted_path: Array[Vector2i] = grid.find_path()
	_assert_true(not rerouted_path.is_empty(), "grid should reroute around partial wall")
	for blocked_cell in grid.blocked_cells.keys():
		_assert_true(not rerouted_path.has(blocked_cell), "path should not include blocked cells")
	_assert_true(rerouted_path.size() > direct_path.size(), "rerouted path should be longer than direct path")

	grid.clear_blocked()
	for y in range(grid.size.y):
		if y != grid.start_cell.y:
			_assert_true(grid.set_blocked(Vector2i(1, y)), "vertical wall cell should be blockable")
	_assert_true(not grid.find_path().is_empty(), "gap in wall should still allow a path")
	_assert_true(grid.set_blocked(Vector2i(1, grid.start_cell.y)), "closing gap should be blockable")
	_assert_true(grid.find_path().is_empty(), "solid wall should block all paths")
	_assert_true(not grid.has_valid_path(), "solid wall should report no valid path")

	print("Grid tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)