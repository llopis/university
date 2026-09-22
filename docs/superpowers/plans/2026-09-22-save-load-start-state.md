# Save/Load and the Start State Implementation Plan (Phase 1 of 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Saving and loading the game (F5/F9 and console), and launching every new game from an authored start-state save instead of an empty campus.

**Architecture:**
- Every state class gets a pure `toDict()` and a `static fromDict(data, buildingDB)`.
- `SaveFile` (`src/utils/`) is the only file I/O: JSON written at full precision, so a loaded game plays out bit-identically.
- `Variants` (`src/utils/`) becomes the one place a parsed Variant turns into a number or bool. `BuildingInfo`'s private copies move there.
- A new `University` state class sits between `GameState` and `Campus` and holds the university's name. `gameState.campus` becomes `gameState.university.campus`.
- `Global.loadGame` replaces `Global.gameState` and reloads the scene, so every view is rebuilt against the new state instead of rewired. `CampusView` creates views for the buildings a loaded game arrives with.

**Tech Stack:** Godot 4.7, fully typed GDScript, gdUnit4, LimboConsole + TCP remote console.

**Spec:** `docs/superpowers/specs/2026-09-22-students-money-hud-design.md`. This plan is its **Phases → 1**, and its **Save / load** section. Read the spec and `CLAUDE.md` before starting any task.

## Global Constraints

- **Paths.** Repo root `/Users/noel/Development/University/game`; Godot project `university/`. `res://` is `university/`.
- **`CLAUDE.md` governs:**
  - camelCase variables and functions; PascalCase classes, constants and signals
  - parenthesized conditions, `if (x):`
  - fully typed GDScript: unsafe property access, method access and call arguments are errors
  - no magic numbers (named `const`)
  - TAB indentation
  - no duplicate logic, surgical changes
- **State classes** (`src/state/`, `src/data/`) are plain `class_name` classes: no `extends Node`, no `Input`, no scene tree, no file I/O, no reference to any view. File I/O lives in `src/utils/save_file.gd` only.
- **A Variant from a Dictionary or Array** never goes into `int()`, `float()`, `bool()` or a typed parameter. Use `Variants.toInt` / `toFloat` / `toBool` (Task 1), `str()`, or `as Dictionary` / `as Array`. The project turns the analyzer's warning into an error, so getting this wrong fails to parse.
- **Exact values from the spec:**
  - Quicksave `user://quicksave.json`; start state `res://data/start_state.json`.
  - F5 saves, F9 loads (input actions `QuickSave`, `QuickLoad`).
  - Save keys: `tickCount`, `university` { `name`, `campus` { `month`, `money`, `buildings`: [{ `type`, `pos`: [x, z], `angle`, `underConstruction`, `opensAtMonth` }] } }.
  - **Not saved:** speed, pause, the half-finished tick, the camera, the armed tool or the selection.
  - **Missing keys are an error**, never a default.
  - A building whose type id isn't in the building data is reported with `push_error` and left out.
  - `money` stays on `Campus` in this phase. Phase 2 moves it.
- **Verified 4.7 APIs** (probed headless on this machine, 2026-09-22):
  - `JSON.stringify(data, indent, sort_keys, full_precision)` exists. With `full_precision = true`, floats round-trip bit-identically; without it they don't.
  - `JSON.parse_string` returns **every** number as a float (type 3), ints included.
  - `FileAccess.file_exists`, `FileAccess.open(path, FileAccess.WRITE / READ)`, `get_as_text`, `store_string`, `close` and `FileAccess.get_open_error()` all work.
  - `res://` is writable when running from the project folder.
  - `SceneTree.reload_current_scene()` exists.
  - `KEY_F5` = 4194336 and `KEY_F9` = 4194340.
  - The `Global` autoload is ready inside gdUnit tests: `Global.buildingDB` is loaded.
- **Never guess a Godot or addon API.** Grep this repo or read the addon source under `university/addons/`.
- **Don't delete what isn't yours.** Never delete `.godot/`. Never hand-edit `university/data/buildings.txt`. `university/data/start_state.json` (Task 5) is hand-authored.
- **Tests** assert behavior and relationships, never the values in `data/buildings.txt` or `data/start_state.json`.
- **Commits.** `.gd.uid` files are committed next to their scripts. Every commit message ends with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  ```
  (name the model you actually are). Commit locally on `main`; do not push.

### Named procedures

**REGISTER** runs after adding or removing any `class_name` script:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --editor --quit-after 20 2>&1 | grep -E "ERROR|WARNING|Parse Error" ; true
```
Expected: no output.

