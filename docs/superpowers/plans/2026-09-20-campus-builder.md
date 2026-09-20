# Campus Builder (First Pass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2D starter template with a 3D campus: grass plane with a 10 m grid, Anno-style camera, building types loaded from the Google Sheet, build menu, free placement at any rotation, selection with an info panel, and destroy.

**Architecture:** Pure state classes (`BuildingInfo`/`BuildingInfoDB`, `OrientedRect`, `Building`, `Campus`) hold every rule and are unit-tested without the engine. Views (`CampusView`, `GameCamera`, `GroundView`, `BuildingView`, `BuildController`, UI scenes) read state and call command methods on it (`Campus.place`, `Campus.destroy`); state answers with signals and never knows a view exists.

**Tech Stack:** Godot 4.7, fully typed GDScript, gdUnit4, LimboConsole + TCP remote console, Python 3 for the sheet export.

**Spec:** `docs/superpowers/specs/2026-09-20-campus-builder-design.md` — read it and `CLAUDE.md` before starting any task.

## Global Constraints

- Repo root `/Users/noel/Development/University/game`; Godot project `university/`. All `res://` paths are relative to `university/`.
- `CLAUDE.md` governs: camelCase variables/functions, PascalCase classes/constants/signals, parenthesized conditions `if (x):`, fully typed GDScript (unsafe access is an error), no magic numbers (named `const`), tabs for indentation, `%UniqueName` node access, UI layout in `.tscn`.
- State classes (`src/state/`, `src/data/`) are plain `class_name` classes: no `extends Node`, no `Input`, no scene tree. State never references a view.
- 1 unit = 1 metre, Y up. State positions are `Vector2` with `x` = world X, `y` = world Z. A rect's `angle` (radians) is the direction of its long axis in that plane: `(cos a, sin a)`. The view converts in one place: `rotation.y = -angle`.
- Never guess a Godot API. If unsure a property/method exists in 4.7, grep this repo or `/Users/noel/Development/Prototypes/Heist3D/game/heist` for a use of it first.
- Never delete `.godot/`, and never delete or overwrite anything under `university/res/`.
- Tests assert behavior and relationships, never the values in `data/buildings.txt`.
- Every commit message ends with:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01KawZT2EUueZde5GiTG86tq
  ```
  Commit locally; do not push.

### Named procedures (referenced by every task)

**REGISTER** — after adding/removing any `class_name` script or hand-written `.tscn`:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --editor --quit-after 20 2>&1 | grep -E "ERROR|WARNING|Parse Error" ; true
```
Expected: no output from the grep.

