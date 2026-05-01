extends SceneTree

const EnemyScript := preload("res://scripts/enemy.gd")

func _initialize() -> void:
	var enemy = EnemyScript.new()
	enemy.configure_visuals("runner", 2)
	_assert_equal(enemy.variant, "runner", "enemy should store visual variant")
	_assert_equal(enemy.rank, 2, "enemy should store visual rank")
	_assert_equal(enemy.color, enemy.body_color, "legacy color should stay synced with body color")
	var points := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	enemy.setup(points, 10.0)
	_assert_equal(enemy.position, Vector2(0, 0), "enemy should start at first path point")
	_assert_true(not enemy.reached, "enemy should not start reached")
	_assert_equal(enemy.health, enemy.max_health, "enemy should start at full health")
	_assert_true(not enemy.take_damage(5.0), "non-lethal damage should not kill enemy")
	_assert_equal(enemy.health, enemy.max_health - 5.0, "enemy should lose health")
	_assert_true(enemy.hit_flash > 0.0, "enemy should flash after taking damage")
	_assert_true(enemy.hit_jolt > 0.0, "enemy should jolt after taking damage")

	enemy.advance(0.5)
	_assert_equal(enemy.position, Vector2(5, 0), "enemy should move toward first target")
	_assert_true(not enemy.reached, "enemy should still be moving")

	enemy.advance(0.5)
	_assert_equal(enemy.position, Vector2(10, 0), "enemy should reach second path point")
	_assert_true(not enemy.reached, "enemy should continue toward final point")

	var reroute_points := PackedVector2Array([enemy.position, Vector2(10, 5), Vector2(15, 5)])
	_assert_true(enemy.update_path_preserving_position(reroute_points), "enemy should accept a replacement path")
	_assert_equal(enemy.path_points[0], enemy.position, "replacement path should start at current enemy position")
	_assert_equal(enemy.target_index, 1, "replacement path should target the next point")
	enemy.advance(0.5)
	_assert_equal(enemy.position, Vector2(10, 5), "enemy should follow replacement path after repath")

	_assert_true(not enemy.update_path_preserving_position(PackedVector2Array([Vector2(0, 0)])), "enemy should reject invalid replacement path")
	_assert_true(enemy.take_damage(enemy.health), "lethal damage should kill enemy")
	_assert_true(enemy.dead, "enemy should mark dead after lethal damage")
	_assert_true(not enemy.advance(1.0), "dead enemy should not advance")

	# Reset for goal-reaching assertions.
	enemy.setup(PackedVector2Array([Vector2(10, 5), Vector2(15, 5)]), 10.0)

	enemy.advance(1.0)
	_assert_equal(enemy.position, Vector2(15, 5), "enemy should reach goal")
	_assert_true(enemy.reached, "enemy should mark reached at final path point")
	enemy.free()

	print("Enemy tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)
