extends GdUnitTestSuite
## Tool and selection rules of the controller, driven without a camera or a
## scene: the parts that decide what a click means, not where the cursor is.

const Diameter: float = 20.0


func _info() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})


func _controller(campus: Campus) -> BuildController:
	var controller: BuildController = auto_free(BuildController.new()) as BuildController
	controller.setup(campus, null)
	return controller


func test_arming_and_cancelling_switch_the_tool() -> void:
	var controller: BuildController = _controller(Campus.new(Finances.new()))
	var changes: Array[int] = []
	controller.ToolChanged.connect(func() -> void: changes.append(1))
	controller.armPlace(_info())
	assert_int(controller.activeTool).is_equal(BuildController.Tool.Place)
	controller.armDestroy()
	assert_int(controller.activeTool).is_equal(BuildController.Tool.Destroy)
	assert_object(controller.placeInfo).is_null()
	controller.cancel()
	assert_int(controller.activeTool).is_equal(BuildController.Tool.None)
	assert_int(changes.size()).is_equal(3)


func test_arming_a_tool_clears_the_selection() -> void:
	var campus: Campus = Campus.new(Finances.new())
	var controller: BuildController = _controller(campus)
	controller.select(campus.place(_info(), Vector2.ZERO, 0.0))
	controller.armDestroy()
	assert_object(controller.selected).is_null()


func test_selecting_a_building_puts_an_armed_tool_away() -> void:
	# An armed tool means no selection; the two must never be on at once.
	var campus: Campus = Campus.new(Finances.new())
	var controller: BuildController = _controller(campus)
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	controller.armPlace(_info())
	controller.select(building)
	assert_int(controller.activeTool).is_equal(BuildController.Tool.None)
	assert_object(controller.selected).is_same(building)


func test_clearing_the_selection_leaves_an_armed_tool_alone() -> void:
	var controller: BuildController = _controller(Campus.new(Finances.new()))
	controller.armPlace(_info())
	controller.select(null)
	assert_int(controller.activeTool).is_equal(BuildController.Tool.Place)


func test_placing_keeps_the_tool_armed_and_uses_the_angle() -> void:
	var campus: Campus = Campus.new(Finances.new())
	var controller: BuildController = _controller(campus)
	controller.armPlace(_info())
	controller.setAngle(PI / 2.0)
	var building: Building = controller.placeAt(Vector2(30.0, 30.0))
	assert_object(building).is_not_null()
	assert_float(building.angle).is_equal_approx(PI / 2.0, 0.0001)
	assert_int(controller.activeTool).is_equal(BuildController.Tool.Place)


func test_placing_on_occupied_ground_places_nothing() -> void:
	var campus: Campus = Campus.new(Finances.new())
	var controller: BuildController = _controller(campus)
	controller.armPlace(_info())
	controller.placeAt(Vector2.ZERO)
	assert_object(controller.placeAt(Vector2.ZERO)).is_null()
	assert_int(campus.buildings.size()).is_equal(1)


func test_destroying_the_selected_building_clears_the_selection() -> void:
	var campus: Campus = Campus.new(Finances.new())
	var controller: BuildController = _controller(campus)
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	controller.select(building)
	var selections: Array[Building] = []
	controller.SelectionChanged.connect(func(b: Building) -> void: selections.append(b))
	campus.destroy(building)
	assert_object(controller.selected).is_null()
	assert_int(selections.size()).is_equal(1)
	assert_object(selections[0]).is_null()


func test_selecting_the_same_building_again_announces_nothing() -> void:
	var campus: Campus = Campus.new(Finances.new())
	var controller: BuildController = _controller(campus)
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	controller.select(building)
	var selections: Array[Building] = []
	controller.SelectionChanged.connect(func(b: Building) -> void: selections.append(b))
	controller.select(building)
	assert_array(selections).is_empty()
