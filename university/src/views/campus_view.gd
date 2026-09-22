class_name CampusView
extends Node3D
## Root of the game scene: hosts the lights, the ground, the camera and the UI,
## and drives the state clock. Lighting and layout are authored in the scene.

@onready var camera: GameCamera = %Camera
@onready var statusBar: StatusBar = %StatusBar
@onready var buildingsRoot: Node3D = %Buildings
@onready var controller: BuildController = %BuildController
@onready var buildMenu: BuildMenu = %BuildMenu
@onready var infoPanel: InfoPanel = %InfoPanel

var gameState: GameState

var _views: Dictionary[Building, BuildingView]
# The building whose view currently shows each highlight, so it can be put back.
var _selectedView: BuildingView
var _hoveredView: BuildingView


func _ready() -> void:
	gameState = Global.gameState
	statusBar.gameState = gameState
	gameState.university.campus.BuildingAdded.connect(_onBuildingAdded)
	gameState.university.campus.BuildingRemoved.connect(_onBuildingRemoved)
	gameState.university.campus.BuildingOpened.connect(_onBuildingOpened)
	# A loaded game arrives with its buildings already standing.
	for building: Building in gameState.university.campus.buildings:
		_onBuildingAdded(building)
	controller.setup(gameState.university.campus, camera)
	controller.SelectionChanged.connect(_onSelectionChanged)
	controller.HoverChanged.connect(_onHoverChanged)
	buildMenu.populate(Global.buildingDB.all)
	buildMenu.showAffordable(gameState.university.campus)
	gameState.university.campus.MoneyChanged.connect(func(_money: int) -> void: buildMenu.showAffordable(gameState.university.campus))
	buildMenu.BuildingChosen.connect(controller.armPlace)
	buildMenu.DestroyChosen.connect(controller.armDestroy)
	buildMenu.Closed.connect(controller.cancel)
	controller.ToolChanged.connect(func() -> void: buildMenu.showTool(controller.activeTool, controller.placeInfo))
	controller.SelectionChanged.connect(infoPanel.showBuilding)


func _process(dt: float) -> void:
	gameState.update(dt)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("TogglePause")):
		gameState.togglePause()
	elif (event.is_action_pressed("SpeedUp")):
		gameState.changeSpeed(1)
	elif (event.is_action_pressed("SpeedDown")):
		gameState.changeSpeed(-1)


func viewFor(building: Building) -> BuildingView:
	return _views.get(building) as BuildingView


func _onSelectionChanged(building: Building) -> void:
	_selectedView = _moveHighlight(_selectedView, building, BuildingView.Highlight.Selected)


func _onHoverChanged(building: Building) -> void:
	_hoveredView = _moveHighlight(_hoveredView, building, BuildingView.Highlight.Destroy)


## Takes the highlight off the view that had it and puts it on the building's.
func _moveHighlight(from: BuildingView, building: Building, kind: BuildingView.Highlight) -> BuildingView:
	# Checked because the old view may already be gone: its building was
	# destroyed, and a later selection change finds the view freed.
	if (is_instance_valid(from)):
		from.setHighlight(BuildingView.Highlight.None)
	var to: BuildingView = viewFor(building) if (building != null) else null
	if (to != null):
		to.setHighlight(kind)
	return to


func _onBuildingAdded(building: Building) -> void:
	var view: BuildingView = BuildingView.create(building)
	_views[building] = view
	buildingsRoot.add_child(view)


func _onBuildingRemoved(building: Building) -> void:
	var view: BuildingView = viewFor(building)
	_views.erase(building)
	view.queue_free()


func _onBuildingOpened(building: Building) -> void:
	viewFor(building).setUnderConstruction(false)
	if (building == controller.selected):
		infoPanel.showBuilding(building)
