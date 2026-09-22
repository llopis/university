# University

Godot 4.7 (GDScript). The Godot project is `university/`; the repo root is
`/Users/noel/Development/University/game`. This is the starting prototype and it
is 3D: **1 world unit = 1 metre, Y up**. The sim reasons on the ground plane,
so state positions are `Vector2` with `x` = world X and `y` =
world Z, and a rectangle's `angle` (radians) is the direction of its own long
axis, `(cos a, sin a)`: a growing angle turns from +X toward +Z. A node's y
rotation turns the other way, from +X toward -Z, so `BuildingView.showRect` is
the one place a state angle becomes a node rotation, `rotation.y = -angle`;
nothing else converts. **There is no grid**: a building goes down at any
position and any angle, and the 10 m lines on the ground are `ground.gdshader`
drawing them from world position — the sim never sees them. The game is a
university management sim — campus view,
buildings placed at any orientation, every student simulated. The prototype
scope is listed in `Prototype.md` below. Repo: https://github.com/llopis/university

Design material (Obsidian, `/Users/noel/Obsidian/Noel/Game development/University/`):
- `Prototype.md` — the scope of this prototype. This is the near-term to-do list.
- `Initial Pitch.md` — the fantasy: what the game is and what the player does.
- `Initial Brainstorm.md`, `Design Discussion 2026-09-17.md` — worked-through design, agreed insights, open questions. Read before proposing design.
- `University Buildings.md`, `University Traits.md` — content tables in prose form.
- `Competition Research.md` — what the neighbours (Two Point Campus, Academia) do.
- `Title Ideas.md`, `Random Ideas.md` — unsorted.

## MANDATORY — Before Reporting Any Change as Done

Every single time, no exceptions:

1. **Launch the game and read stdout.** Tests are NOT sufficient — they only compile scripts that tests reference. New or UI scripts may have fatal parse errors that only surface at runtime.
   ```
   cd /Users/noel/Development/University/game && ./bin/run.sh 2>&1 &
   ```
   Check output for `SCRIPT ERROR`, `Parse Error`, `ERROR:`, AND `WARNING` lines. GDScript analyzer warnings (shadowed names, incompatible ternaries, unsafe access, ...) only exist inside the editor, so `project.godot` escalates the ones that matter to error level under `[debug] gdscript/warnings/*`; a script that trips one then fails to compile at runtime and the launch/test run shows it. When the editor reports a new warning kind, add it there rather than living with it. Zero of ALL of them = pass — GDScript warnings (shadowing, integer division, ...) count as failures and get fixed on the spot, not accumulated. Any error = fix before reporting. `Parse Error: Busy` means a circular dependency — trace the preload/instance chain.

2. **Never show the game window.** Start the polling hider BEFORE Godot launches:
   ```
   (for i in $(seq 1 20); do sleep 0.2; osascript -e 'tell application "System Events" to set visible of process "Godot" to false' 2>/dev/null; done) &
   ```
   Exception: perf measurement sessions must run with a VISIBLE window — the hider suppresses rendering/presentation and zeroes render timings.

3. **Verify visually with a screenshot for any UI/visual change.** The running game hosts a TCP remote console (port 9999, `university/src/debug/remote_console.gd`) that executes LimboConsole commands:
   ```
   echo screenshot | nc -w 3 localhost 9999
   ```
   saves `/tmp/university/screenshot.png` (`DebugCommands.ScreenshotPath` in `university/src/debug/debug_commands.gd`) — then LOOK at it (Read tool). Log greps only catch errors, not wrong-looking output; screenshots catch what greps can't (invisible text, broken layout, bad zoom).

4. **Always kill Godot immediately after checking.** `pkill -f "Godot"` — never leave it running.

5. **Dictionary.get() returns Variant.** Never pass it to `int()`, `bool()`, or typed function params. Use helper functions, of this minimal shape:
   ```gdscript
   static func _to_int(value: Variant) -> int:
       return value
   static func _to_bool(value: Variant) -> bool:
       return value
   ```
   `Variants.toInt`/`toFloat`/`toBool` (`university/src/utils/variants.gd`) is the project's type-checked version of this and the one to call. `str()` works directly. For reference types use `as Dictionary`, `as Array`.

