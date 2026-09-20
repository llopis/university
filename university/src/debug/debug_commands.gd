class_name DebugCommands


const ScreenshotPath: String = "/tmp/university/screenshot.png"


func _init() -> void:
	LimboConsole.register_command(_screenshot, "screenshot", "Save a screenshot to %s." % ScreenshotPath)
	LimboConsole.register_command(_camera, "camera", "Look at ground point <x> <z> from <distance> metres at <yawDeg> degrees.")
	LimboConsole.register_command(_build, "build", "Place building type <id> at ground point <x> <z> (metres), turned <deg> degrees.")
	LimboConsole.register_command(_destroy, "destroy", "Destroy building <n> (index from 'buildings').")
	LimboConsole.register_command(_buildings, "buildings", "One line per building: index, type id, position, angle in degrees.")
	LimboConsole.register_command(_tool, "tool", "Arm a tool: a building type id to place it, 'destroy', or 'none'.")
	LimboConsole.register_command(_select, "select", "Select building <n> (index from 'buildings'); -1 clears the selection.")
	LimboConsole.register_command(_mouseDown, "mousedown", "Press the left mouse button at design-space point <x> <y> (synthetic event through the viewport).")
	LimboConsole.register_command(_mouseUp, "mouseup", "Release the left mouse button at design-space point <x> <y>.")
	LimboConsole.register_command(_mouseMove, "mousemove", "Move the mouse to design-space point <x> <y> (with the left button held if pressed).")
	# Lets the remote console reach the scene tree, e.g.
	# eval get_root().find_child("GameView", true, false).
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


func _campus() -> Campus:
	return Global.gameState.campus


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


func _buildings() -> void:
	var buildings: Array[Building] = _campus().buildings
	for i: int in range(buildings.size()):
		var building: Building = buildings[i]
		LimboConsole.print_line("%d %s (%.1f, %.1f) %.1f deg" % [i, building.info.id, building.pos.x, building.pos.y, rad_to_deg(building.angle)])
	if (buildings.is_empty()):
		LimboConsole.print_line("No buildings")


const ToolDestroy: String = "destroy"
const ToolNone: String = "none"
const NoSelection: int = -1

var _mouseHeld: bool = false


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


func _pushMouse(event: InputEventMouse, x: float, y: float) -> void:
	event.position = Vector2(x, y)
	event.global_position = event.position
	(Engine.get_main_loop() as SceneTree).get_root().push_input(event, true)


func _mouseDown(x: float, y: float) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_mouseHeld = true
	_pushMouse(event, x, y)
	LimboConsole.print_line("Mouse down at (%.0f, %.0f)" % [x, y])


func _mouseUp(x: float, y: float) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	_mouseHeld = false
	_pushMouse(event, x, y)
	LimboConsole.print_line("Mouse up at (%.0f, %.0f)" % [x, y])


func _mouseMove(x: float, y: float) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	if (_mouseHeld):
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_pushMouse(event, x, y)
	LimboConsole.print_line("Mouse at (%.0f, %.0f)" % [x, y])
