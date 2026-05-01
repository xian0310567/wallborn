extends SceneTree

const WallbornGridViewScript := preload("res://scripts/wallborn_grid_view.gd")

func _initialize() -> void:
	var top_down = WallbornGridViewScript.top_down(Vector2(64, 64), 48)
	_assert_equal(top_down.cell_to_world(Vector2i(0, 0)), Vector2(88, 88), "top-down cell center should match existing visual position")
	_assert_equal(top_down.world_to_cell(Vector2(88, 88)), Vector2i(0, 0), "top-down world/cell conversion should round-trip")
	_assert_equal(top_down.world_to_cell(top_down.cell_to_world(Vector2i(3, 2))), Vector2i(3, 2), "top-down conversion should round-trip arbitrary cell")

	var dimetric = WallbornGridViewScript.dimetric_2_5d(Vector2(320, 80), 64, 32)
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(5, 4), Vector2i(15, 8)]:
		_assert_equal(dimetric.world_to_cell(dimetric.cell_to_world(cell)), cell, "2.5D basis should round-trip cell %s" % cell)

	var corners: PackedVector2Array = dimetric.cell_corners(Vector2i(2, 3))
	_assert_equal(corners.size(), 4, "cell corners should describe a projected tile quad")

	var draw_order: Array[Vector2i] = dimetric.get_cells_in_draw_order(Vector2i(3, 3))
	_assert_equal(draw_order.front(), Vector2i(0, 0), "draw order should start at top-left logical cell")
	_assert_equal(draw_order.back(), Vector2i(2, 2), "draw order should end at bottom-right logical cell")

	print("Grid view tests passed")
	quit(0)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)

