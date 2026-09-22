class_name DebugCommands


const ScreenshotPath: String = "/tmp/university/screenshot.png"

# money's sentinel: no amount given, just print the balance.
const KeepMoney: int = -1

# save's and load's sentinel: no path given, use the quicksave.
const NoPath: String = ""

const ToolPlace: String = "place"
const ToolDestroy: String = "destroy"
const ToolNone: String = "none"
const NoSelection: int = -1

# Button names the mouse commands take.
const ButtonLeft: String = "left"
const ButtonRight: String = "right"
const ButtonMiddle: String = "middle"

# What the second argument of 'action' takes.
const ActionDown: String = "down"
const ActionUp: String = "up"
# A synthetic action is always fully pressed.
const FullStrength: float = 1.0

# The button a synthetic press left held, MOUSE_BUTTON_NONE when none is: it
# rides along on the moves that follow, the way a real drag does.
var _heldButton: MouseButton = MOUSE_BUTTON_NONE
# Where the last synthetic event put the cursor, so the next move can carry the
# travel since it — GameCamera adds up `relative` to tell a drag from a click.
var _mouse: Vector2 = Vector2.ZERO


func _init() -> void:
	LimboConsole.register_command(_screenshot, "screenshot", "Save a screenshot to %s." % ScreenshotPath)
	LimboConsole.register_command(_camera, "camera", "Look at ground point <x> <z> from <distance> metres at <yawDeg> degrees.")
	LimboConsole.register_command(_build, "build", "Place building type <id> at ground point <x> <z> (metres), turned <deg> degrees.")
	LimboConsole.register_command(_destroy, "destroy", "Destroy building <n> (index from 'buildings').")
	LimboConsole.register_command(_buildings, "buildings", "One line per building: index, type id, position, angle in degrees, construction status.")
	LimboConsole.register_command(_tool, "tool", "Arm a tool: a building type id to place it, 'destroy', or 'none'.")
	LimboConsole.register_command(_select, "select", "Select building <n> (index from 'buildings'); -1 clears the selection.")
	LimboConsole.register_command(_state, "state", "Print the armed tool, the ghost angle, the selected and hovered buildings, the camera, the time, the money and the university's name.")
	LimboConsole.register_command(_mouseDown, "mousedown", "Press a mouse button at design-space point <x> <y>; <button> is 'left' (default), 'right' or 'middle'.")
	LimboConsole.register_command(_mouseUp, "mouseup", "Release a mouse button at design-space point <x> <y>; <button> is 'left' (default), 'right' or 'middle'.")
	LimboConsole.register_command(_mouseMove, "mousemove", "Move the mouse to design-space point <x> <y>, carrying whichever button is held and the travel since the last synthetic event.")
	LimboConsole.register_command(_action, "action", "Press or release input action <name>: <state> is 'down' or 'up'.")
	LimboConsole.register_command(_pause, "pause", "Toggle pause.")
	LimboConsole.register_command(_speed, "speed", "Run at speed <n>: 1, 2 or 3 (the three transport speeds). Does not unpause.")
	LimboConsole.register_command(_money, "money", "Print the balance, or set it to <amount> dollars.")
	LimboConsole.register_command(_advance, "advance", "Step the sim to the start of the month <months> ahead, paused or not.")
	LimboConsole.register_command(_save, "save", "Save the game to [path] (the quicksave when none is given).")
	LimboConsole.register_command(_load, "load", "Load the game saved at [path] (the quicksave when none is given).")
	LimboConsole.register_command(_newGame, "newgame", "Start over from the start state.")
	# Lets the remote console reach the scene tree, e.g.
	# eval get_root().find_child("CampusView", true, false).
	LimboConsole.set_eval_base_instance(Engine.get_main_loop())


func _campusView() -> CampusView:
	var root: Window = (Engine.get_main_loop() as SceneTree).get_root()
	return root.find_child("CampusView", true, false) as CampusView


func _camera(x: float, z: float, dist: float, yawDegrees: float) -> void:
	var camera: GameCamera = _campusView().camera
	camera.setTarget(Vector2(x, z))
	camera.setZoom(dist)
	camera.setYaw(yawDegrees)
	LimboConsole.print_line("Camera at (%.1f, %.1f), %.1f m, yaw %.1f" % [camera.target().x, camera.target().z, camera.distance(), camera.yaw()])


