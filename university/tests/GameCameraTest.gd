extends GdUnitTestSuite
## The camera's own rules: limits and wrapping. Built outside the scene tree.

const Epsilon: float = 0.001
# Pixels of cursor travel, well past GameCamera.DragThreshold.
const LongMove: float = GameCamera.DragThreshold * 4.0
const ScreenCenter: Vector2 = Vector2(500.0, 500.0)


func _camera() -> GameCamera:
	return auto_free(GameCamera.new()) as GameCamera


## A camera inside the test tree, so ray projection has a viewport. Drag tests
## need it; the pure-maths ones above do not.
func _treeCamera() -> GameCamera:
	var camera: GameCamera = GameCamera.new()
	add_child(camera)
	return auto_free(camera) as GameCamera


static func _button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = ScreenCenter
	return event


static func _motion(dx: float) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = Vector2(dx, 0.0)
	event.position = ScreenCenter + event.relative
	return event


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


func test_a_second_drag_button_mid_drag_does_not_steal_the_drag() -> void:
	# Chording middle onto a right-drag must keep panning, not start turning:
	# otherwise the right release is no longer the one the camera swallows and
	# it reaches the controller as a click.
	var camera: GameCamera = _treeCamera()
	camera._unhandled_input(_button(MOUSE_BUTTON_RIGHT, true))
	camera._unhandled_input(_motion(LongMove))
	var panned: Vector3 = camera.target()
	var turned: float = camera.yaw()
	camera._unhandled_input(_button(MOUSE_BUTTON_MIDDLE, true))
	camera._unhandled_input(_motion(LongMove))
	assert_float(camera.yaw()).is_equal_approx(turned, Epsilon)
	assert_that(camera.target()).is_not_equal(panned)


func test_a_drag_swallows_its_own_release_even_after_a_chord() -> void:
	var camera: GameCamera = _treeCamera()
	camera._unhandled_input(_button(MOUSE_BUTTON_RIGHT, true))
	camera._unhandled_input(_motion(LongMove))
	camera._unhandled_input(_button(MOUSE_BUTTON_MIDDLE, true))
	camera._unhandled_input(_button(MOUSE_BUTTON_MIDDLE, false))
	camera._unhandled_input(_button(MOUSE_BUTTON_RIGHT, false))
	assert_bool(camera.get_viewport().is_input_handled()).is_true()
