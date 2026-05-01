extends SceneTree

const Main3DScript := preload("res://scripts/main_3d.gd")

func _initialize() -> void:
	var main = Main3DScript.new()
	get_root().add_child(main)
	await process_frame

	_assert_true(main.path.size() > 1, "3D main should initialize a valid path")
	_assert_true(main.marker_root.get_child_count() >= main.path.size(), "3D path visuals should include path tiles and segments")

	var place_cell := Vector2i(5, 4)
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
