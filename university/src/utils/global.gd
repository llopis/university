extends Node


# Static data
const BuildingsPath: String = "res://data/buildings.txt"
var buildingDB: BuildingInfoDB


# Game data. Built in _ready, after buildingDB: the campus may read the DB
# while it builds itself.
var gameState: GameState

const RemoteConsoleScript: GDScript = preload("res://src/debug/remote_console.gd")

# No audio buses exist yet; these mute them the moment they're added.
const MusicBus: StringName = &"Music"
const SfxBus: StringName = &"SFX"


func _ready() -> void:
	buildingDB = BuildingInfoDB.loadFrom(BuildingsPath)
	gameState = GameState.new()
	var console: Node = RemoteConsoleScript.new()
	console.name = "RemoteConsole"
	add_child(console)
	if (CommandLine.has_nomusic()):
		_muteBus(MusicBus)
	if (CommandLine.has_nosound()):
		_muteBus(SfxBus)


func _muteBus(busName: StringName) -> void:
	var index: int = AudioServer.get_bus_index(busName)
	if (index >= 0):
		AudioServer.set_bus_mute(index, true)


func _init() -> void:
	DisplayServer.window_set_title("University")