6. **Never guess Godot APIs.** Do NOT assume a property or method exists on a Godot class. If you haven't seen it used in this codebase, search the project for existing usage first. Godot 4.x APIs change between minor versions — a property that exists in docs or training data may not exist in Godot 4.7. When in doubt, grep the codebase or check the engine source. Getting this wrong causes `Parse Error` (treated as fatal) and wastes the user's time.

## Architecture

Strict state/view separation:
- **State** (`university/src/state/`, `university/src/data/`): pure logic classes — no engine/node dependencies, plain `class_name` classes, not Nodes. This is what makes the sim deterministic and testable without the engine. A state class may read an autoload-owned data DB (the Info/DB pattern below) while building itself; nothing else. `Campus` is the buildable world: a `Campus.Size`-metre square of ground centred on the origin (`Campus.bounds()`), the `buildings` array, every placement rule — `canPlace` (inside the bounds, overlapping nothing), `place`, `destroy`, `pick` — spending from the university's `Finances`. `Finances` (`src/state/finances.gd`) is the money: `cash` and `debt`, whole dollars, never negative, written only through `_write` (not `_set`, which is Object's virtual), which emits `MoneyChanged`, so no balance can change unannounced. A bare `Finances.new()` holds nothing; a new game's balances come from `res://data/start_state.json`. Building spends cash only: `canBuild` is `canAfford` and `canPlace` together, and `place` refuses whatever `canBuild` rejects, so to build past the cash the player borrows first. `borrow` draws on the credit line up to `Finances.CreditLimit`, and `repay` pays back at most the debt and the cash. The monthly bill, `charge`, is the one exception to the limit: a bill the cash cannot cover borrows the shortfall automatically, plus `ShortfallFee` of it, however much is already owed, and emits `AutoBorrowed`. There is no bankruptcy. `interest()` is a month of `AnnualInterestRate` on the debt (`MonthlyInterestRate`, derived once). The campus holds the university's `Finances` rather than a balance of its own; `University` makes the two together, and its `fromDict` builds the loaded campus on the loaded finances. `place` spends `info.cost` and stamps `opensAtMonth` from `GameCalendar.nextSemesterStart(month)`; `startMonth(newMonth)` is the one place `Building.underConstruction` is cleared, opening every building whose `opensAtMonth` has come and emitting `BuildingOpened` for each. `destroy` refunds the full cost while a building is still under construction and nothing once it is open, read straight off `underConstruction` so there is no record of what was paid to keep in step. `Building` is one building standing on it (`info`, `pos`, `angle`, plus `underConstruction`, true from placement until the campus opens it, and `opensAtMonth`); `Building.rectFor(info, pos, angle)` is the one footprint derivation, used by a placed building's `rect()`, by `canPlace` and by the ghost alike, so the three can never disagree about what fits. Its constants `DepthRatio` (the footprint's short side as a fraction of the sheet's `diameter`, its long side) and `Height` are placeholders until real models arrive; `Height` is state rather than view because picking tests the box, not the footprint. `OrientedRect` — centre, `size` along its own two axes, `angle` — is the one place rectangle maths lives: `corners`, `contains`, `overlaps` (separating-axis over both rects' axes; rects that only touch along an edge do not overlap, `OrientedRect.Epsilon`), `within(bounds)`, and `rayHit`, a slab test run in the rect's own frame where the box is axis-aligned. `Campus.pick` is `rayHit` against every building's box, nearest wins: a ray against the box rather than the ground point under the cursor, because at the camera's pitch a click on a 10 m roof lands metres behind the footprint and the footprint test would pick nothing, or the building behind. No physics is involved in any of it. `GameCalendar` is static and pure: the one place a month index becomes dates and semesters. Everything it answers is derived from a *month index*, the months since the game began, 0 being `StartMonth` (September) of `FirstYear` — `calendarMonth`, `year`, `monthName`, `label` (`Sep, Year 1`), `isSemesterStart`, `nextSemesterStart`. Years are academic, so `year` steps each September rather than each January, and `SecondsPerMonth` (45 s at 1x) is the only place a month has a length. `nextSemesterStart` finds the first `SemesterStartMonths` month (September or February) *strictly* after the one it is given: a building placed in September must open the following February, never the September it is already standing in, and the strictness is what makes construction always take time. `BuildingInfo`/`BuildingInfoDB` (`src/data/`) are the building types (see **Data**); `BuildingInfo.cost` is held in whole dollars even though the Sheet authors millions (`costM`, which may be fractional), converted by `BuildingInfo.DollarsPerM` in the constructor and nowhere else, so every rule that touches money — `canAfford`, the refund, the menu's prices — compares plain dollars. `GameState` holds the university and the fixed-step clock. `University` (`src/state/university.gd`) is the institution being run: its `name`, its `finances` and its `campus`, made together so the campus spends from the university's finances. `GameState.step` hands each new month to `University.startMonth`, which passes it to the campus and then charges the month's bill. Reach the campus as `gameState.university.campus`.
- **Views** (`university/src/views/`, `university/src/ui/`): Godot nodes that read from state and draw it. A view owns no simulation truth — position, timers and counts live in state and the view copies them each frame. `CampusView` (`campus_view.tscn`, the main scene) is the `Node3D` root: sun, environment, ground, camera, `%Buildings`, `%BuildController` and the UI `CanvasLayer` are authored there; the script calls `GameState.update(dt)` once a frame, creates one `BuildingView` for every building already standing when it starts (a loaded game arrives with its buildings) and then creates and frees one per `Campus.BuildingAdded`/`BuildingRemoved`, wires the menu's signals to the controller, and moves the selected and hovered highlights as the controller's `SelectionChanged`/`HoverChanged` report them. It is also where the `TogglePause`, `SpeedUp` and `SpeedDown` actions become `GameState.togglePause` and `changeSpeed`, where the `QuickSave` and `QuickLoad` actions (F5, F9) become `Global.saveGame` and `loadGame` on `Global.QuickSavePath`, and where `Campus.BuildingOpened` turns that building's view solid and re-shows the info panel when the building that opened is the selected one. `GameCamera` orbits a ground target at constant pitch and FOV; zoom is the distance to the target, `setTarget` clamps it to `Campus.bounds()` so every pan is limited in one place, and `_applyTransform` is the single place the transform is written, which is why `ViewMoved` is emitted from there. `GroundView` only sizes one `PlaneMesh` to `Campus.Size`; the grass and the 10 m lines are `ground.gdshader`'s, computed from world position, anti-aliased with `fwidth` and faded with distance so they never shimmer — visual only. `BuildingView` is a `BoxMesh` shaped from `building.rect().size` extruded to `Building.Height`, placed by `showRect` (the one state-angle-to-node-rotation conversion); `setHighlight` (`None`, `Selected`, `Destroy`) and `setUnderConstruction` both go through `_refresh`, the one place a building's colour is decided — the highlight picks the hue, construction drops the alpha to `ConstructionAlpha` — so a half-built box still highlights and neither setting can undo the other; `setUnderConstruction` also turns shadow casting off while the box is see-through, so a half-built building does not lay down a solid shadow. `createGhost` builds the same box translucent, with `setValid` for the green/red. `BuildController` is the only place input becomes commands, and in `campus_view.tscn` it sits **above** `Camera` in the scene tree on purpose: unhandled input is offered to nodes in reverse tree order, so the camera sees a right-button release first and swallows it when it ended a pan — what still reaches the controller is a real right *click*, which cancels the tool. UI is scene-authored: `StatusBar` across the top, `BuildMenu` bottom-left, `InfoPanel` bottom-right. `StatusBar` carries the transport buttons (`II` `>` `>>` `>>>`), the date and the money, and owns no state of its own: the pause button calls `GameState.setPaused` and the three speed buttons call `GameState.runAt`, while the pressed states, `GameCalendar.label` and the cash are re-read every `_process`, because speed and pause change from the keyboard and the console too and polling is the only way the strip can never be stale. Its buttons take no keyboard focus (`focus_mode = 0`, like the build menu's): a focused button would swallow `Space` as a re-press of itself instead of letting it toggle pause. `MoneyFormat.short` (`src/ui/`) is the one place a balance is abbreviated — `$10.0M`, `$950K`, `$0` — used by the strip and by the menu's prices alike, and the pressed-button style the two share lives in `src/ui/ui_theme.tres` rather than in either scene. `BuildMenu` entries carry the type's name and price, and `showAffordable(campus)` disables the ones `Campus.canAfford` refuses: the menu asks the campus instead of comparing numbers itself, so what is greyed out can never disagree with what `place` would do; `CampusView` calls it on `Finances.MoneyChanged`. `InfoPanel` shows the selected building's name and a status line, `Open` or `Under construction — opens Feb, Year 1`.
- State must NEVER know about views. Communication from state toward views must use signals only (`Campus.BuildingAdded` is the shape to follow).
- **Commands, not input.** State never reads input. Views call command methods on state (`Campus.place`, `Campus.destroy`); state validates, mutates and answers with a signal (`BuildingAdded`, `BuildingRemoved`). `BuildController` is the one node that turns a click or a key into one of those calls. The command methods are also the one seam where a command log would go if replay or undo is ever wanted — there is no order queue, because nothing here has to replay a timeline.
- Time: the view calls `GameState.update(dt)` once per frame with real dt. `GameState` runs a FIXED-STEP accumulator over `Campus.tick` (`GameState.TickStepDuration`, 0.01 s); anything the sim reads must be advanced there. `tickCount` is the ticks run since the game began and `gameTime()` is `tickCount * TickStepDuration` — derived, never accumulated: a running sum of frame dt would drift off the ticks the sim actually ran and would not come out the same twice, while an integer tick count does. `month()` is `tickCount / TicksPerMonth` (a const derived from `GameCalendar.SecondsPerMonth` and `TickStepDuration` next to the latter), the same derivation one step further, and the one place ticks become a month index for `GameCalendar` to answer from. `SpeedSteps` ([1, 3, 8]) is the one list of running speeds and `changeSpeed`/`setSpeedIndex` clamp into it, leaving pause alone — stepping the speed while paused picks what will run once it is unpaused. `paused` is a flag of its own rather than a fourth step, so pausing keeps whichever speed the player chose and `togglePause` hands it straight back; `setPaused(value)` is its one writer and `togglePause` goes through it. `runAt(index)` is what a transport speed button means — unpause and set the speed — so "a speed button also unpauses" lives in the state, not in the strip that draws the buttons. `update` runs no ticks at all while paused and `speedMultiplier()` times as many otherwise, from a frame dt capped at `MaxFrameDt` (0.1 s) *before* the multiplier: the cap bounds the real time one frame may feed the clock, so a hitch or a breakpoint costs at most that much sim time at any speed — capping after the multiplier would let 8x turn the same hitch into eight times the catch-up. `step()` is one tick and the one place the month rolls into the university: it ticks, counts, and calls `University.startMonth(month())` once the month index has moved on. That passes the month to `Campus.startMonth`, so buildings open from the clock and from nothing else, and then charges the month's bill: `Campus.upkeep()` (every open building's `BuildingInfo.upkeep`; one under construction costs nothing) plus `Finances.interest()`. `advanceMonths(n)` steps to the start of the nth month ahead whether or not the clock is paused, for the console and tests. Building and destroying go through none of this — they are direct calls on `Campus` (see **Commands, not input**), which is why they keep working while paused: pause stops the ticks, not the player. `Campus.update(dt)` is the per-frame, non-deterministic-safe part and may not touch anything `tick` reads. Both are empty until there is something to simulate.
- **Data.** Content tables follow the Info/DB pattern: an `Info` class with a typed constructor, a `DB` class holding them keyed by id, loaded from CSV via `CsvLoader` (`university/src/utils/csv_loader.gd`) and owned by the `Global` autoload. Declare a table directly in code only until its sheet exists.
- **Save/load.** A save is one JSON dictionary. Every state class writes itself with a pure `toDict()` and rebuilds with a `static fromDict`, each taking what it needs — `Finances.fromDict(data)`, `Campus.fromDict(data, buildingDB, fundedBy)`, `Building.fromDict(data, buildingInfo)`:
  - `GameState` saves its `university` and `tickCount`, the only one of its clock fields that's saved: speed, pause and the partial tick belong to the session, so a loaded game starts the way a new one does.
  - `University` (with its `finances` and `campus`), `Finances`, `Campus`, and `Building`, which is saved by type id — unlike the others, its `fromDict(data, buildingInfo)` takes the type already looked up rather than the whole `buildingDB`. A type the building data no longer has is reported (`Campus.UnknownTypeError`) and left out.

  A save missing a key is refused, never given a default: each `fromDict` checks its dictionary has every key it reads, via `Variants.hasKeys`, and answers null when one is missing, so `Global.loadGame` returns false with nothing changed. The unknown-building-type rule above is unchanged — that's a reported skip, not a refusal. `SaveFile` (`src/utils/`) is the only file I/O. It writes JSON with full-precision floats, so a loaded game plays out bit-identically (`SaveTest` checks it), and `read` answers null when there's no file.

  JSON gives every number back as a float. `Variants` (`src/utils/`) is the one place a parsed Variant becomes an `int`, `float` or `bool`, for saves and CSV cells alike.

  `Global.loadGame(path)` builds the new `GameState`, swaps it into `Global.gameState` and reloads the scene, so every view is rebuilt against the new state rather than rewired. `saveGame(path)` and `newGame()` sit beside it.

  Launching is a new game: `Global._ready` loads `res://data/start_state.json`, an authored save of a campus already built. It's hand-edited, unlike `buildings.txt`. `StartStateTest` loads it against the real building data and checks every building against `canPlace`.