**RUN-TESTS** — note the reported test-case total before and after; a total that drops means a suite failed to parse:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ 2>&1 | grep -E "Overall Summary|Executed test|FAILED|ERROR|Parse Error|SCRIPT ERROR"
```

**LAUNCH-CHECK** — hidden window, read stdout, screenshot, kill:
```
cd /Users/noel/Development/University/game
(for i in $(seq 1 20); do sleep 0.2; osascript -e 'tell application "System Events" to set visible of process "Godot" to false' 2>/dev/null; done) &
./bin/run.sh > /tmp/university_run.log 2>&1 &
sleep 6
grep -nE "SCRIPT ERROR|Parse Error|ERROR|WARNING" /tmp/university_run.log
# ... task-specific console commands via: echo "<command>" | nc -w 3 localhost 9999
echo screenshot | nc -w 3 localhost 9999
pkill -f "Godot"
```
Expected: the grep prints nothing. Then LOOK at `/tmp/university/screenshot.png` with the Read tool. Always `pkill -f "Godot"` when done.

## File Structure

```
bin/GetDataFromGoogleSheets.py            rewrite: exports Buildings tab -> university/data/buildings.txt
university/data/buildings.txt             generated, committed, never hand-edited
university/src/data/building_info.gd      one building type, parsed from a CSV row
university/src/data/building_info_db.gd   id -> BuildingInfo, sheet-ordered list, loadFrom(path)
university/src/state/oriented_rect.gd     all rectangle maths: corners, contains, overlaps, within, rayHit
university/src/state/building.gd          a placed building: info, pos, angle, rect()
university/src/state/campus.gd            buildings + canPlace/place/destroy/pick + signals   (replaces level.gd)
university/src/state/game_state.gd        modify: level -> campus
university/src/utils/global.gd            modify: owns buildingDB
university/src/views/campus_view.gd/.tscn main scene: lights, ground, camera, buildings root, controller, UI (replaces level_view)
university/src/views/game_camera.gd       orbit camera, ported from Heist3D
university/src/views/ground_view.gd       sizes the ground plane from Campus.Size
university/src/views/ground.gdshader      grass + 10 m grid
university/src/views/building_view.gd     box for a building; also the placement ghost
university/src/views/build_controller.gd  input -> commands; tool state, ghost, hover, selection
university/src/ui/status_bar.tscn         modify: add placeholder Money labels
university/src/ui/build_menu.gd/.tscn     bottom-left Build toggle, building buttons, Destroy
university/src/ui/info_panel.gd/.tscn     bottom-right selected-building name
university/src/debug/debug_commands.gd    modify: build, destroy, select, buildings, tool, camera, mouse*
university/tests/*.gd                     BuildingInfoTest, OrientedRectTest, CampusTest, GameCameraTest, BuildControllerTest
DELETED: src/state/{level,player,enemy}.gd, src/views/{level_view,player_view,enemy_view}.{gd,tscn}, tests/SimpleTest.gd (+ their .uid files)
```

---

### Task 1: Building data pipeline (`BuildingInfo`, `BuildingInfoDB`, sheet export)

**Files:**
- Modify (rewrite): `bin/GetDataFromGoogleSheets.py`
- Create: `university/data/buildings.txt` (by running the script)
- Create: `university/src/data/building_info.gd`, `university/src/data/building_info_db.gd`
- Create: `university/tests/BuildingInfoTest.gd`, `university/tests/fixtures/buildings_fixture.txt`
- Modify: `university/src/utils/global.gd`
- Delete: `university/tests/SimpleTest.gd`, `university/tests/SimpleTest.gd.uid`

**Interfaces:**
- Consumes: `CsvLoader.load_csv(path: String) -> Array[Dictionary]` (exists; blank cells arrive as `""`, ints as `int`, decimals as `float`).
- Produces:
  - `BuildingInfo.new(data: Dictionary)` with fields `id: String`, `name: String`, `category: String`, `cost: int`, `buildTime: float`, `diameter: float`
  - `BuildingInfoDB.new(records: Array[Dictionary])`, `.db: Dictionary[String, BuildingInfo]`, `.all: Array[BuildingInfo]`, `.info(id: String) -> BuildingInfo` (null when unknown), `static BuildingInfoDB.loadFrom(path: String) -> BuildingInfoDB`
  - `Global.buildingDB: BuildingInfoDB`

- [ ] **Step 1: Rewrite the export script**

Replace the whole of `bin/GetDataFromGoogleSheets.py` with (tabs for indentation):

```python
#!/usr/bin/env python3

# Exports the University Google Sheet's data tabs to the committed data files
# the game loads. The Sheet is the SOURCE OF TRUTH; these .txt files are only
# its export — never hand-edit them (see CLAUDE.md). Run:
#     python3 bin/GetDataFromGoogleSheets.py
#
# Notes:
# - Written as .txt, NOT .csv: Godot auto-imports *.csv as a Translation resource,
#   which relocates the file and breaks FileAccess reads (see src/utils/csv_loader.gd).
# - Uses the standard /export CSV endpoint (keyed by numeric gid), which returns the
#   sheet's raw cell values as clean, unquoted CSV. The sheet must be shared
#   "anyone with the link can view"; a private sheet returns an HTML login page,
#   which this script detects and aborts on rather than writing garbage over the data.

import os
import urllib.request

# "University" spreadsheet:
# https://docs.google.com/spreadsheets/d/1SrPqAyHSve_LWaLmMrgl6orvEwqlx_luDhub1MSIFio/
KEY = '1SrPqAyHSve_LWaLmMrgl6orvEwqlx_luDhub1MSIFio'

# (tab gid, output path relative to this script's directory).
EXPORTS = [
	(948960558, '../university/data/buildings.txt'),
]


def sheetCsvUrl(key, gid):
	return 'https://docs.google.com/spreadsheets/d/%s/export?format=csv&gid=%s' % (key, gid)


def fetch(url):
	with urllib.request.urlopen(urllib.request.Request(url)) as response:
		return response.read().decode('utf-8')


def exportSheet(key, gid, filename):
	data = fetch(sheetCsvUrl(key, gid))
	if '<html' in data[:200].lower():
		raise SystemExit(
			"ERROR: got an HTML page, not CSV, for gid %s — the sheet must be shared "
			"'anyone with the link can view'." % gid)
	# Normalize CRLF -> LF so the committed file stays LF-only, and end with one newline.
	data = data.replace('\r\n', '\n').replace('\r', '\n').rstrip('\n') + '\n'
	path = os.path.join(os.path.dirname(__file__), filename)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, 'w') as f:
		f.write(data)
	print('wrote %s (%d bytes)' % (filename, len(data)))


if __name__ == '__main__':
	for gid, filename in EXPORTS:
		exportSheet(KEY, gid, filename)
```

- [ ] **Step 2: Run it**

Run: `cd /Users/noel/Development/University/game && python3 bin/GetDataFromGoogleSheets.py && cat university/data/buildings.txt`
Expected: `wrote ../university/data/buildings.txt (...)`, and the file's first line is `id,name,category,cost,buildTime,diameter` followed by one row per building.

- [ ] **Step 3: Write the fixture and the failing tests**

`university/tests/fixtures/buildings_fixture.txt` (arbitrary values — NOT the game's data):
```
id,name,category,cost,buildTime,diameter
alpha,Alpha Hall,Test,,,12
beta,Beta Hall,Test,150,2.5,7.5
```

`university/tests/BuildingInfoTest.gd`:
```gdscript
extends GdUnitTestSuite
## Parsing and lookup of building definitions. Fixtures are arbitrary records;
## nothing here asserts what the real data file holds.

const FixturePath: String = "res://tests/fixtures/buildings_fixture.txt"
const Epsilon: float = 0.0001


func _records() -> Array[Dictionary]:
	var records: Array[Dictionary] = [
		{"id": "first", "name": "First", "category": "Cat", "cost": "", "buildTime": "", "diameter": 12},
		{"id": "second", "name": "Second", "category": "Cat", "cost": 150, "buildTime": 2.5, "diameter": 7.5},
	]
	return records


func test_blank_numeric_cells_coerce_to_zero() -> void:
	var info: BuildingInfo = BuildingInfo.new(_records()[0])
	assert_int(info.cost).is_equal(0)
	assert_float(info.buildTime).is_equal_approx(0.0, Epsilon)


func test_int_cell_is_read_as_float_diameter() -> void:
	var info: BuildingInfo = BuildingInfo.new(_records()[0])
	assert_float(info.diameter).is_equal_approx(12.0, Epsilon)


func test_missing_optional_columns_default() -> void:
	var info: BuildingInfo = BuildingInfo.new({"id": "bare", "name": "Bare"})
	assert_str(info.category).is_equal("")
	assert_float(info.diameter).is_equal_approx(0.0, Epsilon)


func test_lookup_by_id() -> void:
	var buildingDB: BuildingInfoDB = BuildingInfoDB.new(_records())
	assert_str(buildingDB.info("second").name).is_equal("Second")
	assert_object(buildingDB.info("nope")).is_null()


func test_all_keeps_record_order() -> void:
	var buildingDB: BuildingInfoDB = BuildingInfoDB.new(_records())
	assert_int(buildingDB.all.size()).is_equal(2)
	assert_str(buildingDB.all[0].id).is_equal("first")
	assert_str(buildingDB.all[1].id).is_equal("second")


func test_load_from_file_parses_rows_and_blanks() -> void:
	var buildingDB: BuildingInfoDB = BuildingInfoDB.loadFrom(FixturePath)
	assert_int(buildingDB.all.size()).is_equal(2)
	assert_int(buildingDB.info("alpha").cost).is_equal(0)
	assert_int(buildingDB.info("beta").cost).is_equal(150)
	assert_float(buildingDB.info("beta").diameter).is_equal_approx(7.5, Epsilon)
```

Delete the placeholder suite: `rm university/tests/SimpleTest.gd university/tests/SimpleTest.gd.uid`

- [ ] **Step 4: Run tests to verify they fail**

Run: RUN-TESTS
Expected: a script/parse error naming `BuildingInfo` (class not declared); no passing BuildingInfoTest cases.

- [ ] **Step 5: Implement**

`university/src/data/building_info.gd`:
```gdscript
class_name BuildingInfo
## One building type's definition, parsed from a row of the Buildings tab
## (values arrive as Variant via CsvLoader). The Sheet is the source of truth —
## see CLAUDE.md's Data section.

var id: String
var name: String
var category: String
# Whole dollars.
var cost: int
# Seconds.
var buildTime: float
# Metres: the footprint's longest side (see Building.rectFor).
var diameter: float


func _init(data: Dictionary) -> void:
	id = str(data["id"])
	name = str(data["name"])
	category = str(data.get("category", ""))
	cost = _toInt(data.get("cost", 0))
	buildTime = _toFloat(data.get("buildTime", 0.0))
	diameter = _toFloat(data.get("diameter", 0.0))


# A blank cell arrives as "", so anything that is not a number reads as zero.
static func _toInt(value: Variant) -> int:
	if (value is int):
		return value
	if (value is float):
		return int(value as float)
	return 0


static func _toFloat(value: Variant) -> float:
	if (value is float):
		return value
	if (value is int):
		return float(value as int)
	return 0.0
```

`university/src/data/building_info_db.gd`:
```gdscript
class_name BuildingInfoDB
## id -> BuildingInfo plus the sheet-ordered list (build-menu order). The sole
## source of building definitions.

var db: Dictionary[String, BuildingInfo]
var all: Array[BuildingInfo]


func _init(records: Array[Dictionary]) -> void:
	for data: Dictionary in records:
		var buildingInfo: BuildingInfo = BuildingInfo.new(data)
		db[buildingInfo.id] = buildingInfo
		all.append(buildingInfo)


func info(id: String) -> BuildingInfo:
	return db.get(id) as BuildingInfo


# Named loadFrom (not load) to avoid shadowing GDScript's global load().
static func loadFrom(path: String) -> BuildingInfoDB:
	return BuildingInfoDB.new(CsvLoader.load_csv(path))
```

In `university/src/utils/global.gd`, replace the `# Static data` block and `_ready`'s first lines so the DB is loaded first:
```gdscript
# Static data
const BuildingsPath: String = "res://data/buildings.txt"
var buildingDB: BuildingInfoDB
```
and at the very top of `_ready()`:
```gdscript
	buildingDB = BuildingInfoDB.loadFrom(BuildingsPath)
```

- [ ] **Step 6: Register classes, run tests**

Run: REGISTER, then RUN-TESTS
Expected: `6 test cases | 0 errors | 0 failures`.

- [ ] **Step 7: Commit**

```bash
cd /Users/noel/Development/University/game
git add -A bin university/data university/src/data university/src/utils/global.gd university/tests
git commit   # message: "Load building definitions from the Google Sheet" + trailer
```

---

### Task 2: `OrientedRect` — all rectangle maths

**Files:**
- Create: `university/src/state/oriented_rect.gd`
- Test: `university/tests/OrientedRectTest.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `OrientedRect.new(rectCenter: Vector2, rectSize: Vector2, rectAngle: float)`; fields `center`, `size`, `angle`; `axisX() -> Vector2`, `axisY() -> Vector2`, `toLocal(point: Vector2) -> Vector2`, `corners() -> PackedVector2Array`, `contains(point: Vector2) -> bool`, `overlaps(other: OrientedRect) -> bool`, `within(bounds: Rect2) -> bool`, `rayHit(origin: Vector3, dir: Vector3, height: float) -> float`; consts `Epsilon`, `NoHit` (-1.0).

- [ ] **Step 1: Write the failing tests**

`university/tests/OrientedRectTest.gd`:
```gdscript
extends GdUnitTestSuite
## Rotated-rectangle maths on the ground plane (x = world X, y = world Z).
## Fixtures are arbitrary sizes; assertions are geometric relationships.

const Epsilon: float = 0.0001
const Long: float = 10.0
const Short: float = 2.0
const BoxHeight: float = 10.0
const QuarterTurn: float = PI / 2.0
const EighthTurn: float = PI / 4.0


func _bar(center: Vector2, angle: float) -> OrientedRect:
	return OrientedRect.new(center, Vector2(Long, Short), angle)


func test_axis_aligned_rects_overlap() -> void:
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(_bar(Vector2(Long / 2.0, 0.0), 0.0))).is_true()


func test_separated_rects_do_not_overlap() -> void:
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(_bar(Vector2(Long * 2.0, 0.0), 0.0))).is_false()


func test_rects_touching_along_an_edge_do_not_overlap() -> void:
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(_bar(Vector2(0.0, Short), 0.0))).is_false()


func test_overlap_is_symmetric() -> void:
	var a: OrientedRect = _bar(Vector2.ZERO, EighthTurn)
	var b: OrientedRect = _bar(Vector2(3.0, 1.0), 0.0)
	assert_bool(a.overlaps(b)).is_equal(b.overlaps(a))


func test_rotated_corner_poking_into_a_rect_overlaps() -> void:
	# A diamond whose tip reaches into the bar from above.
	var diamond: OrientedRect = OrientedRect.new(Vector2(0.0, 3.0), Vector2(4.0, 4.0), EighthTurn)
	assert_bool(_bar(Vector2.ZERO, 0.0).overlaps(diamond)).is_true()


func test_rects_with_overlapping_bounding_boxes_can_still_be_separate() -> void:
	# A thin diagonal bar; the square sits inside the bar's bounding box but
	# clear of the bar itself. Only a separating-axis test gets this right.
	var diagonal: OrientedRect = _bar(Vector2.ZERO, EighthTurn)
	var square: OrientedRect = OrientedRect.new(Vector2(3.0, -3.0), Vector2(2.0, 2.0), 0.0)
	assert_bool(diagonal.overlaps(square)).is_false()


func test_contains_follows_the_rotation() -> void:
	var upright: OrientedRect = _bar(Vector2.ZERO, QuarterTurn)
	assert_bool(upright.contains(Vector2(0.0, 4.0))).is_true()
	assert_bool(upright.contains(Vector2(4.0, 0.0))).is_false()


func test_corners_are_at_half_extents_from_the_center() -> void:
	var rect: OrientedRect = _bar(Vector2(5.0, 5.0), EighthTurn)
	var halfDiagonal: float = Vector2(Long, Short).length() / 2.0
	for corner: Vector2 in rect.corners():
		assert_float(corner.distance_to(rect.center)).is_equal_approx(halfDiagonal, Epsilon)


func test_within_bounds() -> void:
	var bounds: Rect2 = Rect2(-10.0, -10.0, 20.0, 20.0)
	assert_bool(_bar(Vector2.ZERO, 0.0).within(bounds)).is_true()
	assert_bool(_bar(Vector2(8.0, 0.0), 0.0).within(bounds)).is_false()
	# Fits lying down, pokes out once turned upright near the top edge.
	assert_bool(_bar(Vector2(0.0, 8.0), 0.0).within(bounds)).is_true()
	assert_bool(_bar(Vector2(0.0, 8.0), QuarterTurn).within(bounds)).is_false()


func test_ray_from_above_hits_the_roof() -> void:
	var rect: OrientedRect = _bar(Vector2.ZERO, 0.0)
	var hit: float = rect.rayHit(Vector3(0.0, 50.0, 0.0), Vector3.DOWN, BoxHeight)
	assert_float(hit).is_equal_approx(50.0 - BoxHeight, Epsilon)


func test_ray_from_the_side_hits_the_wall() -> void:
	var rect: OrientedRect = _bar(Vector2.ZERO, 0.0)
	var hit: float = rect.rayHit(Vector3(-50.0, 5.0, 0.0), Vector3.RIGHT, BoxHeight)
	assert_float(hit).is_equal_approx(50.0 - Long / 2.0, Epsilon)


func test_ray_hit_follows_the_rotation() -> void:
	var upright: OrientedRect = _bar(Vector2.ZERO, QuarterTurn)
	var hit: float = upright.rayHit(Vector3(-50.0, 5.0, 0.0), Vector3.RIGHT, BoxHeight)
	assert_float(hit).is_equal_approx(50.0 - Short / 2.0, Epsilon)


func test_ray_that_passes_beside_or_points_away_misses() -> void:
	var rect: OrientedRect = _bar(Vector2.ZERO, 0.0)
	assert_float(rect.rayHit(Vector3(-50.0, 5.0, 20.0), Vector3.RIGHT, BoxHeight)).is_equal(OrientedRect.NoHit)
	assert_float(rect.rayHit(Vector3(-50.0, 5.0, 0.0), Vector3.LEFT, BoxHeight)).is_equal(OrientedRect.NoHit)
	assert_float(rect.rayHit(Vector3(0.0, 50.0, 0.0), Vector3.UP, BoxHeight)).is_equal(OrientedRect.NoHit)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: RUN-TESTS
Expected: script error naming `OrientedRect`; the 6 BuildingInfoTest cases still pass.

- [ ] **Step 3: Implement**

`university/src/state/oriented_rect.gd`:
```gdscript
class_name OrientedRect
## A rectangle on the ground plane (x = world X, y = world Z) turned by
## `angle` radians: its own x axis points along (cos angle, sin angle). The one
## place rotated-rectangle maths lives — overlap, containment and ray picking.

# Slack for comparisons, in metres: rects that only touch do not overlap.
const Epsilon: float = 0.0001
const NoHit: float = -1.0

var center: Vector2
# Full extents along the rect's own x and y axes.
var size: Vector2
var angle: float


func _init(rectCenter: Vector2, rectSize: Vector2, rectAngle: float) -> void:
	center = rectCenter
	size = rectSize
	angle = rectAngle


func axisX() -> Vector2:
	return Vector2(cos(angle), sin(angle))


func axisY() -> Vector2:
	return Vector2(-sin(angle), cos(angle))


## The point in the rect's own frame: origin at the centre, axes along its sides.
func toLocal(point: Vector2) -> Vector2:
	var offset: Vector2 = point - center
	return Vector2(offset.dot(axisX()), offset.dot(axisY()))


func corners() -> PackedVector2Array:
	var halfX: Vector2 = axisX() * size.x / 2.0
	var halfY: Vector2 = axisY() * size.y / 2.0
	return PackedVector2Array([
		center - halfX - halfY,
		center + halfX - halfY,
		center + halfX + halfY,
		center - halfX + halfY,
	])


func contains(point: Vector2) -> bool:
	var local: Vector2 = toLocal(point)
	return absf(local.x) <= size.x / 2.0 + Epsilon and absf(local.y) <= size.y / 2.0 + Epsilon


## Separating-axis test over both rects' side directions.
func overlaps(other: OrientedRect) -> bool:
	var between: Vector2 = other.center - center
	for axis: Vector2 in [axisX(), axisY(), other.axisX(), other.axisY()]:
		var gap: float = absf(between.dot(axis)) - _reach(axis) - other._reach(axis)
		if (gap >= -Epsilon):
			return false
	return true


# Half the rect's extent along a unit axis.
func _reach(axis: Vector2) -> float:
	return (absf(axisX().dot(axis)) * size.x + absf(axisY().dot(axis)) * size.y) / 2.0


func within(bounds: Rect2) -> bool:
	for corner: Vector2 in corners():
		if (corner.x < bounds.position.x - Epsilon or corner.x > bounds.end.x + Epsilon):
			return false
		if (corner.y < bounds.position.y - Epsilon or corner.y > bounds.end.y + Epsilon):
			return false
	return true


## Distance along a ray (unit `dir`) to the box standing on the ground with
## this footprint and the given height, or NoHit. The ray is turned into the
## rect's frame, where the box is axis-aligned, and clipped slab by slab.
func rayHit(origin: Vector3, dir: Vector3, height: float) -> float:
	var localOrigin: Vector2 = toLocal(Vector2(origin.x, origin.z))
	var flatDir: Vector2 = Vector2(dir.x, dir.z)
	var from: Vector3 = Vector3(localOrigin.x, origin.y, localOrigin.y)
	var along: Vector3 = Vector3(flatDir.dot(axisX()), dir.y, flatDir.dot(axisY()))
	var low: Vector3 = Vector3(-size.x / 2.0, 0.0, -size.y / 2.0)
	var high: Vector3 = Vector3(size.x / 2.0, height, size.y / 2.0)
	var near: float = 0.0
	var far: float = INF
	for i: int in range(3):
		var start: float = from[i]
		var step: float = along[i]
		var slabLow: float = low[i]
		var slabHigh: float = high[i]
		if (absf(step) < Epsilon):
			if (start < slabLow or start > slabHigh):
				return NoHit
			continue
		var enter: float = (slabLow - start) / step
		var leave: float = (slabHigh - start) / step
		near = maxf(near, minf(enter, leave))
		far = minf(far, maxf(enter, leave))
	if (near > far):
		return NoHit
	return near
```

- [ ] **Step 4: Register, run tests**

Run: REGISTER, then RUN-TESTS
Expected: `19 test cases | 0 errors | 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add university/src/state/oriented_rect.gd* university/tests/OrientedRectTest.gd*
git commit   # "Add OrientedRect: overlap, containment and ray picking" + trailer
```

---

### Task 3: `Building` and `Campus`

**Files:**
- Create: `university/src/state/building.gd`, `university/src/state/campus.gd`
- Test: `university/tests/CampusTest.gd`

(`Level`, `GameState` and the old views are untouched here so the game still launches; Task 4 swaps them.)

**Interfaces:**
- Consumes: `BuildingInfo` (Task 1), `OrientedRect` (Task 2).
- Produces:
  - `Building.new(buildingInfo: BuildingInfo, at: Vector2, facing: float)`; fields `info`, `pos`, `angle`; `rect() -> OrientedRect`; `static Building.rectFor(buildingInfo: BuildingInfo, at: Vector2, facing: float) -> OrientedRect`; consts `DepthRatio` (0.6), `Height` (10.0).
  - `Campus`: `signal BuildingAdded(building: Building)`, `signal BuildingRemoved(building: Building)`, `const Size: float = 1000.0`, `buildings: Array[Building]`, `static bounds() -> Rect2`, `canPlace(info, pos, angle) -> bool`, `place(info, pos, angle) -> Building` (null when refused), `destroy(building: Building) -> void`, `pick(origin: Vector3, dir: Vector3) -> Building` (null on miss), `tick(_dt: float)`, `update(_dt: float)`.

- [ ] **Step 1: Write the failing tests**

`university/tests/CampusTest.gd`:
```gdscript
extends GdUnitTestSuite
## Placement, destruction and picking rules. The fixture building type is
## arbitrary; assertions are about rules and relationships, not content.

const Diameter: float = 20.0
const QuarterTurn: float = PI / 2.0
const Overhead: float = 100.0


func _info() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter})


func test_place_on_empty_ground_adds_the_building() -> void:
	var campus: Campus = Campus.new()
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	assert_object(building).is_not_null()
	assert_array(campus.buildings).contains_exactly([building])


func test_place_is_refused_on_overlap() -> void:
	var campus: Campus = Campus.new()
	campus.place(_info(), Vector2.ZERO, 0.0)
	assert_object(campus.place(_info(), Vector2(Diameter / 2.0, 0.0), 0.0)).is_null()
	assert_int(campus.buildings.size()).is_equal(1)


func test_rotation_decides_whether_a_neighbour_fits() -> void:
	var campus: Campus = Campus.new()
	campus.place(_info(), Vector2.ZERO, 0.0)
	# Beside the first along z with a gap: lying the same way it fits, turned
	# a quarter its long side reaches across the gap.
	var depth: float = Diameter * Building.DepthRatio
	var beside: Vector2 = Vector2(0.0, depth + 1.0)
	assert_bool(campus.canPlace(_info(), beside, 0.0)).is_true()
	assert_bool(campus.canPlace(_info(), beside, QuarterTurn)).is_false()


func test_place_is_refused_outside_the_bounds() -> void:
	var campus: Campus = Campus.new()
	var edge: Vector2 = Vector2(Campus.bounds().end.x, 0.0)
	assert_object(campus.place(_info(), edge, 0.0)).is_null()


func test_signals_carry_the_building() -> void:
	var campus: Campus = Campus.new()
	var added: Array[Building] = []
	var removed: Array[Building] = []
	campus.BuildingAdded.connect(func(b: Building) -> void: added.append(b))
	campus.BuildingRemoved.connect(func(b: Building) -> void: removed.append(b))
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	campus.destroy(building)
	assert_array(added).contains_exactly([building])
	assert_array(removed).contains_exactly([building])


func test_a_refused_place_emits_nothing() -> void:
	var campus: Campus = Campus.new()
	campus.place(_info(), Vector2.ZERO, 0.0)
	var added: Array[Building] = []
	campus.BuildingAdded.connect(func(b: Building) -> void: added.append(b))
	campus.place(_info(), Vector2.ZERO, 0.0)
	assert_array(added).is_empty()


func test_destroy_frees_the_ground() -> void:
	var campus: Campus = Campus.new()
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	campus.destroy(building)
	assert_array(campus.buildings).is_empty()
	assert_bool(campus.canPlace(_info(), Vector2.ZERO, 0.0)).is_true()


func test_destroying_a_building_not_on_the_campus_is_ignored() -> void:
	var campus: Campus = Campus.new()
	var removed: Array[Building] = []
	campus.BuildingRemoved.connect(func(b: Building) -> void: removed.append(b))
	campus.destroy(Building.new(_info(), Vector2.ZERO, 0.0))
	assert_array(removed).is_empty()


func test_pick_returns_the_building_under_the_ray() -> void:
	var campus: Campus = Campus.new()
	var building: Building = campus.place(_info(), Vector2(50.0, 50.0), 0.0)
	assert_object(campus.pick(Vector3(50.0, Overhead, 50.0), Vector3.DOWN)).is_same(building)
	assert_object(campus.pick(Vector3(-50.0, Overhead, -50.0), Vector3.DOWN)).is_null()


func test_pick_prefers_the_nearer_of_two_buildings_along_the_ray() -> void:
	var campus: Campus = Campus.new()
	var far: Building = campus.place(_info(), Vector2(100.0, 0.0), 0.0)
	var near: Building = campus.place(_info(), Vector2(50.0, 0.0), 0.0)
	var eyeHeight: float = Building.Height / 2.0
	assert_object(campus.pick(Vector3(0.0, eyeHeight, 0.0), Vector3.RIGHT)).is_same(near)
	assert_object(campus.pick(Vector3(200.0, eyeHeight, 0.0), Vector3.LEFT)).is_same(far)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: RUN-TESTS
Expected: script error naming `Campus`; the earlier 19 cases still pass.

- [ ] **Step 3: Implement**

`university/src/state/building.gd`:
```gdscript
class_name Building
## A building standing on the campus. Position is on the ground plane
## (x = world X, y = world Z), angle in radians (see OrientedRect).

# The footprint's short side as a fraction of BuildingInfo.diameter, which is
# its long side. A placeholder until building types carry their own shape.
const DepthRatio: float = 0.6
# Metres. State rather than view because picking tests the box, not the footprint.
const Height: float = 10.0

var info: BuildingInfo
var pos: Vector2
var angle: float


func _init(buildingInfo: BuildingInfo, at: Vector2, facing: float) -> void:
	info = buildingInfo
	pos = at
	angle = facing


func rect() -> OrientedRect:
	return Building.rectFor(info, pos, angle)


## The footprint a building of this type would have there: the one derivation
## shared by placed buildings, the placement check and the ghost.
static func rectFor(buildingInfo: BuildingInfo, at: Vector2, facing: float) -> OrientedRect:
	var size: Vector2 = Vector2(buildingInfo.diameter, buildingInfo.diameter * DepthRatio)
	return OrientedRect.new(at, size, facing)
```

`university/src/state/campus.gd`:
```gdscript
class_name Campus
## The buildable world: a square of ground and the buildings on it. Views call
## the command methods (place, destroy) and listen to the signals; nothing here
## reads input or knows a view exists.

signal BuildingAdded(building: Building)
signal BuildingRemoved(building: Building)

# Side of the square campus, in metres, centred on the origin.
const Size: float = 1000.0

var buildings: Array[Building]


static func bounds() -> Rect2:
	return Rect2(-Size / 2.0, -Size / 2.0, Size, Size)


func canPlace(info: BuildingInfo, pos: Vector2, angle: float) -> bool:
	var rect: OrientedRect = Building.rectFor(info, pos, angle)
	if (not rect.within(Campus.bounds())):
		return false
	for building: Building in buildings:
		if (rect.overlaps(building.rect())):
			return false
	return true


## The new building, or null when the spot is not free.
func place(info: BuildingInfo, pos: Vector2, angle: float) -> Building:
	if (not canPlace(info, pos, angle)):
		return null
	var building: Building = Building.new(info, pos, angle)
	buildings.append(building)
	BuildingAdded.emit(building)
	return building


func destroy(building: Building) -> void:
	if (not buildings.has(building)):
		return
	buildings.erase(building)
	BuildingRemoved.emit(building)


## The first building a ray (unit `dir`) reaches, or null.
func pick(origin: Vector3, dir: Vector3) -> Building:
	var nearest: Building = null
	var nearestHit: float = INF
	for building: Building in buildings:
		var hit: float = building.rect().rayHit(origin, dir, Building.Height)
		if (hit != OrientedRect.NoHit and hit < nearestHit):
			nearest = building
			nearestHit = hit
	return nearest


func tick(_dt: float) -> void:
	pass


func update(_dt: float) -> void:
	pass
```

- [ ] **Step 4: Register, run tests**

Run: REGISTER, then RUN-TESTS
Expected: `29 test cases | 0 errors | 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add university/src/state/building.gd* university/src/state/campus.gd* university/tests/CampusTest.gd*
git commit   # "Add Building and Campus: placement, destroy and picking rules" + trailer
```

---

### Task 4: The 3D scene — ground, camera, status bar; remove the 2D template

**Files:**
- Create: `university/src/views/game_camera.gd`, `university/src/views/ground_view.gd`, `university/src/views/ground.gdshader`, `university/src/views/campus_view.gd`, `university/src/views/campus_view.tscn`
- Test: `university/tests/GameCameraTest.gd`
- Modify: `university/src/state/game_state.gd`, `university/src/ui/status_bar.tscn`, `university/project.godot`, `university/src/debug/debug_commands.gd`
- Delete (with their `.uid` files): `src/state/level.gd`, `src/state/player.gd`, `src/state/enemy.gd`, `src/views/level_view.gd`, `src/views/level_view.tscn`, `src/views/player_view.gd`, `src/views/player_view.tscn`, `src/views/enemy_view.gd`, `src/views/enemy_view.tscn`. Do NOT touch `res/Player.png` / `res/Enemy.png`.

**Interfaces:**
- Consumes: `Campus`, `Campus.bounds()`, `Campus.Size` (Task 3).
- Produces:
  - `GameState.campus: Campus` (replaces `level`)
  - `GameCamera` (extends `Camera3D`): `signal ViewMoved`, `const DragThreshold`, `target() -> Vector3`, `distance() -> float`, `yaw() -> float`, `setTarget(point: Vector2)`, `setYaw(degrees: float)`, `setZoom(dist: float)`, `groundPoint(screen: Vector2) -> Variant` (Vector3 or null)
  - `CampusView` (extends `Node3D`) scene with unique nodes `%Ground`, `%Camera`, `%Buildings`, `%StatusBar`; field `camera: GameCamera`
  - Input actions `TurnLeft` (Q), `TurnRight` (E), `ZoomIn` (`[`), `ZoomOut` (`]`), `RotateLeft` (`,`), `RotateRight` (`.`)
  - Console command `camera <x> <z> <distance> <yawDeg>`

- [ ] **Step 1: Write the failing camera tests**

`university/tests/GameCameraTest.gd`:
```gdscript
extends GdUnitTestSuite
## The camera's own rules: limits and wrapping. Built outside the scene tree.

const Epsilon: float = 0.001


func _camera() -> GameCamera:
	return auto_free(GameCamera.new()) as GameCamera


func test_target_is_clamped_to_the_campus() -> void:
	var camera: GameCamera = _camera()
	var bounds: Rect2 = Campus.bounds()
	camera.setTarget(bounds.end * 2.0)
	assert_float(camera.target().x).is_equal_approx(bounds.end.x, Epsilon)
	assert_float(camera.target().z).is_equal_approx(bounds.end.y, Epsilon)


func test_zoom_is_clamped_to_its_range() -> void:
	var camera: GameCamera = _camera()
	camera.setZoom(GameCamera.ZoomMax * 2.0)
	assert_float(camera.distance()).is_equal_approx(GameCamera.ZoomMax, Epsilon)
	camera.setZoom(0.0)
	assert_float(camera.distance()).is_equal_approx(GameCamera.ZoomMin, Epsilon)


func test_yaw_wraps_into_one_turn() -> void:
	var camera: GameCamera = _camera()
	camera.setYaw(GameCamera.FullTurn + 30.0)
	assert_float(camera.yaw()).is_equal_approx(30.0, Epsilon)


func test_camera_stays_at_its_distance_from_the_target() -> void:
	var camera: GameCamera = _camera()
	camera.setTarget(Vector2(10.0, -20.0))
	camera.setZoom(GameCamera.ZoomMin)
	assert_float(camera.position.distance_to(camera.target())).is_equal_approx(GameCamera.ZoomMin, Epsilon)


func test_every_move_announces_itself() -> void:
	var camera: GameCamera = _camera()
	var moves: Array[int] = []
	camera.ViewMoved.connect(func() -> void: moves.append(1))
	camera.setTarget(Vector2(5.0, 5.0))
	camera.setYaw(10.0)
	camera.setZoom(GameCamera.ZoomMin)
	assert_int(moves.size()).is_equal(3)
```

Run: RUN-TESTS — Expected: script error naming `GameCamera`; 29 earlier cases pass.

- [ ] **Step 2: Write `game_camera.gd`**

`university/src/views/game_camera.gd`:
```gdscript
class_name GameCamera
extends Camera3D
## Camera orbiting a point on the ground at a fixed pitch. Zoom is distance;
## pan moves the target, which stays on the campus. Right-drag pans, middle-drag
## turns about the vertical axis, the wheel zooms; WASD/arrows, Q/E and [ ] do
## the same from the keyboard. Pitch and FOV are constants so the look can be tuned.

## The view moved, so anything anchored to a screen point now sits over
## different ground.
signal ViewMoved

const PitchDegrees: float = 50.0
const StartYawDegrees: float = 45.0
# Degrees the camera turns per pixel of middle-drag. Negate if it feels inverted.
const TurnDegreesPerPixel: float = 0.25
const FullTurn: float = 360.0
const Fov: float = 30.0
# Zoom is the distance from target to camera, in metres.
const ZoomMin: float = 40.0
const ZoomMax: float = 600.0
const StartZoom: float = 200.0
const ZoomStep: float = 1.15
# Keyboard pan, in distances per second: scaled by the current distance so it
# covers the same fraction of the screen at any zoom.
const PanSpeed: float = 0.5
# How far the cursor must travel with a drag button down before the press
# counts as a drag rather than a click. Under it, a right press stays a click.
const DragThreshold: float = 5.0
# Trackpad two-finger scroll arrives as a stream of small deltas; this scales
# delta into exponent space. Negate if zooming feels inverted on a trackpad.
const GestureZoomGain: float = 0.25
# Keyboard turn, in degrees per second while the key is held.
const TurnSpeed: float = 90.0
# Keyboard zoom, in ZoomStep multiples per second while the key is held.
const ZoomSpeed: float = 4.0
const Ground: Plane = Plane(Vector3.UP, 0.0)

var _target: Vector3 = Vector3.ZERO
var _distance: float = StartZoom
# Degrees about the vertical axis, in [0, FullTurn).
var _yaw: float = StartYawDegrees
# Which button armed the current drag, MOUSE_BUTTON_NONE when idle.
var _dragButton: MouseButton = MOUSE_BUTTON_NONE
# Cursor distance since the press, against DragThreshold.
var _dragTravel: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	fov = Fov
	_applyTransform()


func target() -> Vector3:
	return _target


func distance() -> float:
	return _distance


func yaw() -> float:
	return _yaw


## Moves the target to ground point (x, z), kept on the campus. Every pan
## goes through here, so the limit lives in one place.
func setTarget(point: Vector2) -> void:
	var bounds: Rect2 = Campus.bounds()
	_target = Vector3(
		clampf(point.x, bounds.position.x, bounds.end.x),
		0.0,
		clampf(point.y, bounds.position.y, bounds.end.y))
	_applyTransform()


func setYaw(degrees: float) -> void:
	_yaw = wrapf(degrees, 0.0, FullTurn)
	_applyTransform()


func setZoom(dist: float) -> void:
	_distance = clampf(dist, ZoomMin, ZoomMax)
	_applyTransform()


## Vector from the target to the camera: lifted by pitch, then turned by yaw
## about the vertical axis.
static func offset(pitchDegrees: float, yawDegrees: float, dist: float) -> Vector3:
	var pitch: float = deg_to_rad(pitchDegrees)
	var lifted: Vector3 = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	return lifted.rotated(Vector3.UP, deg_to_rad(yawDegrees))


## Zoom multiplier for one trackpad pan-gesture step. Exponential so that
## scrolling back undoes the zoom exactly.
static func gestureZoomFactor(deltaY: float) -> float:
	return pow(ZoomStep, -deltaY * GestureZoomGain)


## The one place the camera's transform is written, which is why the moved
## signal goes out from here.
func _applyTransform() -> void:
	var off: Vector3 = GameCamera.offset(PitchDegrees, _yaw, _distance)
	transform = Transform3D(Basis.looking_at(-off, Vector3.UP), _target + off)
	ViewMoved.emit()


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if (mb != null):
		if (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE):
			_updateDrag(mb)
		elif (mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP):
			setZoom(_distance / ZoomStep)
		elif (mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			setZoom(_distance * ZoomStep)
		return
	var gesture: InputEventPanGesture = event as InputEventPanGesture
	if (gesture != null):
		# Trackpad two-finger scroll. macOS routes any scroll carrying a gesture
		# phase here and emits NO wheel events for it.
		setZoom(_distance * GameCamera.gestureZoomFactor(gesture.delta.y))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if (motion == null or _dragButton == MOUSE_BUTTON_NONE):
		return
	_dragTravel += motion.relative.length()
	if (_dragTravel > DragThreshold):
		_dragging = true
	if (not _dragging):
		return
	if (_dragButton == MOUSE_BUTTON_MIDDLE):
		setYaw(_yaw + motion.relative.x * TurnDegreesPerPixel)
	else:
		_dragGround(motion.position - motion.relative, motion.position)


## Arms a drag on press and ends it on release. A press only becomes a drag once
## the cursor clears DragThreshold, which keeps a short right press a click; a
## press that DID drag swallows its own release so no click fires from it.
func _updateDrag(mb: InputEventMouseButton) -> void:
	if (mb.pressed):
		_dragButton = mb.button_index
		_dragTravel = 0.0
		_dragging = false
		return
	if (mb.button_index != _dragButton):
		return
	if (_dragging):
		get_viewport().set_input_as_handled()
	_dragButton = MOUSE_BUTTON_NONE
	_dragging = false


## Grab-the-world: the ground point that was under the cursor before the motion
## must be under it after, so the target moves by the opposite of the cursor's
## travel across the ground. Both points use the pre-move camera.
func _dragGround(fromScreen: Vector2, toScreen: Vector2) -> void:
	var before: Variant = groundPoint(fromScreen)
	var after: Variant = groundPoint(toScreen)
	if (before == null or after == null):
		return
	var beforePoint: Vector3 = before
	var afterPoint: Vector3 = after
	var moved: Vector3 = _target - (afterPoint - beforePoint)
	setTarget(Vector2(moved.x, moved.z))


## Ground point under a screen position, or null when the ray misses the ground plane.
func groundPoint(screen: Vector2) -> Variant:
	return Ground.intersects_ray(project_ray_origin(screen), project_ray_normal(screen))


func _process(dt: float) -> void:
	_keyboardTurn(dt)
	_keyboardZoom(dt)
	var dir: Vector2 = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	if (dir == Vector2.ZERO):
		return
	# Screen-relative ground axes: the camera's right and forward, flattened.
	var right: Vector3 = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var forward: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var moved: Vector3 = _target + (right * dir.x - forward * dir.y) * PanSpeed * _distance * dt
	setTarget(Vector2(moved.x, moved.z))


func _keyboardTurn(dt: float) -> void:
	var turn: float = Input.get_axis("TurnLeft", "TurnRight")
	if (turn != 0.0):
		setYaw(_yaw + turn * TurnSpeed * dt)


## Zoom is exponential, like the wheel: ZoomSpeed steps a second, each step
## the same ZoomStep factor a wheel click applies.
func _keyboardZoom(dt: float) -> void:
	var zoom: float = Input.get_axis("ZoomOut", "ZoomIn")
	if (zoom != 0.0):
		setZoom(_distance * pow(ZoomStep, -zoom * ZoomSpeed * dt))
```

- [ ] **Step 3: Ground shader and view**

`university/src/views/ground.gdshader`:
```glsl
shader_type spatial;
// Grass with a thin scale grid. Lines are placed from world position, so the
// grid stays put whatever the mesh or the camera does. Purely visual: the sim
// has no grid.

uniform vec3 grass_color : source_color = vec3(0.36, 0.55, 0.29);
uniform vec3 line_color : source_color = vec3(0.29, 0.46, 0.24);
// Metres between lines, and a line's width in metres.
uniform float grid_spacing = 10.0;
uniform float line_width = 0.2;
// Lines fade out between these distances from the camera, where they would
// otherwise shimmer.
uniform float fade_start = 400.0;
uniform float fade_end = 1200.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres from this fragment to the nearest grid line, per axis.
	vec2 to_line = abs(fract(world_pos.xz / grid_spacing - 0.5) - 0.5) * grid_spacing;
	// Metres one pixel covers: the anti-aliasing band. A line thinner than a
	// pixel keeps its share of the pixel instead of popping in and out.
	vec2 pixel = max(fwidth(world_pos.xz), vec2(0.00001));
	vec2 cover = clamp((0.5 * line_width + 0.5 * pixel - to_line) / pixel, 0.0, 1.0);
	cover *= min(vec2(1.0), line_width / pixel);
	float line = max(cover.x, cover.y);
	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = mix(grass_color, line_color, line * fade);
	ROUGHNESS = 1.0;
}
```

`university/src/views/ground_view.gd`:
```gdscript
class_name GroundView
extends MeshInstance3D
## The campus ground: one plane as large as the campus. The grid on it is the
## material's doing (ground.gdshader).


func _ready() -> void:
	var plane: PlaneMesh = mesh as PlaneMesh
	plane.size = Vector2(Campus.Size, Campus.Size)
```

- [ ] **Step 4: `GameState` swaps `level` for `campus`**

Replace `university/src/state/game_state.gd` with:
```gdscript
class_name GameState


# TODO: Things of the overall campaign, unlocks, etc.

var campus: Campus
var gameTime: float

var remainingDt: float

const TickStepDuration: float = 0.01


func _init() -> void:
	campus = Campus.new()


func update(dt: float) -> void:
	gameTime += dt

	remainingDt += dt
	while (remainingDt >= TickStepDuration):
		campus.tick(TickStepDuration)
		remainingDt -= TickStepDuration

	campus.update(dt)
```

- [ ] **Step 5: `CampusView` script and scene**

`university/src/views/campus_view.gd`:
```gdscript
class_name CampusView
extends Node3D
## Root of the game scene: hosts the lights, the ground, the camera and the UI,
## and drives the state clock. Lighting and layout are authored in the scene.

@onready var camera: GameCamera = %Camera
@onready var statusBar: StatusBar = %StatusBar

var gameState: GameState


func _ready() -> void:
	gameState = Global.gameState
	statusBar.gameState = gameState


func _process(dt: float) -> void:
	gameState.update(dt)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("ExitGame")):
		get_tree().quit()
```

`university/src/views/campus_view.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://src/views/campus_view.gd" id="1_view"]
[ext_resource type="Script" path="res://src/views/ground_view.gd" id="2_ground"]
[ext_resource type="Shader" path="res://src/views/ground.gdshader" id="3_shader"]
[ext_resource type="Script" path="res://src/views/game_camera.gd" id="4_camera"]
[ext_resource type="PackedScene" path="res://src/ui/status_bar.tscn" id="5_status"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_ground"]
shader = ExtResource("3_shader")

[sub_resource type="PlaneMesh" id="PlaneMesh_ground"]
material = SubResource("ShaderMaterial_ground")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 1
background_color = Color(0.62, 0.78, 0.9, 1)
ambient_light_source = 2
ambient_light_color = Color(0.75, 0.78, 0.8, 1)

[node name="CampusView" type="Node3D"]
script = ExtResource("1_view")

[node name="Ground" type="MeshInstance3D" parent="."]
unique_name_in_owner = true
mesh = SubResource("PlaneMesh_ground")
script = ExtResource("2_ground")

[node name="Buildings" type="Node3D" parent="."]
unique_name_in_owner = true

[node name="Camera" type="Camera3D" parent="."]
unique_name_in_owner = true
script = ExtResource("4_camera")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.93967193, -0.26200005, 0.21984288, 0, 0.6427813, 0.76603246, -0.3420126, -0.7198392, 0.6040134, 0, 10, 0)
shadow_enabled = true
directional_shadow_max_distance = 800.0

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="UI root" type="CanvasLayer" parent="."]

[node name="StatusBar" parent="UI root" instance=ExtResource("5_status")]
unique_name_in_owner = true
```

In `university/project.godot` change the main scene line to:
```
run/main_scene="res://src/views/campus_view.tscn"
```

- [ ] **Step 6: Status bar gets placeholder Money labels**

In `university/src/ui/status_bar.tscn`, change the `MarginContainer`'s `offset_left = -200.0` to `offset_left = -420.0`, and append at the end of the file:
```
[node name="MoneyLabel" type="Label" parent="MarginContainer/HBoxContainer"]
layout_mode = 2
text = "Money: "

[node name="MoneyAmount" type="Label" parent="MarginContainer/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "$0"
```
`status_bar.gd` is unchanged (time keeps counting; money is static placeholder text).

- [ ] **Step 7: Input actions**

In `university/project.godot`, inside `[input]`, add after the `MoveDown={...}` block (Q, E, `[`, `]`, `,`, `.`):
```
TurnLeft={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":113,"location":0,"echo":false,"script":null)
]
}
TurnRight={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
ZoomIn={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":91,"key_label":0,"unicode":91,"location":0,"echo":false,"script":null)
]
}
ZoomOut={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":93,"key_label":0,"unicode":93,"location":0,"echo":false,"script":null)
]
}
RotateLeft={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":44,"key_label":0,"unicode":44,"location":0,"echo":false,"script":null)
]
}
RotateRight={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":46,"key_label":0,"unicode":46,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 8: `camera` console command**

In `university/src/debug/debug_commands.gd`, add to `_init()` after the screenshot registration:
```gdscript
	LimboConsole.register_command(_camera, "camera", "Look at ground point <x> <z> from <distance> metres at <yawDeg> degrees.")
```
and add:
```gdscript
func _campusView() -> CampusView:
	var root: Window = (Engine.get_main_loop() as SceneTree).get_root()
	return root.find_child("CampusView", true, false) as CampusView


func _camera(x: float, z: float, dist: float, yawDegrees: float) -> void:
	var camera: GameCamera = _campusView().camera
	camera.setTarget(Vector2(x, z))
	camera.setZoom(dist)
	camera.setYaw(yawDegrees)
	LimboConsole.print_line("Camera at (%.1f, %.1f), %.1f m, yaw %.1f" % [camera.target().x, camera.target().z, camera.distance(), camera.yaw()])
```

- [ ] **Step 9: Delete the 2D template**

```bash
cd /Users/noel/Development/University/game/university
git rm -q src/state/level.gd src/state/level.gd.uid src/state/player.gd src/state/player.gd.uid src/state/enemy.gd src/state/enemy.gd.uid \
  src/views/level_view.gd src/views/level_view.gd.uid src/views/level_view.tscn \
  src/views/player_view.gd src/views/player_view.gd.uid src/views/player_view.tscn \
  src/views/enemy_view.gd src/views/enemy_view.gd.uid src/views/enemy_view.tscn
grep -rn "Level\b\|Player\|Enemy\|\.level\b" src tests --include="*.gd" --include="*.tscn"
```
Expected: the grep prints nothing.

- [ ] **Step 10: Register, test, launch, look**

Run: REGISTER, then RUN-TESTS — Expected: `34 test cases | 0 errors | 0 failures`.
Run: LAUNCH-CHECK, with these console commands before the screenshot:
```
echo "camera 0 0 150 45" | nc -w 3 localhost 9999
```
Expected in the screenshot: sky-blue background, green ground filling the view with a faint darker grid whose squares shrink with distance, status bar at the top showing `Time:` counting and `Money: $0`. Take a second screenshot after `camera 480 480 600 120` and confirm the grid is still visible but faint and nothing shimmers into moiré at the far edge; if it does, raise `line_width` or lower `fade_start` in the shader defaults until it doesn't.

- [ ] **Step 11: Commit**

```bash
cd /Users/noel/Development/University/game && git add -A university && git commit   # "Replace the 2D template with the 3D campus scene: ground, grid, camera" + trailer
```

---

### Task 5: `BuildingView` — buildings appear and disappear with state

**Files:**
- Create: `university/src/views/building_view.gd`
- Modify: `university/src/views/campus_view.gd`, `university/src/debug/debug_commands.gd`

**Interfaces:**
- Consumes: `Building`, `Building.Height`, `OrientedRect`, `Campus` signals, `Global.buildingDB`.
- Produces:
  - `BuildingView` (extends `MeshInstance3D`): `enum Highlight { None, Selected, Destroy }`, `building: Building`, `static create(forBuilding: Building) -> BuildingView`, `static createGhost() -> BuildingView`, `showRect(rect: OrientedRect)`, `setHighlight(kind: Highlight)`, `setValid(valid: bool)`
  - `CampusView.viewFor(building: Building) -> BuildingView` (null when none)
  - Console commands `build <id> <x> <z> <deg>`, `destroy <n>`, `buildings`

- [ ] **Step 1: Write `building_view.gd`**

```gdscript
class_name BuildingView
extends MeshInstance3D
## A building drawn as a box, until models exist: the footprint from state,
## extruded to Building.Height. Also the placement ghost, which is the same
## box with a translucent material and no building behind it.

enum Highlight { None, Selected, Destroy }

const BaseColor: Color = Color(0.86, 0.82, 0.74)
const SelectedColor: Color = Color(1.0, 0.86, 0.4)
const DestroyColor: Color = Color(0.9, 0.32, 0.27)
const GhostValidColor: Color = Color(0.45, 0.9, 0.5, 0.55)
const GhostInvalidColor: Color = Color(0.95, 0.3, 0.25, 0.55)

# Null for the ghost.
var building: Building

var _material: StandardMaterial3D = StandardMaterial3D.new()


static func create(forBuilding: Building) -> BuildingView:
	var view: BuildingView = BuildingView.new()
	view.building = forBuilding
	view._setup()
	view.showRect(forBuilding.rect())
	view.setHighlight(Highlight.None)
	return view


static func createGhost() -> BuildingView:
	var view: BuildingView = BuildingView.new()
	view._setup()
	view._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.setValid(true)
	return view


func _setup() -> void:
	mesh = BoxMesh.new()
	material_override = _material


## Shapes and places the box over a footprint. The one place a state angle
## becomes a node rotation: state turns from +X toward +Z, a node's y rotation
## turns from +X toward -Z.
func showRect(rect: OrientedRect) -> void:
	var box: BoxMesh = mesh as BoxMesh
	box.size = Vector3(rect.size.x, Building.Height, rect.size.y)
	position = Vector3(rect.center.x, Building.Height / 2.0, rect.center.y)
	rotation = Vector3(0.0, -rect.angle, 0.0)


func setHighlight(kind: Highlight) -> void:
	match kind:
		Highlight.Selected:
			_material.albedo_color = SelectedColor
		Highlight.Destroy:
			_material.albedo_color = DestroyColor
		_:
			_material.albedo_color = BaseColor


func setValid(valid: bool) -> void:
	_material.albedo_color = GhostValidColor if (valid) else GhostInvalidColor
```

- [ ] **Step 2: `CampusView` spawns and frees the views**

In `university/src/views/campus_view.gd` add the onready, the map, the wiring in `_ready`, and the handlers:
```gdscript
@onready var buildingsRoot: Node3D = %Buildings

var _views: Dictionary[Building, BuildingView]
```
at the end of `_ready()`:
```gdscript
	gameState.campus.BuildingAdded.connect(_onBuildingAdded)
	gameState.campus.BuildingRemoved.connect(_onBuildingRemoved)
```
and:
```gdscript
func viewFor(building: Building) -> BuildingView:
	return _views.get(building) as BuildingView


func _onBuildingAdded(building: Building) -> void:
	var view: BuildingView = BuildingView.create(building)
	_views[building] = view
	buildingsRoot.add_child(view)


func _onBuildingRemoved(building: Building) -> void:
	var view: BuildingView = viewFor(building)
	_views.erase(building)
	view.queue_free()
```

- [ ] **Step 3: Console commands**

In `debug_commands.gd` `_init()`:
```gdscript
	LimboConsole.register_command(_build, "build", "Place building type <id> at ground point <x> <z> (metres), turned <deg> degrees.")
	LimboConsole.register_command(_destroy, "destroy", "Destroy building <n> (index from 'buildings').")
	LimboConsole.register_command(_buildings, "buildings", "One line per building: index, type id, position, angle in degrees.")
```
and:
```gdscript
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
```
(`DebugCommands` is a script class, not an `eval` expression, so the `Global` autoload resolves by name here.)

- [ ] **Step 4: Register, test, launch, look**

Run: REGISTER, RUN-TESTS — Expected: still `34 test cases | 0 errors | 0 failures`.
Run: LAUNCH-CHECK with, before the screenshot:
```
echo "camera 0 0 180 45" | nc -w 3 localhost 9999
echo "build admissions 0 0 0" | nc -w 3 localhost 9999
echo "build dorm 40 10 30" | nc -w 3 localhost 9999
echo "build engineering_1 -50 -20 -60" | nc -w 3 localhost 9999
echo "build dorm 40 10 30" | nc -w 3 localhost 9999     # expect: Refused
echo "buildings" | nc -w 3 localhost 9999                # expect: 3 lines
```
Expected in the screenshot: three cream boxes of clearly different lengths (the longest side growing admissions < dorm < engineering), each turned differently, casting shadows on the grass, their sizes plausible against the 10 m grid. Then `destroy 1`, screenshot again: the middle-sized box is gone.
Check the rotation convention with your eyes: `build dorm 0 100 0` and `build dorm 0 160 90` — the first box's long side must run along world X, the second's along world Z (use `camera 0 130 250 0` so screen-right is world X).

- [ ] **Step 5: Commit**

```bash
git add -A university && git commit   # "Draw buildings as boxes that follow the campus state" + trailer
```

---

### Task 6: `BuildController` — tools, ghost, hover, selection

**Files:**
- Create: `university/src/views/build_controller.gd`
- Test: `university/tests/BuildControllerTest.gd`
- Modify: `university/src/views/campus_view.gd`, `university/src/views/campus_view.tscn`, `university/src/debug/debug_commands.gd`

**Interfaces:**
- Consumes: `Campus` (place/destroy/pick/canPlace, `BuildingRemoved`), `GameCamera` (`groundPoint`, `project_ray_origin`, `project_ray_normal`), `BuildingView` (`createGhost`, `showRect`, `setValid`, `setHighlight`), `CampusView.viewFor`.
- Produces `BuildController` (extends `Node3D`):
  - `signal ToolChanged`, `signal SelectionChanged(building: Building)`, `signal HoverChanged(building: Building)`
  - `enum Tool { None, Place, Destroy }`; fields `activeTool: Tool`, `placeInfo: BuildingInfo`, `selected: Building`, `hovered: Building`
  - `setup(campus: Campus, camera: GameCamera)`, `armPlace(info: BuildingInfo)`, `armDestroy()`, `cancel()`, `select(building: Building)`, `placeAt(point: Vector2) -> Building`, `angle() -> float`, `setAngle(radians: float)`
  - Console commands `tool <id|destroy|none>`, `select <n>`, `mousedown <x> <y>`, `mouseup <x> <y>`, `mousemove <x> <y>`

Scene-tree order matters: `_unhandled_input` reaches nodes lowest in the tree first. `BuildController` must sit ABOVE `Camera` in `campus_view.tscn` so the camera sees a right-button release first and can swallow it when it ended a pan; what still reaches the controller is a click.

- [ ] **Step 1: Write the failing tests**

`university/tests/BuildControllerTest.gd`:
```gdscript
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
	var controller: BuildController = _controller(Campus.new())
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
	var campus: Campus = Campus.new()
	var controller: BuildController = _controller(campus)
	controller.select(campus.place(_info(), Vector2.ZERO, 0.0))
	controller.armDestroy()
	assert_object(controller.selected).is_null()


func test_placing_keeps_the_tool_armed_and_uses_the_angle() -> void:
	var campus: Campus = Campus.new()
	var controller: BuildController = _controller(campus)
	controller.armPlace(_info())
	controller.setAngle(PI / 2.0)
	var building: Building = controller.placeAt(Vector2(30.0, 30.0))
	assert_object(building).is_not_null()
	assert_float(building.angle).is_equal_approx(PI / 2.0, 0.0001)
	assert_int(controller.activeTool).is_equal(BuildController.Tool.Place)


func test_placing_on_occupied_ground_places_nothing() -> void:
	var campus: Campus = Campus.new()
	var controller: BuildController = _controller(campus)
	controller.armPlace(_info())
	controller.placeAt(Vector2.ZERO)
	assert_object(controller.placeAt(Vector2.ZERO)).is_null()
	assert_int(campus.buildings.size()).is_equal(1)


func test_destroying_the_selected_building_clears_the_selection() -> void:
	var campus: Campus = Campus.new()
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
	var campus: Campus = Campus.new()
	var controller: BuildController = _controller(campus)
	var building: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	controller.select(building)
	var selections: Array[Building] = []
	controller.SelectionChanged.connect(func(b: Building) -> void: selections.append(b))
	controller.select(building)
	assert_array(selections).is_empty()
```

Run: RUN-TESTS — Expected: script error naming `BuildController`; 34 earlier cases pass.

- [ ] **Step 2: Write `build_controller.gd`**

```gdscript
class_name BuildController
extends Node3D
## The one place input becomes commands on the campus. Holds the current tool:
## None (a click selects), Place (a ghost follows the cursor, a click builds
## and the tool stays armed) or Destroy (a click removes the building under
## the cursor). A right click or Esc puts the tool away. Everything arrives
## through _unhandled_input, so a click on the UI never reaches the world.
## Sits above the camera in the scene so the camera sees a right release first
## and swallows it when it ended a pan: what still arrives here is a click.

signal ToolChanged
signal SelectionChanged(building: Building)
signal HoverChanged(building: Building)

enum Tool { None, Place, Destroy }

# Degrees per second the ghost turns while a rotate key is held.
const RotateSpeedDegrees: float = 90.0

var activeTool: Tool = Tool.None
# The type being placed; null unless the tool is Place.
var placeInfo: BuildingInfo
var selected: Building
# The building the Destroy tool would remove on a click.
var hovered: Building

var _campus: Campus
var _camera: GameCamera
var _ghost: BuildingView
var _angle: float = 0.0
# Last known cursor position. Taken from events rather than polled, so
# synthetic events from the console work with the window hidden.
var _mouse: Vector2
var _hasMouse: bool = false


func setup(campus: Campus, camera: GameCamera) -> void:
	_campus = campus
	_camera = camera
	_campus.BuildingRemoved.connect(_onBuildingRemoved)


func angle() -> float:
	return _angle


func setAngle(radians: float) -> void:
	_angle = wrapf(radians, 0.0, TAU)


func armPlace(info: BuildingInfo) -> void:
	_setTool(Tool.Place, info)


func armDestroy() -> void:
	_setTool(Tool.Destroy, null)


func cancel() -> void:
	_setTool(Tool.None, null)


func _setTool(newTool: Tool, info: BuildingInfo) -> void:
	activeTool = newTool
	placeInfo = info
	if (activeTool != Tool.None):
		select(null)
	if (activeTool != Tool.Destroy):
		_setHovered(null)
	if (activeTool == Tool.Place and _ghost == null):
		_ghost = BuildingView.createGhost()
		_ghost.visible = false
		add_child(_ghost)
	elif (activeTool != Tool.Place and _ghost != null):
		_ghost.queue_free()
		_ghost = null
	ToolChanged.emit()


func select(building: Building) -> void:
	if (building == selected):
		return
	selected = building
	SelectionChanged.emit(selected)


func _setHovered(building: Building) -> void:
	if (building == hovered):
		return
	hovered = building
	HoverChanged.emit(hovered)


## Builds the armed type at a ground point with the current angle. Null when
## nothing is armed or the campus refuses the spot. The tool stays armed.
func placeAt(point: Vector2) -> Building:
	if (activeTool != Tool.Place):
		return null
	return _campus.place(placeInfo, point, _angle)


func _onBuildingRemoved(building: Building) -> void:
	if (building == selected):
		select(null)
	if (building == hovered):
		_setHovered(null)


# Per frame rather than per mouse event: the camera can move the world under a
# still cursor, and the rotate keys are held.
func _process(dt: float) -> void:
	if (activeTool == Tool.Place):
		var turn: float = Input.get_axis("RotateLeft", "RotateRight")
		if (turn != 0.0):
			setAngle(_angle + turn * deg_to_rad(RotateSpeedDegrees) * dt)
		_updateGhost()
	elif (activeTool == Tool.Destroy):
		_setHovered(_pick(_mouse) if (_hasMouse) else null)


func _updateGhost() -> void:
	var point: Variant = _camera.groundPoint(_mouse) if (_hasMouse) else null
	_ghost.visible = (point != null)
	if (point == null):
		return
	var ground: Vector3 = point
	var at: Vector2 = Vector2(ground.x, ground.z)
	_ghost.showRect(Building.rectFor(placeInfo, at, _angle))
	_ghost.setValid(_campus.canPlace(placeInfo, at, _angle))


func _pick(screen: Vector2) -> Building:
	return _campus.pick(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen))


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if (motion != null):
		_mouse = motion.position
		_hasMouse = true
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if (mb != null):
		_mouse = mb.position
		_hasMouse = true
		if (mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
			_leftClick()
		elif (mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and activeTool != Tool.None):
			# A release the camera did not swallow: a click, not the end of a pan.
			cancel()
		return
	if (event.is_action_pressed("ExitGame")):
		if (activeTool != Tool.None):
			cancel()
		elif (selected != null):
			select(null)
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()


func _leftClick() -> void:
	match activeTool:
		Tool.Place:
			var point: Variant = _camera.groundPoint(_mouse)
			if (point != null):
				var ground: Vector3 = point
				placeAt(Vector2(ground.x, ground.z))
		Tool.Destroy:
			var target: Building = _pick(_mouse)
			if (target != null):
				_campus.destroy(target)
		_:
			select(_pick(_mouse))
```

- [ ] **Step 3: Wire it into `CampusView`**

In `campus_view.tscn`, add an ext_resource and a node. The node goes BEFORE the `Camera` node (see the ordering note above):
```
[ext_resource type="Script" path="res://src/views/build_controller.gd" id="6_controller"]
```
```
[node name="BuildController" type="Node3D" parent="."]
unique_name_in_owner = true
script = ExtResource("6_controller")
```

In `campus_view.gd`: add the onready, remove the whole `_unhandled_input` function (the controller owns Esc now), extend `_ready`, and add the highlight handlers:
```gdscript
@onready var controller: BuildController = %BuildController
```
at the end of `_ready()`:
```gdscript
	controller.setup(gameState.campus, camera)
	controller.SelectionChanged.connect(_onSelectionChanged)
	controller.HoverChanged.connect(_onHoverChanged)
```
and:
```gdscript
# The building whose view currently shows each highlight, so it can be put back.
var _selectedView: BuildingView
var _hoveredView: BuildingView


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
```

- [ ] **Step 4: Console commands**

In `debug_commands.gd` `_init()`:
```gdscript
	LimboConsole.register_command(_tool, "tool", "Arm a tool: a building type id to place it, 'destroy', or 'none'.")
	LimboConsole.register_command(_select, "select", "Select building <n> (index from 'buildings'); -1 clears the selection.")
	LimboConsole.register_command(_mouseDown, "mousedown", "Press the left mouse button at design-space point <x> <y> (synthetic event through the viewport).")
	LimboConsole.register_command(_mouseUp, "mouseup", "Release the left mouse button at design-space point <x> <y>.")
	LimboConsole.register_command(_mouseMove, "mousemove", "Move the mouse to design-space point <x> <y> (with the left button held if pressed).")
```
and:
```gdscript
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
```

- [ ] **Step 5: Register, test, launch, look**

Run: REGISTER, RUN-TESTS — Expected: `40 test cases | 0 errors | 0 failures`.
Run: LAUNCH-CHECK with this sequence (design space is 1920x1080; 960,540 is screen centre = the camera target):
```
echo "camera 0 0 180 45" | nc -w 3 localhost 9999
echo "tool dorm" | nc -w 3 localhost 9999
echo "mousemove 960 540" | nc -w 3 localhost 9999
echo screenshot | nc -w 3 localhost 9999      # LOOK: translucent GREEN ghost at the centre
echo "mousedown 960 540" | nc -w 3 localhost 9999
echo "mouseup 960 540" | nc -w 3 localhost 9999
echo "buildings" | nc -w 3 localhost 9999      # expect 1 dorm near (0, 0)
echo screenshot | nc -w 3 localhost 9999      # LOOK: solid box with a RED ghost over it (spot now taken)
echo "mousemove 1300 540" | nc -w 3 localhost 9999
echo screenshot | nc -w 3 localhost 9999      # LOOK: ghost green again, beside the box
echo "tool none" | nc -w 3 localhost 9999
echo "mousedown 960 520" | nc -w 3 localhost 9999
echo "mouseup 960 520" | nc -w 3 localhost 9999
echo screenshot | nc -w 3 localhost 9999      # LOOK: box is YELLOW (selected), no ghost
echo "tool destroy" | nc -w 3 localhost 9999
echo "mousemove 960 520" | nc -w 3 localhost 9999
echo screenshot | nc -w 3 localhost 9999      # LOOK: box is RED (destroy hover)
echo "mousedown 960 520" | nc -w 3 localhost 9999
echo "buildings" | nc -w 3 localhost 9999      # expect: No buildings
```
Take the screenshots one at a time (copy each aside or Read it before the next overwrites it).

- [ ] **Step 6: Commit**

```bash
git add -A university && git commit   # "Add BuildController: place with a ghost, select, destroy" + trailer
```

---

### Task 7: UI — build menu and info panel

**Files:**
- Create: `university/src/ui/build_menu.gd`, `university/src/ui/build_menu.tscn`, `university/src/ui/info_panel.gd`, `university/src/ui/info_panel.tscn`
- Modify: `university/src/views/campus_view.gd`, `university/src/views/campus_view.tscn`

**Interfaces:**
- Consumes: `Global.buildingDB.all`, `BuildController` (`armPlace`, `armDestroy`, `cancel`, `ToolChanged`, `SelectionChanged`, `activeTool`, `placeInfo`).
- Produces:
  - `BuildMenu` (extends `VBoxContainer`): `signal BuildingChosen(info: BuildingInfo)`, `signal DestroyChosen`, `signal Closed`; `populate(infos: Array[BuildingInfo])`, `showTool(armed: BuildController.Tool, info: BuildingInfo)`
  - `InfoPanel` (extends `PanelContainer`): `showBuilding(building: Building)`

- [ ] **Step 1: `build_menu.tscn` and script**

`university/src/ui/build_menu.tscn` — anchored bottom-left, growing upward; the options panel sits above the Build button and starts hidden:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://src/ui/build_menu.gd" id="1_menu"]

[node name="BuildMenu" type="VBoxContainer"]
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 16.0
offset_top = -56.0
offset_right = 216.0
offset_bottom = -16.0
grow_vertical = 0
theme_override_constants/separation = 8
alignment = 2
script = ExtResource("1_menu")

[node name="Options" type="PanelContainer" parent="."]
unique_name_in_owner = true
visible = false
layout_mode = 2

[node name="Margin" type="MarginContainer" parent="Options"]
layout_mode = 2
theme_override_constants/margin_left = 8
theme_override_constants/margin_top = 8
theme_override_constants/margin_right = 8
theme_override_constants/margin_bottom = 8

[node name="OptionList" type="VBoxContainer" parent="Options/Margin"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 6

[node name="DestroyButton" type="Button" parent="Options/Margin/OptionList"]
unique_name_in_owner = true
custom_minimum_size = Vector2(184, 40)
layout_mode = 2
toggle_mode = true
text = "Destroy"

[node name="BuildButton" type="Button" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(200, 40)
layout_mode = 2
toggle_mode = true
text = "Build"
```

`university/src/ui/build_menu.gd`:
```gdscript
class_name BuildMenu
extends VBoxContainer
## The Build button in the bottom-left corner and the list it opens: one entry
## per building type, then Destroy. It only announces what was chosen and
## shows what it is told is armed; the controller owns the tool. The entries
## are made in code because how many there are is data.

signal BuildingChosen(info: BuildingInfo)
signal DestroyChosen
## The list was closed, which puts any tool away.
signal Closed

@onready var options: PanelContainer = %Options
@onready var optionList: VBoxContainer = %OptionList
@onready var destroyButton: Button = %DestroyButton
@onready var buildButton: Button = %BuildButton

var _buttons: Dictionary[BuildingInfo, Button]


func _ready() -> void:
	buildButton.toggled.connect(_onBuildToggled)
	destroyButton.pressed.connect(func() -> void: DestroyChosen.emit())


func populate(infos: Array[BuildingInfo]) -> void:
	for info: BuildingInfo in infos:
		var button: Button = Button.new()
		button.text = info.name
		button.toggle_mode = true
		button.custom_minimum_size = destroyButton.custom_minimum_size
		button.pressed.connect(func() -> void: BuildingChosen.emit(info))
		optionList.add_child(button)
		optionList.move_child(button, destroyButton.get_index())
		_buttons[info] = button


## Shows which entry is armed. Called on every tool change, so a press that
## toggled a button the wrong way is put right here.
func showTool(armed: BuildController.Tool, info: BuildingInfo) -> void:
	destroyButton.set_pressed_no_signal(armed == BuildController.Tool.Destroy)
	for entry: BuildingInfo in _buttons:
		_buttons[entry].set_pressed_no_signal(armed == BuildController.Tool.Place and entry == info)


func _onBuildToggled(open: bool) -> void:
	options.visible = open
	if (not open):
		Closed.emit()
```

- [ ] **Step 2: `info_panel.tscn` and script**

`university/src/ui/info_panel.tscn` — bottom-right:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://src/ui/info_panel.gd" id="1_panel"]

[node name="InfoPanel" type="PanelContainer"]
visible = false
custom_minimum_size = Vector2(280, 0)
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -296.0
offset_top = -76.0
offset_right = -16.0
offset_bottom = -16.0
grow_horizontal = 0
grow_vertical = 0
script = ExtResource("1_panel")

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 2
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 10

[node name="NameLabel" type="Label" parent="Margin"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 22
text = "Building"
```

`university/src/ui/info_panel.gd`:
```gdscript
class_name InfoPanel
extends PanelContainer
## What is known about the selected building: for now, its name. Hidden while
## nothing is selected.

@onready var nameLabel: Label = %NameLabel


func showBuilding(building: Building) -> void:
	visible = (building != null)
	if (building != null):
		nameLabel.text = building.info.name
```

- [ ] **Step 3: Wire into `CampusView`**

`campus_view.tscn`: add ext_resources
```
[ext_resource type="PackedScene" path="res://src/ui/build_menu.tscn" id="7_menu"]
[ext_resource type="PackedScene" path="res://src/ui/info_panel.tscn" id="8_info"]
```
and, at the end (children of `UI root`):
```
[node name="BuildMenu" parent="UI root" instance=ExtResource("7_menu")]
unique_name_in_owner = true

[node name="InfoPanel" parent="UI root" instance=ExtResource("8_info")]
unique_name_in_owner = true
```

`campus_view.gd`: onreadys
```gdscript
@onready var buildMenu: BuildMenu = %BuildMenu
@onready var infoPanel: InfoPanel = %InfoPanel
```
end of `_ready()`:
```gdscript
	buildMenu.populate(Global.buildingDB.all)
	buildMenu.BuildingChosen.connect(controller.armPlace)
	buildMenu.DestroyChosen.connect(controller.armDestroy)
	buildMenu.Closed.connect(controller.cancel)
	controller.ToolChanged.connect(func() -> void: buildMenu.showTool(controller.activeTool, controller.placeInfo))
	controller.SelectionChanged.connect(infoPanel.showBuilding)
```

- [ ] **Step 4: Register, test, launch, drive the UI with synthetic clicks**

Run: REGISTER, RUN-TESTS — Expected: `40 test cases | 0 errors | 0 failures`.
Run: LAUNCH-CHECK. First find where the controls are (eval cannot name autoloads or classes; go through `get_root()`):
```
echo 'eval get_root().find_child("BuildButton", true, false).global_position' | nc -w 3 localhost 9999
echo 'eval get_root().find_child("BuildButton", true, false).size' | nc -w 3 localhost 9999
```
Click the centre of that rect with `mousedown X Y` / `mouseup X Y`, screenshot, and LOOK: the panel is open above the button listing every building name from the sheet in sheet order, then Destroy. Read each entry's position the same way (`find_child("OptionList", true, false).get_child(0).global_position`), click the first entry, move the mouse to `960 540`, screenshot: the entry shows pressed and a green ghost sits at screen centre. Click `960 540`: a building appears. Click the Build button again to close: the ghost is gone (tool cancelled). Click the building: the info panel appears bottom-right with its name; the box is yellow. Open the menu, click Destroy, click the building: it is gone and the info panel is hidden.
Also confirm a UI click does not leak into the world: with a building type armed, clicking the Build button must NOT place a building under it (`buildings` count unchanged).

- [ ] **Step 5: Commit**

```bash
git add -A university && git commit   # "Add the build menu and the building info panel" + trailer
```

---

### Task 8: Bring `CLAUDE.md` and the spec in line with what was built

**Files:**
- Modify: `CLAUDE.md`, `docs/superpowers/specs/2026-09-20-campus-builder-design.md`

**Interfaces:** Consumes everything above. Produces documentation only.

- [ ] **Step 1: `CLAUDE.md`**

- Header paragraph: replace the "2D starter template" description with: 3D, 1 unit = 1 metre, Y up; state positions are `Vector2` (`x` = world X, `y` = world Z); a rect's `angle` is the direction of its long axis, `(cos a, sin a)`, and `BuildingView.showRect` is the one place it becomes a node rotation (`-angle`); no grid — the 10 m lines on the ground are the shader's and the sim never sees them.
- Architecture: replace the `State`/`Views` bullets' examples with the real classes (`Campus`, `Building`, `OrientedRect`, `BuildingInfo`/`BuildingInfoDB`; `CampusView`, `GameCamera`, `GroundView`, `BuildingView`, `BuildController`, `BuildMenu`, `InfoPanel`, `StatusBar`), one or two sentences each on what it owns, including: `OrientedRect` is the one place rectangle maths lives; `Building.rectFor` is the one footprint derivation shared by placed buildings, `canPlace` and the ghost; picking is a ray against the box in state (`Campus.pick`), not physics; `BuildController` must sit above `Camera` in the scene tree and why.
- Replace the "Orders, not input" bullet with: **Commands, not input.** State never reads input. Views call command methods on state (`Campus.place`, `Campus.destroy`); state validates, mutates and answers with signals (`BuildingAdded`, `BuildingRemoved`). The command methods are the one seam where a command log would go if replay or undo is ever wanted. Remove the sentence about `PlayerView`.
- Data: replace the "no spreadsheet pipeline" paragraph with the live one: `python3 bin/GetDataFromGoogleSheets.py` exports the `Buildings` tab (gid 948960558) to `university/data/buildings.txt`; `.txt` because Godot imports `*.csv` as a Translation; the Sheet is the source of truth and the file is never hand-edited; `Global.buildingDB` loads it in `_ready`.
- LimboConsole: list every registered command with its one-line description (`screenshot`, `camera`, `build`, `destroy`, `buildings`, `tool`, `select`, `mousedown`/`mouseup`/`mousemove`), and add an "In-game" paragraph: WASD/arrows pan, Q/E turn, `[`/`]` and wheel/two-finger scroll zoom, right-drag pans, middle-drag turns; Build (bottom-left) opens the list; choosing a type arms it, the ghost is green where it can go and red where it cannot, `,`/`.` turn it while held, LMB places and the tool stays armed, a right click or Esc puts the tool away, closing the list does too; with no tool LMB selects a building and the info panel shows its name; Destroy reddens the building under the cursor and LMB removes it; Esc with nothing armed or selected quits.
- Console automation limits: replace the generic paragraph about synthetic mouse events with the fact that they now exist and that design space is 1920x1080.

- [ ] **Step 2: Spec corrections**

In the spec: replace the angle sentence under "Units and conventions" with the `(cos a, sin a)` / `rotation.y = -angle` convention above; rename `TopBar` to `StatusBar` throughout; in the `GameCamera` section replace "a new `ray(screen)`" with "callers build a ray from `project_ray_origin`/`project_ray_normal`" and add `setTarget`; in `BuildController` add the `HoverChanged` signal and that `CampusView` applies highlights from the controller's signals; in `BuildMenu` add the `Closed` signal (closing the list cancels the tool).

- [ ] **Step 3: Final full verification**

Run: RUN-TESTS — Expected: `40 test cases | 0 errors | 0 failures`.
Run: LAUNCH-CHECK once more with a `build` of each type and a screenshot, confirming clean stdout.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs && git commit   # "Document the campus builder in CLAUDE.md; align the spec" + trailer
```