**RUN-TESTS** runs the whole suite. If the total drops, a suite failed to parse:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Overall Summary|Executed test|FAILED|Parse Error|SCRIPT ERROR"
```
To run one suite, replace `--add tests/` with `--add tests/<Suite>.gd`. Some `ERROR:` lines are expected, because tests assert on deliberate `push_error`s (`BuildingInfoTest` today; `SaveFileTest` and `SaveTest` after this plan). The summary must still read `0 errors | 0 failures`.

Expected totals after each task (91 cases in 9 suites today):
- Task 1: 95 cases, 10 suites
- Task 2: 99, 11
- Task 3: 100, 12
- Task 4: 104, 13
- Task 5: 106, 14
- Task 6: 106, 14

**LAUNCH-CHECK** launches with the window hidden, reads stdout, drives the game by console, takes a screenshot and kills Godot:
```
cd /Users/noel/Development/University/game
mkdir -p /tmp/university
(for i in $(seq 1 20); do sleep 0.2; osascript -e 'tell application "System Events" to set visible of process "Godot" to false' 2>/dev/null; done) &
./bin/run.sh > /tmp/university/run.log 2>&1 &
sleep 6
grep -nE "SCRIPT ERROR|Parse Error|ERROR|WARNING" /tmp/university/run.log
# console commands: echo "<command>" | nc -w 3 localhost 9999   (sleep 0.3 before a screenshot that should show the effect)
echo screenshot | nc -w 3 localhost 9999
pkill -f "Godot"
```
- **Expected:** the grep prints nothing.
- LOOK at `/tmp/university/screenshot.png` with the Read tool.
- Always `pkill -f "Godot"` when done.
- **Existing console commands:**
  - `camera <x> <z> <dist> <yaw>`
  - `build <id> <x> <z> <deg>`, `destroy <n>`, `buildings`
  - `tool <id|destroy|none>`, `select <n>`, `state`
  - `mousedown|mouseup <x> <y> [left|right|middle]`, `mousemove <x> <y>` (design space is 1920x1080)
  - `action <name> <down|up>`
  - `pause`, `speed <1-3>`, `money [amount]`, `advance <months>`
- **Building type ids** in the data: `admissions`, `dorm`, `engineering_1`, `dining_1`.

---

### Task 1: `Variants`, the one place parsed values become numbers

`BuildingInfo` has private `_toInt` and `_toFloat` helpers. Loading a save needs the same conversions: JSON gives back every number as a float. Move them into a shared static class instead of copying them, and add `toBool` for the saved flags.

**Files:**
- Create: `university/src/utils/variants.gd`
- Modify: `university/src/data/building_info.gd` (lines 25–45)
- Test: `university/tests/VariantsTest.gd`

**Interfaces:**
- Produces:
  - `Variants.toInt(value: Variant) -> int`
  - `Variants.toFloat(value: Variant) -> float`
  - `Variants.toBool(value: Variant) -> bool`
  - All three are static. Anything that isn't the right kind of value reads as 0, 0.0 or false.

- [ ] **Step 1: Write the failing test**

Create `university/tests/VariantsTest.gd`:

```gdscript
extends GdUnitTestSuite
## Reading typed values out of parsed data: JSON gives every number back as a
## float, and a blank CSV cell arrives as "".

const Epsilon: float = 0.0001


func test_a_whole_float_reads_as_the_same_int() -> void:
	assert_int(Variants.toInt(50000000.0)).is_equal(50000000)
	assert_int(Variants.toInt(-3.0)).is_equal(-3)


func test_an_int_reads_as_itself_either_way() -> void:
	assert_int(Variants.toInt(7)).is_equal(7)
	assert_float(Variants.toFloat(7)).is_equal_approx(7.0, Epsilon)


func test_anything_that_is_not_a_number_reads_as_zero() -> void:
	assert_int(Variants.toInt("")).is_equal(0)
	assert_float(Variants.toFloat("")).is_equal_approx(0.0, Epsilon)
	assert_int(Variants.toInt(null)).is_equal(0)


func test_only_a_true_bool_reads_as_true() -> void:
	assert_bool(Variants.toBool(true)).is_true()
	assert_bool(Variants.toBool(false)).is_false()
	assert_bool(Variants.toBool("")).is_false()
	assert_bool(Variants.toBool(null)).is_false()
```

- [ ] **Step 2: Run it to see it fail**

Run RUN-TESTS with `--add tests/VariantsTest.gd`.
Expected: a `Parse Error` about the identifier `Variants`, and 0 test cases executed. The class doesn't exist yet.

- [ ] **Step 3: Write `Variants`**

Create `university/src/utils/variants.gd`:

```gdscript
class_name Variants
## Reads typed values out of parsed data. JSON has one number type, so a saved
## int comes back as a float; a blank CSV cell comes back as "". The one place
## either becomes an int, a float or a bool.


## A float reads truncated toward zero, which gives back exactly every whole
## number JSON wrote. Anything that is not a number reads as zero.
static func toInt(value: Variant) -> int:
	if (value is int):
		return value
	if (value is float):
		return int(value as float)
	return 0


## Anything that is not a number reads as zero.
static func toFloat(value: Variant) -> float:
	if (value is float):
		return value
	if (value is int):
		return float(value as int)
	return 0.0


## Anything that is not a bool reads as false.
static func toBool(value: Variant) -> bool:
	if (value is bool):
		return value
	return false
```

- [ ] **Step 4: Point `BuildingInfo` at it and remove its copies**

In `university/src/data/building_info.gd`, replace:

```gdscript
	cost = roundi(maxf(_toFloat(data.get("costM", 0.0)), 0.0) * float(DollarsPerM))
	buildTime = _toFloat(data.get("buildTime", 0.0))
	diameter = _toFloat(data.get("diameter", 0.0))
```

with:

```gdscript
	cost = roundi(maxf(Variants.toFloat(data.get("costM", 0.0)), 0.0) * float(DollarsPerM))
	buildTime = Variants.toFloat(data.get("buildTime", 0.0))
	diameter = Variants.toFloat(data.get("diameter", 0.0))
```

Then delete everything from the comment line `# A blank cell arrives as "", so anything that is not a number reads as zero.` to the end of the file: that's `_toInt` and `_toFloat`. The file now ends with the `_init` function.

- [ ] **Step 5: REGISTER, then run the tests**

Run REGISTER, then RUN-TESTS.
Expected: 95 cases in 10 suites, `0 errors | 0 failures`. `BuildingInfoTest` still passes, which proves blank cells still read as zero.

- [ ] **Step 6: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/utils/variants.gd university/src/utils/variants.gd.uid university/src/data/building_info.gd university/tests/VariantsTest.gd university/tests/VariantsTest.gd.uid
git commit -m "$(cat <<'EOF'
Give parsed Variants one place to become numbers

Saves need the same conversions BuildingInfo made privately, so they
move to Variants rather than being copied.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `SaveFile`, a dictionary on disk

**Files:**
- Create: `university/src/utils/save_file.gd`
- Test: `university/tests/SaveFileTest.gd`

**Interfaces:**
- Consumes: `Variants.toInt`, `Variants.toFloat`, `Variants.toBool` (Task 1), in the test only.
- Produces:
  - `SaveFile.encode(data: Dictionary) -> String`
  - `SaveFile.decode(text: String) -> Variant`: a Dictionary, or null
  - `SaveFile.write(path: String, data: Dictionary) -> bool`
  - `SaveFile.read(path: String) -> Variant`: a Dictionary, or null when there's no file; a file that isn't a save is reported and gives null
  - `SaveFile.NotASaveError: String`, `SaveFile.WriteError: String`
  - All static.

