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
	_assert_true(grid.set_blocked(Vector2i(3, 3)), "empty cell should be blockable")
	_assert_true(not grid.is_buildable(Vector2i(3, 3)), "blocked cell should not be buildable")
	_assert_equal(grid.world_to_cell(grid.cell_to_world(Vector2i(2, 2))), Vector2i(2, 2), "cell/world conversion should round-trip")
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