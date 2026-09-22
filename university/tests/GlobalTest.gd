extends GdUnitTestSuite
## Global.loadGame's refusal paths. A successful load reloads the scene,
## which during tests is the test runner, so only refusal is tested here.

const MissingPath: String = "user://global_test_missing.json"
const BrokenPath: String = "user://global_test_broken.json"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BrokenPath))


func test_loading_a_missing_path_changes_nothing() -> void:
	var before: GameState = Global.gameState
	assert_bool(Global.loadGame(MissingPath)).is_false()
	assert_object(Global.gameState).is_same(before)


func test_loading_a_save_missing_a_key_is_refused() -> void:
	var before: GameState = Global.gameState
	SaveFile.write(BrokenPath, {"tickCount": 0})
	var results: Array[bool] = []
	await assert_error(func() -> void: results.append(Global.loadGame(BrokenPath))) \
		.is_push_error(Variants.MissingKeysError % ["GameState", "university"])
	assert_bool(results[0]).is_false()
	assert_object(Global.gameState).is_same(before)
