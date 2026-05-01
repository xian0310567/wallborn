extends SceneTree

const Enemy3DScript := preload("res://scripts/enemy_3d.gd")

func _initialize() -> void:
	var enemy = Enemy3DScript.new()
	get_root().add_child(enemy)
	await process_frame

	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 2)]
	_assert_true(enemy.setup(points, 2.0), "3D enemy should accept a path with at least two points")
	_assert_equal(enemy.global_position, Vector3(0, 0, 0), "3D enemy should start at first path point")
	_assert_true(not enemy.reached, "3D enemy should not start reached")

	enemy.advance(0.5)
	_assert_equal(enemy.global_position, Vector3(1, 0, 0), "3D enemy should move toward first target")

	enemy.advance(0.5)
	_assert_equal(enemy.global_position, Vector3(2, 0, 0), "3D enemy should reach second point")
	_assert_true(not enemy.reached, "3D enemy should continue after second point")

	var reroute: Array[Vector3] = [enemy.global_position, Vector3(3, 0, 0), Vector3(3, 0, 1)]
	_assert_true(enemy.update_path_preserving_position(reroute), "3D enemy should accept replacement path")
	_assert_equal(enemy.path_points[0], enemy.global_position, "replacement path should preserve current position")

	enemy.advance(1.0)
	_assert_equal(enemy.global_position, Vector3(3, 0, 1), "3D enemy should follow rerouted path")
	_assert_true(enemy.reached, "3D enemy should mark reached at final point")
	_assert_true(not enemy.update_path_preserving_position([Vector3.ZERO]), "3D enemy should reject invalid replacement path")

	enemy.queue_free()
	print("Enemy 3D tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)
