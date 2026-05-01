extends Node2D
class_name Enemy

signal reached_goal(enemy: Enemy)
signal died(enemy: Enemy)

var path_points: PackedVector2Array = PackedVector2Array()
var speed := 120.0
var target_index := 1
var radius := 11.0
var color := Color("#60a5fa")
var body_color := Color("#60a5fa")
var belly_color := Color("#bfdbfe")
var eye_color := Color("#0f172a")
var horn_color := Color("#e0f2fe")
var shadow_color := Color(0, 0, 0, 0.28)
var outline_color := Color("#dbeafe")
var variant := "crawler"
var rank := 1
var reached := false
var dead := false
var max_health := 30.0
var health := 30.0
var bob_time := 0.0
var hit_flash := 0.0
var hit_jolt := 0.0

func setup(p_path_points: PackedVector2Array, p_speed: float = 120.0) -> void:
	path_points = p_path_points
	speed = p_speed
	target_index = 1
	reached = false
	dead = false
	health = max_health
	bob_time = 0.0
	hit_flash = 0.0
	hit_jolt = 0.0
	if path_points.size() > 0:
		position = path_points[0]
	queue_redraw()

func configure_visuals(p_variant: String, p_rank: int = 1) -> void:
	variant = p_variant
	rank = maxi(p_rank, 1)
	match variant:
		"runner":
			radius = 9.0
			body_color = Color("#a3e635")
			belly_color = Color("#ecfccb")
			outline_color = Color("#bef264")
			horn_color = Color("#f7fee7")
		"brute":
			radius = 14.0
			body_color = Color("#fb7185")
			belly_color = Color("#ffe4e6")
			outline_color = Color("#fecdd3")
			horn_color = Color("#fff1f2")
		_:
			radius = 11.0
			body_color = Color("#60a5fa")
			belly_color = Color("#bfdbfe")
			outline_color = Color("#dbeafe")
			horn_color = Color("#e0f2fe")
	color = body_color
	queue_redraw()

func update_path_preserving_position(p_path_points: PackedVector2Array) -> bool:
	if p_path_points.size() < 2:
		return false
	path_points = p_path_points
	path_points[0] = position
	target_index = 1
	reached = false
	queue_redraw()
	return true

func _process(delta: float) -> void:
	hit_flash = maxf(hit_flash - delta, 0.0)
	hit_jolt = maxf(hit_jolt - delta * 5.0, 0.0)
	advance(delta)

func take_damage(amount: float) -> bool:
	if dead or reached:
		return false
	health = maxf(health - amount, 0.0)
	hit_flash = 0.16
	hit_jolt = minf(hit_jolt + 0.55, 1.0)
	queue_redraw()
	if health <= 0.0:
		dead = true
		died.emit(self)
		return true
	return false

func advance(delta: float) -> bool:
	if dead or reached or path_points.size() < 2:
		return reached

	bob_time += delta * speed * 0.035
	var remaining_distance := speed * delta
	while remaining_distance > 0.0 and not reached:
		var target := path_points[target_index]
		var to_target := target - position
		var distance := to_target.length()

		if distance <= remaining_distance:
			position = target
			remaining_distance -= distance
			target_index += 1
			if target_index >= path_points.size():
				reached = true
				reached_goal.emit(self)
		else:
			position += to_target.normalized() * remaining_distance
			remaining_distance = 0.0

	queue_redraw()
	return reached

func _draw() -> void:
	var bob := sin(bob_time) * 1.2
	var hit_shake := Vector2(sin(bob_time * 5.0) * hit_jolt * 4.0, -hit_jolt * 2.0)
	var body_offset := Vector2(0, bob) + hit_shake
	var facing := Vector2.RIGHT
	if path_points.size() > target_index:
		var to_target := path_points[target_index] - position
		if to_target.length() > 0.01:
			facing = to_target.normalized()
	var side := signf(facing.x)
	if side == 0.0:
		side = 1.0

	_draw_filled_ellipse(Rect2(Vector2(-radius * 1.05, radius * 0.35), Vector2(radius * 2.1, radius * 0.75)), shadow_color)
	_draw_monster_body(body_offset, side)
	if hit_flash > 0.0:
		draw_arc(body_offset, radius + 4.0 + hit_flash * 12.0, 0.0, TAU, 28, Color(0.996, 0.953, 0.780, 0.85), 3.0)
		draw_circle(body_offset + Vector2(side * radius * 0.55, -radius * 0.2), 4.0 + hit_flash * 14.0, Color(0.992, 0.902, 0.541, 0.8))
	var health_ratio: float = clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-radius, -radius - 8.0), Vector2(radius * 2.0, 3.0)), Color("#1e293b"), true)
	draw_rect(Rect2(Vector2(-radius, -radius - 8.0), Vector2(radius * 2.0 * health_ratio, 3.0)), Color("#22c55e"), true)