func _screenshot() -> void:
	# A hidden window otherwise stops rendering, so the captured texture is stale.
	# Force a fresh frame before reading it back.
	RenderingServer.force_draw()
	var viewport: Viewport = (Engine.get_main_loop() as SceneTree).get_root()
	var image: Image = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ScreenshotPath.get_base_dir())
	image.save_png(ScreenshotPath)
	LimboConsole.print_line("Screenshot saved to %s" % ScreenshotPath)


func _gameState() -> GameState:
	return Global.gameState


func _campus() -> Campus:
	return _gameState().university.campus


func _finances() -> Finances:
	return _gameState().university.finances


func _buildingAt(index: int) -> Building:
	var buildings: Array[Building] = _campus().buildings
	if (index < 0 or index >= buildings.size()):
		LimboConsole.print_line("No building %d" % index)
		return null
	return buildings[index]


func _build(id: String, x: float, z: float, degrees: float) -> void:
	var info: BuildingInfo = Global.buildingDB.info(id)
	if (info == null):
		LimboConsole.print_line("Unknown building type '%s'" % id)
		return
	var building: Building = _campus().place(info, Vector2(x, z), deg_to_rad(degrees))
	LimboConsole.print_line("Placed %s" % id if (building != null) else "Refused: not free or out of bounds")


func _destroy(index: int) -> void:
	var building: Building = _buildingAt(index)
	if (building != null):
		_campus().destroy(building)
		LimboConsole.print_line("Destroyed %d" % index)


func _statusOf(building: Building) -> String:
	if (building.underConstruction):
		return "under construction, opens %s" % GameCalendar.label(building.opensAtMonth)
	return "open"


func _buildings() -> void:
	var buildings: Array[Building] = _campus().buildings
	for i: int in range(buildings.size()):
		var building: Building = buildings[i]
		LimboConsole.print_line("%d %s (%.1f, %.1f) %.1f deg, %s" % [i, building.info.id, building.pos.x, building.pos.y, rad_to_deg(building.angle), _statusOf(building)])
	if (buildings.is_empty()):
		LimboConsole.print_line("No buildings")


func _tool(toolName: String) -> void:
	var controller: BuildController = _campusView().controller
	if (toolName == ToolDestroy):
		controller.armDestroy()
	elif (toolName == ToolNone):
		controller.cancel()
	else:
		var info: BuildingInfo = Global.buildingDB.info(toolName)
		if (info == null):
			LimboConsole.print_line("Unknown tool '%s'" % toolName)
			return
		controller.armPlace(info)
	LimboConsole.print_line("Tool: %s" % toolName)


func _select(index: int) -> void:
	var controller: BuildController = _campusView().controller
	if (index == NoSelection):
		controller.select(null)
		return
	var building: Building = _buildingAt(index)
	if (building != null):
		controller.select(building)
		LimboConsole.print_line("Selected %d (%s)" % [index, building.info.name])


func _indexOf(building: Building) -> int:
	return _campus().buildings.find(building) if (building != null) else NoSelection


func _toolName(armed: BuildController.Tool, info: BuildingInfo) -> String:
	match armed:
		BuildController.Tool.Place:
			return "%s %s" % [ToolPlace, info.id]
		BuildController.Tool.Destroy:
			return ToolDestroy
		_:
			return ToolNone


func _state() -> void:
	var view: CampusView = _campusView()
	var controller: BuildController = view.controller
	LimboConsole.print_line("Tool: %s | angle %.1f deg | selected %d | hovered %d" % [
		_toolName(controller.activeTool, controller.placeInfo),
		rad_to_deg(controller.angle()),
		_indexOf(controller.selected),
		_indexOf(controller.hovered)])
	var camera: GameCamera = view.camera
	LimboConsole.print_line("Camera: target (%.1f, %.1f) | %.1f m | yaw %.1f deg" % [
		camera.target().x, camera.target().z, camera.distance(), camera.yaw()])
	LimboConsole.print_line("Time: %s, %s, speed %dx. Money: $%d" % [
		GameCalendar.label(_gameState().month()),
		"paused" if (_gameState().paused) else "running",
		_gameState().speedMultiplier(),
		_finances().cash])
	LimboConsole.print_line("University: %s" % _gameState().university.name)


