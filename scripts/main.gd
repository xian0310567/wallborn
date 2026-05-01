extends Node2D

const WallbornGridScript := preload("res://scripts/wallborn_grid.gd")
const WallbornGridViewScript := preload("res://scripts/wallborn_grid_view.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const GRID_SIZE := Vector2i(16, 9)
const CELL_SIZE := 56
const GRID_ORIGIN := Vector2(192, 128)
const SCREEN_SIZE := Vector2(1280, 720)

var grid := WallbornGridScript.new(GRID_SIZE, CELL_SIZE)
var grid_view = WallbornGridViewScript.top_down(GRID_ORIGIN, CELL_SIZE)
var path: Array[Vector2i] = []
var enemies: Array[Node] = []
var defense_units: Dictionary = {}
var attack_effects: Array[Dictionary] = []

var wave_index := 0
var wave_active := false
var wave_enemies_to_spawn := 0
var wave_spawned_count := 0
var wave_resolved_count := 0
var wave_spawn_timer := 0.0
var wave_spawn_interval := 0.75
var waves_cleared := 0
var start_wave_button: Button = null
var card_buttons: Array[Button] = []
var card_choices: Array[Dictionary] = []
var awaiting_card_choice := false
var defense_damage_bonus := 0.0
var defense_range_bonus := 0.0
var defense_cooldown_multiplier := 1.0

func _ready() -> void:
	path = grid.find_path()
	_create_wave_button()
	print("Wallborn boot OK")
	print("Grid ready: %sx%s cells, cell_size=%s" % [grid.size.x, grid.size.y, grid.cell_size])
	print("Path ready: %s cells" % path.size())
	queue_redraw()

func _process(delta: float) -> void:
	_update_wave(delta)
	_update_defenses(delta)
	_update_attack_effects(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_place_defense_at(event.position)

func _create_wave_button() -> void:
	start_wave_button = Button.new()
	start_wave_button.text = "START WAVE"
	start_wave_button.position = Vector2(1040, 24)
	start_wave_button.size = Vector2(176, 44)
	start_wave_button.add_theme_font_size_override("font_size", 18)
	start_wave_button.pressed.connect(start_wave)
	add_child(start_wave_button)

func _set_wave_button_enabled(enabled: bool) -> void:
	if start_wave_button != null:
		start_wave_button.disabled = not enabled

func start_wave() -> bool:
	if wave_active or awaiting_card_choice:
		return false
	if path.size() < 2:
		push_warning("Cannot start wave: no valid path")
		return false
	wave_index += 1
	wave_active = true
	wave_enemies_to_spawn = 4 + wave_index
	wave_spawned_count = 0
	wave_resolved_count = 0
	wave_spawn_timer = 0.0
	_set_wave_button_enabled(false)
	print("Wave %s started: %s enemies" % [wave_index, wave_enemies_to_spawn])
	queue_redraw()
	return true

func _update_wave(delta: float) -> void:
	if not wave_active:
		return
	if wave_spawned_count >= wave_enemies_to_spawn:
		return
	wave_spawn_timer -= delta
	if wave_spawn_timer <= 0.0:
		if spawn_enemy():
			wave_spawned_count += 1
			wave_spawn_timer = wave_spawn_interval
		_check_wave_completed()

func _record_enemy_resolved() -> void:
	if wave_active:
		wave_resolved_count += 1
		_check_wave_completed()

func _check_wave_completed() -> void:
	if not wave_active:
		return
	if wave_spawned_count >= wave_enemies_to_spawn and wave_resolved_count >= wave_enemies_to_spawn:
		wave_active = false
		waves_cleared += 1
		print("Wave %s cleared" % wave_index)
		_present_card_choices()
		queue_redraw()

func _get_card_pool() -> Array[Dictionary]:
	return [
		{"title": "Sharper Walls", "description": "+5 defense damage", "effect": "damage", "amount": 5.0},
		{"title": "Longer Reach", "description": "+24 defense range", "effect": "range", "amount": 24.0},
		{"title": "Faster Fire", "description": "-10% attack cooldown", "effect": "cooldown", "amount": 0.9},
	]

func _present_card_choices() -> void:
	awaiting_card_choice = true
	_set_wave_button_enabled(false)
	_clear_card_buttons()
	card_choices = _get_card_pool()
	for i in range(card_choices.size()):
		var card: Dictionary = card_choices[i]
		var button := Button.new()
		button.text = "%s
%s" % [card["title"], card["description"]]
		button.position = Vector2(64 + i * 190, 520)
		button.size = Vector2(180, 72)
		button.pressed.connect(select_card.bind(i))
		card_buttons.append(button)
		add_child(button)
	print("Card choices ready")

func _clear_card_buttons() -> void:
	for button in card_buttons:
		if is_instance_valid(button):
			button.queue_free()
	card_buttons.clear()

func select_card(index: int) -> bool:
	if not awaiting_card_choice:
		return false
	if index < 0 or index >= card_choices.size():
		return false
	var card: Dictionary = card_choices[index]
	_apply_card(card)
	awaiting_card_choice = false
	_clear_card_buttons()
	card_choices.clear()
	_set_wave_button_enabled(true)
	print("Card selected: %s" % card["title"])
	queue_redraw()
	return true

func _apply_card(card: Dictionary) -> void:
	match String(card["effect"]):
		"damage":
			defense_damage_bonus += float(card["amount"])
			for cell in defense_units.keys():
				var unit: Dictionary = defense_units[cell]
				unit["damage"] = float(unit["damage"]) + float(card["amount"])
				defense_units[cell] = unit
		"range":
			defense_range_bonus += float(card["amount"])
			for cell in defense_units.keys():
				var unit: Dictionary = defense_units[cell]
				unit["range"] = float(unit["range"]) + float(card["amount"])
				defense_units[cell] = unit
		"cooldown":
			defense_cooldown_multiplier *= float(card["amount"])
			for cell in defense_units.keys():
				var unit: Dictionary = defense_units[cell]
				unit["cooldown_duration"] = float(unit["cooldown_duration"]) * float(card["amount"])
				defense_units[cell] = unit

func try_place_defense_at(world_pos: Vector2) -> bool:
	var cell: Vector2i = grid_view.world_to_cell(world_pos)
	if not grid.try_set_blocked_preserving_path(cell):
		print("Defense placement rejected: %s" % cell)
		return false
	defense_units[cell] = _create_defense_unit()
	path = grid.find_path()
	_repath_enemies()
	print("Defense placed at %s. New path length: %s" % [cell, path.size()])
	queue_redraw()
	return true

func spawn_enemy() -> bool:
	var path_points := _path_to_world_points(path)
	if path_points.size() < 2:
		push_warning("Cannot spawn enemy: no valid path")
		return false
	var enemy = EnemyScript.new()
	enemy.setup(path_points, 120.0)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	add_child(enemy)
	print("Enemy spawned")
	return true

func _on_enemy_reached_goal(enemy: Node) -> void:
	print("Enemy reached goal")
	enemies.erase(enemy)
	_record_enemy_resolved()
	enemy.queue_free()

func _on_enemy_died(enemy: Node) -> void:
	print("Enemy defeated")
	enemies.erase(enemy)
	_record_enemy_resolved()
	enemy.queue_free()

func _create_defense_unit() -> Dictionary:
	return {
		"range": CELL_SIZE * 2.5 + defense_range_bonus,
		"damage": 10.0 + defense_damage_bonus,
		"cooldown": 0.0,
		"cooldown_duration": 0.6 * defense_cooldown_multiplier,
	}

func _update_defenses(delta: float) -> void:
	if defense_units.is_empty() or enemies.is_empty():
		return
	var did_attack := false
	for cell in defense_units.keys():
		var unit: Dictionary = defense_units[cell]
		var cooldown: float = maxf(float(unit.get("cooldown", 0.0)) - delta, 0.0)
		if cooldown <= 0.0:
			var target: Node = _find_target_for_defense(cell, float(unit["range"]))
			if target != null and target.has_method("take_damage"):
				var from_pos: Vector2 = grid_view.cell_to_world(cell)
				var to_pos: Vector2 = target.position
				target.take_damage(float(unit["damage"]))
				attack_effects.append({"from": from_pos, "to": to_pos, "time": 0.12})
				cooldown = float(unit["cooldown_duration"])
				did_attack = true
		unit["cooldown"] = cooldown
		defense_units[cell] = unit
	if did_attack:
		queue_redraw()

func _find_target_for_defense(cell: Vector2i, attack_range: float) -> Node:
	var origin: Vector2 = grid_view.cell_to_world(cell)
	var best_enemy: Node = null
	var best_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = origin.distance_to(enemy.position)
		if distance <= attack_range and distance < best_distance:
			best_enemy = enemy
			best_distance = distance
	return best_enemy

func _update_attack_effects(delta: float) -> void:
	if attack_effects.is_empty():
		return
	var remaining_effects: Array[Dictionary] = []
	for effect in attack_effects:
		var next_time: float = float(effect["time"]) - delta
		if next_time > 0.0:
			effect["time"] = next_time
			remaining_effects.append(effect)
	attack_effects = remaining_effects
	queue_redraw()

func _repath_enemies() -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_cell: Vector2i = grid_view.world_to_cell(enemy.position)
		var enemy_path: Array[Vector2i] = grid.find_path(enemy_cell, grid.goal_cell)
		if enemy_path.size() < 2:
			push_warning("Cannot repath enemy from cell %s" % enemy_cell)
			continue
		if enemy.has_method("update_path_preserving_position"):
			enemy.update_path_preserving_position(_path_to_world_points(enemy_path))

func _path_to_world_points(cell_path: Array[Vector2i]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in cell_path:
		points.append(grid_view.cell_to_world(cell))
	return points

func _draw() -> void:
	_draw_background()
	_draw_board_frame()
	_draw_cells()
	_draw_path()
	_draw_attack_effects()
	_draw_hud()
	_draw_card_overlay()
	_draw_grid_lines()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("#0b1020"), true)
	draw_rect(Rect2(Vector2(0, 0), Vector2(SCREEN_SIZE.x, 88)), Color("#111827"), true)
	draw_line(Vector2(0, 88), Vector2(SCREEN_SIZE.x, 88), Color("#334155"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(64, 48), "WALLBORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#f8fafc"))
	draw_string(ThemeDB.fallback_font, Vector2(64, 72), "Roguelike wall-defense prototype", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#94a3b8"))

func _draw_board_frame() -> void:
	var board_size := Vector2(grid.size.x * CELL_SIZE, grid.size.y * CELL_SIZE)
	var frame := Rect2(GRID_ORIGIN - Vector2(18, 18), board_size + Vector2(36, 36))
	draw_rect(frame, Color("#111827"), true)
	draw_rect(frame, Color("#475569"), false, 2.0)
	var shadow := Rect2(frame.position + Vector2(8, 8), frame.size)
	draw_rect(shadow, Color(0, 0, 0, 0.22), true)

func _draw_cells() -> void:
	for cell in grid_view.get_cells_in_draw_order(grid.size):
		var corners: PackedVector2Array = grid_view.cell_corners(cell)
		var fill := Color("#182033")
		match grid.get_cell_type(cell):
			grid.CELL_START:
				fill = Color("#14532d")
			grid.CELL_GOAL:
				fill = Color("#7f1d1d")
			grid.CELL_BLOCKED:
				fill = Color("#475569")
		draw_colored_polygon(corners, fill)
		draw_colored_polygon(PackedVector2Array([corners[1], corners[2], corners[2] + Vector2(0, 5), corners[1] + Vector2(0, 5)]), Color(0, 0, 0, 0.18))
		draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), Color("#334155"), 1.0)
		if grid.get_cell_type(cell) == grid.CELL_START:
			_draw_spawn_gate(cell)
		elif grid.get_cell_type(cell) == grid.CELL_GOAL:
			_draw_core(cell)
		elif grid.get_cell_type(cell) == grid.CELL_BLOCKED:
			_draw_defense_unit(cell)

func _draw_spawn_gate(cell: Vector2i) -> void:
	var center: Vector2 = grid_view.cell_to_world(cell)
	draw_circle(center, 17.0, Color("#22c55e"))
	draw_arc(center, 23.0, 0.0, TAU, 32, Color("#bbf7d0"), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-12, 6), "IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#052e16"))

