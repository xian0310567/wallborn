extends SceneTree

const Main3DScript := preload("res://scripts/main_3d.gd")

func _initialize() -> void:
	var main = Main3DScript.new()
	get_root().add_child(main)
	await process_frame

	_assert_true(main.path.size() > 1, "3D main should initialize a valid path")
	_assert_true(main.grid.size == Vector2i(48, 28), "3D main should use the large-map grid size")
	_assert_true(main.path.size() > 32, "large-map path should be meaningfully longer than the old small board")
	_assert_true(main.marker_root.get_child_count() >= main.path.size(), "3D path visuals should include path tiles and segments")
	_assert_true(main.camera_rig.home_position == main.grid_view.cell_to_world(main.grid.goal_cell), "camera home should focus the core on large maps")
	_assert_true(main.core_indicator_label != null, "3D main should create a core focus indicator")
	_assert_true(main.enemy_indicator_label != null, "3D main should create an enemy focus indicator")
	_assert_true(main.decoration_root.get_child_count() >= 6, "large map should include visible landmark clusters")

	var place_cell := Vector2i(5, 14)
	var place_world: Vector3 = main.grid_view.cell_to_world(place_cell)
	_assert_true(main.try_place_defense_at_world(place_world), "3D placement should succeed on a path-preserving cell")
	_assert_true(main.path_reroute_flash > 0.0, "3D path visuals should flash after rerouting")
	_assert_true(main.marker_root.get_child_count() > main.path.size(), "3D path visuals should include connected segments, not only dots")

	main.queue_free()
	print("Main 3D path visual tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
