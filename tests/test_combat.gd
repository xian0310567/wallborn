extends SceneTree

const MainScript := preload("res://scripts/main.gd")

func _initialize() -> void:
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame
	_assert_true(main.spawn_enemy(), "combat test should spawn one enemy")

	_assert_true(main.enemies.size() == 1, "main should have one enemy for combat test")
	var enemy: Node = main.enemies[0]
	enemy.position = main.grid_view.cell_to_world(Vector2i(3, 4))
	var defense_cell := Vector2i(2, 4)
	var defense := main._create_defense_unit()
	main.defense_units[defense_cell] = defense

	var target: Node = main._find_target_for_defense(defense_cell, float(defense["range"]))
	_assert_true(target == enemy, "defense should detect enemy in range")

	enemy.position = main.grid_view.cell_to_world(Vector2i(15, 8))
	var far_target: Node = main._find_target_for_defense(defense_cell, float(defense["range"]))
	_assert_true(far_target == null, "defense should ignore enemy out of range")

	enemy.position = main.grid_view.cell_to_world(Vector2i(3, 4))
	var health_before: float = enemy.health
	main._update_defenses(1.0)
	_assert_true(enemy.health < health_before, "defense update should damage enemy in range")
	_assert_true(main.attack_effects.size() > 0, "defense attack should create a visible attack effect")

	main.queue_free()
	print("Combat tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)

