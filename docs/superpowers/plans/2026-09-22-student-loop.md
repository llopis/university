# Students and the Loop Implementation Plan (Phase 3 of 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every student simulated, as cohorts.
- Buildings provide seats, beds and dining.
- Each fall, applicants arrive from reputation and price, and the best are admitted up to the open seats (a minimum grade can cut the class).
- Cohorts graduate after 8 semesters.
- Fees arrive each semester start.
- Satisfaction falls with housing overflow and dining crowding.
- Reputation moves each fall toward half grades, half satisfaction.
- All of it is saved, driven from the console, and tuned with a `simulate` command.

**Architecture:**
- Pure state classes: `Cohort`/`StudentBody`, `Prices`/`Policy`, and `UniversityRules`, the static tuning consts and formulas.
  - `UniversityRules` returns small records: `Intake`, `Satisfaction`, `Fees`.
  - `SemesterReport` records each semester start. `Problem` is what alerts will draw from.
- `University` runs the sequence in `startMonth`: open buildings → semester steps → fees → the monthly bill.
- `Campus` answers capacities over open buildings.
- No UI in this phase; everything is reached through the console.

**Tech Stack:** Godot 4.7, fully typed GDScript, gdUnit4, LimboConsole + TCP remote console, Python 3 sheet export.

**Spec:** `docs/superpowers/specs/2026-09-22-students-money-hud-design.md`. The relevant sections are **Phases → 3**, **State** (`StudentBody`, `Policy`, `UniversityRules`, `University` and its `startMonth` sequence, `SemesterReport`, `problems()`), **Data** and **Console**. Read the spec and `CLAUDE.md` before any task.

## Global Constraints

- **Paths.** The repo root is `/Users/noel/Development/University/game`; the Godot project is `university/`. `res://` is `university/`.
- **`CLAUDE.md` governs:**
  - camelCase functions and variables; PascalCase classes, constants and signals
  - conditions written `if (x):`
  - fully typed GDScript. **Unsafe access and shadowing are errors:** a local or parameter named like a member of its own class fails to parse, including in static functions and lambdas.
  - no magic numbers (named `const`)
  - TAB indentation
  - no duplicate logic, and surgical changes
- **State classes** (`src/state/`, `src/data/`) are plain `class_name` classes: no Node, no Input, no scene tree, no file I/O, no views.
- **A Variant from a Dictionary or Array** never goes straight into `int()`, `float()`, `bool()` or a typed parameter. Use `Variants.toInt` / `toFloat` / `toBool`, `str()`, or `as Dictionary` / `as Array`.
- **The formulas and starting values, exact from the spec.** They all live in `UniversityRules`, as named consts.
  - **Applicants:**
    - `A = floor(ApplicantPool × 2^((R − ReputationReference) / ReputationDoubling) × 2^(−(P − ReferencePrice) / PriceHalving))`, where P is the total price (tuition + room + meal plan).
    - Values: ApplicantPool 4000, ReputationReference 50, ReputationDoubling 20, ReferencePrice 18300, PriceHalving 6000.
  - **Admission:**
    - With S = open seats (seats − enrolled, floored at 0) and m = the minimum in use:
      - cutoff `c = clamp(GradeBase + GradeSpread × ln(A / S), 0, MaxGrade)`
      - admitted `n = floor(min(A, S) × e^(−max(0, m − c) / GradeSpread))`
      - entry grade `max(c, m)`
    - No seats or no applicants: nobody is admitted.
    - Values: GradeBase 2.8, GradeSpread 0.35, MaxGrade 4.0.
  - **Housing and dining:**
    - housed = `min(enrolled, beds)`; off campus = the rest
    - meal plans = `min(housed, floor(DiningHardLimit × meals))`; unfed = housed − meal plans
    - dining load = housed / meals
  - **Satisfaction** (0 to MaxScore 100): `SatisfactionBase − housing − crowding − unfed`, clamped, where
    - housing = `OverflowWeight × max(0, offCampus/enrolled − OverflowThreshold)`
    - crowding = `CrowdingWeight × clamp(load − 1, 0, DiningHardLimit − 1) × mealPlans/enrolled`
    - unfed = `UnfedWeight × unfed/enrolled`
    - Values: SatisfactionBase 75, OverflowThreshold 0.25, OverflowWeight 100, CrowdingWeight 50, DiningHardLimit 1.3, UnfedWeight 150.
  - **Reputation** (0 to 100), stepped each fall start:
    - `R += ReputationRate × (T − R)`, where `T = ReputationGradeWeight × lastIntakeGrade × GradeToScore + (1 − ReputationGradeWeight) × mean(this year's satisfaction samples)`
    - `GradeToScore = MaxScore / MaxGrade`
    - Values: ReputationRate 0.3, ReputationGradeWeight 0.5.
  - **Fees:** tuition × enrolled + room × housed + meal plan × meal plans. Off-campus students pay tuition only.
- **Policy.**
  - Defaults are tuition $9,606, room $4,542 and meal plan $4,136.
  - Prices are yearly: the player sets `next`, and each fall start makes it `current`. With no open Admissions Office, the defaults apply and the minimum is off.
  - The minimum grade is 0 (off) up to MaxGrade.
- **Cohorts.**
  - Each has `size`, `entryGrade` and `semestersCompleted`.
  - At every semester start, each cohort completes one semester. Those reaching `SemestersToGraduate` (8) graduate whole.
  - Admission is at the fall start only.
