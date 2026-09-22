extends Node


# Static data
const BuildingsPath: String = "res://data/buildings.txt"
var buildingDB: BuildingInfoDB


# A new game is this save: an authored university that is already running.
const StartStatePath: String = "res://data/start_state.json"
# Where F5 saves and F9 loads, and the console's save/load with no path.
const QuickSavePath: String = "user://quicksave.json"
const NoStartStateError: String = "Global: could not load the start state at '%s'; starting with an empty campus."

# Game data. Loaded from the start state in _ready, after buildingDB, which
# loading needs to look building types up. A load replaces it.
var gameState: GameState

const RemoteConsoleScript: GDScript = preload("res://src/debug/remote_console.gd")

# No audio buses exist yet; these mute them the moment they're added.
const MusicBus: StringName = &"Music"
const SfxBus: StringName = &"SFX"


func _ready() -> void:
	buildingDB = BuildingInfoDB.loadFrom(BuildingsPath)
	gameState = _readGame(StartStatePath)
	if (gameState == null):
		push_error(NoStartStateError % StartStatePath)
		gameState = GameState.new()
	var console: Node = RemoteConsoleScript.new()
	console.name = "RemoteConsole"
	add_child(console)
	if (CommandLine.has_nomusic()):
		_muteBus(MusicBus)
	if (CommandLine.has_nosound()):
		_muteBus(SfxBus)


## Starts over from the start state. False when the start state was refused.
func newGame() -> bool:
	return loadGame(StartStatePath)


func saveGame(path: String) -> bool:
	return SaveFile.write(path, gameState.toDict())


## Replaces the game with the one saved at path and reloads the scene, so every
## view is built again against the new state rather than rewired. False, with
## nothing changed, when there is no save there.
func loadGame(path: String) -> bool:
	var loaded: GameState = _readGame(path)
	if (loaded == null):
		return false
	gameState = loaded
	get_tree().reload_current_scene()
	return true


func _readGame(path: String) -> GameState:
	var data: Variant = SaveFile.read(path)
	if (data == null):
		return null
	return GameState.fromDict(data as Dictionary, buildingDB)


func _muteBus(busName: StringName) -> void:
	var index: int = AudioServer.get_bus_index(busName)
	if (index >= 0):
		AudioServer.set_bus_mute(index, true)


func _init() -> void:
	DisplayServer.window_set_title("University")