- `Global` (autoload, `university/src/utils/global.gd`) owns the single `GameState`, loaded from the start state at launch (see **Save/load**), and spins up the remote console. Views fetch state through `Global.gameState`. After a load that's a different object, which is why loading reloads the scene. Build anything that reads another autoload in `_ready`, not as a field initialiser — the autoload name is unbound while its own members initialise.
- Don't use abstractions if they're not needed. No interface classes unless strictly necessary.
- Always use unique names (`%NodeName`) when accessing scene nodes in scripts. Set `unique_name_in_owner = true` in the .tscn file. Exception: `%` can't cross scene owner boundaries, so use path-based `get_node("Name")` when accessing nodes inside sub-scene instances.
- Always prefer scene files (.tscn) for UI layout — position, anchors, margins, font overrides, colors — rather than creating/configuring nodes in code. Code should only set dynamic text or visibility. Only build UI in code when nodes are truly dynamic (e.g., populating a grid with variable-count items).

## Code Style

- camelCase for variables and functions (`gameState`, `createNewLevel`), PascalCase for classes, constants, and signals (`TickStepDuration`, `EnemyAdded`). This is deliberate — do not "correct" it to snake_case.
- Fully typed GDScript. The project sets `unsafe_property_access`, `unsafe_method_access`, and `unsafe_call_argument` warnings to error level — untyped code fails to run.
- Conditions are parenthesized: `if (x):`. Match existing style.
- Game-facing tuning constants are authored in metres and seconds. Any unit conversion happens in exactly one place as a derived constant next to the source value.

