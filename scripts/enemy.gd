extends Node2D
class_name Enemy

signal reached_goal(enemy: Enemy)

var path_points: PackedVector2Array = PackedVector2Array()
var speed := 120.0
var target_index := 1
var radius := 11.0
var color := Color("#60a5fa")
var reached := false

func setup(p_path_points: PackedVector2Array, p_speed: float = 120.0) -> void:
	path_points = p_path_points
	speed = p_speed
	target_index = 1
	reached = false
	if path_points.size() > 0:
		position = path_points[0]
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
	advance(delta)

func advance(delta: float) -> bool:
	if reached or path_points.size() < 2:
		return reached

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
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 24, Color("#dbeafe"), 2.0)