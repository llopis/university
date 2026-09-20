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
	gameState.campus.BuildingAdded.connect(_onBuildingAdded)
	gameState.campus.BuildingRemoved.connect(_onBuildingRemoved)
	controller.setup(gameState.campus, camera)
	controller.SelectionChanged.connect(_onSelectionChanged)
	controller.HoverChanged.connect(_onHoverChanged)
	buildMenu.populate(Global.buildingDB.all)
	buildMenu.BuildingChosen.connect(controller.armPlace)
	buildMenu.DestroyChosen.connect(controller.armDestroy)
	buildMenu.Closed.connect(controller.cancel)
	controller.ToolChanged.connect(func() -> void: buildMenu.showTool(controller.activeTool, controller.placeInfo))
	controller.SelectionChanged.connect(infoPanel.showBuilding)


func _process(dt: float) -> void:
	gameState.update(dt)


func viewFor(building: Building) -> BuildingView:
	return _views.get(building) as BuildingView


func _onSelectionChanged(building: Building) -> void:
	_selectedView = _moveHighlight(_selectedView, building, BuildingView.Highlight.Selected)


func _onHoverChanged(building: Building) -> void:
	_hoveredView = _moveHighlight(_hoveredView, building, BuildingView.Highlight.Destroy)


## Takes the highlight off the view that had it and puts it on the building's.
## The old view may already be freed: its building was just destroyed.
func _moveHighlight(from: BuildingView, building: Building, kind: BuildingView.Highlight) -> BuildingView:
	if (is_instance_valid(from) and not from.is_queued_for_deletion()):
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