func _pause() -> void:
	_gameState().togglePause()
	LimboConsole.print_line("Paused" if (_gameState().paused) else "Running")


func _speed(step: int) -> void:
	_gameState().setSpeedIndex(step - 1)
	LimboConsole.print_line("Speed %dx" % _gameState().speedMultiplier())


func _money(amount: int = KeepMoney) -> void:
	if (amount != KeepMoney):
		_finances().setCash(amount)
	LimboConsole.print_line("Money: $%d" % _finances().cash)


func _advance(months: int) -> void:
	_gameState().advanceMonths(months)
	LimboConsole.print_line("Now %s" % GameCalendar.label(_gameState().month()))


func _savePath(path: String) -> String:
	return Global.QuickSavePath if (path == NoPath) else path


func _save(path: String = NoPath) -> void:
	var target: String = _savePath(path)
	LimboConsole.print_line(("Saved to %s" if (Global.saveGame(target)) else "Could not save to %s") % target)


func _load(path: String = NoPath) -> void:
	var target: String = _savePath(path)
	LimboConsole.print_line(("Loaded %s" if (Global.loadGame(target)) else "Could not load %s") % target)


func _newGame() -> void:
	LimboConsole.print_line(("New game from %s" if (Global.newGame()) else "Could not start a new game from %s") % Global.StartStatePath)


# The button a name stands for, or MOUSE_BUTTON_NONE when the name is not one.
static func _mouseButton(buttonName: String) -> MouseButton:
	match buttonName:
		ButtonLeft:
			return MOUSE_BUTTON_LEFT
		ButtonRight:
			return MOUSE_BUTTON_RIGHT
		ButtonMiddle:
			return MOUSE_BUTTON_MIDDLE
		_:
			return MOUSE_BUTTON_NONE


# The button_mask bit for whichever button is held, 0 when none is.
func _heldMask() -> int:
	match _heldButton:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_MASK_RIGHT
		MOUSE_BUTTON_MIDDLE:
			return MOUSE_BUTTON_MASK_MIDDLE
		_:
			return 0


func _pushMouse(event: InputEventMouse, x: float, y: float) -> void:
	event.position = Vector2(x, y)
	event.global_position = event.position
	_mouse = event.position
	(Engine.get_main_loop() as SceneTree).get_root().push_input(event, true)


func _mouseButtonEvent(x: float, y: float, buttonName: String, pressed: bool) -> void:
	var button: MouseButton = DebugCommands._mouseButton(buttonName)
	if (button == MOUSE_BUTTON_NONE):
		LimboConsole.print_line("Unknown button '%s'" % buttonName)
		return
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	_heldButton = button if (pressed) else MOUSE_BUTTON_NONE
	event.button_mask = _heldMask()
	_pushMouse(event, x, y)
	LimboConsole.print_line("Mouse %s %s at (%.0f, %.0f)" % [
		buttonName, ActionDown if (pressed) else ActionUp, x, y])


func _mouseDown(x: float, y: float, buttonName: String = ButtonLeft) -> void:
	_mouseButtonEvent(x, y, buttonName, true)


func _mouseUp(x: float, y: float, buttonName: String = ButtonLeft) -> void:
	_mouseButtonEvent(x, y, buttonName, false)


func _mouseMove(x: float, y: float) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = _heldMask()
	event.relative = Vector2(x, y) - _mouse
	_pushMouse(event, x, y)
	LimboConsole.print_line("Mouse at (%.0f, %.0f), moved (%.0f, %.0f)" % [x, y, event.relative.x, event.relative.y])


## Presses or releases an input action, so both the polled reads (Input.get_axis)
## and the _unhandled_input handlers see it, which the keyboard cannot do here.
func _action(actionName: String, state: String) -> void:
	if (not InputMap.has_action(actionName)):
		LimboConsole.print_line("Unknown action '%s'" % actionName)
		return
	if (state != ActionDown and state != ActionUp):
		LimboConsole.print_line("Expected '%s' or '%s', got '%s'" % [ActionDown, ActionUp, state])
		return
	var event: InputEventAction = InputEventAction.new()
	event.action = actionName
	event.pressed = (state == ActionDown)
	event.strength = FullStrength if (event.pressed) else 0.0
	Input.parse_input_event(event)
	LimboConsole.print_line("Action %s %s" % [actionName, state])