func _draw_monster_body(offset: Vector2, side: float) -> void:
	match variant:
		"runner":
			_draw_runner(offset, side)
		"brute":
			_draw_brute(offset, side)
		_:
			_draw_crawler(offset, side)

func _draw_crawler(offset: Vector2, side: float) -> void:
	var body_rect := Rect2(offset + Vector2(-radius, -radius * 0.65), Vector2(radius * 2.0, radius * 1.45))
	_draw_filled_ellipse(body_rect, body_color)
	draw_arc(offset + Vector2.ZERO, radius + 2.0, 0.0, TAU, 24, outline_color, 2.0)
	_draw_filled_ellipse(Rect2(offset + Vector2(-radius * 0.48, -radius * 0.2), Vector2(radius * 0.96, radius * 0.78)), belly_color)
	_draw_face(offset, side, radius * 0.72)
	for leg in [-0.65, -0.25, 0.25, 0.65]:
		draw_line(offset + Vector2(leg * radius, radius * 0.3), offset + Vector2(leg * radius + side * 5.0, radius * 0.8), outline_color, 2.0)

func _draw_runner(offset: Vector2, side: float) -> void:
	var points := PackedVector2Array([
		offset + Vector2(-radius * 0.9, radius * 0.55),
		offset + Vector2(-radius * 0.5, -radius * 0.55),
		offset + Vector2(radius * 0.65, -radius * 0.7),
		offset + Vector2(radius * 1.05, radius * 0.15),
		offset + Vector2(radius * 0.25, radius * 0.75),
	])
	draw_colored_polygon(points, body_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]), outline_color, 2.0)
	draw_colored_polygon(PackedVector2Array([
		offset + Vector2(-radius * 0.25, -radius * 0.55),
		offset + Vector2(radius * 0.15, -radius * 1.15),
		offset + Vector2(radius * 0.35, -radius * 0.45),
	]), horn_color)
	_draw_face(offset + Vector2(side * 2.0, -1.0), side, radius * 0.68)
	draw_line(offset + Vector2(-radius * 0.55, radius * 0.45), offset + Vector2(-radius * 1.0, radius * 0.95), outline_color, 2.0)
	draw_line(offset + Vector2(radius * 0.35, radius * 0.45), offset + Vector2(radius * 0.95, radius * 0.9), outline_color, 2.0)

func _draw_brute(offset: Vector2, side: float) -> void:
	var top := PackedVector2Array([
		offset + Vector2(-radius * 1.05, radius * 0.25),
		offset + Vector2(-radius * 0.65, -radius * 0.8),
		offset + Vector2(radius * 0.55, -radius * 0.92),
		offset + Vector2(radius * 1.1, radius * 0.2),
		offset + Vector2(radius * 0.55, radius * 0.85),
		offset + Vector2(-radius * 0.55, radius * 0.85),
	])
	draw_colored_polygon(top, body_color)
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[4], top[5], top[0]]), outline_color, 2.0)
	draw_colored_polygon(PackedVector2Array([
		offset + Vector2(-radius * 0.72, -radius * 0.7),
		offset + Vector2(-radius * 1.1, -radius * 1.2),
		offset + Vector2(-radius * 0.35, -radius * 0.88),
	]), horn_color)
	draw_colored_polygon(PackedVector2Array([
		offset + Vector2(radius * 0.5, -radius * 0.78),
		offset + Vector2(radius * 1.0, -radius * 1.18),
		offset + Vector2(radius * 0.2, -radius * 0.92),
	]), horn_color)
	_draw_filled_ellipse(Rect2(offset + Vector2(-radius * 0.58, -radius * 0.1), Vector2(radius * 1.16, radius * 0.7)), belly_color)
	_draw_face(offset + Vector2(side * 2.0, -2.0), side, radius * 0.75)

func _draw_face(offset: Vector2, side: float, scale: float) -> void:
	var eye_y := -scale * 0.22
	var front_eye := offset + Vector2(side * scale * 0.34, eye_y)
	var back_eye := offset + Vector2(-side * scale * 0.16, eye_y - 1.0)
	draw_circle(back_eye, 2.7, eye_color)
	draw_circle(front_eye, 3.2, eye_color)
	draw_circle(front_eye + Vector2(0.8, -0.8), 1.0, Color("#f8fafc"))
	draw_line(offset + Vector2(-side * scale * 0.22, scale * 0.25), offset + Vector2(side * scale * 0.42, scale * 0.28), eye_color, 1.8)

func _draw_filled_ellipse(rect: Rect2, fill_color: Color, segments: int = 18) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x := rect.size.x * 0.5
	var radius_y := rect.size.y * 0.5
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, fill_color)