## Testing

gdUnit4, suites in `university/tests/`. Run all tests after every change:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/
```

**The reported total is load-bearing.** gdUnit silently DROPS an entire suite
when one of its files fails to parse, while still printing PASSED. Note the
case/suite count before a change and compare after: a total that went DOWN
while you were adding tests means a suite failed to parse, not that a test
vanished. Find which one before believing a green run.

### Never test that data holds specific values

Do NOT write tests that assert game-content/balance values — hp, speed, colors, names, spawn counts, or that a data file contains particular values. Those tests just mirror the data: they break every time a value is tuned and catch no bug. They are counter-productive; delete them on sight.

Test **system behavior** instead: parsing/type-coercion, keyed lookup, movement, simulation rules. Fixtures may feed arbitrary inputs to exercise logic, but assertions must verify behavior or relationships, not that the content table holds a specific number.

## Data

**The Sheet is the absolute source of truth.** `python3 bin/GetDataFromGoogleSheets.py`
exports the "University" spreadsheet's `Buildings` tab (gid 948960558) to
`university/data/buildings.txt`, which is committed and **never hand-edited** —
an edit there is lost the next time anyone runs the export. A new tab is a new
`(gid, path)` pair in that script's `EXPORTS`. The export is written as `.txt`,
not `.csv`, because Godot auto-imports `*.csv` as a Translation resource, which
relocates the file and breaks the `FileAccess` read. `CsvLoader`
(`university/src/utils/csv_loader.gd`) parses it into `Array[Dictionary]`,
coercing each cell to bool/int/float where it looks like one, and
`Global.buildingDB` is built from `Global.BuildingsPath` in `Global._ready`,
before anything asks for a building type. A sheet that is not shared "anyone
with the link can view" answers the export endpoint with an HTML login page;
the script detects that and aborts rather than writing garbage over the data.
The `Buildings` tab authors cost in millions of dollars, in a column named
`costM` that may hold a fraction (0.5): `BuildingInfo.DollarsPerM` turns it
into whole dollars in the constructor, rounded, and nowhere after, so no other
code ever sees $M. A renamed or missing column reads as free, not as an error.
Its `buildTime` column is still parsed and deliberately unread — construction
ends at the next semester start, not after a duration. Upkeep is authored the
same way in thousands a month, in `upkeepK`, and `BuildingInfo.DollarsPerK`
turns it into `BuildingInfo.upkeep`, whole dollars.

## LimboConsole

LimboConsole is available as an autoload (toggle with the backtick key in-game). When debug commands are added, register them in `university/src/debug/debug_commands.gd` and list them here.

Registered debug commands:
- `screenshot` — save a screenshot to /tmp/university/screenshot.png.
- `camera <x> <z> <distance> <yawDeg>` — look at ground point <x> <z> from <distance> metres at <yawDeg> degrees.
- `build <id> <x> <z> <deg>` — place building type <id> at ground point <x> <z> (metres), turned <deg> degrees.
- `destroy <n>` — destroy building <n> (index from `buildings`).
- `buildings` — one line per building: index, type id, position, angle in degrees, construction status.
- `tool <id|destroy|none>` — arm a tool: a building type id to place it, `destroy`, or `none`.
- `select <n>` — select building <n> (index from `buildings`); -1 clears the selection.
- `state` — print the armed tool, the ghost angle in degrees, the selected and hovered building indices, the camera's target, distance and yaw, the time (date, paused/running, speed), the cash, the debt, the month's interest and upkeep, and the university's name. Read-only.
- `mousedown <x> <y> [button]`, `mouseup <x> <y> [button]` — synthetic button events at a design-space point (1920x1080), pushed through the root viewport so they route to the GUI exactly like a real click. `button` is `left` (default), `right` or `middle`.
- `mousemove <x> <y>` — synthetic motion to a design-space point, carrying whichever button a `mousedown` left held and the travel since the last synthetic event, so drags accumulate against `GameCamera.DragThreshold`.
- `action <name> <down|up>` — press or release an input action (`RotateLeft`, `RotateRight`, `ExitGame`, ...) as an `InputEventAction`, so polled reads and `_unhandled_input` handlers both see it.
- `pause` — toggle pause.
- `speed <1-3>` — run at speed 1, 2 or 3 (the three transport speeds). Does not unpause.
- `money [amount]` — print the cash, or set it to `<amount>` dollars.
- `debt [amount]` — print the debt and what may still be borrowed, or set the debt to `<amount>` dollars.
- `borrow <amount>` — borrow on the credit line, up to `Finances.CreditLimit`.
- `repay <amount>` — repay, at most the debt and the cash.
- `advance <months>` — step the sim to the start of the month `<months>` ahead, paused or not.
- `save [path]` — save the game to `<path>`, or to the quicksave (`user://quicksave.json`) when none is given. `save res://data/start_state.json` writes the start state from a running game; hand-edit it afterwards (open buildings, tick 0, campus month 0, cash and debt) — a start state re-saved from a running game carries that game's balances.
- `load [path]` — load the game saved at `<path>`, or the quicksave. Reloads the scene, so the camera and any armed tool or selection start fresh. A save missing a key is refused, with nothing changed.
- `newgame` — start over from the start state.

