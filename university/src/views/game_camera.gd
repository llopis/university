class_name GameCamera
extends Camera3D
## Camera orbiting a point on the ground at a fixed pitch. Zoom is distance;
## pan moves the target, which stays on the campus. Right-drag pans, middle-drag
## turns about the vertical axis, the wheel zooms; WASD/arrows, Q/E and [ ] do
## the same from the keyboard. Pitch and FOV are constants so the look can be tuned.

## The view moved, so anything anchored to a screen point now sits over
## different ground.
signal ViewMoved

const PitchDegrees: float = 50.0
const StartYawDegrees: float = 45.0
# Degrees the camera turns per pixel of middle-drag. Negate if it feels inverted.
const TurnDegreesPerPixel: float = 0.25
const FullTurn: float = 360.0
const Fov: float = 30.0
# Zoom is the distance from target to camera, in metres.
const ZoomMin: float = 40.0
const ZoomMax: float = 600.0
const StartZoom: float = 200.0
const ZoomStep: float = 1.15
# Keyboard pan, in distances per second: scaled by the current distance so it
# covers the same fraction of the screen at any zoom.
const PanSpeed: float = 0.5
# How far the cursor must travel with a drag button down before the press
# counts as a drag rather than a click. Under it, a right press stays a click.
const DragThreshold: float = 5.0
# Trackpad two-finger scroll arrives as a stream of small deltas; this scales
# delta into exponent space. Negate if zooming feels inverted on a trackpad.
const GestureZoomGain: float = 0.25
# Keyboard turn, in degrees per second while the key is held.
const TurnSpeed: float = 90.0
# Keyboard zoom, in ZoomStep multiples per second while the key is held.
const ZoomSpeed: float = 4.0
const Ground: Plane = Plane(Vector3.UP, 0.0)

## The Hud turns this off while an overlay covers the view, so its keys stop
## panning, turning or zooming the camera underneath it.
var keysEnabled: bool = true

var _target: Vector3 = Vector3.ZERO
var _distance: float = StartZoom
# Degrees about the vertical axis, in [0, FullTurn).
var _yaw: float = StartYawDegrees
# Which button armed the current drag, MOUSE_BUTTON_NONE when idle.
var _dragButton: MouseButton = MOUSE_BUTTON_NONE
# Cursor distance since the press, against DragThreshold.
var _dragTravel: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	fov = Fov
	_applyTransform()


func target() -> Vector3:
	return _target


func distance() -> float:
	return _distance


func yaw() -> float:
	return _yaw


## Moves the target to ground point (x, z), kept on the campus. Every pan
## goes through here, so the limit lives in one place.
func setTarget(point: Vector2) -> void:
	var bounds: Rect2 = Campus.bounds()
	_target = Vector3(
		clampf(point.x, bounds.position.x, bounds.end.x),
		0.0,
		clampf(point.y, bounds.position.y, bounds.end.y))
	_applyTransform()


func setYaw(degrees: float) -> void:
	_yaw = wrapf(degrees, 0.0, FullTurn)
	_applyTransform()


func setZoom(dist: float) -> void:
	_distance = clampf(dist, ZoomMin, ZoomMax)
	_applyTransform()


## Vector from the target to the camera: lifted by pitch, then turned by yaw
## about the vertical axis.
static func offset(pitchDegrees: float, yawDegrees: float, dist: float) -> Vector3:
	var pitch: float = deg_to_rad(pitchDegrees)
	var lifted: Vector3 = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	return lifted.rotated(Vector3.UP, deg_to_rad(yawDegrees))


## Zoom multiplier for one trackpad pan-gesture step. Exponential so that
## scrolling back undoes the zoom exactly.
static func gestureZoomFactor(deltaY: float) -> float:
	return pow(ZoomStep, -deltaY * GestureZoomGain)