- [ ] **Step 1: Write the failing test**

Create `university/tests/SaveFileTest.gd`:

```gdscript
extends GdUnitTestSuite
## Saves on disk: JSON text that gives back exactly what was written, floats
## included.

const TestPath: String = "user://save_file_test.json"
const MissingPath: String = "user://no_such_save.json"
const NotASave: String = "[1, 2]"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TestPath))


func test_floats_come_back_bit_identical() -> void:
	# Values with no short decimal form: any precision lost would show.
	var values: Array[float] = [PI / 7.0, 0.1 + 0.2, -123.456789012345678, 1.0e-17]
	var back: Dictionary = SaveFile.decode(SaveFile.encode({"values": values})) as Dictionary
	var backValues: Array = back["values"] as Array
	for i: int in range(values.size()):
		assert_float(Variants.toFloat(backValues[i])).is_equal(values[i])


func test_what_is_written_is_what_is_read() -> void:
	var data: Dictionary = {"name": "Somewhere", "count": 3, "nested": {"flag": true}}
	assert_bool(SaveFile.write(TestPath, data)).is_true()
	var back: Dictionary = SaveFile.read(TestPath) as Dictionary
	assert_str(str(back["name"])).is_equal("Somewhere")
	assert_int(Variants.toInt(back["count"])).is_equal(3)
	assert_bool(Variants.toBool((back["nested"] as Dictionary)["flag"])).is_true()


func test_reading_where_nothing_was_saved_gives_null() -> void:
	assert_that(SaveFile.read(MissingPath)).is_null()


func test_a_file_that_is_not_a_save_is_reported() -> void:
	var file: FileAccess = FileAccess.open(TestPath, FileAccess.WRITE)
	file.store_string(NotASave)
	file.close()
	var results: Array[Variant] = []
	await assert_error(func() -> void: results.append(SaveFile.read(TestPath))) \
		.is_push_error(SaveFile.NotASaveError % TestPath)
	assert_that(results[0]).is_null()
```

- [ ] **Step 2: Run it to see it fail**

Run RUN-TESTS with `--add tests/SaveFileTest.gd`.
Expected: a `Parse Error` about `SaveFile`, and 0 cases.

- [ ] **Step 3: Write `SaveFile`**

Create `university/src/utils/save_file.gd`:

```gdscript
class_name SaveFile
## A saved game on disk: one dictionary written as JSON text. Floats are
## written at full precision, so what is read back is bit-identical to what was
## saved and a loaded game plays out exactly as the saved one would have. The
## only file I/O a save goes through; state classes never touch files.

const Indent: String = "\t"
const SortKeys: bool = true
const FullPrecision: bool = true
const NotASaveError: String = "SaveFile: '%s' does not hold a saved game."
const WriteError: String = "SaveFile: could not write '%s' (error %d)."


static func encode(data: Dictionary) -> String:
	return JSON.stringify(data, Indent, SortKeys, FullPrecision)


## The dictionary the text holds, or null when it holds anything else.
static func decode(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	return parsed if (parsed is Dictionary) else null


static func write(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if (file == null):
		push_error(WriteError % [path, FileAccess.get_open_error()])
		return false
	file.store_string(encode(data))
	file.close()
	return true


## The dictionary saved at path, or null when there is no file there. A file
## that is there but is not a save is reported, and also gives null.
static func read(path: String) -> Variant:
	if (not FileAccess.file_exists(path)):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var data: Variant = decode(file.get_as_text())
	if (data == null):
		push_error(NotASaveError % path)
	return data
```

- [ ] **Step 4: REGISTER, then run the tests**

Run REGISTER, then RUN-TESTS.
Expected: 99 cases in 11 suites, `0 errors | 0 failures`. There will be one extra `ERROR:` line in the output, from the deliberate not-a-save.

- [ ] **Step 5: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/utils/save_file.gd university/src/utils/save_file.gd.uid university/tests/SaveFileTest.gd university/tests/SaveFileTest.gd.uid
git commit -m "$(cat <<'EOF'
Add SaveFile: a dictionary on disk as full-precision JSON

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `University` between `GameState` and `Campus`

This is a pure restructure: nothing plays differently. `GameState` now holds a `University`, which holds the name and the campus, and each new month reaches the campus through it.

**Files:**
- Create: `university/src/state/university.gd`
- Modify:
  - `university/src/state/game_state.gd`
  - `university/src/views/campus_view.gd`
  - `university/src/ui/status_bar.gd:29`
  - `university/src/debug/debug_commands.gd:84`
  - `university/tests/GameStateTest.gd`
  - `CLAUDE.md` (lines 64 and 68)
- Test: `university/tests/UniversityTest.gd`

**Interfaces:**
- Produces:
  - `University.name: String`
  - `University.campus: Campus`
  - `University.startMonth(newMonth: int) -> void`
  - `GameState.university: University`. It replaces `GameState.campus`, which is removed.

- [ ] **Step 1: Write the failing test**

Create `university/tests/UniversityTest.gd`:

```gdscript
extends GdUnitTestSuite
## The university hands each new month on to its campus.

const Diameter: float = 20.0


func test_a_new_month_reaches_the_campus() -> void:
	var university: University = University.new()
	var info: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})
	var building: Building = university.campus.place(info, Vector2.ZERO, 0.0)
	university.startMonth(building.opensAtMonth)
	assert_int(university.campus.month).is_equal(building.opensAtMonth)
	assert_bool(building.underConstruction).is_false()
```

- [ ] **Step 2: Run it to see it fail**

Run RUN-TESTS with `--add tests/UniversityTest.gd`.
Expected: a `Parse Error` about `University`, and 0 cases.

- [ ] **Step 3: Write `University`**

Create `university/src/state/university.gd`:

```gdscript
class_name University
## The institution being run: its name and its campus. GameState holds one;
## everything the player runs hangs off it.

var name: String
var campus: Campus


func _init() -> void:
	campus = Campus.new()


## A new month began. The campus opens whatever is due.
func startMonth(newMonth: int) -> void:
	campus.startMonth(newMonth)
```