In-game: WASD/arrows pan the camera (speed scales with the zoom distance, so it
covers the same fraction of the screen at any zoom), Q and E turn it while held,
`[` and `]` zoom while held and the wheel or a trackpad two-finger scroll zooms
a step at a time; right-drag pans grab-the-world style (past
`GameCamera.DragThreshold`) and middle-drag turns. `Space` toggles pause and
`+` and `-` (main row or keypad) step the speed through 1x, 3x and 8x; the four
buttons at the top right do the same with exactly one of them reading as
pressed, and the date and the cash sit to their right. The speed buttons
unpause as well as choose the speed, while the keys only move the speed —
stepping while paused picks what will run once it is unpaused. The `Build`
button in the bottom-left corner opens the list: one entry per building type in
sheet order, each with its price and greyed out while it costs more than the
cash, then `Destroy`. Choosing a type arms it — a translucent ghost follows
the cursor, green where `Campus.canBuild` accepts it and red where it does not
(taken ground and too high a price both read red, so an unaffordable type still
shows a ghost, it just never builds), `,` and `.` turn it while held
(`BuildController.RotateSpeedDegrees`), and LMB builds it. The tool stays armed
at the same angle, so a row of dorms is one click each. A right click or Esc puts the tool away, and so does closing the
list. With no tool armed, LMB selects the building under the cursor — or clears
the selection when it hits nothing — and the bottom-right info panel shows the
selected building's name and whether it is open or still under construction.
`Destroy` reddens whichever building is under the cursor and LMB removes it.
A new building goes up translucent and stands under construction until the next
semester begins — September or February, always a later month than the one it
was placed in — then turns solid by itself. It takes up its ground and can be
selected the whole time, and `Destroy` gives the full price back while it is
unfinished and nothing at all once it has opened. Building and destroying work
while paused. Every open building costs upkeep, charged at the start of each
month with the interest on any debt; a bill bigger than the cash is borrowed
automatically, plus a fee, and the credit line itself is console-only until the
HUD's Money panel arrives. Esc with nothing armed and nothing selected quits. F5 saves the
game to the quicksave and F9 loads it back; every launch is a new game, from
the start state.

