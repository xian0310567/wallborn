extends SceneTree

const MainScript := preload("res://scripts/main.gd")

func _initialize() -> void:
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame

	main._present_card_choices()
	_assert_true(main.awaiting_card_choice, "card choice state should be active")
	_assert_equal(main.card_choices.size(), 3, "three cards should be offered")
	_assert_equal(main.card_buttons.size(), 3, "three card buttons should be created")
	_assert_true(not main.start_wave(), "wave should not start while waiting for card choice")

	var base_unit := main._create_defense_unit()
	main.defense_units[Vector2i(2, 4)] = base_unit
	var base_damage: float = float(base_unit["damage"])
	_assert_true(main.select_card(0), "valid card selection should succeed")
	_assert_true(not main.awaiting_card_choice, "card choice should close after selection")
	_assert_equal(main.card_choices.size(), 0, "card choices should clear after selection")
	_assert_equal(main.card_buttons.size(), 0, "card buttons should clear after selection")
	_assert_equal(main.defense_damage_bonus, 5.0, "damage card should increase future defense damage bonus")
	var updated_unit: Dictionary = main.defense_units[Vector2i(2, 4)]
	_assert_equal(float(updated_unit["damage"]), base_damage + 5.0, "damage card should update existing defense damage")
	_assert_true(main.start_wave(), "wave should start after card choice")

	main.queue_free()
	print("Card tests passed")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)