func _draw_core(cell: Vector2i) -> void:
	var center: Vector2 = grid_view.cell_to_world(cell)
	draw_circle(center, 19.0, Color("#ef4444"))
	draw_circle(center, 10.0, Color("#fee2e2"))
	draw_arc(center, 25.0, 0.0, TAU, 32, Color("#fecaca"), 3.0)

func _draw_defense_unit(cell: Vector2i) -> void:
	var center: Vector2 = grid_view.cell_to_world(cell)
	var half: float = minf(grid_view.basis_x.length(), grid_view.basis_y.length()) * 0.32
	var base := Rect2(center - Vector2(half, half * 0.55), Vector2(half * 2.0, half * 1.1))
	draw_rect(base, Color("#64748b"), true)
	draw_rect(base, Color("#cbd5e1"), false, 2.0)
	draw_rect(Rect2(center + Vector2(-5, -half - 8), Vector2(10, half + 10)), Color("#e2e8f0"), true)
	draw_circle(center + Vector2(0, -half - 10), 7.0, Color("#f97316"))

func _draw_attack_effects() -> void:
	for effect in attack_effects:
		draw_line(effect["from"], effect["to"], Color("#f97316"), 4.0)
		draw_circle(effect["to"], 5.0, Color("#fed7aa"))

func _draw_path() -> void:
	if path.size() < 2:
		return
	var points := _path_to_world_points(path)
	draw_polyline(points, Color("#facc15"), 4.0)
	for point in points:
		draw_circle(point, 5.0, Color("#fde68a"))