Command-line flags (`university/src/utils/command_line.gd`, passed after `--`): `--nomusic`, `--nosound` mute the `Music` / `SFX` audio buses if they exist.

### Console automation limits

`eval` runs against the SceneTree via `Expression`, which does NOT resolve
global class names or autoload names — `Global.foo` fails with "Invalid named
index". Reach everything through `get_root()`:
`get_root().get_node("Global")`, `get_root().find_child("CampusView", true, false)`.
Statics are callable on the instance, which is how you reach them. No lambdas either.

The real keyboard cannot be reached, and `warp_mouse` does nothing while the
window is hidden — so anything that follows the OS cursor usually draws
off-screen and cannot be screenshotted. The synthetic-input commands are the
way round it. `mousedown`/`mousemove`/`mouseup` push events through the root
viewport's GUI routing, so they hit-test controls and fall through to
`_unhandled_input` exactly as a real click does, and `BuildController` takes
the cursor position from the event rather than polling `Input`, which is what
makes the ghost and picking work with the window hidden. They take any of the
three buttons, and `mousemove` carries the held button and the travel since the
last synthetic event, so a right- or middle-drag adds up against
`GameCamera.DragThreshold` the way a real one does. Their coordinates are
design space, 1920x1080 (`project.godot`'s viewport size, `canvas_items`
stretch), whatever the real window is; read a control's `global_position` and
`size` over `eval` to aim at one. `action <name> <down|up>` covers the keyboard:
it feeds an `InputEventAction` through `Input.parse_input_event`, so both the
polled reads (`Input.get_axis`, for held keys like `,`/`.` and Q/E) and the
`_unhandled_input` handlers (Esc) see it. A held action stays down until the
matching `action <name> up`, which is how a per-frame effect is given time to
accumulate. `state` reads the result back without changing anything. For
everything else prefer a command that drives state directly (`build`,
`destroy`, `select`, `tool`, `camera`) and verify it by asserting state over
`eval`, not by looking.