- [ ] **Step 4: Make `GameState` hold the university**

In `university/src/state/game_state.gd`, make these edits.

Replace:
```gdscript
## The session: the campus and the clock that drives it. Time moves in fixed
```
with:
```gdscript
## The session: the university and the clock that drives it. Time moves in fixed
```

Replace:
```gdscript
var campus: Campus
var paused: bool = false
```
with:
```gdscript
var university: University
var paused: bool = false
```

Replace:
```gdscript
func _init() -> void:
	campus = Campus.new()
```
with:
```gdscript
func _init() -> void:
	university = University.new()
```

Replace:
```gdscript
## One tick of the sim. The one place the month rolls over into the campus.
func step() -> void:
	campus.tick(TickStepDuration)
	tickCount += 1
	if (month() != campus.month):
		campus.startMonth(month())
```
with:
```gdscript
## One tick of the sim. The one place the month rolls over into the university.
func step() -> void:
	university.campus.tick(TickStepDuration)
	tickCount += 1
	if (month() != university.campus.month):
		university.startMonth(month())
```

Replace:
```gdscript
	campus.update(dt)
```
with:
```gdscript
	university.campus.update(dt)
```

- [ ] **Step 5: Update every caller**

- `university/src/views/campus_view.gd`: replace every `gameState.campus` with `gameState.university.campus`. There are 7 occurrences in `_ready`, two of them on the `MoneyChanged` line, one inside its lambda.
- `university/src/ui/status_bar.gd`: replace `MoneyFormat.short(gameState.campus.money)` with `MoneyFormat.short(gameState.university.campus.money)`.
- `university/src/debug/debug_commands.gd`: in `_campus()`, replace `return _gameState().campus` with `return _gameState().university.campus`.
- `university/tests/GameStateTest.gd`: replace every `state.campus.` with `state.university.campus.`. There are 6 occurrences.

Check nothing is left:
```bash
cd /Users/noel/Development/University/game && grep -rnE "gameState\.campus|state\.campus|_gameState\(\)\.campus" university/src university/tests
```
Expected: no output.

- [ ] **Step 6: Update `CLAUDE.md`**

In `CLAUDE.md`, replace:
```
`GameState` holds the campus and the fixed-step clock.
```
with:
```
`GameState` holds the university and the fixed-step clock. `University` (`src/state/university.gd`) is the institution being run: its `name` and its `campus`. `GameState.step` hands each new month to `University.startMonth`, which passes it on to the campus. Reach the campus as `gameState.university.campus`.
```

In `CLAUDE.md`, replace:
```
`step()` is one tick and the one place the month rolls into the campus: it ticks, counts, and calls `Campus.startMonth(month())` once the month index has moved on, so buildings open from the clock and from nothing else.
```
with:
```
`step()` is one tick and the one place the month rolls into the university: it ticks, counts, and calls `University.startMonth(month())` once the month index has moved on. That passes the month to `Campus.startMonth`, so buildings open from the clock and from nothing else.
```

- [ ] **Step 7: REGISTER, run the tests, run LAUNCH-CHECK**

Run REGISTER, then RUN-TESTS.
Expected: 100 cases in 12 suites, `0 errors | 0 failures`.

Run LAUNCH-CHECK with no console commands except `screenshot`.
Expected: the grep prints nothing. The screenshot shows today's empty campus with the status bar reading `Sep, Year 1` and `$50.0M`, exactly as before this task.

- [ ] **Step 8: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/university.gd university/src/state/university.gd.uid university/src/state/game_state.gd university/src/views/campus_view.gd university/src/ui/status_bar.gd university/src/debug/debug_commands.gd university/tests/GameStateTest.gd university/tests/UniversityTest.gd university/tests/UniversityTest.gd.uid CLAUDE.md
git commit -m "$(cat <<'EOF'
Put a University between the game state and the campus

It holds the university's name and its campus, and each new month
reaches the campus through it. Nothing plays differently.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: The save format, `toDict` and `fromDict`

**Files:**
- Modify:
  - `university/src/state/building.gd`
  - `university/src/state/campus.gd`
  - `university/src/state/university.gd`
  - `university/src/state/game_state.gd`
- Test: `university/tests/SaveTest.gd`

**Interfaces:**
- Consumes:
  - `Variants.toInt/toFloat/toBool` (Task 1)
  - `SaveFile.encode/decode` (Task 2), in the test only
  - `GameState.university`, `University.name/campus` (Task 3)
- Produces:
  - `Building.toDict() -> Dictionary`
  - `static Building.fromDict(data: Dictionary, buildingInfo: BuildingInfo) -> Building`
  - `Campus.toDict() -> Dictionary`
  - `static Campus.fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> Campus`
  - `Campus.UnknownTypeError: String`
  - `University.toDict() -> Dictionary`
  - `static University.fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> University`
  - `GameState.toDict() -> Dictionary`
  - `static GameState.fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> GameState`

- [ ] **Step 1: Write the failing tests**

Create `university/tests/SaveTest.gd`:

```gdscript
extends GdUnitTestSuite
## Saving and loading: a round trip gives back the same game, and a loaded game
## plays out exactly as the saved one would have. Building types are fixtures.

const Diameter: float = 20.0
const Spacing: float = 40.0
# No short decimal form, so a save that lost precision would show.
const Angle: float = PI / 7.0
const MonthsAfterLoading: int = 7
const Name: String = "Test University"


func _db() -> BuildingInfoDB:
	var records: Array[Dictionary] = [
		{"id": "hall", "name": "Hall", "diameter": Diameter, "costM": 1},
		{"id": "lab", "name": "Lab", "diameter": Diameter, "costM": 2},
	]
	return BuildingInfoDB.new(records)


## A game some months in: one building open, one still under construction.
func _playedState(buildingDB: BuildingInfoDB) -> GameState:
	var state: GameState = GameState.new()
	state.university.name = Name
	state.university.campus.place(buildingDB.info("hall"), Vector2.ZERO, Angle)
	state.advanceMonths(GameCalendar.nextSemesterStart(0))
	state.university.campus.place(buildingDB.info("lab"), Vector2(Spacing, Spacing), -Angle)
	state.advanceMonths(1)
	return state


## Through the same text a save file holds.
func _reloaded(state: GameState, buildingDB: BuildingInfoDB) -> GameState:
	var data: Dictionary = SaveFile.decode(SaveFile.encode(state.toDict())) as Dictionary
	return GameState.fromDict(data, buildingDB)


func test_a_round_trip_gives_back_the_same_game() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var state: GameState = _playedState(buildingDB)
	var saved: String = SaveFile.encode(state.toDict())
	assert_str(SaveFile.encode(_reloaded(state, buildingDB).toDict())).is_equal(saved)


func test_a_loaded_game_plays_out_as_the_saved_one_would_have() -> void:
	# The lab opens during the months played after loading, in both games.
	var buildingDB: BuildingInfoDB = _db()
	var original: GameState = _playedState(buildingDB)
	var loaded: GameState = _reloaded(original, buildingDB)
	original.advanceMonths(MonthsAfterLoading)
	loaded.advanceMonths(MonthsAfterLoading)
	assert_str(SaveFile.encode(loaded.toDict())).is_equal(SaveFile.encode(original.toDict()))


func test_loading_restores_the_campus_as_it_was() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var state: GameState = _playedState(buildingDB)
	var loaded: GameState = _reloaded(state, buildingDB)
	var campus: Campus = state.university.campus
	var back: Campus = loaded.university.campus
	assert_str(loaded.university.name).is_equal(Name)
	assert_int(loaded.tickCount).is_equal(state.tickCount)
	assert_int(back.month).is_equal(campus.month)
	assert_int(back.money).is_equal(campus.money)
	assert_int(back.buildings.size()).is_equal(campus.buildings.size())
	for i: int in range(campus.buildings.size()):
		var was: Building = campus.buildings[i]
		var now: Building = back.buildings[i]
		assert_object(now.info).is_same(was.info)
		assert_vector(now.pos).is_equal(was.pos)
		assert_float(now.angle).is_equal(was.angle)
		assert_bool(now.underConstruction).is_equal(was.underConstruction)
		assert_int(now.opensAtMonth).is_equal(was.opensAtMonth)


func test_a_building_whose_type_is_gone_is_left_out_and_reported() -> void:
	var data: Dictionary = _playedState(_db()).toDict()
	var records: Array[Dictionary] = [{"id": "hall", "name": "Hall", "diameter": Diameter}]
	var withoutLab: BuildingInfoDB = BuildingInfoDB.new(records)
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, withoutLab))) \
		.is_push_error(Campus.UnknownTypeError % "lab")
	var buildings: Array[Building] = loaded[0].university.campus.buildings
	assert_int(buildings.size()).is_equal(1)
	assert_str(buildings[0].info.id).is_equal("hall")
```

- [ ] **Step 2: Run them to see them fail**

Run RUN-TESTS with `--add tests/SaveTest.gd`.
Expected: a `Parse Error` (for example "Static function "fromDict()" not found in base "GameState""), and 0 cases.

- [ ] **Step 3: `Building`**

Append to `university/src/state/building.gd`:

```gdscript


## The type is saved by id; the campus looks it up when loading.
func toDict() -> Dictionary:
	return {
		"type": info.id,
		"pos": [pos.x, pos.y],
		"angle": angle,
		"underConstruction": underConstruction,
		"opensAtMonth": opensAtMonth,
	}


## A saved building standing again, as the type it was looked up to be.
static func fromDict(data: Dictionary, buildingInfo: BuildingInfo) -> Building:
	var saved: Array = data["pos"] as Array
	var at: Vector2 = Vector2(Variants.toFloat(saved[0]), Variants.toFloat(saved[1]))
	var building: Building = Building.new(buildingInfo, at, Variants.toFloat(data["angle"]))
	building.underConstruction = Variants.toBool(data["underConstruction"])
	building.opensAtMonth = Variants.toInt(data["opensAtMonth"])
	return building
```

- [ ] **Step 4: `Campus`**

In `university/src/state/campus.gd`, add this const below `StartingMoney`:

```gdscript
# Reported when a save names a building type the building data no longer has.
const UnknownTypeError: String = "Campus: saved building type '%s' is not in the building data; leaving it out."
```

Append to the end of `university/src/state/campus.gd`:

```gdscript


func toDict() -> Dictionary:
	var saved: Array[Dictionary] = []
	for building: Building in buildings:
		saved.append(building.toDict())
	return {"month": month, "money": money, "buildings": saved}


## A saved campus, rebuilt without announcing anything: nothing is listening
## yet, and the view makes what it needs from `buildings` when it starts. A
## building whose type is gone from the data is reported and left out.
static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> Campus:
	var campus: Campus = Campus.new()
	campus.month = Variants.toInt(data["month"])
	campus.setMoney(Variants.toInt(data["money"]))
	for saved: Variant in data["buildings"] as Array:
		var entry: Dictionary = saved as Dictionary
		var typeId: String = str(entry["type"])
		var buildingInfo: BuildingInfo = buildingDB.info(typeId)
		if (buildingInfo == null):
			push_error(UnknownTypeError % typeId)
			continue
		campus.buildings.append(Building.fromDict(entry, buildingInfo))
	return campus
```

- [ ] **Step 5: `University`**

Append to `university/src/state/university.gd`:

```gdscript


func toDict() -> Dictionary:
	return {"name": name, "campus": campus.toDict()}


static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> University:
	var university: University = University.new()
	university.name = str(data["name"])
	university.campus = Campus.fromDict(data["campus"] as Dictionary, buildingDB)
	return university
```

- [ ] **Step 6: `GameState`**

Append to `university/src/state/game_state.gd`:

```gdscript


## The clock is saved as its tick count. Speed, pause and the partial tick in
## `remainingDt` belong to the session, so a loaded game starts the way a new
## one does.
func toDict() -> Dictionary:
	return {"tickCount": tickCount, "university": university.toDict()}


static func fromDict(data: Dictionary, buildingDB: BuildingInfoDB) -> GameState:
	var state: GameState = GameState.new()
	state.tickCount = Variants.toInt(data["tickCount"])
	state.university = University.fromDict(data["university"] as Dictionary, buildingDB)
	return state
```

