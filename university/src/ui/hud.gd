class_name Hud
extends Control
## The HUD's root: the top bar, its popovers (one open at a time) and the
## semester popup. It carries the shared theme. Everything it shows is read
## from the game state it is set up with.

@onready var topBar: TopBar = %TopBar

var state: GameState
var camera: GameCamera
var controller: BuildController


func setup(gameState: GameState, gameCamera: GameCamera, buildController: BuildController) -> void:
	state = gameState
	camera = gameCamera
	controller = buildController
	topBar.state = state
