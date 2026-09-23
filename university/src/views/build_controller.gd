class_name BuildController
extends Node3D
## The one place input becomes commands on the campus. Holds the current tool:
## None (a click selects), Place (a ghost follows the cursor, a click builds
## and the tool stays armed) or Destroy (a click removes the building under
## the cursor). A right click or Esc puts the tool away; Esc with nothing to
## cancel asks for the game menu instead of quitting. Everything arrives
## through _unhandled_input, so a click on the UI never reaches the world.
## Sits above the camera in the scene so the camera sees a right release first
## and swallows it when it ended a pan: what still arrives here is a click.

signal ToolChanged
signal SelectionChanged(building: Building)
signal HoverChanged(building: Building)
## Esc found no tool to put away and no selection to clear: the game menu
## opens instead of the game quitting.
signal NothingToCancel

enum Tool { None, Place, Destroy }

# Degrees per second the ghost turns while a rotate key is held.
const RotateSpeedDegrees: float = 90.0

var activeTool: Tool = Tool.None
# The type being placed; null unless the tool is Place.
var placeInfo: BuildingInfo
var selected: Building
# The building the Destroy tool would remove on a click.
var hovered: Building

var _campus: Campus
var _camera: GameCamera
var _ghost: BuildingView
var _angle: float = 0.0
# Last known cursor position. Taken from events rather than polled, so
# synthetic events from the console work with the window hidden.
var _mouse: Vector2
var _hasMouse: bool = false


func setup(campus: Campus, camera: GameCamera) -> void:
	_campus = campus
	_camera = camera
	_campus.BuildingRemoved.connect(_onBuildingRemoved)


func angle() -> float:
	return _angle


func setAngle(radians: float) -> void:
	_angle = wrapf(radians, 0.0, TAU)


func armPlace(info: BuildingInfo) -> void:
	_setTool(Tool.Place, info)


func armDestroy() -> void:
	_setTool(Tool.Destroy, null)


func cancel() -> void:
	_setTool(Tool.None, null)


func _setTool(newTool: Tool, info: BuildingInfo) -> void:
	activeTool = newTool
	placeInfo = info
	if (activeTool != Tool.None):
		select(null)
	if (activeTool != Tool.Destroy):
		_setHovered(null)
	if (activeTool == Tool.Place and _ghost == null):
		_ghost = BuildingView.createGhost()
		_ghost.visible = false
		add_child(_ghost)
	elif (activeTool != Tool.Place and _ghost != null):
		_ghost.queue_free()
		_ghost = null
	ToolChanged.emit()


## Choosing a building puts any armed tool away: the two are never on at once.
func select(building: Building) -> void:
	if (building != null and activeTool != Tool.None):
		cancel()
	if (building == selected):
		return
	selected = building
	SelectionChanged.emit(selected)


func _setHovered(building: Building) -> void:
	if (building == hovered):
		return
	hovered = building
	HoverChanged.emit(hovered)


## Builds the armed type at a ground point with the current angle. Null when
## nothing is armed or the campus refuses the spot. The tool stays armed.
func placeAt(point: Vector2) -> Building:
	if (activeTool != Tool.Place):
		return null
	return _campus.place(placeInfo, point, _angle)


func _onBuildingRemoved(building: Building) -> void:
	if (building == selected):
		select(null)
	if (building == hovered):
		_setHovered(null)


# Per frame rather than per mouse event: the camera can move the world under a
# still cursor, and the rotate keys are held.
func _process(dt: float) -> void:
	if (activeTool == Tool.Place):
		var turn: float = Input.get_axis("RotateLeft", "RotateRight")
		if (turn != 0.0):
			setAngle(_angle + turn * deg_to_rad(RotateSpeedDegrees) * dt)
		_updateGhost()
	elif (activeTool == Tool.Destroy):
		_setHovered(_pick(_mouse) if (_hasMouse) else null)


## The ground point under the cursor as a state position, or null when there is
## no cursor yet or the ray misses the ground plane.
func _groundUnderCursor() -> Variant:
	if (not _hasMouse):
		return null
	var point: Variant = _camera.groundPoint(_mouse)
	if (point == null):
		return null
	var ground: Vector3 = point
	return Vector2(ground.x, ground.z)


func _updateGhost() -> void:
	var point: Variant = _groundUnderCursor()
	_ghost.visible = (point != null)
	if (point == null):
		return
	var at: Vector2 = point
	_ghost.showRect(Building.rectFor(placeInfo, at, _angle))
	_ghost.setValid(_campus.canBuild(placeInfo, at, _angle))


func _pick(screen: Vector2) -> Building:
	return _campus.pick(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen))


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if (motion != null):
		_mouse = motion.position
		_hasMouse = true
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if (mb != null):
		_mouse = mb.position
		_hasMouse = true
		if (mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
			_leftClick()
		elif (mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and activeTool != Tool.None):
			# A release the camera did not swallow: a click, not the end of a pan.
			cancel()
		return
	if (event.is_action_pressed("ExitGame")):
		if (activeTool != Tool.None):
			cancel()
		elif (selected != null):
			select(null)
		else:
			NothingToCancel.emit()
		if (is_inside_tree()):
			get_viewport().set_input_as_handled()


func _leftClick() -> void:
	match activeTool:
		Tool.Place:
			var point: Variant = _groundUnderCursor()
			if (point != null):
				var at: Vector2 = point
				placeAt(at)
		Tool.Destroy:
			var target: Building = _pick(_mouse)
			if (target != null):
				_campus.destroy(target)
		_:
			select(_pick(_mouse))
