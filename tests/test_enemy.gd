extends SceneTree

const EnemyScript := preload("res://scripts/enemy.gd")

func _initialize() -> void:
	var enemy = EnemyScript.new()
	var points := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	enemy.setup(points, 10.0)
	_assert_equal(enemy.position, Vector2(0, 0), "enemy should start at first path point")
	_assert_true(not enemy.reached, "enemy should not start reached")

	enemy.advance(0.5)
	_assert_equal(enemy.position, Vector2(5, 0), "enemy should move toward first target")
	_assert_true(not enemy.reached, "enemy should still be moving")

	enemy.advance(0.5)
	_assert_equal(enemy.position, Vector2(10, 0), "enemy should reach second path point")
	_assert_true(not enemy.reached, "enemy should continue toward final point")

	enemy.advance(1.0)
	_assert_equal(enemy.position, Vector2(10, 10), "enemy should reach goal")
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