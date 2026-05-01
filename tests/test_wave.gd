extends SceneTree

const MainScript := preload("res://scripts/main.gd")

func _initialize() -> void:
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame

	_assert_true(not main.wave_active, "wave should start inactive")
	_assert_true(main.enemies.is_empty(), "main should not auto-spawn enemies before wave start")
	_assert_true(main.start_wave(), "start_wave should start a valid wave")
	_assert_true(main.wave_active, "wave should become active")
	_assert_true(not main.start_wave(), "start_wave should reject overlapping waves")
	_assert_equal(main.wave_enemies_to_spawn, 5, "first wave should spawn five enemies")

	for i in range(main.wave_enemies_to_spawn):
		main._update_wave(main.wave_spawn_interval + 0.01)
	_assert_equal(main.wave_spawned_count, main.wave_enemies_to_spawn, "wave should spawn all enemies sequentially")
	_assert_equal(main.enemies.size(), main.wave_enemies_to_spawn, "spawned enemies should be alive until resolved")

	for enemy in main.enemies.duplicate():
		main._on_enemy_died(enemy)
	_assert_equal(main.wave_resolved_count, main.wave_enemies_to_spawn, "wave should count resolved enemies")
	_assert_true(not main.wave_active, "wave should end after all spawned enemies are resolved")
	_assert_equal(main.waves_cleared, 1, "wave clear count should increment")
	_assert_true(main.awaiting_card_choice, "wave clear should present card choices before next wave")
	_assert_true(not main.start_wave(), "next wave should wait until a card is selected")

	main.queue_free()
	print("Wave tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)