## The one place the camera's transform is written, which is why the moved
## signal goes out from here.
func _applyTransform() -> void:
	var off: Vector3 = GameCamera.offset(PitchDegrees, _yaw, _distance)
	transform = Transform3D(Basis.looking_at(-off, Vector3.UP), _target + off)
	ViewMoved.emit()


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if (mb != null):
		if (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE):
			_updateDrag(mb)
		elif (mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP):
			setZoom(_distance / ZoomStep)
		elif (mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			setZoom(_distance * ZoomStep)
		return
	var gesture: InputEventPanGesture = event as InputEventPanGesture
	if (gesture != null):
		# Trackpad two-finger scroll. macOS routes any scroll carrying a gesture
		# phase here and emits NO wheel events for it.
		setZoom(_distance * GameCamera.gestureZoomFactor(gesture.delta.y))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if (motion == null or _dragButton == MOUSE_BUTTON_NONE):
		return
	_dragTravel += motion.relative.length()
	if (_dragTravel > DragThreshold):
		_dragging = true
	if (not _dragging):
		return
	if (_dragButton == MOUSE_BUTTON_MIDDLE):
		setYaw(_yaw + motion.relative.x * TurnDegreesPerPixel)
	else:
		_dragGround(motion.position - motion.relative, motion.position)


## Arms a drag on press and ends it on release. A press only becomes a drag once
## the cursor clears DragThreshold, which keeps a short right press a click; a
## press that DID drag swallows its own release so no click fires from it.
func _updateDrag(mb: InputEventMouseButton) -> void:
	if (mb.pressed):
		# A second drag button pressed mid-drag is ignored: taking it over would
		# leave the first button's release unswallowed, and the controller would
		# read the end of a pan as a click.
		if (_dragButton == MOUSE_BUTTON_NONE):
			_dragButton = mb.button_index
			_dragTravel = 0.0
			_dragging = false
		return
	if (mb.button_index != _dragButton):
		return
	if (_dragging):
		get_viewport().set_input_as_handled()
	_dragButton = MOUSE_BUTTON_NONE
	_dragging = false


## Grab-the-world: the ground point that was under the cursor before the motion
## must be under it after, so the target moves by the opposite of the cursor's
## travel across the ground. Both points use the pre-move camera.
func _dragGround(fromScreen: Vector2, toScreen: Vector2) -> void:
	var before: Variant = groundPoint(fromScreen)
	var after: Variant = groundPoint(toScreen)
	if (before == null or after == null):
		return
	var beforePoint: Vector3 = before
	var afterPoint: Vector3 = after
	var moved: Vector3 = _target - (afterPoint - beforePoint)
	setTarget(Vector2(moved.x, moved.z))


## Ground point under a screen position, or null when the ray misses the ground plane.
func groundPoint(screen: Vector2) -> Variant:
	return Ground.intersects_ray(project_ray_origin(screen), project_ray_normal(screen))


func _process(dt: float) -> void:
	if (not keysEnabled):
		return
	_keyboardTurn(dt)
	_keyboardZoom(dt)
	var dir: Vector2 = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	if (dir == Vector2.ZERO):
		return
	# Screen-relative ground axes: the camera's right and forward, flattened.
	var right: Vector3 = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var forward: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var moved: Vector3 = _target + (right * dir.x - forward * dir.y) * PanSpeed * _distance * dt
	setTarget(Vector2(moved.x, moved.z))


func _keyboardTurn(dt: float) -> void:
	var turn: float = Input.get_axis("TurnLeft", "TurnRight")
	if (turn != 0.0):
		setYaw(_yaw + turn * TurnSpeed * dt)


## Zoom is exponential, like the wheel: ZoomSpeed steps a second, each step
## the same ZoomStep factor a wheel click applies.
func _keyboardZoom(dt: float) -> void:
	var zoom: float = Input.get_axis("ZoomOut", "ZoomIn")
	if (zoom != 0.0):
		setZoom(_distance * pow(ZoomStep, -zoom * ZoomSpeed * dt))
