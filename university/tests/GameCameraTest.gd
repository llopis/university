extends GdUnitTestSuite
## The camera's own rules: limits and wrapping. Built outside the scene tree.

const Epsilon: float = 0.001


func _camera() -> GameCamera:
	return auto_free(GameCamera.new()) as GameCamera


func test_target_is_clamped_to_the_campus() -> void:
	var camera: GameCamera = _camera()
	var bounds: Rect2 = Campus.bounds()
	camera.setTarget(bounds.end * 2.0)
	assert_float(camera.target().x).is_equal_approx(bounds.end.x, Epsilon)
	assert_float(camera.target().z).is_equal_approx(bounds.end.y, Epsilon)


func test_zoom_is_clamped_to_its_range() -> void:
	var camera: GameCamera = _camera()
	camera.setZoom(GameCamera.ZoomMax * 2.0)
	assert_float(camera.distance()).is_equal_approx(GameCamera.ZoomMax, Epsilon)
	camera.setZoom(0.0)
	assert_float(camera.distance()).is_equal_approx(GameCamera.ZoomMin, Epsilon)


func test_yaw_wraps_into_one_turn() -> void:
	var camera: GameCamera = _camera()
	camera.setYaw(GameCamera.FullTurn + 30.0)
	assert_float(camera.yaw()).is_equal_approx(30.0, Epsilon)


func test_camera_stays_at_its_distance_from_the_target() -> void:
	var camera: GameCamera = _camera()
	camera.setTarget(Vector2(10.0, -20.0))
	camera.setZoom(GameCamera.ZoomMin)
	assert_float(camera.position.distance_to(camera.target())).is_equal_approx(GameCamera.ZoomMin, Epsilon)


func test_every_move_announces_itself() -> void:
	var camera: GameCamera = _camera()
	var moves: Array[int] = []
	camera.ViewMoved.connect(func() -> void: moves.append(1))
	camera.setTarget(Vector2(5.0, 5.0))
	camera.setYaw(10.0)
	camera.setZoom(GameCamera.ZoomMin)
	assert_int(moves.size()).is_equal(3)