- [ ] **Step 7: Run the tests**

Run RUN-TESTS.
Expected: 104 cases in 13 suites, `0 errors | 0 failures`. There's one more expected `ERROR:` line, from the deliberately missing `lab` type.

If `test_a_round_trip_gives_back_the_same_game` fails, compare the two strings. A number that differs only as `3` against `3.0` means some `fromDict` stored a JSON float where the field is an int: route it through `Variants.toInt`.

- [ ] **Step 8: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/building.gd university/src/state/campus.gd university/src/state/university.gd university/src/state/game_state.gd university/tests/SaveTest.gd university/tests/SaveTest.gd.uid
git commit -m "$(cat <<'EOF'
Write the game state to a dictionary and read it back

Every state class saves itself with toDict and rebuilds with fromDict.
A round trip gives back the same game, and a loaded game plays out
exactly as the saved one would have.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Launch into the start state

`Global` gets `saveGame`, `loadGame` and `newGame`, and loads the start state at launch. `CampusView` builds views for the buildings a loaded game arrives with. The start state is a small authored campus with every building open, using today's four building types.

**Files:**
- Create: `university/data/start_state.json`
- Modify:
  - `university/src/utils/global.gd`
  - `university/src/views/campus_view.gd` (`_ready`)
  - `CLAUDE.md` (lines 50, 65, 69, 70)
- Test: `university/tests/StartStateTest.gd`

**Interfaces:**
- Consumes:
  - `SaveFile.read/write` (Task 2)
  - `GameState.fromDict/toDict` (Task 4)
  - `Campus.canPlace`, `Campus.buildings`
- Produces:
  - `Global.StartStatePath: String` = `"res://data/start_state.json"`
  - `Global.QuickSavePath: String` = `"user://quicksave.json"`
  - `Global.saveGame(path: String) -> bool`
  - `Global.loadGame(path: String) -> bool`: false, with nothing changed, when there's no save at `path`
  - `Global.newGame() -> void`

- [ ] **Step 1: Write the failing test**

Create `university/tests/StartStateTest.gd`:

```gdscript
extends GdUnitTestSuite
## The shipped start state: it loads against the shipped building data, and
## every building in it stands where the placement rules allow. Nothing here
## asserts what the start state contains.


func _startData() -> Dictionary:
	return SaveFile.read(Global.StartStatePath) as Dictionary


func _startState() -> GameState:
	return GameState.fromDict(_startData(), Global.buildingDB)


func test_the_start_state_loads_every_building_it_lists() -> void:
	var campusData: Dictionary = (_startData()["university"] as Dictionary)["campus"] as Dictionary
	var listed: Array = campusData["buildings"] as Array
	assert_int(listed.size()).is_greater(0)
	assert_int(_startState().university.campus.buildings.size()).is_equal(listed.size())


func test_every_start_building_stands_where_it_could_be_placed() -> void:
	# Set down one by one on an empty campus: each must be inside the bounds and
	# clear of the ones before it, so a hand edit cannot sneak in an overlap.
	var check: Campus = Campus.new()
	for building: Building in _startState().university.campus.buildings:
		assert_bool(check.canPlace(building.info, building.pos, building.angle)).is_true()
		check.buildings.append(building)
```

- [ ] **Step 2: Run it to see it fail**

Run RUN-TESTS with `--add tests/StartStateTest.gd`.
Expected: a `Parse Error` about `StartStatePath` not being a member of `Global`, and 0 cases.

- [ ] **Step 3: Write the start state**

Create `university/data/start_state.json`. Every building is open. The layout is within about 100 m of the origin, so the default camera sees all of it. Footprints are `diameter × 0.6 diameter`: admissions 20×12, dorm 30×18, engineering 40×24, dining 60×36. The admissions office is turned 15° (π/12) to show off free rotation.

```json
{
	"tickCount": 0,
	"university": {
		"campus": {
			"buildings": [
				{ "angle": 0.2617993877991494, "opensAtMonth": 0, "pos": [0.0, -60.0], "type": "admissions", "underConstruction": false },
				{ "angle": 0.0, "opensAtMonth": 0, "pos": [60.0, 0.0], "type": "engineering_1", "underConstruction": false },
				{ "angle": 0.0, "opensAtMonth": 0, "pos": [60.0, 40.0], "type": "engineering_1", "underConstruction": false },
				{ "angle": 0.0, "opensAtMonth": 0, "pos": [-10.0, 20.0], "type": "dining_1", "underConstruction": false },
				{ "angle": 0.0, "opensAtMonth": 0, "pos": [-80.0, -30.0], "type": "dorm", "underConstruction": false },
				{ "angle": 0.0, "opensAtMonth": 0, "pos": [-80.0, 0.0], "type": "dorm", "underConstruction": false },
				{ "angle": 0.0, "opensAtMonth": 0, "pos": [-80.0, 30.0], "type": "dorm", "underConstruction": false }
			],
			"money": 50000000,
			"month": 0
		},
		"name": "Pioneer Valley State"
	}
}
```

- [ ] **Step 4: Give `Global` the save API and load the start state at launch**

In `university/src/utils/global.gd`, replace:

```gdscript
# Game data. Built in _ready, after buildingDB: the campus may read the DB
# while it builds itself.
var gameState: GameState
```

with:

```gdscript
# A new game is this save: an authored university that is already running.
const StartStatePath: String = "res://data/start_state.json"
# Where F5 saves and F9 loads, and the console's save/load with no path.
const QuickSavePath: String = "user://quicksave.json"
const NoStartStateError: String = "Global: no start state at '%s'; starting with an empty campus."

# Game data. Loaded from the start state in _ready, after buildingDB, which
# loading needs to look building types up. A load replaces it.
var gameState: GameState
```

Replace:

```gdscript
	buildingDB = BuildingInfoDB.loadFrom(BuildingsPath)
	gameState = GameState.new()
```

with:

