class_name DebugCommands


const ScreenshotPath: String = "/tmp/university/screenshot.png"


func _init() -> void:
	LimboConsole.register_command(_screenshot, "screenshot", "Save a screenshot to %s." % ScreenshotPath)
	LimboConsole.register_command(_camera, "camera", "Look at ground point <x> <z> from <distance> metres at <yawDeg> degrees.")
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