To prove a revert/undo really restored something, screenshot before and after
and pixel-diff the two images: identical means bit-identical, which no state
assertion can show. `ImageChops.difference(...).getbbox()` returning `None` is
the proof.

## Godot project directory

Never delete the `.godot/` directory or any project-level cache without explicit permission. It contains editor settings, window layout, and local state that is painful to lose.

Never delete, move, or overwrite anything under a `user/` or `res/` data directory, or under a hand-authored content directory (levels, data), without explicit permission — hand-authored content there is not recoverable.

After adding a new script with `class_name`, register it by running:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --editor --quit-after 20
```
This updates the global script class cache without opening a window. The same pass registers the `uid` of a hand-authored `.tscn` in `uid_cache.bin`, but only if the editor stays up long enough to scan the filesystem — `--quit-after 2` has proved too short for a scene uid (the launch then prints a uid WARNING), `--quit-after 20` registered it.

**The same applies after any git operation that adds or removes `class_name`
scripts — merge, pull, checkout, rebase.** The `.godot/global_script_class_cache.cfg`
is editor-managed and git-ignored, so git changes leave it stale: it will lack the
new classes and still point at deleted ones. Running the game with a stale cache makes
any script that references an unregistered `class_name` fail to compile — e.g. an
autoload like `Global` referencing a state class comes up `Nil`, and everything downstream
(`Global.gameState`, etc.) crashes with a blank screen. Rebuild the cache with the
command above before launching after a merge/pull.

New or changed imported assets (textures, models) need a Godot import pass before `run.sh` shows them: the open editor does it on focus, headless it's `--headless --import` (the game runtime never imports).

## Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.
Before implementing:
    State your assumptions explicitly. If uncertain, ask.
    If multiple interpretations exist, present them - don't pick silently.
    If a simpler approach exists, say so. Push back when warranted.
    If something is unclear, stop. Name what's confusing. Ask.

## Simplicity First

Minimum code that solves the problem. Nothing speculative.
    No features beyond what was asked.
    No abstractions for single-use code.
    No "flexibility" or "configurability" that wasn't requested.
    No error handling for impossible scenarios.
    If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Prefer Generic Over Engine-Specific

Never reach for a Godot-specific API, class, or type when a plain, generic construct does the job without extra work. If the caller only needs a piece of information, return the information — not an engine object it has to interrogate.

- Keep engine types (`Tween`, `Node`, signals, `SceneTreeTimer`, ...) at the edge that genuinely needs them; pass plain values (numbers, enums, `Vector3`, dictionaries) across seams.
- This makes code simpler to reason about, trivially testable without the engine, and decoupled — the generic version is almost always the smaller one too.

Only use the engine-specific construct when the generic one would require real extra machinery to match its behavior. When that's the case, it's not "extra work" — it's the right tool.

## No Magic Numbers

Every tweakable numeric or color literal must be a named `const`. No bare numbers in logic.
- Game-balance values (speeds, counts, probabilities, thresholds) -> `const` at top of file.
- Values local to one file -> `const` at top of that file's class.
- Exceptions: `0`, `1`, `-1` as index/flag sentinels, `/2.0` for centering math, and `Color.WHITE`/`Color.TRANSPARENT` equivalents.

## No Duplicate Logic

Before writing a calculation or derivation, search for existing code that does the same thing. Common computations must live in a single function — callers delegate to it, never re-implement. If duplication is genuinely unavoidable (e.g., circular dependency, performance), flag it and ask before proceeding.

## Surgical Changes

Touch only what you must. Clean up only your own mess.
When editing existing code:
    Don't "improve" adjacent code, comments, or formatting.
    Don't refactor things that aren't broken.
    Match existing style, even if you'd do it differently.
    If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
    Remove imports/variables/functions that YOUR changes made unused.
    Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.
