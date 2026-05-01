extends SceneTree

const CameraRig3DScript := preload("res://scripts/camera_rig_3d.gd")

func _initialize() -> void:
	var rig = CameraRig3DScript.new()
	get_root().add_child(rig)
	await process_frame

	rig.focus_on(Vector3.ZERO)
	rig.configure_focus_bounds(Vector3.ZERO, Vector3(16, 0, 9), 2.0)

	rig.global_position = Vector3(100, 0, -100)
	rig.clamp_to_focus_bounds()
	_assert_equal(rig.global_position, Vector3(10, 0, -6.5), "camera focus should clamp to board bounds plus margin")

	rig.yaw_degrees = 135.0
	rig.camera.size = 7.0
	rig.global_position = Vector3(3, 0, 2)
	rig.reset_home()
	_assert_equal(rig.global_position, Vector3.ZERO, "camera home should return to board center")
	_assert_equal(rig.yaw_degrees, 45.0, "camera home should restore diorama yaw")
	_assert_equal(rig.camera.size, rig.default_ortho_size, "camera home should restore default zoom")
	_assert_equal(rig.min_ortho_size, 7.0, "camera min zoom should stay constrained for defense readability")
	_assert_equal(rig.max_ortho_size, 14.0, "camera max zoom should stay constrained for defense readability")

	rig.queue_free()
	print("Camera rig 3D tests passed")
	quit(0)

func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("%s. Expected %s, got %s" % [message, expected, actual])
		quit(1)