func _draw_hud() -> void:
	var status := "WAVE %s" % wave_index
	var detail := "Spawned %s/%s  |  Resolved %s/%s  |  Cleared %s" % [wave_spawned_count, wave_enemies_to_spawn, wave_resolved_count, wave_enemies_to_spawn, waves_cleared]
	if awaiting_card_choice:
		status = "WAVE CLEARED"
		detail = "Choose one upgrade card"
	elif not wave_active:
		status = "READY"
		detail = "Cleared %s waves. Build walls, then start the next wave." % waves_cleared
	draw_string(ThemeDB.fallback_font, Vector2(330, 42), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#f8fafc"))
	draw_string(ThemeDB.fallback_font, Vector2(330, 68), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#cbd5e1"))
	draw_string(ThemeDB.fallback_font, Vector2(64, 680), "Left click: place wall-turret   |   Goal: force reroutes, survive waves, pick upgrades", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#94a3b8"))

func _draw_card_overlay() -> void:
	if not awaiting_card_choice:
		return
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0, 0, 0, 0.52), true)
	draw_rect(Rect2(Vector2(300, 190), Vector2(680, 330)), Color("#111827"), true)
	draw_rect(Rect2(Vector2(300, 190), Vector2(680, 330)), Color("#facc15"), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(470, 245), "CHOOSE AN UPGRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#f8fafc"))

func _draw_grid_lines() -> void:
	# Cell outlines are drawn in _draw_cells(). Keeping this hook makes future
	# projection-specific overlays possible without coupling gameplay to rendering.
	pass