```gdscript
	buildingDB = BuildingInfoDB.loadFrom(BuildingsPath)
	gameState = _readGame(StartStatePath)
	if (gameState == null):
		push_error(NoStartStateError % StartStatePath)
		gameState = GameState.new()
```

Add these functions after `_ready`, before `_muteBus`:

```gdscript
## Starts over from the start state.
func newGame() -> void:
	loadGame(StartStatePath)


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
```

- [ ] **Step 5: Make `CampusView` draw the buildings the game starts with**

In `university/src/views/campus_view.gd`, `_ready`, replace:

```gdscript
	gameState.university.campus.BuildingOpened.connect(_onBuildingOpened)
```

with:

```gdscript
	gameState.university.campus.BuildingOpened.connect(_onBuildingOpened)
	# A loaded game arrives with its buildings already standing.
	for building: Building in gameState.university.campus.buildings:
		_onBuildingAdded(building)
```

- [ ] **Step 6: Run the tests**

Run RUN-TESTS.
Expected: 106 cases in 14 suites, `0 errors | 0 failures`.

- [ ] **Step 7: LAUNCH-CHECK: the game opens on the start state**

Run LAUNCH-CHECK. Before `screenshot`, run `echo buildings | nc -w 3 localhost 9999` and `echo state | nc -w 3 localhost 9999`.
Expected:
- The grep prints nothing.
- `buildings` lists 7 buildings, all `open`.
- The screenshot shows seven **solid** (not translucent) boxes around the centre of the view: three small ones in a column on the left, a big one in the middle, two to the right, and a small turned one at the front.
- The status bar reads `Sep, Year 1` and `$50.0M`.

- [ ] **Step 8: Update `CLAUDE.md`**

In `CLAUDE.md`, replace:
```
5. **Dictionary.get() returns Variant.** Never pass it to `int()`, `bool()`, or typed function params. Use helper functions:
```
with:
```
5. **Dictionary.get() returns Variant.** Never pass it to `int()`, `bool()`, or typed function params. Use helper functions: `Variants.toInt`/`toFloat`/`toBool` (`university/src/utils/variants.gd`) are the project's, shaped like this:
```

In `CLAUDE.md`, replace:
```
the script calls `GameState.update(dt)` once a frame, creates and frees one `BuildingView` per `Campus.BuildingAdded`/`BuildingRemoved`,
```
with:
```
the script calls `GameState.update(dt)` once a frame, creates one `BuildingView` for every building already standing when it starts (a loaded game arrives with its buildings) and then creates and frees one per `Campus.BuildingAdded`/`BuildingRemoved`,
```

In `CLAUDE.md`, replace:
```
Declare a table directly in code only until its sheet exists.
```
with:
```
Declare a table directly in code only until its sheet exists.
- **Save/load.** A save is one JSON dictionary. Every state class writes itself with a pure `toDict()` and rebuilds with `static fromDict(data, buildingDB)`:
  - `GameState` saves only `tickCount`: speed, pause and the partial tick belong to the session, so a loaded game starts the way a new one does.
  - `University`, `Campus`, and `Building`, which is saved by type id. A type the building data no longer has is reported (`Campus.UnknownTypeError`) and left out.

  A missing key is an error, never a default. `SaveFile` (`src/utils/`) is the only file I/O. It writes JSON with full-precision floats, so a loaded game plays out bit-identically (`SaveTest` checks it), and `read` answers null when there's no file.

  JSON gives every number back as a float. `Variants` (`src/utils/`) is the one place a parsed Variant becomes an `int`, `float` or `bool`, for saves and CSV cells alike.

  `Global.loadGame(path)` builds the new `GameState`, swaps it into `Global.gameState` and reloads the scene, so every view is rebuilt against the new state rather than rewired. `saveGame(path)` and `newGame()` sit beside it.

  Launching is a new game: `Global._ready` loads `res://data/start_state.json`, an authored save of a campus already built. It's hand-edited, unlike `buildings.txt`. `StartStateTest` loads it against the real building data and checks every building against `canPlace`.