- **`University.startMonth(m)`**, in this order:
  1. `campus.startMonth(m)`, which now returns the buildings it opened.
  2. If m is a semester start:
     1. Graduation.
     2. Fall only: the reputation step (then the year's samples reset), `policy.lockYear(hasOffice)`, applicants, admission, `lastIntakeGrade`.
     3. Satisfaction is sampled.
     4. Fees go to `finances.receive`.
     5. A `SemesterReport` is kept and `SemesterStarted` is emitted.
  3. Always: `finances.charge(monthlyExpenses())`, where `monthlyExpenses()` = `campus.upkeep() + finances.interest()`. That function is the one source of the bill.
- **Month 0 never runs `startMonth`.** Tick 0 already is month 0. So the start state is the moment just after month 0's fall start: the first cohort is already admitted, its fees are paid, and one satisfaction sample is taken.
- **Save format.** Each new class has `toDict`, plus a `static fromDict` that checks `Variants.hasKeys` against a `SavedKeys` const matching `toDict` and returns null on a missing key. A parent refuses when a child refuses. Every new saved field gets a non-default value in `SaveTest._playedState`.
- **Kept out of this phase** (the ruling is in the ledger; phase 4 adds them with the HUD that needs them): the projection queries (`expectedApplicants`, `seatsToFillNextFall`, `expectedIntake`, `projectedFees`, `cashAtSemesterStart`), `graduatingByNextFall`, and "Class of Year N". Wrong-typed save values reading as 0 also stay deferred.
- **Sheet columns.** The controller added them to the Sheet on 2026-09-22: `seats` (engineering_1 400), `beds` (dorm 120), `meals` (dining_1 650) and `admissionsOffice` (admissions TRUE). Task 1's export brings them in. `university/data/buildings.txt` is only ever written by `python3 bin/GetDataFromGoogleSheets.py`.
- **`university/data/start_state.json`** is hand-authored and in git. Tasks 6 and 9 edit it, with the user's standing go-ahead.
- **Never guess a Godot or addon API.** Grep this repo or the addon source under `university/addons/`. GDScript's natural log is `log(x)`, and `exp(x)` and `pow(b, e)` are built in.
- **Tests** assert behavior and relationships, never the values in `data/buildings.txt` or `data/start_state.json`, and never a tuning const's value.
- **Commits.** `.gd.uid` files are committed next to their scripts. Every commit message ends with `Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>`. Commit locally on `main`; do not push.

### Named procedures

**REGISTER** runs after adding or removing any `class_name` script:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --editor --quit-after 20 2>&1 | grep -E "ERROR|WARNING|Parse Error" ; true
```
Expected: no output.

**RUN-TESTS** runs the whole suite. A total that drops means a suite failed to parse:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Overall Summary|Executed test|FAILED|Parse Error|SCRIPT ERROR|leaked"
```
- To run one suite, replace `--add tests/` with `--add tests/<Suite>.gd`.
- `ERROR:` lines from deliberate, asserted `push_error`s are expected.
- The summary must read `0 errors | 0 failures`, and nothing may say `leaked`.

Expected totals after each task. Today it's 128 cases in 16 suites.

| After task | Cases | Suites |
|---|---|---|
| 1 | 132 | 16 |
| 2 | 137 | 17 |
| 3 | 144 | 18 |
| 4 | 156 | 19 |
| 5 | 167 | 19 |
| 6 | 170 | 19 |
| 7 | 174 | 19 |
| 8 | 174 | 19 |
| 9 | 174 | 19 |

**LAUNCH-CHECK** launches with the window hidden, reads stdout, drives the game by console, then kills Godot:
```
cd /Users/noel/Development/University/game
mkdir -p /tmp/university
(for i in $(seq 1 20); do sleep 0.2; osascript -e 'tell application "System Events" to set visible of process "Godot" to false' 2>/dev/null; done) &
./bin/run.sh > /tmp/university/run.log 2>&1 &
sleep 7
grep -nE "SCRIPT ERROR|Parse Error|ERROR|WARNING" /tmp/university/run.log
# console commands: echo "<command>" | nc -w 3 localhost 9999
pkill -f "Godot"
```
- **Expected:** the grep prints nothing.
- Run `pause` first whenever you read numbers, so no month rolls over mid-check.
- Always `pkill -f "Godot"` when done.
- Never delete anything in `~/Library/Application Support/Godot/app_userdata/University/` except a `quicksave.json` your own check created.
- **Existing console commands:**
  - `camera <x> <z> <dist> <yaw>`
  - `build <id> <x> <z> <deg>`, `destroy <n>`, `buildings`
  - `tool <id|destroy|none>`, `select <n>`
  - `state`
  - `mousedown|mouseup <x> <y> [button]`, `mousemove <x> <y>`
  - `action <name> <down|up>`
  - `pause`, `speed <1-3>`
  - `money [amount]`, `debt [amount]`, `borrow <amount>`, `repay <amount>`
  - `advance <months>`
  - `save [path]`, `load [path]`, `newgame`
- **Building type ids:** `admissions`, `dorm`, `engineering_1`, `dining_1`.

---

### Task 1: Capacities: seats, beds, meals and the Admissions Office

**Files:**
- Modify:
  - `university/data/buildings.txt`, by running the export script only
  - `university/src/data/building_info.gd`
  - `university/src/state/campus.gd`
  - `CLAUDE.md` (the Data section)
- Test: `university/tests/BuildingInfoTest.gd`, `university/tests/CampusTest.gd`

**Interfaces:**
- **Produces:**
  - `BuildingInfo`: `seats: int`, `beds: int`, `meals: int`, `admissionsOffice: bool`
  - `Campus`:
    - `seats() -> int`, `beds() -> int`, `meals() -> int` (open buildings only)
    - `hasOpenAdmissionsOffice() -> bool`
    - `startMonth(newMonth: int) -> Array[Building]`, the buildings it opened, in the order announced
    - `upkeep()`, now built on the same private `_openTotal(amount: Callable) -> int`

- [ ] **Step 1: Export the Sheet**

```bash
cd /Users/noel/Development/University/game && python3 bin/GetDataFromGoogleSheets.py && cat university/data/buildings.txt
```

Expected:
- The header ends `,upkeepK,seats,beds,meals,admissionsOffice`.
- engineering_1 has seats 400, dorm has beds 120, dining_1 has meals 650, and admissions has `TRUE`.

If the script reports an HTML page, stop and report BLOCKED. Never hand-edit the file.

- [ ] **Step 2: Write the failing tests**

**`university/tests/BuildingInfoTest.gd`**, append:

```gdscript


func test_capacities_read_as_whole_numbers_and_blanks_as_none() -> void:
	var info: BuildingInfo = BuildingInfo.new({"id": "x", "name": "X", "seats": 400, "beds": "", "meals": 650, "admissionsOffice": true})
	assert_int(info.seats).is_equal(400)
	assert_int(info.beds).is_equal(0)
	assert_int(info.meals).is_equal(650)
	assert_bool(info.admissionsOffice).is_true()
	assert_bool(BuildingInfo.new({"id": "y", "name": "Y"}).admissionsOffice).is_false()
```

**`university/tests/CampusTest.gd`**, append:

```gdscript


const Seats: int = 40
const Beds: int = 30
const Meals: int = 20


func test_capacities_count_only_open_buildings() -> void:
	var campus: Campus = _campus()
	var hall: BuildingInfo = BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": Seats, "beds": Beds, "meals": Meals})
	var first: Building = campus.place(hall, Vector2.ZERO, 0.0)
	assert_int(campus.seats() + campus.beds() + campus.meals()).is_equal(0)
	campus.startMonth(first.opensAtMonth)
	campus.place(hall, Vector2(Diameter * 2.0, 0.0), 0.0)
	assert_int(campus.seats()).is_equal(Seats)
	assert_int(campus.beds()).is_equal(Beds)
	assert_int(campus.meals()).is_equal(Meals)


func test_only_an_open_admissions_office_counts() -> void:
	var campus: Campus = _campus()
	var office: BuildingInfo = BuildingInfo.new({"id": "office", "name": "Office", "diameter": Diameter, "admissionsOffice": true})
	var building: Building = campus.place(office, Vector2.ZERO, 0.0)
	assert_bool(campus.hasOpenAdmissionsOffice()).is_false()
	campus.startMonth(building.opensAtMonth)
	assert_bool(campus.hasOpenAdmissionsOffice()).is_true()


func test_a_month_start_answers_the_buildings_it_opened() -> void:
	var campus: Campus = _campus()
	var first: Building = campus.place(_info(), Vector2.ZERO, 0.0)
	var opened: Array[Building] = campus.startMonth(first.opensAtMonth)
	assert_array(opened).contains_exactly([first])
	assert_array(campus.startMonth(first.opensAtMonth + 1)).is_empty()
```

- [ ] **Step 3: Run them to see them fail**

Run RUN-TESTS.
Expected: `BuildingInfoTest` and `CampusTest` drop out with parse errors (`seats` isn't a member, and `startMonth` returns nothing). Everything else passes.

- [ ] **Step 4: `BuildingInfo` capacities**

In `university/src/data/building_info.gd`, below `var upkeep: int` and its comment, add:

```gdscript
# Academic seats, beds, and how many diners a dining hall is meant for.
var seats: int
var beds: int
var meals: int
# This type grants the price and minimum-grade levers: the Admissions Office.
var admissionsOffice: bool
```

In `_init`, after the `upkeep = …` line, add:

```gdscript
	seats = maxi(Variants.toInt(data.get("seats", 0)), 0)
	beds = maxi(Variants.toInt(data.get("beds", 0)), 0)
	meals = maxi(Variants.toInt(data.get("meals", 0)), 0)
	admissionsOffice = Variants.toBool(data.get("admissionsOffice", false))
```

- [ ] **Step 5: `Campus` totals and the opened list**

In `university/src/state/campus.gd`, replace the whole `startMonth` function (and its doc comment) with:

```gdscript
## A new month began: every building due by now opens. The due ones are
## collected before any is announced, so a listener that destroys the building
## it hears about cannot cut the pass short. Answers the buildings it opened,
## in the order announced.
func startMonth(newMonth: int) -> Array[Building]:
	month = newMonth
	var due: Array[Building] = []
	for building: Building in buildings:
		if (building.underConstruction and building.opensAtMonth <= month):
			due.append(building)
	var opened: Array[Building] = []
	for building: Building in due:
		# A listener may have destroyed it while an earlier one was announced.
		if (not buildings.has(building)):
			continue
		building.underConstruction = false
		opened.append(building)
		BuildingOpened.emit(building)
	return opened
```

Replace the whole `upkeep` function (and its doc comment) with:

```gdscript
## The month's upkeep in whole dollars: every open building's. One still under
## construction costs nothing yet.
func upkeep() -> int:
	return _openTotal(func(info: BuildingInfo) -> int: return info.upkeep)


## Academic seats in open buildings.
func seats() -> int:
	return _openTotal(func(info: BuildingInfo) -> int: return info.seats)


## Beds in open buildings.
func beds() -> int:
	return _openTotal(func(info: BuildingInfo) -> int: return info.beds)


## The diners every open dining hall is meant for, together.
func meals() -> int:
	return _openTotal(func(info: BuildingInfo) -> int: return info.meals)


## Whether an open building grants the price and minimum-grade levers.
func hasOpenAdmissionsOffice() -> bool:
	for building: Building in buildings:
		if (not building.underConstruction and building.info.admissionsOffice):
			return true
	return false


# The one sum over open buildings: amount answers what one type contributes.
func _openTotal(amount: Callable) -> int:
	var total: int = 0
	for building: Building in buildings:
		if (not building.underConstruction):
			total += Variants.toInt(amount.call(building.info))
	return total
```

- [ ] **Step 6: Run the tests**

Run RUN-TESTS.
Expected: 132 cases in 16 suites, `0 errors | 0 failures`, no `leaked`.

- [ ] **Step 7: Update `CLAUDE.md`**

In `CLAUDE.md`, replace:

```
same way in thousands a month, in `upkeepK`, and `BuildingInfo.DollarsPerK`
turns it into `BuildingInfo.upkeep`, whole dollars.
```

with:

```
same way in thousands a month, in `upkeepK`, and `BuildingInfo.DollarsPerK`
turns it into `BuildingInfo.upkeep`, whole dollars. Capacities are whole
numbers: `seats` (academic), `beds` and `meals` (the diners a dining hall is
meant for, not a hard cap), and `admissionsOffice` is TRUE on the type that
grants the price and minimum-grade levers. A blank reads as none. `Campus`
answers `seats()`, `beds()`, `meals()` and `upkeep()` over open buildings only,
through one `_openTotal`, and `hasOpenAdmissionsOffice()`.
```

- [ ] **Step 8: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/data/buildings.txt university/src/data/building_info.gd university/src/state/campus.gd university/tests/BuildingInfoTest.gd university/tests/CampusTest.gd CLAUDE.md
git commit -m "$(cat <<'EOF'
Give buildings seats, beds, dining and the admissions office

Capacities come from the Sheet's new columns; the campus totals them
over open buildings, and a month start answers what it opened.

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `Cohort` and `StudentBody`

**Files:**
- Create: `university/src/state/cohort.gd`, `university/src/state/student_body.gd`
- Test: `university/tests/StudentBodyTest.gd`

**Interfaces:**
- **Consumes:** `Variants.hasKeys`, `Variants.toInt`, `Variants.toFloat`, `Variants.MissingKeysError`.
- **Produces:**
  - `Cohort`:
    - `size: int`, `entryGrade: float`, `semestersCompleted: int`
    - `_init(students: int, grade: float)`
    - `SavedKeys`, `toDict()`, `static fromDict(data: Dictionary) -> Cohort`
  - `StudentBody`:
    - `SemestersToGraduate: int` = 8
    - `cohorts: Array[Cohort]`
    - `enrolled() -> int`
    - `completeSemester() -> int` (returns how many graduated)
    - `admit(size: int, grade: float) -> void`
    - `SavedKeys`, `toDict()`, `static fromDict(data: Dictionary) -> StudentBody`

- [ ] **Step 1: Write the failing tests**

Create `university/tests/StudentBodyTest.gd`:

```gdscript
extends GdUnitTestSuite
## Students as cohorts: enrolment, graduation after the full course, and the
## save round trip. Sizes and grades are arbitrary fixtures.

const Size: int = 120
const Grade: float = 3.1
const OtherSize: int = 90


func test_enrolment_is_every_cohort_together() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	body.admit(OtherSize, Grade)
	assert_int(body.enrolled()).is_equal(Size + OtherSize)


func test_admitting_no_one_adds_no_cohort() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(0, Grade)
	assert_array(body.cohorts).is_empty()


func test_a_cohort_graduates_after_the_full_course_and_not_before() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	for _semester: int in range(StudentBody.SemestersToGraduate - 1):
		assert_int(body.completeSemester()).is_equal(0)
	assert_int(body.enrolled()).is_equal(Size)
	assert_int(body.completeSemester()).is_equal(Size)
	assert_int(body.enrolled()).is_equal(0)


func test_a_round_trip_keeps_every_cohort() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	body.completeSemester()
	body.admit(OtherSize, Grade)
	var back: StudentBody = StudentBody.fromDict(SaveFile.decode(SaveFile.encode(body.toDict())) as Dictionary)
	assert_str(SaveFile.encode(back.toDict())).is_equal(SaveFile.encode(body.toDict()))


func test_a_cohort_missing_a_key_is_refused() -> void:
	var body: StudentBody = StudentBody.new()
	body.admit(Size, Grade)
	var data: Dictionary = body.toDict()
	((data["cohorts"] as Array)[0] as Dictionary).erase("entryGrade")
	var loaded: Array[StudentBody] = []
	await assert_error(func() -> void: loaded.append(StudentBody.fromDict(data))) \
		.is_push_error(Variants.MissingKeysError % ["Cohort", "entryGrade"])
	assert_object(loaded[0]).is_null()
```

- [ ] **Step 2: Run them to see them fail**

Run RUN-TESTS with `--add tests/StudentBodyTest.gd`.
Expected: a `Parse Error` about `StudentBody`, and 0 cases.

- [ ] **Step 3: Write `Cohort`**

Create `university/src/state/cohort.gd`:

```gdscript
class_name Cohort
## One fall's intake, from admission to graduation: how many students it has,
## the grade of the weakest one admitted, and how many semesters it has
## completed. A cohort never shrinks; it graduates whole.

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["size", "entryGrade", "semestersCompleted"]

var size: int
var entryGrade: float
var semestersCompleted: int = 0


func _init(students: int, grade: float) -> void:
	size = students
	entryGrade = grade


func toDict() -> Dictionary:
	return {"size": size, "entryGrade": entryGrade, "semestersCompleted": semestersCompleted}


## Null when data is missing a key.
static func fromDict(data: Dictionary) -> Cohort:
	if (not Variants.hasKeys(data, SavedKeys, "Cohort")):
		return null
	var cohort: Cohort = Cohort.new(maxi(Variants.toInt(data["size"]), 0), Variants.toFloat(data["entryGrade"]))
	cohort.semestersCompleted = maxi(Variants.toInt(data["semestersCompleted"]), 0)
	return cohort
```

- [ ] **Step 4: Write `StudentBody`**

Create `university/src/state/student_body.gd`:

```gdscript
class_name StudentBody
## Every student enrolled, as cohorts: one per fall intake. At each semester
## start every cohort completes a semester, and those that have completed
## SemestersToGraduate leave together.

const SemestersToGraduate: int = 8
# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["cohorts"]

var cohorts: Array[Cohort]


func enrolled() -> int:
	var total: int = 0
	for cohort: Cohort in cohorts:
		total += cohort.size
	return total


## A semester began: every cohort has completed one more, and those that have
## completed the full course graduate. Returns how many students graduated.
func completeSemester() -> int:
	var graduated: int = 0
	var staying: Array[Cohort] = []
	for cohort: Cohort in cohorts:
		cohort.semestersCompleted += 1
		if (cohort.semestersCompleted >= SemestersToGraduate):
			graduated += cohort.size
		else:
			staying.append(cohort)
	cohorts = staying
	return graduated


## A fall intake joins. Admitting no one adds no cohort.
func admit(size: int, grade: float) -> void:
	if (size > 0):
		cohorts.append(Cohort.new(size, grade))


func toDict() -> Dictionary:
	var saved: Array[Dictionary] = []
	for cohort: Cohort in cohorts:
		saved.append(cohort.toDict())
	return {"cohorts": saved}


## Null when data, or any cohort in it, is missing a key.
static func fromDict(data: Dictionary) -> StudentBody:
	if (not Variants.hasKeys(data, SavedKeys, "StudentBody")):
		return null
	var body: StudentBody = StudentBody.new()
	for saved: Variant in data["cohorts"] as Array:
		var cohort: Cohort = Cohort.fromDict(saved as Dictionary)
		if (cohort == null):
			return null
		body.cohorts.append(cohort)
	return body
```

- [ ] **Step 5: REGISTER, then run the tests**

Run REGISTER, then RUN-TESTS.
Expected: 137 cases in 17 suites, `0 errors | 0 failures`.

- [ ] **Step 6: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/cohort.gd university/src/state/cohort.gd.uid university/src/state/student_body.gd university/src/state/student_body.gd.uid university/tests/StudentBodyTest.gd university/tests/StudentBodyTest.gd.uid
git commit -m "$(cat <<'EOF'
Add cohorts: students admitted each fall, graduating after 8 semesters

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `Prices` and `Policy`

**Files:**
- Create: `university/src/state/prices.gd`, `university/src/state/policy.gd`
- Test: `university/tests/PolicyTest.gd`

**Interfaces:**
- **Consumes:** `Variants.*`. It also reads `UniversityRules.MaxGrade`, which doesn't exist until Task 4. So `Policy` uses its own `const MaxMinimumGrade: float = 4.0` for now, and Task 4 replaces it with `UniversityRules.MaxGrade` (see Task 4, Step 5).
- **Produces:**
  - `Prices`:
    - `tuition: int`, `room: int`, `mealPlan: int`
    - `_init(tuitionPrice: int, roomPrice: int, mealPlanPrice: int)`
    - `total() -> int`, `copy() -> Prices`
    - `SavedKeys`, `toDict()`, `static fromDict(data) -> Prices`
  - `Policy`:
    - `DefaultTuition` 9606, `DefaultRoom` 4542, `DefaultMealPlan` 4136
    - `current: Prices`, `next: Prices`, `minimumGrade: float`
    - `static defaultPrices() -> Prices`
    - `setNextTuition(amount: int)`, `setNextRoom(amount: int)`, `setNextMealPlan(amount: int)`
    - `setMinimumGrade(grade: float)`
    - `lockYear(hasOffice: bool)`
    - `minimumInUse(hasOffice: bool) -> float`
    - `SavedKeys`, `toDict()`, `static fromDict(data) -> Policy`

- [ ] **Step 1: Write the failing tests**

Create `university/tests/PolicyTest.gd`:

```gdscript
extends GdUnitTestSuite
## Prices set a year ahead and the minimum grade, and what applies without an
## Admissions Office. Prices are arbitrary fixtures.

const Tuition: int = 12000
const Room: int = 5000
const MealPlan: int = 4000
const Minimum: float = 3.2


func test_a_new_policy_charges_the_defaults() -> void:
	var policy: Policy = Policy.new()
	assert_int(policy.current.total()).is_equal(Policy.defaultPrices().total())
	assert_int(policy.next.total()).is_equal(Policy.defaultPrices().total())
	assert_float(policy.minimumGrade).is_equal(0.0)


func test_the_total_is_what_a_semester_costs() -> void:
	assert_int(Prices.new(Tuition, Room, MealPlan).total()).is_equal(Tuition + Room + MealPlan)


func test_prices_and_the_minimum_stay_in_range() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(-Tuition)
	policy.setNextRoom(-Room)
	policy.setNextMealPlan(-MealPlan)
	assert_int(policy.next.total()).is_equal(0)
	policy.setMinimumGrade(-Minimum)
	assert_float(policy.minimumGrade).is_equal(0.0)
	policy.setMinimumGrade(Minimum * 10.0)
	assert_float(policy.minimumGrade).is_less_equal(Policy.MaxMinimumGrade)


func test_next_years_prices_apply_only_when_the_year_is_locked() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	assert_int(policy.current.tuition).is_equal(Policy.DefaultTuition)
	policy.lockYear(true)
	assert_int(policy.current.tuition).is_equal(Tuition)
	# The year's prices are a copy: setting next year's again leaves them alone.
	policy.setNextTuition(Tuition * 2)
	assert_int(policy.current.tuition).is_equal(Tuition)


func test_without_an_admissions_office_the_defaults_apply_and_there_is_no_minimum() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	policy.setMinimumGrade(Minimum)
	policy.lockYear(false)
	assert_int(policy.current.total()).is_equal(Policy.defaultPrices().total())
	assert_float(policy.minimumInUse(false)).is_equal(0.0)
	assert_float(policy.minimumInUse(true)).is_equal(Minimum)


func test_a_round_trip_keeps_the_policy() -> void:
	var policy: Policy = Policy.new()
	policy.setNextTuition(Tuition)
	policy.setMinimumGrade(Minimum)
	var back: Policy = Policy.fromDict(SaveFile.decode(SaveFile.encode(policy.toDict())) as Dictionary)
	assert_str(SaveFile.encode(back.toDict())).is_equal(SaveFile.encode(policy.toDict()))


func test_a_policy_missing_a_key_is_refused() -> void:
	var data: Dictionary = Policy.new().toDict()
	(data["next"] as Dictionary).erase("room")
	var loaded: Array[Policy] = []
	await assert_error(func() -> void: loaded.append(Policy.fromDict(data))) \
		.is_push_error(Variants.MissingKeysError % ["Prices", "room"])
	assert_object(loaded[0]).is_null()
```

- [ ] **Step 2: Run them to see them fail**

Run RUN-TESTS with `--add tests/PolicyTest.gd`.
Expected: a `Parse Error` about `Policy`, and 0 cases.

- [ ] **Step 3: Write `Prices`**

Create `university/src/state/prices.gd`:

```gdscript
class_name Prices
## What a semester costs a student, in whole dollars: tuition, a room on
## campus and a meal plan. Off-campus students pay tuition only.

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["tuition", "room", "mealPlan"]

var tuition: int
var room: int
var mealPlan: int


func _init(tuitionPrice: int, roomPrice: int, mealPlanPrice: int) -> void:
	tuition = tuitionPrice
	room = roomPrice
	mealPlan = mealPlanPrice


## The sticker price applicants weigh: everything a semester on campus costs.
func total() -> int:
	return tuition + room + mealPlan


func copy() -> Prices:
	return Prices.new(tuition, room, mealPlan)


func toDict() -> Dictionary:
	return {"tuition": tuition, "room": room, "mealPlan": mealPlan}


## Null when data is missing a key. A price below zero reads as zero.
static func fromDict(data: Dictionary) -> Prices:
	if (not Variants.hasKeys(data, SavedKeys, "Prices")):
		return null
	return Prices.new(
		maxi(Variants.toInt(data["tuition"]), 0),
		maxi(Variants.toInt(data["room"]), 0),
		maxi(Variants.toInt(data["mealPlan"]), 0))
```

- [ ] **Step 4: Write `Policy`**

Create `university/src/state/policy.gd`:

```gdscript
class_name Policy
## What the university charges and whom it admits. Prices are set a year
## ahead: the player sets `next`, and each fall start makes it `current` for
## the whole academic year. The Admissions Office grants the levers: with none
## open, the defaults apply and there is no minimum grade.

# UMass 2026-27 in-state, per semester.
const DefaultTuition: int = 9606
const DefaultRoom: int = 4542
const DefaultMealPlan: int = 4136
# The highest a minimum grade can be set.
const MaxMinimumGrade: float = 4.0
# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["current", "next", "minimumGrade"]

var current: Prices
var next: Prices
# 0 is off.
var minimumGrade: float = 0.0


func _init() -> void:
	current = Policy.defaultPrices()
	next = Policy.defaultPrices()


static func defaultPrices() -> Prices:
	return Prices.new(DefaultTuition, DefaultRoom, DefaultMealPlan)


func setNextTuition(amount: int) -> void:
	next.tuition = maxi(amount, 0)


func setNextRoom(amount: int) -> void:
	next.room = maxi(amount, 0)


func setNextMealPlan(amount: int) -> void:
	next.mealPlan = maxi(amount, 0)


func setMinimumGrade(grade: float) -> void:
	minimumGrade = clampf(grade, 0.0, MaxMinimumGrade)


## The fall start: next year's prices become this year's, or the defaults when
## no Admissions Office is open.
func lockYear(hasOffice: bool) -> void:
	current = next.copy() if (hasOffice) else Policy.defaultPrices()


## The minimum the fall admission applies: none without an Admissions Office.
func minimumInUse(hasOffice: bool) -> float:
	return minimumGrade if (hasOffice) else 0.0


func toDict() -> Dictionary:
	return {"current": current.toDict(), "next": next.toDict(), "minimumGrade": minimumGrade}


## Null when data, or either set of prices in it, is missing a key.
static func fromDict(data: Dictionary) -> Policy:
	if (not Variants.hasKeys(data, SavedKeys, "Policy")):
		return null
	var loadedCurrent: Prices = Prices.fromDict(data["current"] as Dictionary)
	if (loadedCurrent == null):
		return null
	var loadedNext: Prices = Prices.fromDict(data["next"] as Dictionary)
	if (loadedNext == null):
		return null
	var policy: Policy = Policy.new()
	policy.current = loadedCurrent
	policy.next = loadedNext
	policy.setMinimumGrade(Variants.toFloat(data["minimumGrade"]))
	return policy
```

- [ ] **Step 5: REGISTER, then run the tests**

Run REGISTER, then RUN-TESTS.
Expected: 144 cases in 18 suites, `0 errors | 0 failures`.

- [ ] **Step 6: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/prices.gd university/src/state/prices.gd.uid university/src/state/policy.gd university/src/state/policy.gd.uid university/tests/PolicyTest.gd university/tests/PolicyTest.gd.uid
git commit -m "$(cat <<'EOF'
Add prices set a year ahead and the minimum grade

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `UniversityRules`, the loop's formulas

**Files:**
- Create:
  - `university/src/state/university_rules.gd`
  - `university/src/state/intake.gd`
  - `university/src/state/satisfaction.gd`
  - `university/src/state/fees.gd`
- Modify: `university/src/state/policy.gd` (use `UniversityRules.MaxGrade`)
- Test: `university/tests/UniversityRulesTest.gd`

**Interfaces:**
- **Consumes:** `Prices` (Task 3).
- **Produces:**
  - `Intake`: `admitted: int`, `entryGrade: float`, `_init(students: int, grade: float)`
  - `Satisfaction`: `base: float`, `housing: float`, `crowding: float`, `unfed: float`, `total() -> float`
  - `Fees`: `tuition: int`, `room: int`, `meals: int`, `total() -> int`
  - `UniversityRules`:
    - consts, as in the Global Constraints: ApplicantPool, ReputationReference, ReputationDoubling, ReferencePrice, PriceHalving, GradeBase, GradeSpread, MaxGrade, MaxScore, GradeToScore, SatisfactionBase, OverflowThreshold, OverflowWeight, CrowdingWeight, DiningHardLimit, UnfedWeight, ReputationRate, ReputationGradeWeight
    - `static applicants(reputation: float, totalPrice: int) -> int`
    - `static admission(applicantCount: int, openSeats: int, minimum: float) -> Intake`
    - `static housed(enrolled: int, beds: int) -> int`
    - `static mealPlans(housedCount: int, meals: int) -> int`
    - `static diningLoad(housedCount: int, meals: int) -> float`
    - `static satisfaction(enrolled: int, housedCount: int, meals: int) -> Satisfaction`
    - `static reputationTarget(intakeGrade: float, meanSatisfaction: float) -> float`
    - `static nextReputation(reputation: float, target: float) -> float`
    - `static fees(prices: Prices, enrolled: int, housedCount: int, plans: int) -> Fees`
    - `static loopGain() -> float`

- [ ] **Step 1: Write the failing tests**

Create `university/tests/UniversityRulesTest.gd`:

```gdscript
extends GdUnitTestSuite
## The student loop's rules, as relationships: they hold whatever the tuning
## values are. Inputs are arbitrary fixtures built around the consts.

const Seats: int = 200
const HalfSeats: int = 100
const Reputation: float = 60.0
const Price: int = 18000
const Room: int = 9000
const MealPlan: int = 6000
const Enrolled: int = 1000
const HalfEnrolled: int = 500
const QuarterEnrolled: int = 250
# A dining load between recommended and the hard limit.
const Crowded: float = 1.2
const Epsilon: float = 0.0001


func test_applicants_rise_with_reputation() -> void:
	var better: int = UniversityRules.applicants(Reputation + UniversityRules.ReputationDoubling, Price)
	assert_int(better).is_greater(UniversityRules.applicants(Reputation, Price))


func test_applicants_fall_with_price_and_stay_finite_at_zero() -> void:
	var dearer: int = UniversityRules.applicants(Reputation, Price + roundi(UniversityRules.PriceHalving))
	assert_int(dearer).is_less(UniversityRules.applicants(Reputation, Price))
	assert_int(UniversityRules.applicants(Reputation, 0)).is_greater(0)


func test_as_many_applicants_as_seats_fills_them_at_the_base_grade() -> void:
	var intake: Intake = UniversityRules.admission(Seats, Seats, 0.0)
	assert_int(intake.admitted).is_equal(Seats)
	assert_float(intake.entryGrade).is_equal_approx(UniversityRules.GradeBase, Epsilon)


func test_more_applicants_fill_the_seats_with_a_higher_grade() -> void:
	var intake: Intake = UniversityRules.admission(Seats * 3, Seats, 0.0)
	assert_int(intake.admitted).is_equal(Seats)
	assert_float(intake.entryGrade).is_greater(UniversityRules.GradeBase)


func test_fewer_applicants_are_all_admitted_with_a_lower_grade() -> void:
	var intake: Intake = UniversityRules.admission(HalfSeats, Seats, 0.0)
	assert_int(intake.admitted).is_equal(HalfSeats)
	assert_float(intake.entryGrade).is_less(UniversityRules.GradeBase)


func test_a_minimum_above_the_cutoff_trades_students_for_grade() -> void:
	var open: Intake = UniversityRules.admission(Seats * 3, Seats, 0.0)
	var raised: float = open.entryGrade + UniversityRules.GradeSpread
	var picky: Intake = UniversityRules.admission(Seats * 3, Seats, raised)
	assert_int(picky.admitted).is_less(open.admitted)
	assert_float(picky.entryGrade).is_equal_approx(raised, Epsilon)
	# One below the cutoff changes nothing.
	var lenient: Intake = UniversityRules.admission(Seats * 3, Seats, open.entryGrade - UniversityRules.GradeSpread)
	assert_int(lenient.admitted).is_equal(open.admitted)
	assert_float(lenient.entryGrade).is_equal_approx(open.entryGrade, Epsilon)


func test_no_open_seats_admits_no_one() -> void:
	assert_int(UniversityRules.admission(Seats, 0, 0.0).admitted).is_equal(0)
	assert_int(UniversityRules.admission(0, Seats, 0.0).admitted).is_equal(0)


func test_housing_costs_satisfaction_only_past_the_threshold() -> void:
	var atThreshold: int = roundi(float(Enrolled) * (1.0 - UniversityRules.OverflowThreshold))
	var plentyOfMeals: int = Enrolled * 2
	assert_float(UniversityRules.satisfaction(Enrolled, atThreshold, plentyOfMeals).housing).is_equal_approx(0.0, Epsilon)
	var overflowing: Satisfaction = UniversityRules.satisfaction(Enrolled, atThreshold / 2, plentyOfMeals)
	assert_float(overflowing.housing).is_greater(0.0)
	assert_float(overflowing.total()).is_less(UniversityRules.SatisfactionBase)


func test_dining_crowds_past_its_recommended_load_and_starves_past_the_limit() -> void:
	var meals: int = HalfEnrolled
	var comfortable: Satisfaction = UniversityRules.satisfaction(Enrolled, meals, meals)
	assert_float(comfortable.crowding + comfortable.unfed).is_equal_approx(0.0, Epsilon)
	var crowded: Satisfaction = UniversityRules.satisfaction(Enrolled, roundi(float(meals) * Crowded), meals)
	assert_float(crowded.crowding).is_greater(0.0)
	assert_float(crowded.unfed).is_equal_approx(0.0, Epsilon)
	var atLimit: int = floori(UniversityRules.DiningHardLimit * float(meals))
	var starving: Satisfaction = UniversityRules.satisfaction(Enrolled, Enrolled, meals)
	assert_float(starving.unfed).is_greater(0.0)
	# Crowding stops growing at the limit: past it, the rest simply can't eat.
	var limited: Satisfaction = UniversityRules.satisfaction(Enrolled, atLimit, meals)
	assert_float(starving.crowding).is_equal_approx(limited.crowding, Epsilon)
	assert_int(UniversityRules.mealPlans(Enrolled, meals)).is_equal(atLimit)


func test_no_students_means_base_satisfaction() -> void:
	assert_float(UniversityRules.satisfaction(0, 0, 0).total()).is_equal_approx(UniversityRules.SatisfactionBase, Epsilon)


func test_reputation_moves_part_of_the_way_to_its_target_and_stays_in_range() -> void:
	var target: float = Reputation + 10.0
	var moved: float = UniversityRules.nextReputation(Reputation, target)
	assert_float(moved - Reputation).is_equal_approx(UniversityRules.ReputationRate * (target - Reputation), Epsilon)
	assert_float(UniversityRules.nextReputation(UniversityRules.MaxScore, UniversityRules.MaxScore * 3.0)).is_less_equal(UniversityRules.MaxScore)
	assert_float(UniversityRules.nextReputation(0.0, -UniversityRules.MaxScore)).is_greater_equal(0.0)


func test_the_grades_reputation_applicants_loop_settles_by_itself() -> void:
	# Once round the loop, an extra point of reputation must come back as less
	# than a point of target, or reputation runs away.
	assert_float(UniversityRules.loopGain()).is_less(1.0)


func test_off_campus_students_pay_tuition_only() -> void:
	var prices: Prices = Prices.new(Price, Room, MealPlan)
	var fees: Fees = UniversityRules.fees(prices, Enrolled, HalfEnrolled, QuarterEnrolled)
	assert_int(fees.tuition).is_equal(Price * Enrolled)
	assert_int(fees.room).is_equal(Room * HalfEnrolled)
	assert_int(fees.meals).is_equal(MealPlan * QuarterEnrolled)
	assert_int(fees.total()).is_equal(fees.tuition + fees.room + fees.meals)
```

There's no integer division anywhere: the halves and quarters are named consts, because CLAUDE.md counts the INTEGER_DIVISION warning as a failure.

- [ ] **Step 2: Run them to see them fail**

Run RUN-TESTS with `--add tests/UniversityRulesTest.gd`.
Expected: a `Parse Error` about `UniversityRules`, and 0 cases.

- [ ] **Step 3: The records**

Create `university/src/state/intake.gd`:

```gdscript
class_name Intake
## One fall admission: how many were admitted and the grade of the weakest.

var admitted: int
var entryGrade: float


func _init(students: int, grade: float) -> void:
	admitted = students
	entryGrade = grade
```

Create `university/src/state/satisfaction.gd`:

```gdscript
class_name Satisfaction
## A satisfaction score and what it is made of: a base, less three penalties.

var base: float
var housing: float = 0.0
var crowding: float = 0.0
var unfed: float = 0.0


func total() -> float:
	return clampf(base - housing - crowding - unfed, 0.0, UniversityRules.MaxScore)
```

Create `university/src/state/fees.gd`:

```gdscript
class_name Fees
## One semester start's fees, whole dollars, by what they pay for.

var tuition: int = 0
var room: int = 0
var meals: int = 0


func total() -> int:
	return tuition + room + meals
```

- [ ] **Step 4: `UniversityRules`**

Create `university/src/state/university_rules.gd`:

```gdscript
class_name UniversityRules
## The student loop's rules and tuning, as pure functions: how many apply, who
## is admitted and at what grade, where students live and eat, how satisfied
## they are, and how reputation moves. Every tuning value is a named const
## here; they are starting points for tuning, not decisions.

# Applicants: every ReputationDoubling points of reputation doubles them, and
# every PriceHalving dollars of total price above ReferencePrice halves them.
const ApplicantPool: float = 4000.0
const ReputationReference: float = 50.0
const ReputationDoubling: float = 20.0
const ReferencePrice: float = 18300.0
const PriceHalving: float = 6000.0
# Grades are GPA, 0 to MaxGrade. The weakest admit's grade is GradeBase when
# applicants equal open seats, and rises GradeSpread per factor of e beyond.
const GradeBase: float = 2.8
const GradeSpread: float = 0.35
const MaxGrade: float = 4.0
# Satisfaction and reputation are scores from 0 to MaxScore.
const MaxScore: float = 100.0
const GradeToScore: float = MaxScore / MaxGrade
# Satisfaction has only penalties so far, so its base sits below the top.
const SatisfactionBase: float = 75.0
const OverflowThreshold: float = 0.25
const OverflowWeight: float = 100.0
const CrowdingWeight: float = 50.0
const DiningHardLimit: float = 1.3
const UnfedWeight: float = 150.0
const ReputationRate: float = 0.3
const ReputationGradeWeight: float = 0.5
const Doubling: float = 2.0


## How many apply at a fall start.
static func applicants(reputation: float, totalPrice: int) -> int:
	var fromReputation: float = pow(Doubling, (reputation - ReputationReference) / ReputationDoubling)
	var fromPrice: float = pow(Doubling, -(float(totalPrice) - ReferencePrice) / PriceHalving)
	return floori(ApplicantPool * fromReputation * fromPrice)


## Who is admitted from the applicants into the open seats, and the grade of the
## weakest one admitted. The class trails off above that cutoff, so a minimum
## above it trims the class along the same spread: it always trades students
## for grade. No seats or no applicants admits nobody.
static func admission(applicantCount: int, openSeats: int, minimum: float) -> Intake:
	if (applicantCount <= 0 or openSeats <= 0):
		return Intake.new(0, 0.0)
	var cutoff: float = clampf(GradeBase + GradeSpread * log(float(applicantCount) / float(openSeats)), 0.0, MaxGrade)
	var kept: float = exp(-maxf(0.0, minimum - cutoff) / GradeSpread)
	return Intake.new(floori(float(mini(applicantCount, openSeats)) * kept), maxf(cutoff, minimum))


## Students in a bed on campus; the rest live off campus.
static func housed(enrolled: int, beds: int) -> int:
	return mini(enrolled, beds)


## Housed students who eat on campus: all of them, up to DiningHardLimit times
## what the dining halls are meant for. Past that the rest can't eat, and buy
## no meal plan. Off-campus students buy none either.
static func mealPlans(housedCount: int, meals: int) -> int:
	return mini(housedCount, floori(DiningHardLimit * float(meals)))


## Housed students per diner the dining halls are meant for. With no dining
## hall it is measured against one, so it reads as hopelessly over.
static func diningLoad(housedCount: int, meals: int) -> float:
	return float(housedCount) / float(maxi(meals, 1))


static func satisfaction(enrolled: int, housedCount: int, meals: int) -> Satisfaction:
	var result: Satisfaction = Satisfaction.new()
	result.base = SatisfactionBase
	if (enrolled <= 0):
		return result
	var plans: int = mealPlans(housedCount, meals)
	var perStudent: float = 1.0 / float(enrolled)
	result.housing = OverflowWeight * maxf(0.0, float(enrolled - housedCount) * perStudent - OverflowThreshold)
	result.crowding = CrowdingWeight * clampf(diningLoad(housedCount, meals) - 1.0, 0.0, DiningHardLimit - 1.0) * float(plans) * perStudent
	result.unfed = UnfedWeight * float(housedCount - plans) * perStudent
	return result


## Where reputation heads: half the latest intake's grade (as a score), half the
## year's satisfaction, weighted by ReputationGradeWeight.
static func reputationTarget(intakeGrade: float, meanSatisfaction: float) -> float:
	return ReputationGradeWeight * intakeGrade * GradeToScore + (1.0 - ReputationGradeWeight) * meanSatisfaction


## A fall's step: ReputationRate of the way to the target.
static func nextReputation(reputation: float, target: float) -> float:
	return clampf(reputation + ReputationRate * (target - reputation), 0.0, MaxScore)


static func fees(prices: Prices, enrolled: int, housedCount: int, plans: int) -> Fees:
	var result: Fees = Fees.new()
	result.tuition = prices.tuition * enrolled
	result.room = prices.room * housedCount
	result.meals = prices.mealPlan * plans
	return result


## Once round grades → reputation → applicants: how much of an extra point of
## reputation comes back as target. Below 1 the loop settles by itself.
static func loopGain() -> float:
	return ReputationGradeWeight * GradeToScore * GradeSpread * log(Doubling) / ReputationDoubling
```

- [ ] **Step 5: `Policy` uses the one `MaxGrade`**

In `university/src/state/policy.gd`, delete these two lines:

```gdscript
# The highest a minimum grade can be set.
const MaxMinimumGrade: float = 4.0
```

and replace `clampf(grade, 0.0, MaxMinimumGrade)` with `clampf(grade, 0.0, UniversityRules.MaxGrade)`.

In `university/tests/PolicyTest.gd`, replace `Policy.MaxMinimumGrade` with `UniversityRules.MaxGrade`.

- [ ] **Step 6: REGISTER, then run the tests**

Run REGISTER, then RUN-TESTS.
Expected: 156 cases in 19 suites, `0 errors | 0 failures`.

- [ ] **Step 7: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/university_rules.gd university/src/state/university_rules.gd.uid university/src/state/intake.gd university/src/state/intake.gd.uid university/src/state/satisfaction.gd university/src/state/satisfaction.gd.uid university/src/state/fees.gd university/src/state/fees.gd.uid university/src/state/policy.gd university/tests/UniversityRulesTest.gd university/tests/UniversityRulesTest.gd.uid university/tests/PolicyTest.gd
git commit -m "$(cat <<'EOF'
Add the student loop's rules: applicants, admission, satisfaction, reputation

Pure functions with the tuning values as named consts; the loop's gain
is guarded below 1 so grades, reputation and applicants settle.

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: The university runs the semester

**Files:**
- Create: `university/src/state/semester_report.gd`
- Modify:
  - `university/src/state/university.gd`
  - `university/src/state/finances.gd` (add `receive`)
  - `university/src/state/game_calendar.gd` (add `isFallStart`)
  - `CLAUDE.md`
- Test: `university/tests/UniversityTest.gd`, `university/tests/FinancesTest.gd`, `university/tests/GameCalendarTest.gd`

**Interfaces:**
- **Consumes:** everything from Tasks 1–4.
- **Produces:**
  - `GameCalendar.isFallStart(monthIndex: int) -> bool`
  - `Finances.receive(amount: int)`. `refund` now calls it.
  - `SemesterReport`:
    - `month: int`, `isFall: bool`
    - `applicants`, `openSeats`, `admitted` (int), `entryGrade` (float), `graduated` (int)
    - `enrolled`, `housed`, `beds`, `mealPlans` (int), `diningLoad` (float)
    - `tuitionFees`, `roomFees`, `mealFees` (int)
    - `reputation`, `reputationChange`, `satisfaction`, `satisfactionChange` (float)
    - `cash`, `debt` (int), `opened: Array[String]`
    - `offCampus() -> int`, `unfed() -> int`, `totalFees() -> int`
    - `SavedKeys`, `toDict()`, `static fromDict(data) -> SemesterReport`
  - `University`:
    - `signal SemesterStarted(report: SemesterReport)`
    - `students: StudentBody`, `policy: Policy`
    - `reputation: float` (starts at `UniversityRules.ReputationReference`)
    - `satisfactionSamples: Array[float]`
    - `lastIntakeGrade: float` (starts at `UniversityRules.GradeBase`)
    - `reports: Array[SemesterReport]`
    - `monthlyExpenses() -> int`, `housed() -> int`, `mealPlans() -> int`
    - `satisfactionNow() -> Satisfaction`, `reputationTarget() -> float`
    - `startMonth(newMonth)` runs the whole sequence

- [ ] **Step 1: Write the failing tests**

**`university/tests/GameCalendarTest.gd`**, append:

```gdscript


func test_only_september_starts_a_fall() -> void:
	assert_bool(GameCalendar.isFallStart(0)).is_true()
	assert_bool(GameCalendar.isFallStart(GameCalendar.MonthsPerYear)).is_true()
	assert_bool(GameCalendar.isFallStart(GameCalendar.nextSemesterStart(0))).is_false()
```

**`university/tests/FinancesTest.gd`**, append:

```gdscript


func test_receiving_adds_to_the_cash() -> void:
	var finances: Finances = _finances(Cash, Borrowed)
	finances.receive(Bill)
	assert_int(finances.cash).is_equal(Cash + Bill)
	assert_int(finances.debt).is_equal(Borrowed)
```

**`university/tests/UniversityTest.gd`**, append. The fixture campus is one open hall with seats, beds and meals, opened at the first semester start:

```gdscript


const HallSeats: int = 100
const HallBeds: int = 60
const HallMeals: int = 80
# Upkeep, so the monthly bill is never zero: a zero bill cannot show what it
# was paid from.
const HallUpkeepK: int = 100
const Students: int = 50
const Grade: float = 3.0


func _hall() -> BuildingInfo:
	return BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "seats": HallSeats, "beds": HallBeds, "meals": HallMeals, "upkeepK": HallUpkeepK})


## A university with an open hall, a first cohort and money, just after the
## spring start at which the hall opened.
func _running() -> University:
	var university: University = University.new()
	university.finances.setCash(Cash)
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	university.students.admit(Students, Grade)
	university.startMonth(building.opensAtMonth)
	return university


## The latest semester report. Indexed, not back(): back() answers an untyped
## Variant, and reading a field off one is an error in this project.
func _last(university: University) -> SemesterReport:
	return university.reports[university.reports.size() - 1]


func _nextFall(university: University) -> int:
	var month: int = university.campus.month + 1
	while (not GameCalendar.isFallStart(month)):
		month += 1
	return month


func test_admission_happens_only_at_a_fall_start() -> void:
	var university: University = _running()
	# _running() ended on a spring start: one cohort, the one it began with.
	assert_int(university.students.cohorts.size()).is_equal(1)
	university.startMonth(_nextFall(university))
	assert_int(university.students.cohorts.size()).is_equal(2)
	assert_bool(_last(university).isFall).is_true()
	assert_int(_last(university).admitted).is_greater(0)


func test_fees_arrive_before_that_months_bill() -> void:
	var university: University = _running()
	# Cash below the bill: were the bill charged first, it would borrow.
	university.finances.setCash(0)
	var borrowed: Array[int] = []
	university.finances.AutoBorrowed.connect(func(drawn: int, _charged: int) -> void: borrowed.append(drawn))
	var bill: int = university.monthlyExpenses()
	university.startMonth(_nextFall(university))
	var report: SemesterReport = _last(university)
	assert_array(borrowed).is_empty()
	assert_int(university.finances.cash).is_equal(report.totalFees() - bill)


func test_overflow_students_pay_tuition_only() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	university.students.admit(HallBeds * 2, Grade)
	university.startMonth(building.opensAtMonth)
	var report: SemesterReport = _last(university)
	assert_int(report.housed).is_equal(HallBeds)
	assert_int(report.roomFees).is_equal(university.policy.current.room * HallBeds)
	assert_int(report.tuitionFees).is_equal(university.policy.current.tuition * HallBeds * 2)


func test_a_building_opening_at_a_semester_start_counts_that_semester() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(_hall(), Vector2.ZERO, 0.0)
	university.students.admit(Students, Grade)
	university.startMonth(building.opensAtMonth)
	var report: SemesterReport = _last(university)
	assert_int(report.beds).is_equal(HallBeds)
	assert_int(report.housed).is_equal(Students)
	assert_array(report.opened).contains_exactly([_hall().name])


func test_a_cohort_graduates_after_eight_semesters_and_is_reported() -> void:
	var university: University = _running()
	university.students.cohorts[0].semestersCompleted = StudentBody.SemestersToGraduate - 1
	university.startMonth(_nextFall(university))
	assert_int(_last(university).graduated).is_equal(Students)


func test_reputation_steps_toward_its_target_only_at_a_fall_start() -> void:
	var university: University = _running()
	var before: float = university.reputation
	var target: float = university.reputationTarget()
	university.startMonth(university.campus.month + 1)
	assert_float(university.reputation).is_equal(before)
	university.startMonth(_nextFall(university))
	assert_float(university.reputation).is_equal_approx(UniversityRules.nextReputation(before, target), 0.0001)


func test_without_an_admissions_office_the_fall_charges_the_defaults() -> void:
	var university: University = _running()
	university.policy.setNextTuition(Policy.DefaultTuition * 2)
	university.startMonth(_nextFall(university))
	assert_int(university.policy.current.total()).is_equal(Policy.defaultPrices().total())


func test_every_semester_start_is_reported_and_announced() -> void:
	var university: University = _running()
	var announced: Array[SemesterReport] = []
	university.SemesterStarted.connect(func(report: SemesterReport) -> void: announced.append(report))
	var reportsBefore: int = university.reports.size()
	university.startMonth(_nextFall(university))
	assert_int(university.reports.size()).is_equal(reportsBefore + 1)
	assert_array(announced).contains_exactly([_last(university)])


func test_a_plain_month_charges_exactly_the_monthly_expenses() -> void:
	var university: University = _running()
	university.finances.borrow(Debt)
	var before: int = university.finances.cash
	var bill: int = university.monthlyExpenses()
	university.startMonth(university.campus.month + 1)
	assert_int(university.finances.cash).is_equal(before - bill)
```

Two lambdas capture a local university or report array, never `self` and never an object that holds the lambda. If RUN-TESTS prints `leaked`, disconnect the lambda before asserting, as `CampusTest` does.

- [ ] **Step 2: Run them to see them fail**

Run RUN-TESTS.
Expected: `GameCalendarTest`, `FinancesTest` and `UniversityTest` drop out with parse errors (`isFallStart`, `receive`, `students` and `reports` don't exist yet).

- [ ] **Step 3: `isFallStart` and `receive`**

In `university/src/state/game_calendar.gd`, after `isSemesterStart`, add:

```gdscript
## A September: the fall start, when the year's prices lock and a class is admitted.
static func isFallStart(monthIndex: int) -> bool:
	return calendarMonth(monthIndex) == September
```

In `university/src/state/finances.gd`, replace:

```gdscript
## What destroying a building still under construction gives back.
func refund(amount: int) -> void:
	_write(cash + amount, debt)
```

with:

```gdscript
## Money coming in: a semester's fees.
func receive(amount: int) -> void:
	_write(cash + amount, debt)


## What destroying a building still under construction gives back.
func refund(amount: int) -> void:
	receive(amount)
```

- [ ] **Step 4: `SemesterReport`**

Create `university/src/state/semester_report.gd`:

```gdscript
class_name SemesterReport
## What happened at one semester start, for the popup, the history and the
## console. The admission fields stay 0 in spring. Cash and debt are as they
## stood after the fees came in, before that month's bill.

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = [
	"month", "isFall", "applicants", "openSeats", "admitted", "entryGrade", "graduated",
	"enrolled", "housed", "beds", "mealPlans", "diningLoad",
	"tuitionFees", "roomFees", "mealFees",
	"reputation", "reputationChange", "satisfaction", "satisfactionChange",
	"cash", "debt", "opened"]

var month: int = 0
var isFall: bool = false
var applicants: int = 0
var openSeats: int = 0
var admitted: int = 0
var entryGrade: float = 0.0
var graduated: int = 0
var enrolled: int = 0
var housed: int = 0
var beds: int = 0
var mealPlans: int = 0
var diningLoad: float = 0.0
var tuitionFees: int = 0
var roomFees: int = 0
var mealFees: int = 0
var reputation: float = 0.0
var reputationChange: float = 0.0
var satisfaction: float = 0.0
var satisfactionChange: float = 0.0
var cash: int = 0
var debt: int = 0
# Names of the buildings that opened at this start.
var opened: Array[String]


func offCampus() -> int:
	return enrolled - housed


func unfed() -> int:
	return housed - mealPlans


func totalFees() -> int:
	return tuitionFees + roomFees + mealFees


func toDict() -> Dictionary:
	return {
		"month": month, "isFall": isFall, "applicants": applicants, "openSeats": openSeats,
		"admitted": admitted, "entryGrade": entryGrade, "graduated": graduated,
		"enrolled": enrolled, "housed": housed, "beds": beds, "mealPlans": mealPlans,
		"diningLoad": diningLoad, "tuitionFees": tuitionFees, "roomFees": roomFees,
		"mealFees": mealFees, "reputation": reputation, "reputationChange": reputationChange,
		"satisfaction": satisfaction, "satisfactionChange": satisfactionChange,
		"cash": cash, "debt": debt, "opened": opened,
	}


## Null when data is missing a key.
static func fromDict(data: Dictionary) -> SemesterReport:
	if (not Variants.hasKeys(data, SavedKeys, "SemesterReport")):
		return null
	var report: SemesterReport = SemesterReport.new()
	report.month = Variants.toInt(data["month"])
	report.isFall = Variants.toBool(data["isFall"])
	report.applicants = Variants.toInt(data["applicants"])
	report.openSeats = Variants.toInt(data["openSeats"])
	report.admitted = Variants.toInt(data["admitted"])
	report.entryGrade = Variants.toFloat(data["entryGrade"])
	report.graduated = Variants.toInt(data["graduated"])
	report.enrolled = Variants.toInt(data["enrolled"])
	report.housed = Variants.toInt(data["housed"])
	report.beds = Variants.toInt(data["beds"])
	report.mealPlans = Variants.toInt(data["mealPlans"])
	report.diningLoad = Variants.toFloat(data["diningLoad"])
	report.tuitionFees = Variants.toInt(data["tuitionFees"])
	report.roomFees = Variants.toInt(data["roomFees"])
	report.mealFees = Variants.toInt(data["mealFees"])
	report.reputation = Variants.toFloat(data["reputation"])
	report.reputationChange = Variants.toFloat(data["reputationChange"])
	report.satisfaction = Variants.toFloat(data["satisfaction"])
	report.satisfactionChange = Variants.toFloat(data["satisfactionChange"])
	report.cash = Variants.toInt(data["cash"])
	report.debt = Variants.toInt(data["debt"])
	for buildingName: Variant in data["opened"] as Array:
		report.opened.append(str(buildingName))
	return report
```

- [ ] **Step 5: `University` runs the semester**

In `university/src/state/university.gd`:

Replace the class doc comment (its first three `##` lines) with:

```gdscript
## The institution being run: its name, money, campus, students and policy,
## and the standing they earn (reputation, satisfaction). GameState holds one;
## everything the player runs hangs off it. The campus spends from the
## university's finances, so the two are made together. _init makes parts only:
## it connects nothing, so fromDict can swap loaded parts in safely.

## A semester began: what happened, for the popup and the history.
signal SemesterStarted(report: SemesterReport)
```

Replace:

```gdscript
var name: String
var finances: Finances
var campus: Campus
```

with:

```gdscript
var name: String
var finances: Finances
var campus: Campus
var students: StudentBody
var policy: Policy
# 0 to UniversityRules.MaxScore; steps each fall start.
var reputation: float = UniversityRules.ReputationReference
# This academic year's satisfaction, one sample per semester start.
var satisfactionSamples: Array[float]
# The weakest admit's grade in the latest fall that admitted anyone.
var lastIntakeGrade: float = UniversityRules.GradeBase
# Every semester start so far, oldest first.
var reports: Array[SemesterReport]
```

In `_init`, after `campus = Campus.new(finances)`, add:

```gdscript
	students = StudentBody.new()
	policy = Policy.new()
```

Replace the whole `startMonth` function (and its doc comment) with:

```gdscript
## A new month began. The campus opens whatever is due; at a semester start the
## semester runs (see _startSemester); last, the month's bill is charged, after
## any fees so the fees pay it.
func startMonth(newMonth: int) -> void:
	var opened: Array[Building] = campus.startMonth(newMonth)
	if (GameCalendar.isSemesterStart(newMonth)):
		_startSemester(newMonth, opened)
	finances.charge(monthlyExpenses())


## What a month costs: every open building's upkeep and the interest on the
## debt. The one source of the monthly bill.
func monthlyExpenses() -> int:
	return campus.upkeep() + finances.interest()


func housed() -> int:
	return UniversityRules.housed(students.enrolled(), campus.beds())


func mealPlans() -> int:
	return UniversityRules.mealPlans(housed(), campus.meals())


func satisfactionNow() -> Satisfaction:
	return UniversityRules.satisfaction(students.enrolled(), housed(), campus.meals())


## Where the next fall start will step reputation toward: the latest intake's
## grade and this year's mean satisfaction (today's, before any sample).
func reputationTarget() -> float:
	return UniversityRules.reputationTarget(lastIntakeGrade, _yearSatisfaction())


func _yearSatisfaction() -> float:
	if (satisfactionSamples.is_empty()):
		return satisfactionNow().total()
	var sum: float = 0.0
	for sample: float in satisfactionSamples:
		sum += sample
	return sum / float(satisfactionSamples.size())


## A semester start: every cohort completes a semester and the finished ones
## graduate; in fall the year begins (see _startYear); then satisfaction is
## sampled and the fees come in. Kept as a report and announced.
func _startSemester(semesterMonth: int, opened: Array[Building]) -> void:
	var report: SemesterReport = SemesterReport.new()
	report.month = semesterMonth
	report.isFall = GameCalendar.isFallStart(semesterMonth)
	var reputationBefore: float = reputation
	var satisfactionBefore: float = reports[reports.size() - 1].satisfaction if (not reports.is_empty()) else satisfactionNow().total()
	report.graduated = students.completeSemester()
	if (report.isFall):
		_startYear(report)
	var sampled: float = satisfactionNow().total()
	satisfactionSamples.append(sampled)
	var fees: Fees = UniversityRules.fees(policy.current, students.enrolled(), housed(), mealPlans())
	finances.receive(fees.total())
	report.enrolled = students.enrolled()
	report.housed = housed()
	report.beds = campus.beds()
	report.mealPlans = mealPlans()
	report.diningLoad = UniversityRules.diningLoad(report.housed, campus.meals())
	report.tuitionFees = fees.tuition
	report.roomFees = fees.room
	report.mealFees = fees.meals
	report.reputation = reputation
	report.reputationChange = reputation - reputationBefore
	report.satisfaction = sampled
	report.satisfactionChange = sampled - satisfactionBefore
	report.cash = finances.cash
	report.debt = finances.debt
	for building: Building in opened:
		report.opened.append(building.info.name)
	reports.append(report)
	SemesterStarted.emit(report)


## The fall start: reputation takes its yearly step on the year just ended, the
## year's prices lock, and the new class is admitted into the open seats.
func _startYear(report: SemesterReport) -> void:
	reputation = UniversityRules.nextReputation(reputation, reputationTarget())
	satisfactionSamples.clear()
	var hasOffice: bool = campus.hasOpenAdmissionsOffice()
	policy.lockYear(hasOffice)
	report.applicants = UniversityRules.applicants(reputation, policy.current.total())
	report.openSeats = maxi(campus.seats() - students.enrolled(), 0)
	var intake: Intake = UniversityRules.admission(report.applicants, report.openSeats, policy.minimumInUse(hasOffice))
	students.admit(intake.admitted, intake.entryGrade)
	report.admitted = intake.admitted
	report.entryGrade = intake.entryGrade
	if (intake.admitted > 0):
		lastIntakeGrade = intake.entryGrade
```

`_startSemester`'s parameter is `semesterMonth`: a parameter named like the `startMonth` method would shadow it, which is an error here.

- [ ] **Step 6: REGISTER, then run the tests**

Run REGISTER (a new `class_name`: `SemesterReport`), then RUN-TESTS.
Expected: 167 cases in 19 suites, `0 errors | 0 failures`, no `leaked`.

- [ ] **Step 7: LAUNCH-CHECK**

Run `pause`, `advance 5` (to the February start), and `state`.

Expected:
- The grep prints nothing.
- `state` shows `Cash: $44100000`. The start state has no students yet, so the February start brings no fees, and cash is 50,000,000 − 5 × 1,180,000. Phase 3 changes nothing for a university with no students.

- [ ] **Step 8: Update `CLAUDE.md`**

In `CLAUDE.md`, find the paragraph under **Architecture** that begins `- Time: the view calls` and ends `Both are empty until there is something to simulate.` Insert this new bullet directly after it, as its own line starting `- **The student loop.**`:

```
- **The student loop.**
  - **Cohorts.** `StudentBody` holds the students as `Cohort`s (`size`, `entryGrade`, `semestersCompleted`), one per fall intake. At every semester start each completes a semester, and those reaching `StudentBody.SemestersToGraduate` graduate whole.
  - **Policy.** `Policy` holds this year's `Prices` (`current`) and next year's (`next`, what the player sets), and the minimum grade (0 is off). `lockYear(hasOffice)` makes `next` current at each fall start, or the defaults when no Admissions Office is open, and with no office there is no minimum.
  - **Rules.** `UniversityRules` is static and pure. It holds every tuning const and formula, and answers small records (`Intake`, `Satisfaction`, `Fees`):
    - applicants from reputation and total price
    - admission into the open seats: the cutoff is `GradeBase + GradeSpread·ln(A/S)`, and a minimum above it trims the class
    - housed, meal plans and dining load
    - satisfaction as a base less housing, crowding and unfed penalties
    - reputation's yearly step toward half the latest intake's grade, half the year's mean satisfaction
    - fees, where off-campus students pay tuition only
    - `loopGain()`, which a test holds below 1 so the loop settles
  - **`University.startMonth(m)`**, in this order:
    1. `Campus.startMonth`, which answers the buildings it opened.
    2. At a semester start, `_startSemester`:
       1. Graduation.
       2. At a fall start, `_startYear`: the reputation step (then the year's samples reset), `lockYear`, applicants, admission and `lastIntakeGrade`.
       3. Satisfaction is sampled.
       4. The fees go to `Finances.receive`.
       5. A `SemesterReport` is kept in `reports` and `SemesterStarted` is emitted.
    3. Last, always, `finances.charge(monthlyExpenses())`, after the fees so they pay it.
  - **Live queries.** `monthlyExpenses()` (upkeep plus interest) is the one source of the bill. `housed()`, `mealPlans()`, `satisfactionNow()` and `reputationTarget()` are derived live, never stored.
  - **Month 0 never runs `startMonth`,** because tick 0 already is month 0. The start state is therefore the moment just after month 0's fall start: its first cohort is admitted, its fees are paid, and one satisfaction sample is taken.
```

- [ ] **Step 9: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/semester_report.gd university/src/state/semester_report.gd.uid university/src/state/university.gd university/src/state/finances.gd university/src/state/game_calendar.gd university/tests/UniversityTest.gd university/tests/FinancesTest.gd university/tests/GameCalendarTest.gd CLAUDE.md
git commit -m "$(cat <<'EOF'
Run the semester: graduation, admission, satisfaction, fees, reputation

Each semester start graduates finished cohorts, and each fall steps
reputation, locks the year's prices and admits a class; fees come in
before the month's bill, and every start is kept as a report.

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Save the loop; the start state gains students

**Files:**
- Modify:
  - `university/src/state/university.gd` (`SavedKeys`, `toDict`, `fromDict`)
  - `university/data/start_state.json`
  - `CLAUDE.md` (the Save/load block)
- Test: `university/tests/SaveTest.gd`, `university/tests/StartStateTest.gd`

**Interfaces:**
- **Consumes:** `StudentBody.toDict/fromDict`, `Policy.toDict/fromDict`, `SemesterReport.toDict/fromDict`, and `University`'s new fields.
- **Produces:**
  - `University.SavedKeys` = `["name", "finances", "campus", "students", "policy", "reputation", "satisfactionSamples", "lastIntakeGrade", "reports"]`
  - A start state with those keys.

- [ ] **Step 1: Write the failing tests**

In **`university/tests/SaveTest.gd`**:

(a) Replace the two `_db()` record lines with ones that give the fixtures capacities, so the played months house, feed and, after loading, admit:

```gdscript
		{"id": "hall", "name": "Hall", "diameter": Diameter, "costM": 1, "upkeepK": 7, "beds": 20, "meals": 10, "admissionsOffice": true},
		{"id": "lab", "name": "Lab", "diameter": Diameter, "costM": 2, "upkeepK": 11, "seats": 60},
```

(b) Below `const Borrowed: int = 3000000`, add:

```gdscript
# Non-default loop state, so a save that forgot any of it would show.
const FirstClass: int = 30
const SecondClass: int = 25
const FirstGrade: float = 3.1
const SecondGrade: float = 2.9
const NextTuition: int = 9000
const Minimum: float = 2.5
const StartReputation: float = 61.5
```

(c) In `_playedState`, after the `borrow` line, add:

```gdscript
	state.university.students.admit(FirstClass, FirstGrade)
	state.university.students.admit(SecondClass, SecondGrade)
	state.university.policy.setNextTuition(NextTuition)
	state.university.policy.setMinimumGrade(Minimum)
	state.university.reputation = StartReputation
	state.university.lastIntakeGrade = SecondGrade
```

The months `_playedState` then plays pass the February start (month 5), which adds a satisfaction sample and a report. The determinism test's seven months after loading cross the September start (month 12): a reputation step, `lockYear`, and admission into the lab's seats.

(d) Append:

```gdscript


func test_a_save_missing_a_students_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	((data["university"] as Dictionary)["students"] as Dictionary).erase("cohorts")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["StudentBody", "cohorts"])
	assert_object(loaded[0]).is_null()


func test_a_save_missing_a_policy_key_is_refused() -> void:
	var buildingDB: BuildingInfoDB = _db()
	var data: Dictionary = _playedState(buildingDB).toDict()
	((data["university"] as Dictionary)["policy"] as Dictionary).erase("next")
	var loaded: Array[GameState] = []
	await assert_error(func() -> void: loaded.append(GameState.fromDict(data, buildingDB))) \
		.is_push_error(Variants.MissingKeysError % ["Policy", "next"])
	assert_object(loaded[0]).is_null()
```

In **`university/tests/StartStateTest.gd`**, append:

```gdscript


func test_the_start_students_fit_the_seats() -> void:
	var state: GameState = _startState()
	assert_int(state.university.students.enrolled()).is_less_equal(state.university.campus.seats())
```

- [ ] **Step 2: Run the tests to see them fail**

Run RUN-TESTS.
Expected failures:
- `SaveTest`'s round-trip and replay tests fail: the loop fields aren't saved, so a loaded game differs from the saved one.
- The two refusal tests fail: there are no such keys yet.
- `StartStateTest`'s new test passes vacuously (0 students ≤ 800 seats). That's fine; it guards the next step.

- [ ] **Step 3: Save and load the loop**

In `university/src/state/university.gd`:

Replace `const SavedKeys: Array[String] = ["name", "finances", "campus"]` with:

```gdscript
const SavedKeys: Array[String] = ["name", "finances", "campus", "students", "policy", "reputation", "satisfactionSamples", "lastIntakeGrade", "reports"]
```

Replace the whole `toDict` function with:

```gdscript
func toDict() -> Dictionary:
	var savedReports: Array[Dictionary] = []
	for report: SemesterReport in reports:
		savedReports.append(report.toDict())
	return {
		"name": name, "finances": finances.toDict(), "campus": campus.toDict(),
		"students": students.toDict(), "policy": policy.toDict(),
		"reputation": reputation, "satisfactionSamples": satisfactionSamples,
		"lastIntakeGrade": lastIntakeGrade, "reports": savedReports,
	}
```

In `fromDict`, directly before the line `var university: University = University.new()`, add:

```gdscript
	var loadedStudents: StudentBody = StudentBody.fromDict(data["students"] as Dictionary)
	if (loadedStudents == null):
		return null
	var loadedPolicy: Policy = Policy.fromDict(data["policy"] as Dictionary)
	if (loadedPolicy == null):
		return null
	var loadedReports: Array[SemesterReport] = []
	for saved: Variant in data["reports"] as Array:
		var report: SemesterReport = SemesterReport.fromDict(saved as Dictionary)
		if (report == null):
			return null
		loadedReports.append(report)
```

In `fromDict`, directly before `return university`, add:

```gdscript
	university.students = loadedStudents
	university.policy = loadedPolicy
	university.reports = loadedReports
	university.reputation = clampf(Variants.toFloat(data["reputation"]), 0.0, UniversityRules.MaxScore)
	university.lastIntakeGrade = Variants.toFloat(data["lastIntakeGrade"])
	for sample: Variant in data["satisfactionSamples"] as Array:
		university.satisfactionSamples.append(Variants.toFloat(sample))
```

Also update the `fromDict` doc comment to say it refuses when its finances, campus, students, policy or any report refuse.

- [ ] **Step 4: The start state gains its students, policy and standing**

The start state is the moment just after the Year 1 fall start (month 0), with four cohorts already in: this fall's (0 semesters done) and the three before it. These numbers are placeholders; Task 9 tunes them.

In `university/data/start_state.json`, inside `"university"`, add these keys beside `"campus"`, `"finances"` and `"name"`:

```json
		"lastIntakeGrade": 3.0,
		"policy": {
			"current": { "mealPlan": 4136, "room": 4542, "tuition": 9606 },
			"minimumGrade": 0.0,
			"next": { "mealPlan": 4136, "room": 4542, "tuition": 9606 }
		},
		"reports": [],
		"reputation": 50.0,
		"satisfactionSamples": [60.0],
		"students": {
			"cohorts": [
				{ "entryGrade": 3.0, "semestersCompleted": 6, "size": 180 },
				{ "entryGrade": 3.0, "semestersCompleted": 4, "size": 180 },
				{ "entryGrade": 3.0, "semestersCompleted": 2, "size": 180 },
				{ "entryGrade": 3.0, "semestersCompleted": 0, "size": 180 }
			]
		},
```

Keep the result valid JSON: commas between keys, and none after the last.

- [ ] **Step 5: Run the tests**

Run RUN-TESTS.
Expected: 170 cases in 19 suites, `0 errors | 0 failures`.

- [ ] **Step 6: LAUNCH-CHECK: the start state's students pay at the spring start**

Run `pause`, `state`, `advance 5` and `state`.

Expected:
- The grep prints nothing.
- The second `state` shows `Cash: $54140400`: 50,000,000 − 5 × 1,180,000 + the February fees of 10,040,400. The fees are 720 × $9,606 tuition + 360 housed (three dorms × 120 beds) × $4,542 room + 360 meal plans (dining is meant for 650) × $4,136.

Also run `save /tmp/university/p3.json`, `load /tmp/university/p3.json`, `state`. The same cash and date should come back. Then `rm -f /tmp/university/p3.json`.

- [ ] **Step 7: Update `CLAUDE.md`**

In `CLAUDE.md`, replace:

```
  - `University` (with its `finances` and `campus`), `Finances`, `Campus`, and `Building`, which is saved by type id
```

with:

```
  - `University` (its `finances`, `campus`, `students`, `policy`, `reputation`, `satisfactionSamples`, `lastIntakeGrade` and `reports`), `Finances`, `StudentBody` and its `Cohort`s, `Policy` and its two `Prices`, `SemesterReport`, `Campus`, and `Building`, which is saved by type id
```

- [ ] **Step 8: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/university.gd university/data/start_state.json university/tests/SaveTest.gd university/tests/StartStateTest.gd CLAUDE.md
git commit -m "$(cat <<'EOF'
Save the student loop; the start state gains its students

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `problems()`

**Files:**
- Create: `university/src/state/problem.gd`
- Modify: `university/src/state/university.gd`, `CLAUDE.md`
- Test: `university/tests/UniversityTest.gd`

**Interfaces:**
- **Consumes:** the `University` live queries (Task 5), and `Finances.availableCredit` and `debt`.
- **Produces:**
  - `Problem`: `enum Kind { HousingOverflow, DiningCrowded, DiningUnfed, CreditMaxed }`, `kind: Kind`, `count: int`, `fraction: float`, `_init(problemKind: Kind, problemCount: int, problemFraction: float)`
  - `University.problems() -> Array[Problem]`
- **What the fields mean:**
  - `HousingOverflow`: count = off campus, fraction = the share off campus
  - `DiningCrowded`: fraction = the dining load
  - `DiningUnfed`: count = unfed, fraction = the dining load
  - `CreditMaxed`: count = the debt
  - Dining is crowded while its load is over 1 and nobody goes unfed. Once anyone is unfed, it's `DiningUnfed` instead.

- [ ] **Step 1: Write the failing tests**

**`university/tests/UniversityTest.gd`**, append:

```gdscript


func _kinds(university: University) -> Array[int]:
	var kinds: Array[int] = []
	for problem: Problem in university.problems():
		kinds.append(problem.kind)
	return kinds


func test_a_healthy_campus_has_no_problems() -> void:
	assert_array(_kinds(_running())).is_empty()


func test_housing_overflow_is_a_problem_only_past_the_threshold() -> void:
	var university: University = _running()
	var allowed: int = floori(float(HallBeds) / (1.0 - UniversityRules.OverflowThreshold)) - Students
	university.students.admit(allowed, Grade)
	assert_array(_kinds(university)).not_contains([Problem.Kind.HousingOverflow])
	university.students.admit(HallBeds, Grade)
	assert_array(_kinds(university)).contains([Problem.Kind.HousingOverflow])


func test_dining_is_crowded_and_then_unfed() -> void:
	var university: University = University.new()
	var building: Building = university.campus.place(BuildingInfo.new({"id": "hall", "name": "Hall", "diameter": Diameter, "beds": HallBeds * 10, "meals": HallMeals}), Vector2.ZERO, 0.0)
	university.campus.startMonth(building.opensAtMonth)
	university.students.admit(HallMeals + 1, Grade)
	assert_array(_kinds(university)).contains_exactly([Problem.Kind.DiningCrowded])
	university.students.admit(HallMeals * 2, Grade)
	assert_array(_kinds(university)).contains_exactly([Problem.Kind.DiningUnfed])


func test_a_full_credit_line_is_a_problem() -> void:
	var university: University = _running()
	university.finances.borrow(Finances.CreditLimit)
	assert_array(_kinds(university)).contains([Problem.Kind.CreditMaxed])
```

Arithmetic check for the overflow test. `_running()` has 50 students and 60 beds.
- `allowed` = floor(60 / 0.75) − 50 = 80 − 50 = 30, so there are 80 students and 20 off campus. 20/80 = 0.25 is not past the threshold.
- Admitting 60 more makes 140 students, 80 off campus. 80/140 = 0.57 is past it.

`_running()` has meals 80 and 60 housed, so its dining is comfortable.

- [ ] **Step 2: Run them to see them fail**

Run RUN-TESTS.
Expected: `UniversityTest` drops out with a parse error (`Problem` doesn't exist yet).

- [ ] **Step 3: `Problem`**

Create `university/src/state/problem.gd`:

```gdscript
class_name Problem
## Something wrong on campus right now, for alerts and campus markers. Every
## threshold lives in UniversityRules or Finances; this only carries what was
## found. count and fraction mean what the kind says.

enum Kind {
	HousingOverflow, # count: students off campus; fraction: their share
	DiningCrowded, # fraction: dining load, over 1
	DiningUnfed, # count: students who can't eat; fraction: dining load
	CreditMaxed, # count: the debt
}

var kind: Kind
var count: int
var fraction: float


func _init(problemKind: Kind, problemCount: int, problemFraction: float) -> void:
	kind = problemKind
	count = problemCount
	fraction = problemFraction
```

- [ ] **Step 4: `University.problems()`**

In `university/src/state/university.gd`, after `reputationTarget`, add:

```gdscript
## What is wrong on campus right now. The one list alerts and markers draw
## from, so each threshold is checked in one place.
func problems() -> Array[Problem]:
	var found: Array[Problem] = []
	var enrolledCount: int = students.enrolled()
	var housedCount: int = housed()
	var offCampus: int = enrolledCount - housedCount
	if (enrolledCount > 0 and float(offCampus) / float(enrolledCount) > UniversityRules.OverflowThreshold):
		found.append(Problem.new(Problem.Kind.HousingOverflow, offCampus, float(offCampus) / float(enrolledCount)))
	var dining: float = UniversityRules.diningLoad(housedCount, campus.meals())
	var unfed: int = housedCount - mealPlans()
	if (unfed > 0):
		found.append(Problem.new(Problem.Kind.DiningUnfed, unfed, dining))
	elif (dining > 1.0):
		found.append(Problem.new(Problem.Kind.DiningCrowded, 0, dining))
	if (finances.availableCredit() == 0):
		found.append(Problem.new(Problem.Kind.CreditMaxed, finances.debt, 0.0))
	return found
```

- [ ] **Step 5: REGISTER, then run the tests**

Run REGISTER, then RUN-TESTS.
Expected: 174 cases in 19 suites, `0 errors | 0 failures`.

- [ ] **Step 6: Update `CLAUDE.md`**

In `CLAUDE.md`, in the **The student loop** bullet from Task 5, after the sentence ending `are derived live, never stored.`, add:

```
 `problems()` is the one list of what is wrong right now (`Problem.Kind`: `HousingOverflow` past `OverflowThreshold`, `DiningCrowded` while the dining load is over 1 and nobody goes unfed, `DiningUnfed` once anyone does, `CreditMaxed` when `availableCredit()` is 0), which alerts and campus markers will draw from, so each threshold is checked in one place.
```

- [ ] **Step 7: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/state/problem.gd university/src/state/problem.gd.uid university/src/state/university.gd university/tests/UniversityTest.gd CLAUDE.md
git commit -m "$(cat <<'EOF'
Answer the campus's problems: overflow, dining and a full credit line

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Console: students, prices, minimum, reputation, report, simulate

**Files:**
- Modify: `university/src/debug/debug_commands.gd`, `CLAUDE.md` (the console list)

**Interfaces:**
- **Consumes:** everything on `University` from Tasks 5–7, `Policy`'s setters, and `SemesterReport`.
- **Produces these console commands:**
  - `students`
  - `prices [tuition room meal]`
  - `minimum [grade]`
  - `reputation [value]`
  - `report`
  - `simulate <years>`
- `state` also prints the enrolled count and the reputation.

No new unit tests: the rules are the state's, and the state's suites cover them. This task is checked in the running game (Step 3).

- [ ] **Step 1: The commands**

In `university/src/debug/debug_commands.gd`:

Below `const KeepDebt: int = -1`, add:

```gdscript
# prices', minimum's and reputation's sentinels: no value given, just print.
const KeepPrice: int = -1
const KeepGrade: float = -1.0
const KeepReputation: float = -1.0
# One row of a semester report, for 'report' and 'simulate'.
const ReportRow: String = "%s | apps %d, open %d, admitted %d at %.2f, graduated %d | enrolled %d, housed %d, off %d | dining %.0f%% | sat %.1f, rep %.1f | fees $%d | cash $%d, debt $%d"
const Percent: float = 100.0
```

In `_init`, after the `repay` registration, add:

```gdscript
	LimboConsole.register_command(_students, "students", "Print the cohorts, where students live and eat, and satisfaction.")
	LimboConsole.register_command(_prices, "prices", "Print this year's and next year's prices, or set next year's: [tuition room meal] dollars.")
	LimboConsole.register_command(_minimum, "minimum", "Print the minimum entry grade, or set it to [grade] (0 is off).")
	LimboConsole.register_command(_reputation, "reputation", "Print the reputation and where it heads, or set it to [value].")
	LimboConsole.register_command(_report, "report", "Print the last semester start's report.")
	LimboConsole.register_command(_simulate, "simulate", "Play a copy of the game <years> ahead with no input and print every semester start; the live game is untouched.")
```

In `_state()`, directly before the `University: %s` print, add:

```gdscript
	LimboConsole.print_line("Students: %d enrolled | reputation %.1f" % [
		_gameState().university.students.enrolled(), _gameState().university.reputation])
```

After `_repay`, add:

```gdscript
func _university() -> University:
	return _gameState().university


func _students() -> void:
	var university: University = _university()
	for cohort: Cohort in university.students.cohorts:
		LimboConsole.print_line("Cohort: %d students, entry grade %.2f, %d semesters done" % [cohort.size, cohort.entryGrade, cohort.semestersCompleted])
	var enrolledCount: int = university.students.enrolled()
	LimboConsole.print_line("Enrolled %d of %d seats | housed %d of %d beds, %d off campus | meal plans %d, dining %.0f%%" % [
		enrolledCount, university.campus.seats(), university.housed(), university.campus.beds(),
		enrolledCount - university.housed(), university.mealPlans(),
		UniversityRules.diningLoad(university.housed(), university.campus.meals()) * Percent])
	var now: Satisfaction = university.satisfactionNow()
	LimboConsole.print_line("Satisfaction %.1f = %.1f - housing %.1f - crowding %.1f - unfed %.1f" % [
		now.total(), now.base, now.housing, now.crowding, now.unfed])


func _prices(tuition: int = KeepPrice, room: int = KeepPrice, meal: int = KeepPrice) -> void:
	var policy: Policy = _university().policy
	if (tuition != KeepPrice):
		policy.setNextTuition(tuition)
	if (room != KeepPrice):
		policy.setNextRoom(room)
	if (meal != KeepPrice):
		policy.setNextMealPlan(meal)
	LimboConsole.print_line("This year: tuition $%d, room $%d, meal plan $%d (total $%d)" % [
		policy.current.tuition, policy.current.room, policy.current.mealPlan, policy.current.total()])
	LimboConsole.print_line("Next year: tuition $%d, room $%d, meal plan $%d (total $%d)" % [
		policy.next.tuition, policy.next.room, policy.next.mealPlan, policy.next.total()])


func _minimum(grade: float = KeepGrade) -> void:
	if (grade != KeepGrade):
		_university().policy.setMinimumGrade(grade)
	LimboConsole.print_line("Minimum entry grade: %.2f" % _university().policy.minimumGrade)


func _reputation(value: float = KeepReputation) -> void:
	if (value != KeepReputation):
		_university().reputation = clampf(value, 0.0, UniversityRules.MaxScore)
	LimboConsole.print_line("Reputation %.1f, heading for %.1f" % [_university().reputation, _university().reputationTarget()])


func _reportLine(report: SemesterReport) -> String:
	return ReportRow % [
		GameCalendar.label(report.month), report.applicants, report.openSeats, report.admitted,
		report.entryGrade, report.graduated, report.enrolled, report.housed, report.offCampus(),
		report.diningLoad * Percent, report.satisfaction, report.reputation, report.totalFees(),
		report.cash, report.debt]


func _report() -> void:
	var reports: Array[SemesterReport] = _university().reports
	LimboConsole.print_line(_reportLine(reports[reports.size() - 1]) if (not reports.is_empty()) else "No semester has started yet")


## Plays a copy of the game forward with no input, so the live game is untouched.
func _simulate(years: int) -> void:
	var copy: GameState = GameState.fromDict(_gameState().toDict(), Global.buildingDB)
	var first: int = copy.university.reports.size()
	copy.advanceMonths(years * GameCalendar.MonthsPerYear)
	for i: int in range(first, copy.university.reports.size()):
		LimboConsole.print_line(_reportLine(copy.university.reports[i]))
```

- [ ] **Step 2: Run the tests**

Run RUN-TESTS.
Expected: 174 cases in 19 suites, `0 errors | 0 failures`.

- [ ] **Step 3: LAUNCH-CHECK: the loop from the console**

Run these commands in order, with `pause` first:
1. `students`
2. `prices`
3. `prices 12000 5000 4500`, then `prices`
4. `minimum 3.3`, then `minimum 0`
5. `reputation`
6. `report`
7. `simulate 4`
8. `state`

Expected:
- The grep prints nothing.
- `students` lists 4 cohorts of 180, then "Enrolled 720 of 800 seats | housed 360 of 360 beds, 360 off campus", and a satisfaction breakdown with a housing penalty.
- Next year's prices change; this year's don't.
- `report` says no semester has started yet. The start state has no reports.
- `simulate 4` prints 8 rows (4 years × 2 starts), Feb Year 1 through Sep Year 5.
- `state` afterwards still shows `Sep, Year 1`: the live game is untouched.

Paste the `simulate` output into the report: Task 9 tunes from it.

- [ ] **Step 4: Update `CLAUDE.md`**

In `CLAUDE.md`, replace:

```
- `newgame` — start over from the start state.
```

with:

```
- `newgame` — start over from the start state.
- `students` — print the cohorts, enrolment against seats, housing against beds, meal plans and the dining load, and today's satisfaction broken down.
- `prices [tuition room meal]` — print this year's and next year's prices, or set next year's (they apply from the next fall).
- `minimum [grade]` — print the minimum entry grade, or set it (0 is off).
- `reputation [value]` — print the reputation and where it is heading, or set it.
- `report` — print the last semester start's report.
- `simulate <years>` — copy the game through `toDict`/`fromDict`, play the copy `<years>` ahead with no input, and print one row per semester start (applicants, open seats, admitted and entry grade, graduated, enrolled, housed and off campus, dining load, satisfaction, reputation, fees, cash, debt). The live game is untouched; this is the tuning tool.
```

Replace the `state` bullet's text `the cash, the debt, the month's interest and upkeep, and the university's name.` with `the cash, the debt, the month's interest and upkeep, the enrolled count and reputation, and the university's name.`

- [ ] **Step 5: Commit**

```bash
cd /Users/noel/Development/University/game
git add university/src/debug/debug_commands.gd CLAUDE.md
git commit -m "$(cat <<'EOF'
Drive the student loop from the console, and simulate years ahead

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Tuning pass: a start state near its own balance

This is judgment work: read the loop's trajectory and set the start state so the game opens near the balance its own rules settle at, not in the middle of a correction.

**Files:**
- Modify: `university/data/start_state.json`, and only if a criterion below can't be met otherwise, `UniversityRules.ApplicantPool`
- Report: the tuning notes go in the task report. The controller relays them to the user.

**Rules for this task:**
- **Don't touch the Sheet** or `data/buildings.txt`: capacities and costs are the user's.
- **Don't change the formulas.**
- **Only one `UniversityRules` const may change:** `ApplicantPool`, the scale of the applicant market.
- **Any other tuning change is out of scope.** Put the recommendation in the report instead.

- [ ] **Step 1: Read the trajectory**

Launch as in LAUNCH-CHECK, `pause`, and `simulate 8`. Paste the output into the report.

- [ ] **Step 2: Judge it against these criteria**

1. **Selective but not elite.** At each fall start, applicants per open seat is between 1.5 and 5, so the entry grade is about 2.9–3.4.
2. **No big correction in the first year.** The first fall's reputation change is under 5 points either way, and enrolment stays within 10% of the seats.
3. **Solvent doing nothing.** Cash never reaches 0 over 8 years with no player action. If it does, report which year. The fix may be the user's (upkeep, prices, capacities), so don't change those.
4. **The drift check** from the design doc: does a visible problem appear within a few semesters, purely from the campus's own state? Report which, or that none does. Housing overflow at the start counts only if it grows or stays.

- [ ] **Step 3: Set the start state**

Move the start state toward what the simulation settles at after about 3 years:
- **Cohorts:** four cohorts of the steady intake size, entry grade the steady entry grade, with `semestersCompleted` 6, 4, 2 and 0.
- **`lastIntakeGrade`:** the steady entry grade.
- **`reputation`:** the steady reputation.
- **`satisfactionSamples`:** one sample, the steady satisfaction.
- **`finances.cash`:** unchanged ($50M) unless criterion 3 fails in year 1.

If criterion 1 can't be met by the start state alone, scale `UniversityRules.ApplicantPool` so the first fall's applicants per open seat is about 2.5. Record the old and new values and why.

Re-run `simulate 8` after each change. At most three rounds. If it still doesn't meet the criteria, report where it stands.

- [ ] **Step 4: Run the tests**

Run RUN-TESTS.
Expected: 174 cases in 19 suites, `0 errors | 0 failures`. `StartStateTest` must still pass: the students fit the seats, and the saved month matches the tick count.

- [ ] **Step 5: Commit, and write up the tuning**

```bash
cd /Users/noel/Development/University/game
git add university/data/start_state.json university/src/state/university_rules.gd
git commit -m "$(cat <<'EOF'
Tune the start state to the loop's own balance

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

(Only add `university_rules.gd` if you changed it.)

The report must contain:
- the first and last `simulate 8` outputs
- each criterion's verdict
- every value you changed, from what to what
- the drift-check answer
- any recommendation for the user's tuning: Sheet values, prices, or `UniversityRules` consts you didn't touch