```

In `CLAUDE.md`, replace:
```
- `Global` (autoload, `university/src/utils/global.gd`) owns the single `GameState` and spins up the remote console. Views fetch state through `Global.gameState`.
```
with:
```
- `Global` (autoload, `university/src/utils/global.gd`) owns the single `GameState`, loaded from the start state at launch (see **Save/load**), and spins up the remote console. Views fetch state through `Global.gameState`. After a load that's a different object, which is why loading reloads the scene.
```

- [ ] **Step 9: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/data/start_state.json university/src/utils/global.gd university/src/views/campus_view.gd university/tests/StartStateTest.gd university/tests/StartStateTest.gd.uid CLAUDE.md
git commit -m "$(cat <<'EOF'
Start every new game from an authored start-state save

Global loads res://data/start_state.json at launch and gains saveGame,
loadGame and newGame. A load swaps the game state and reloads the
scene, and the campus view draws the buildings a game arrives with.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: F5/F9 and the `save`, `load` and `newgame` console commands

**Files:**
- Modify:
  - `university/project.godot` (the `[input]` section)
  - `university/src/views/campus_view.gd` (`_unhandled_input`)
  - `university/src/debug/debug_commands.gd`
  - `CLAUDE.md` (the console list and the in-game paragraph)

**Interfaces:**
- Consumes: `Global.saveGame`, `Global.loadGame`, `Global.newGame`, `Global.QuickSavePath`, `Global.StartStatePath` (Task 5); `University.name` (Task 3).
- Produces: input actions `QuickSave` (F5) and `QuickLoad` (F9); console commands `save [path]`, `load [path]`, `newgame`. `state` also prints the university's name.

No new unit tests: the rules are all in `Global` and the state, which Tasks 4 and 5 cover. This task is checked end to end in the running game (Step 5).

- [ ] **Step 1: Add the input actions**

In `university/project.godot`, `[input]` section, after the closing `}` of `SpeedDown={ … }`, add:

```
QuickSave={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194336,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
QuickLoad={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194340,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

(4194336 is `KEY_F5` and 4194340 is `KEY_F9`, probed in 4.7.)

- [ ] **Step 2: Handle them in `CampusView`**

In `university/src/views/campus_view.gd`, replace:

```gdscript
	elif (event.is_action_pressed("SpeedDown")):
		gameState.changeSpeed(-1)
```

with:

```gdscript
	elif (event.is_action_pressed("SpeedDown")):
		gameState.changeSpeed(-1)
	elif (event.is_action_pressed("QuickSave")):
		Global.saveGame(Global.QuickSavePath)
	elif (event.is_action_pressed("QuickLoad")):
		Global.loadGame(Global.QuickSavePath)
```

- [ ] **Step 3: Add the console commands**

In `university/src/debug/debug_commands.gd`:

Below `const KeepMoney: int = -1`, add:

```gdscript
# save's and load's sentinel: no path given, use the quicksave.
const NoPath: String = ""
```

In `_init`, after the `advance` registration line, add:

```gdscript
	LimboConsole.register_command(_save, "save", "Save the game to [path] (the quicksave when none is given).")
	LimboConsole.register_command(_load, "load", "Load the game saved at [path] (the quicksave when none is given).")
	LimboConsole.register_command(_newGame, "newgame", "Start over from the start state.")
```

Replace the `state` registration's description string `"Print the armed tool, the ghost angle, the selected and hovered buildings, the camera, the time and the money."` with `"Print the armed tool, the ghost angle, the selected and hovered buildings, the camera, the time, the money and the university's name."`.

In `_state()`, after the last `LimboConsole.print_line(...)` call (the one that prints Time and Money), add:

```gdscript
	LimboConsole.print_line("University: %s" % _gameState().university.name)
```

After `_advance`, add:

```gdscript
func _savePath(path: String) -> String:
	return Global.QuickSavePath if (path == NoPath) else path


func _save(path: String = NoPath) -> void:
	var target: String = _savePath(path)
	LimboConsole.print_line(("Saved to %s" if (Global.saveGame(target)) else "Could not save to %s") % target)


func _load(path: String = NoPath) -> void:
	var target: String = _savePath(path)
	LimboConsole.print_line(("Loaded %s" if (Global.loadGame(target)) else "No save at %s") % target)


func _newGame() -> void:
	Global.newGame()
	LimboConsole.print_line("New game from %s" % Global.StartStatePath)
```

- [ ] **Step 4: Run the tests**

Run RUN-TESTS.
Expected: 106 cases in 14 suites, `0 errors | 0 failures`.

- [ ] **Step 5: LAUNCH-CHECK: save, change, load, and new game, end to end**

Remove any old quicksave first: `rm -f "$HOME/Library/Application Support/Godot/app_userdata/University/quicksave.json"`.

Launch as in LAUNCH-CHECK, then run these commands one at a time with `echo "<command>" | nc -w 3 localhost 9999`, reading each reply:

1. `pause`, then `screenshot`, then `cp /tmp/university/screenshot.png /tmp/university/start.png`. That's the start state as launched.
2. `load`. Expected: `No save at user://quicksave.json`, with nothing changed.
3. `build dorm 0 100 0`. Expected: `Placed dorm`.
4. `action QuickSave down`, then `action QuickSave up`. This is F5. Check it: `ls "$HOME/Library/Application Support/Godot/app_userdata/University/quicksave.json"` shows the file.
5. `destroy 7`. That's the new dorm; `buildings` now lists 7.
6. `action QuickLoad down`, then `action QuickLoad up`. This is F9. Then `buildings`. Expected: 8 buildings; the last is `dorm (0.0, 100.0) 0.0 deg, under construction, opens Feb, Year 1`.
7. `state`. Expected: `University: Pioneer Valley State`, and `running`, because a load starts the way a new game does.
8. `pause`, then `screenshot`, then LOOK. The eighth box stands at the front, **translucent**.
9. `newgame`, then `pause`, then `buildings`. Expected: 7 buildings, all open. Then `screenshot`.
10. Pixel-diff the start and the new game:
    ```bash
    python3 -c "from PIL import Image, ImageChops; a=Image.open('/tmp/university/start.png').convert('RGB'); b=Image.open('/tmp/university/screenshot.png').convert('RGB'); print(ImageChops.difference(a,b).getbbox())"
    ```
    Expected: `None`. The new game is bit-identical to the launch. If the only difference is the date or money text in the status bar, a month rolled over between the two shots: rerun steps 1 and 9 faster.
11. `pkill -f "Godot"`, then `grep -nE "SCRIPT ERROR|Parse Error|ERROR|WARNING" /tmp/university/run.log`. Expected: no output.

- [ ] **Step 6: Update `CLAUDE.md`**

In `CLAUDE.md`, replace:
```
- `state` — print the armed tool, the ghost angle in degrees, the selected and hovered building indices, the camera's target, distance and yaw, and the time (date, paused/running, speed) and money. Read-only.
```
with:
```
- `state` — print the armed tool, the ghost angle in degrees, the selected and hovered building indices, the camera's target, distance and yaw, the time (date, paused/running, speed), the money and the university's name. Read-only.
```

In `CLAUDE.md`, replace:
```
- `advance <months>` — step the sim to the start of the month `<months>` ahead, paused or not.
```
with:
```
- `advance <months>` — step the sim to the start of the month `<months>` ahead, paused or not.
- `save [path]` — save the game to `<path>`, or to the quicksave (`user://quicksave.json`) when none is given. `save res://data/start_state.json` writes the start state from a running game; hand-edit it afterwards (open buildings, tick 0).
- `load [path]` — load the game saved at `<path>`, or the quicksave. Reloads the scene, so the camera and any armed tool or selection start fresh.
- `newgame` — start over from the start state.
```

In `CLAUDE.md`, replace:
```
while paused. Esc with nothing armed and nothing selected quits.
```
with:
```
while paused. Esc with nothing armed and nothing selected quits. F5 saves the
game to the quicksave and F9 loads it back; every launch is a new game, from
the start state.
```

- [ ] **Step 7: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/project.godot university/src/views/campus_view.gd university/src/debug/debug_commands.gd CLAUDE.md
git commit -m "$(cat <<'EOF'
Save with F5, load with F9, and save/load/newgame in the console

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
EOF
)"
```
