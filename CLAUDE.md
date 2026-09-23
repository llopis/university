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
- **State** (`university/src/state/`, `university/src/data/`): pure logic classes — no engine/node dependencies, plain `class_name` classes, not Nodes. This is what makes the sim deterministic and testable without the engine. A state class may read an autoload-owned data DB (the Info/DB pattern below) while building itself; nothing else. `Campus` is the buildable world: a `Campus.Size`-metre square of ground centred on the origin (`Campus.bounds()`), the `buildings` array, every placement rule — `canPlace` (inside the bounds, overlapping nothing), `place`, `destroy`, `pick` — spending from the university's `Finances`. `refundFor(building)` is the one refund rule — the full cost while still under construction, nothing once open — that `destroy` reads rather than recomputing. `openWithRole(role)` and `capacityFor(role)` group and total the open buildings by `BuildingInfo.Role`, for the side panes. `Finances` (`src/state/finances.gd`) is the money: `cash` and `debt`, whole dollars, never negative, written only through `_write` (not `_set`, which is Object's virtual), which emits `MoneyChanged`, so no balance can change unannounced. A bare `Finances.new()` holds nothing; a new game's balances come from `res://data/start_state.json`. Building spends cash only: `canBuild` is `canAfford` and `canPlace` together, and `place` refuses whatever `canBuild` rejects, so to build past the cash the player borrows first. `borrow` draws on the credit line up to `Finances.CreditLimit`, and `repay` pays back at most the debt and the cash. The monthly bill, `charge`, is the one exception to the limit: a bill the cash cannot cover borrows the shortfall automatically, plus `ShortfallFee` of it, however much is already owed, and emits `AutoBorrowed`. There is no bankruptcy. `interest()` is a month of `AnnualInterestRate` on the debt (`MonthlyInterestRate`, derived once). The campus holds the university's `Finances` rather than a balance of its own; `University` makes the two together, and its `fromDict` builds the loaded campus on the loaded finances. `place` spends `info.cost` and stamps `opensAtMonth` from `GameCalendar.nextSemesterStart(month)`; `startMonth(newMonth)` is the one place `Building.underConstruction` is cleared, opening every building whose `opensAtMonth` has come and emitting `BuildingOpened` for each. `destroy` refunds the full cost while a building is still under construction and nothing once it is open, read straight off `underConstruction` so there is no record of what was paid to keep in step. `Building` is one building standing on it (`info`, `pos`, `angle`, plus `underConstruction`, true from placement until the campus opens it, and `opensAtMonth`); `Building.rectFor(info, pos, angle)` is the one footprint derivation, used by a placed building's `rect()`, by `canPlace` and by the ghost alike, so the three can never disagree about what fits. Its constants `DepthRatio` (the footprint's short side as a fraction of the sheet's `diameter`, its long side) and `Height` are placeholders until real models arrive; `Height` is state rather than view because picking tests the box, not the footprint. `OrientedRect` — centre, `size` along its own two axes, `angle` — is the one place rectangle maths lives: `corners`, `contains`, `overlaps` (separating-axis over both rects' axes; rects that only touch along an edge do not overlap, `OrientedRect.Epsilon`), `within(bounds)`, and `rayHit`, a slab test run in the rect's own frame where the box is axis-aligned. `Campus.pick` is `rayHit` against every building's box, nearest wins: a ray against the box rather than the ground point under the cursor, because at the camera's pitch a click on a 10 m roof lands metres behind the footprint and the footprint test would pick nothing, or the building behind. No physics is involved in any of it. `GameCalendar` is static and pure: the one place a month index becomes dates and semesters. Everything it answers is derived from a *month index*, the months since the game began, 0 being `StartMonth` (September) of `FirstYear` — `calendarMonth`, `year`, `monthName`, `label` (`Sep, Year 1`), `isSemesterStart`, `nextSemesterStart`. It also answers periods and weeks: `WeeksPerMonth` = 4; `Period` Fall (Sep–Jan), Spring (Feb–May) and Summer (Jun–Aug, a label only); `periodLabel`, `weekInPeriod`, `weeksInPeriod`, `weeksToNextPeriod` and `clockLine`, from a week index `GameState.week()` derives from ticks through `TicksPerWeek`. Years are academic, so `year` steps each September rather than each January, and `SecondsPerMonth` (45 s at 1x) is the only place a month has a length. `nextSemesterStart` finds the first `SemesterStartMonths` month (September or February) *strictly* after the one it is given: a building placed in September must open the following February, never the September it is already standing in, and the strictness is what makes construction always take time. `BuildingInfo`/`BuildingInfoDB` (`src/data/`) are the building types (see **Data**); `BuildingInfo.cost` is held in whole dollars even though the Sheet authors millions (`costM`, which may be fractional), converted by `BuildingInfo.DollarsPerM` in the constructor and nowhere else, so every rule that touches money — `canAfford`, the refund, the menu's prices — compares plain dollars. `GameState` holds the university and the fixed-step clock. `University` (`src/state/university.gd`) is the institution being run: its `name`, `finances`, `campus`, `students`, `policy`, `reputation`, `satisfactionSamples`, `lastIntakeGrade` and `reports` — see **The student loop** for the sequence `startMonth` runs over them. Reach the campus as `gameState.university.campus`.
- **Views** (`university/src/views/`, `university/src/ui/`): Godot nodes that read from state and draw it. A view owns no simulation truth — position, timers and counts live in state and the view copies them each frame. `CampusView` (`campus_view.tscn`, the main scene) is the `Node3D` root: sun, environment, ground, camera, `%Buildings`, `%BuildController` and the UI `CanvasLayer` are authored there; the script calls `GameState.update(dt)` once a frame, creates one `BuildingView` for every building already standing when it starts (a loaded game arrives with its buildings) and then creates and frees one per `Campus.BuildingAdded`/`BuildingRemoved`, and moves the selected and hovered highlights as the controller's `SelectionChanged`/`HoverChanged` report them; `Hud.setup` wires the menu's signals to the controller. It is also where the `TogglePause`, `SpeedUp` and `SpeedDown` actions become `GameState.togglePause` and `changeSpeed`, where the `QuickSave` and `QuickLoad` actions (F5, F9) become `Global.saveGame` and `loadGame` on `Global.QuickSavePath`, and where `Campus.BuildingOpened` turns that building's view solid — the side panel needs no signal for this, since it polls the selected building itself. `GameCamera` orbits a ground target at constant pitch and FOV; zoom is the distance to the target, `setTarget` clamps it to `Campus.bounds()` so every pan is limited in one place, and `_applyTransform` is the single place the transform is written, which is why `ViewMoved` is emitted from there. `GroundView` only sizes one `PlaneMesh` to `Campus.Size`; the grass and the 10 m lines are `ground.gdshader`'s, computed from world position, anti-aliased with `fwidth` and faded with distance so they never shimmer — visual only. `BuildingView` is a `BoxMesh` shaped from `building.rect().size` extruded to `Building.Height`, placed by `showRect` (the one state-angle-to-node-rotation conversion); `setHighlight` (`None`, `Selected`, `Destroy`) and `setUnderConstruction` both go through `_refresh`, the one place a building's colour is decided — the highlight picks the hue, construction drops the alpha to `ConstructionAlpha` — so a half-built box still highlights and neither setting can undo the other; `setUnderConstruction` also turns shadow casting off while the box is see-through, so a half-built building does not lay down a solid shadow. `createGhost` builds the same box translucent, with `setValid` for the green/red. `BuildController` is the only place input becomes commands, and in `campus_view.tscn` it sits **above** `Camera` in the scene tree on purpose: unhandled input is offered to nodes in reverse tree order, so the camera sees a right-button release first and swallows it when it ended a pan — what still reaches the controller is a real right *click*, which cancels the tool. UI is scene-authored: `Hud` across the top, `ActionBar` and `BuildPanel` bottom-left, `SidePanel` docked right. Icons are PNGs in `university/assets/icons/`, supplied by the user, never SVG.
  - **`Hud`** (`src/ui/hud.tscn`) is the UI root in `UI root` and gets GUI input first. It carries `ui_theme.tres`, `setup` takes the game state, camera, controller and the building DB, and it hosts the `TopBar`, the `SidePanel`, the `ActionBar`, its popovers (including the `BuildPanel`) and the popup, in that order, so the popovers draw over the side panel and the panel over the world. It opens at most one popover at a time — `toggle`/`openPopover`/`closePopover` by name (`gamemenu`, `unimenu`, `students`, `housing`, `money`, `reputation`, `build`) — closed by Esc first of all, or by a left click that still reaches the world underneath. `showBuilding(building)` selects a building and moves the camera to it (`universityMenu.BuildingChosen` and `sidePanel.BuildingWanted` both call it). `showPane(which)` selects the first building a pane name stands for and moves the camera there, answering whether one was found; `_firstFor(which)` is the one place a name becomes that building — `&"construction"`, the first building under construction, and `&"admissions"`, `&"academic"`, `&"dorm"` and `&"dining"`, the first open building of the matching `BuildingInfo.Role` (`Admissions`, `Academic`, `Housing`, `Dining`) through the shared `_firstOpen(role)`. `hud construction`/`hud admissions`/`hud academic`/`hud dorm`/`hud dining` drive it from the console. `openBuildPanel(category)` opens the `build` popover on one category, for the panes' "add a building" jumps (`sidePanel.BuildWanted`); `_armPlace`, wired to `BuildPanel.BuildingChosen`, arms the chosen type on `BuildController` and closes the panel, and `_toggleDemolish`, wired to both `actionBar.DemolishPressed` and the `Demolish` action, arms or disarms the destroy tool.
  - **`ActionBar`** (`src/ui/action_bar.tscn`), bottom-left, holds `Build` and `Demolish`; each only announces its press (`BuildPressed`/`DemolishPressed`) and reads pressed as `Hud` tells it to (`showBuildOpen` while the `build` popover is open, `showTool` while the destroy tool is armed) — it owns neither what is open nor what is armed.
  - **`BuildPanel`** (`src/ui/build_panel.tscn`, the `build` popover, 900×430) lists `BuildingInfoDB.categories()` down the left with each one's count (`db.inCategory(category).size()`) and, for the selected category (`showCategory`), a card per type — its price, what it adds, its upkeep and its footprint (`BuildingText.adds`/`footprint`) — greyed out (`modulate.a`) while `Campus.canAfford` refuses it (`showAffordable`) and highlighted while its type is armed (`showTool`); cards are made in code because how many there are is data. Its footer names the hovered or armed type with its cost and the cash on hand, warns when the cash falls short of it, and always names when it would open; with neither hovered nor armed it reads "Choose a building to place it." Choosing a card only emits `BuildingChosen` — arming it and closing the panel is `Hud._armPlace`'s job, and closing the panel no longer cancels the tool the way the old build list did.
  - **`SidePanel`** (`src/ui/side_panel.tscn`), docked right under the top bar, opens on `BuildController.SelectionChanged` and closes with it (`showBuilding(null)`), so × and a left click on empty ground both close it through the existing selection-clearing they already did. It is not a popover: a dropdown can still open beside it, and Esc's "clear the selection" step is what closes it, not `Hud`'s popover handling. It owns no state — everything is re-read every `_process`, so a building opening mid-view swaps its pane by itself. The header reads the type's name, "Category · what it holds" (`BuildingText.holds`) and, while the building is under construction, an info pill, "Under construction · opens Spring, Year N". The footer's Demolish button calls `Campus.destroy`, reading "Demolish · refund $2.0M" from `Campus.refundFor` while it is above 0, "Demolish" otherwise; the controller clears the selection when the destroyed building was selected, which is what closes the panel. Below the header, `ConstructionPane` shows while the building is going up (what opening changes — the role's capacity added, before and after; off campus before and after for housing; upkeep from then on; the refund note; a jump to the housing or students pane); an open Admissions Office shows `AdmissionsPane` instead — the next fall's live projection as three stages (seats to fill, expected applicants, expected intake, the first highlighted), a bar chart of applicants per fall from `University.fallReports()` (the last `AdmissionsPane.ChartFalls`, the latest accent-coloured), and the levers — minimum entry grade, tuition, room and meal plan — as `Stepper`s calling `Policy.stepMinimum`/`stepNextTuition`/`stepNextRoom`/`stepNextMealPlan`, applying from next fall; an open academic building shows `AcademicPane` instead — three `KpiView`s (students over every open seat, open seats, this fall's entry grade), a `MeterBar` of enrolled over seats, the note on how many will graduate before next fall and how many seats that opens up, then every open academic building as a `BuildingRow` (a `Button` theme variation, accent-bordered on hover; `BuildingRowAdd` is its accent-text twin for the add row after it) reading its name, `BuildingText.holds` and its upkeep, and jumps to All students and to Admissions, the latter hidden with none open; an open dorm shows `DormPane` — beds filled and off campus (warn past `UniversityRules.OverflowThreshold`), all dorms' beds against `Campus.beds()`, any opening at the next semester start, this dorm's room fees (`University.roomFeesOf`) against its upkeep, and a jump to All housing; an open dining hall shows `DiningPane` — meal plans, the load and who can't eat (toned by `DiningLoadLine.toneFor`), the same `DiningLoadLine` the housing dropdown uses, all dining halls' meal plan fees against this hall's upkeep, and a jump to Build. Every pane follows the same shape: a `VBoxContainer` with `university` and `building`, filling itself in `_process` while visible, emitting `PopoverWanted`/`BuildWanted`/`BuildingWanted` for its jumps rather than acting on them, which `SidePanel` relays.
  - **`Alerts`** (`src/ui/alerts.tscn`), between `SidePanel` and `ActionBar`/`Popovers` in `Hud`'s children so a dropdown draws over it, stacks a line top-right, under the bar, for every problem `University.problems()` reports right now and for events — an automatic loan, a building opening. `AlertFeed` (plain state, `src/ui/alert_feed.gd`) is the one place the rules live: a problem shows dated the week it first appeared and keeps that date while it holds; dismissing one hides it until it clears, coming back newly dated if it returns; events show newest first, at most `AlertFeed.MaxEvents`, until dismissed; problems come before events. Each line is an `AlertEntry` (`Source.Problem`, `AutoBorrowed` or `Opened`, carrying the `problem`, the `amount`/`fee` or the `building` it is about) shown by an `AlertRow` (`src/ui/alert_row.tscn`) — `GameCalendar.weekInPeriod(entry.week)`, its text and ×. `Alerts._process` calls `feed.update(university.problems(), state.week())` every frame and rebuilds the rows only when the shown list changes, by count or by entry identity, then refreshes every row's text regardless, since a count such as the off-campus share still moves. `Alerts.setup(state)` connects `Finances.AutoBorrowed` and `Campus.BuildingOpened` to handlers that only add an event to the feed, since both fire mid-tick. Clicking a line emits `PlaceWanted(entry)`; `Hud._openPlace` sends a problem through `Hud.openProblem(kind)` (the Housing dropdown for `HousingOverflow`, the first open dining hall's pane or, with none, the Housing dropdown for `DiningCrowded`/`DiningUnfed`, the Money dropdown for `CreditMaxed`), opens the Money dropdown for `AutoBorrowed`, and selects the building for `Opened` if it still stands; × calls `AlertFeed.dismiss`. While the side panel is open, `Hud._process` shifts `Alerts`' left and right offsets by the panel's width, since both are anchored to the same right edge.
  - **`SemesterPopup`** (`src/ui/semester_popup.tscn`, `Hud`'s last child, so it draws above the popovers) is the report every semester start opens: admissions (fall only — applicants, admitted with its open-seats note, entry grade, graduated), then fees collected, on/off campus, dining, reputation and satisfaction (each with its change) and what opened. `Hud.showReport`, wired to `University.SemesterStarted`, remembers `state.paused` only when the popup isn't already showing, then pauses, closes any popover and calls `SemesterPopup.showReport` — so several reports in a row show the latest while still remembering the pause from before the first of them. The Continue button calls the public `SemesterPopup.dismiss()` (hide, then emit `Continued`), which hands that remembered pause back. Esc calls `dismiss()` too, checked first of all in `Hud._unhandled_input`, which while the popup is showing also marks a `TogglePause` press handled and does nothing else, so Space does nothing behind it. `SemesterStarted` fires mid-tick, before that month's bill (`University.startMonth`), so `showReport` must only pause and show — never save, load or otherwise touch state. `hud popup` (`showLatestReport`) shows the latest `University.reports` entry, for the console.
  - **`GameMenu`** (☰) holds Save, Load (disabled without a quicksave), New game and Quit; choosing Save, Load or New game closes the popover and calls `Global.saveGame`/`loadGame`/`newGame` on the quicksave path, and Quit calls `get_tree().quit()` directly.
  - **`UniversityMenu`** (the crest) lists Admissions Office, Finances and Reputation under University, and Housing and Dining (with live "N dorms"/"N halls" counts) under Services; choosing Admissions Office or Dining selects the first open building of that kind and moves the camera to it, disabled while none is open. A `StatusDot` (a `Panel` theme variation, tinted through `self_modulate` rather than a changed stylebox) marks Admissions Office good when one is open, Housing warn on `Problem.Kind.HousingOverflow`, and Dining warn on `DiningCrowded` or bad on `DiningUnfed`, dim otherwise.
  - **`TopBar`** holds:
    - ☰ (Game menu) and the crest (University menu)
    - the six `SlotView`s: students/seats, beds with off campus, cash with debt, monthly expenses, next fees, reputation with its target
    - the clock: `GameCalendar.periodLabel`/`clockLine` and a `MeterBar` of the period's progress
    - the transport buttons (`II` `1×` `3×` `8×`), with the same rules the top bar had (pause calls `setPaused`, a speed calls `runAt`, exactly one reads pressed, no focus)
  - **It owns no state** and re-reads everything each `_process`, because speed, pause and every number change from the keyboard and the console too and polling is the only way the bar can never be stale. Its buttons take no keyboard focus (`focus_mode = 0`, like the action bar's): a focused button would swallow `Space` as a re-press of itself instead of letting it toggle pause.
  - **`StudentsDropdown`** (the Students slot) shows five `KpiView`s (enrolled, open seats, admitted this fall, graduating before fall, this fall's entry grade), the cohorts as a table — each row's class reads `Cohort.graduationYear(month)`, "Class of Year N" — then housing (`InfoRow`s for on campus, off campus with a warn pill past `UniversityRules.OverflowThreshold`, and any beds opening at the next semester start) and next fall's live projection (`seatsToFillNextFall`, `expectedApplicants`, `expectedIntake`) at today's reputation and next year's prices, worded by `ProjectionText` — `seatsNote(university)` ("N open + M graduating", or just "M graduating" once nothing is left beyond the graduating class) and `intakeNote(intake)` ("entry grade ≈ 3.24", or "" for none admitted) — shared with `AdmissionsPane`, the one place either note is worded.
  - **`ReputationDropdown`** (the Reputation slot, and the university menu's Reputation entry) shows reputation, its `reputationTarget()` and where `UniversityRules.nextReputation` would take it by next fall, then the target's two halves — the latest intake's grade and the year's satisfaction — beside `satisfactionNow()`'s three penalties (housing, crowding, unfed).
  - **`HousingDropdown`** (the Beds slot, and the university menu's Housing entry) shows four `KpiView`s (beds filled, off campus with a warn tone past `UniversityRules.OverflowThreshold`, the threshold itself, and beds opening at the next semester start), every dorm as a table — each row's beds read `University.residentsOf(building)` over `info.beds`, since dorms fill evenly — and the dining load beside housing, since only housed students eat on campus: an `InfoRow` for who is eating and a `MeterBar` scaled to `UniversityRules.DiningHardLimit`, with a white mark at `RecommendedLoad` and the red limit at the bar's end.
  - **`MoneyDropdown`** (the Cash, Monthly expenses and Fees slots, and the university menu's Finances entry) shows cash, the monthly bill's two lines (upkeep and interest) and the credit line — `Owed`/`Credit left` and Borrow/Repay buttons that move `Finances.LoanStep` and are disabled through `Finances.canBorrow()`/`canRepay()` rather than comparing balances themselves — beside the coming semester's fees at today's enrolment, from `University.pricesAt` and `projectedFees()`, and `cashAtSemesterStart()` both as a KPI and after the fees land. It needs `GameState` for `week()`, so it is set up with `setState(gameState)` rather than `setUniversity`.
  - **All four dropdowns** refresh their numbers every `_process` while visible, and rebuild their variable rows (the cohort and dorm tables) on becoming visible (`visibility_changed`) and on `University.SemesterStarted` — the rebuild only reads state, never writes it.

  `UiTone` (a tone is a theme variation suffix — `Good`/`Warn`/`Bad`/`Dim` on a base type such as `Value`), `KpiView`, `InfoRow`, `SlotView` and `MeterBar` (`src/ui/`) are the HUD's shared building blocks, coloured through `ui_theme.tres`'s `Palette`. Every Label in the HUD carries exactly one of five theme type variations: `Title` (26 px, the Cormorant `SerifBold` `FontVariation`, no tones — the crest name, the shield letter, the popups' headings), `Heading` (16 px, Barlow Semi Condensed SemiBold, uppercase, no tones — section titles, table headers), `Value` (24 px, Barlow Semi Condensed SemiBold — the slots' and KPIs' headline numbers), `Body` (18 px, Barlow Regular, also the theme's `default_font`/`default_font_size` — row keys and values, table cells, the base `Button`) and `Caption` (16 px, Barlow Semi Condensed Medium, muted — sub-labels and notes); `Value`, `Body` and `Caption` each carry the four tones as a `Good`/`Warn`/`Bad`/`Dim` suffix through `UiTone.variation`, `Title` and `Heading` have none. `Pill`/`PillGood`/`PillWarn`/`PillBad`/`PillDim` keep their own coloured background box but take `Caption`'s font and size. Buttons map onto the same five: menu items, building rows, category buttons, cards, `GhostButton`/`PrimaryButton` and the base `Button` are `Body`; the speed buttons, the action buttons and jump links are `Heading`; the ×/−/+ glyph buttons (`CloseButton`, `AlertClose`, `StepButton`) are `Value`. `Palette` holds `chrome`/`chrome2`/`chrome3`, `line`/`line2`, `text`/`muted`/`dim`, `good`/`warn`/`bad`/`maroon` and the blue accent — `accent` (#4a90e2) and `accent2` (#8cc2ff) for highlights, borders and hovers, `onAccent` for text sat on an accent-filled control — everywhere gold used to be; `warn` (amber) is unchanged, so a problem still reads as a warning rather than a highlight. The top bar is 72 px tall; every dropdown, menu and the side panel sit at `offset_top = 72` to clear it, and `Alerts` sits at 86 to clear the bar plus its own margin. `MoneyFormat.short` is the one place a balance is abbreviated — `$10.0M`, `$950K`, `$0` — used by the top bar and by the build panel's cards alike; `full` groups whole dollars (`$9,606`) and `signed` reads a balance with its direction (`+$16.6M`, `−$1.9M`). `NumberFormat.count` groups a whole number (`1,080`) and `percent` floors a fraction to a whole share (`33%`).
- State must NEVER know about views. Communication from state toward views must use signals only (`Campus.BuildingAdded` is the shape to follow).
- **Commands, not input.** State never reads input. Views call command methods on state (`Campus.place`, `Campus.destroy`); state validates, mutates and answers with a signal (`BuildingAdded`, `BuildingRemoved`). `BuildController` is the one node that turns a click or a key into one of those calls. The command methods are also the one seam where a command log would go if replay or undo is ever wanted — there is no order queue, because nothing here has to replay a timeline.
- Time: the view calls `GameState.update(dt)` once per frame with real dt. `GameState` runs a FIXED-STEP accumulator over `Campus.tick` (`GameState.TickStepDuration`, 0.01 s); anything the sim reads must be advanced there. `tickCount` is the ticks run since the game began and `gameTime()` is `tickCount * TickStepDuration` — derived, never accumulated: a running sum of frame dt would drift off the ticks the sim actually ran and would not come out the same twice, while an integer tick count does. `month()` is `tickCount / TicksPerMonth` (a const derived from `GameCalendar.SecondsPerMonth` and `TickStepDuration` next to the latter), the same derivation one step further, and the one place ticks become a month index for `GameCalendar` to answer from. `SpeedSteps` ([1, 3, 8]) is the one list of running speeds and `changeSpeed`/`setSpeedIndex` clamp into it, leaving pause alone — stepping the speed while paused picks what will run once it is unpaused. `paused` is a flag of its own rather than a fourth step, so pausing keeps whichever speed the player chose and `togglePause` hands it straight back; `setPaused(value)` is its one writer and `togglePause` goes through it. `runAt(index)` is what a transport speed button means — unpause and set the speed — so "a speed button also unpauses" lives in the state, not in the top bar that draws the buttons. `update` runs no ticks at all while paused and `speedMultiplier()` times as many otherwise, from a frame dt capped at `MaxFrameDt` (0.1 s) *before* the multiplier: the cap bounds the real time one frame may feed the clock, so a hitch or a breakpoint costs at most that much sim time at any speed — capping after the multiplier would let 8x turn the same hitch into eight times the catch-up. `update` also stops ticking the moment `paused` is set, even mid-frame: a listener on `University.SemesterStarted` (the semester popup) may pause from inside a tick, and the rest of that frame's ticks wait rather than run through it. `step()` is one tick and the one place the month rolls into the university: it ticks, counts, and calls `University.startMonth(month())` once the month index has moved on, which runs the sequence in **The student loop** and ends with `finances.charge(monthlyExpenses())`. `advanceMonths(n)` steps to the start of the nth month ahead whether or not the clock is paused, for the console and tests. Building and destroying go through none of this — they are direct calls on `Campus` (see **Commands, not input**), which is why they keep working while paused: pause stops the ticks, not the player. `Campus.update(dt)` is the per-frame, non-deterministic-safe part and may not touch anything `tick` reads. Both are empty until there is something to simulate.
- **The student loop.**
  - **Cohorts.** `StudentBody` holds the students as `Cohort`s (`size`, `entryGrade`, `semestersCompleted`), one per fall intake. At every semester start each completes a semester, and those reaching `StudentBody.SemestersToGraduate` graduate whole.
  - **Policy.** `Policy` holds this year's `Prices` (`current`) and next year's (`next`, what the player sets), and the minimum grade (0 is off). `lockYear(hasOffice)` makes `next` current at each fall start, or the defaults when no Admissions Office is open, and with no office there is no minimum. `stepNextTuition`, `stepNextRoom` and `stepNextMealPlan` move next year's prices by `Policy.PriceStep` dollars at a time, the Admissions Office pane's steppers; `stepMinimum` moves the minimum by `Policy.GradeStep` a step, and from off a step up starts it at `UniversityRules.GradeBase` (the cutoff when applicants equal seats), while a step below that turns it off again.
  - **Rules.** `UniversityRules` is static and pure. It holds every tuning const and formula, and answers small records (`Intake`, `Satisfaction`, `Fees`):
    - applicants from reputation and total price
    - admission into the open seats: the cutoff is `GradeBase + GradeSpread·ln(A/S)`, and a minimum above it trims the class
    - housed, meal plans (capped by `diningLimit(meals)`) and dining load
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
  - **Live queries.** `monthlyExpenses()` (upkeep plus interest) is the one source of the bill. `housed()`, `offCampus()`, `mealPlans()`, `unfed()`, `satisfactionNow()`, `yearSatisfaction()` and `reputationTarget()` are derived live, never stored; `setReputation` is the one writer of `reputation`, clamped to `0..UniversityRules.MaxScore`. `problems()` is the one list of what is wrong right now (`Problem.Kind`: `HousingOverflow` past `OverflowThreshold`, `DiningCrowded` while the dining load is over 1 and nobody goes unfed, `DiningUnfed` once anyone does, `CreditMaxed` when `availableCredit()` is 0), which alerts draw from, so each threshold is checked in one place.
    The HUD's projections come from the same state, each in one place:
    - `Campus.seatsBy`, `bedsBy`, `mealsBy` and `hasAdmissionsOfficeBy(m)` count buildings open by month m, including those still under construction that open by then.
    - `Policy.pricesFor(hasOffice)` is the one rule for what next fall charges.
    - `University` answers:
      - `pricesAt(start)`: what a semester start charges
      - `graduatingByNextFall()`
      - `seatsToFillNextFall()`
      - `expectedApplicants()` and `expectedIntake()`, at today's reputation
      - `housedAt(m)`, `mealPlansAt(m)` and `projectedFees()`, at today's enrolment
      - `cashAtSemesterStart()`, which runs the monthly bills on a copy of the finances
      - `residentsOf(building)`: dorms fill evenly
      - `lastFallReport()` and `fallReports()`, oldest first
      - `offCampusShare()`, backed by `UniversityRules.offCampusShare`, the one off-campus fraction; `offCampusWith(beds)` and `offCampusShareWith(beds)` answer it at a given bed count, at today's enrolment, so a dorm's effect can be read before it opens
      - `feesNow()`: what a semester start collects at today's numbers and this year's prices; `_startSemester` uses it
      - `roomFeesOf(building)`: one dorm's residents at this year's room price
      - `hasProblem(kind)`
    - `Cohort.graduationYear(m)` is "Class of Year N".
    The start state carries its own Year 1 fall report, since it stands just after that start.
  - **Month 0 never runs `startMonth`,** because tick 0 already is month 0. The start state is therefore the moment just after month 0's fall start: its first cohort is admitted, its fees are paid, and one satisfaction sample is taken.
- **Data.** Content tables follow the Info/DB pattern: an `Info` class with a typed constructor, a `DB` class holding them keyed by id, loaded from CSV via `CsvLoader` (`university/src/utils/csv_loader.gd`) and owned by the `Global` autoload. Declare a table directly in code only until its sheet exists.
- **Save/load.** A save is one JSON dictionary. Every state class writes itself with a pure `toDict()` and rebuilds with a `static fromDict`, each taking what it needs — `Finances.fromDict(data)`, `Campus.fromDict(data, buildingDB, fundedBy)`, `Building.fromDict(data, buildingInfo)`:
  - `GameState` saves its `university` and `tickCount`, the only one of its clock fields that's saved: speed, pause and the partial tick belong to the session, so a loaded game starts the way a new one does.
  - `University` (its `finances`, `campus`, `students`, `policy`, `reputation`, `satisfactionSamples`, `lastIntakeGrade` and `reports`), `Finances`, `StudentBody` and its `Cohort`s, `Policy` and its two `Prices`, `SemesterReport`, `Campus`, and `Building`, which is saved by type id — unlike the others, its `fromDict(data, buildingInfo)` takes the type already looked up rather than the whole `buildingDB`. A type the building data no longer has is reported (`Campus.UnknownTypeError`) and left out.

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
turns it into `BuildingInfo.upkeep`, whole dollars. Capacities are whole
numbers: `seats` (academic), `beds` and `meals` (the diners a dining hall is
meant for, not a hard cap), and `admissionsOffice` is TRUE on the type that
grants the price and minimum-grade levers. A blank reads as none. `Campus`
answers `seats()`, `beds()`, `meals()` and `upkeep()` over open buildings only,
through one `_totalBy`, which also serves the `…By(m)` projections, and
`hasOpenAdmissionsOffice()`. `BuildingInfo.role()` is what a type is for — the
first of `Role.Admissions`, `Academic`, `Housing` and `Dining` that applies, or
`Other` — which decides its side-panel pane and how it is counted; `capacity()`
is what it holds of that role (seats, beds or meals; 0 for `Admissions` and
`Other`). `BuildingInfoDB.categories()` lists the sheet's `category` values in
the order the sheet first uses them, the build panel's tabs, and
`inCategory(category)` answers one tab's types in sheet order.

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
- `state` — print the armed tool, the ghost angle in degrees, the selected and hovered building indices, the camera's target, distance and yaw, the time (date, paused/running, speed), the week, the cash, the debt, the month's interest and upkeep, the enrolled count and reputation, and the university's name. Read-only.
- `mousedown <x> <y> [button]`, `mouseup <x> <y> [button]` — synthetic button events at a design-space point (1920x1080), pushed through the root viewport so they route to the GUI exactly like a real click. `button` is `left` (default), `right` or `middle`.
- `mousemove <x> <y>` — synthetic motion to a design-space point, carrying whichever button a `mousedown` left held and the travel since the last synthetic event, so drags accumulate against `GameCamera.DragThreshold`.
- `action <name> <down|up>` — press or release an input action (`RotateLeft`, `RotateRight`, `ExitGame`, ...) as an `InputEventAction`, so polled reads and `_unhandled_input` handlers both see it.
- `pause` — toggle pause.
- `speed <1-3>` — run at speed 1, 2 or 3 (the three transport speeds). Does not unpause.
- `money [amount]` — print the cash, or set it to `<amount>` dollars.
- `debt [amount]` — print the debt and what may still be borrowed, or set the debt to `<amount>` dollars.
- `borrow <amount>` — borrow on the credit line, up to `Finances.CreditLimit`.
- `repay <amount>` — repay, at most the debt and the cash.
- `students` — print the cohorts, enrolment against seats, housing against beds, meal plans and the dining load, and today's satisfaction broken down.
- `prices [tuition room meal]` — print this year's and next year's prices, or set next year's (they apply from the next fall).
- `minimum [grade]` — print the minimum entry grade, or set it (0 is off).
- `reputation [value]` — print the reputation and where it is heading, or set it.
- `report` — print the last semester start's report.
- `simulate <years>` — copy the game through `toDict`/`fromDict`, play the copy `<years>` ahead with no input, and print one row per semester start (applicants, open seats, admitted and entry grade, graduated, enrolled, housed and off campus, dining load, satisfaction, reputation, fees, cash, debt). The live game is untouched; this is the tuning tool.
- `advance <months>` — step the sim to the start of the month `<months>` ahead, paused or not.
- `save [path]` — save the game to `<path>`, or to the quicksave (`user://quicksave.json`) when none is given. `save res://data/start_state.json` writes the start state from a running game; hand-edit it afterwards (open buildings, tick 0, campus month 0, cash and debt) — a start state re-saved from a running game also carries that game's `reports` and `satisfactionSamples`, cohorts, `lastIntakeGrade`, reputation and prices, so set those deliberately too (keep exactly one report: that start's own).
- `load [path]` — load the game saved at `<path>`, or the quicksave. Reloads the scene, so the camera and any armed tool or selection start fresh. A save missing a key is refused, with nothing changed.
- `newgame` — start over from the start state.
- `hud <name>` — open a HUD popover by name (`gamemenu`, `unimenu`, `students`, `reputation`, `housing`, `money`, `build`) or a side-panel pane by name (`construction`, `admissions`, `academic`, `dorm`, `dining`, selecting its first building and moving the camera there; with no matching building it prints "No building for HUD pane: `<name>`" and changes nothing); `popup` shows the latest semester report; `none` closes whichever popover is open; any other name prints "Unknown HUD name: `<name>`" and changes nothing.

In-game: WASD/arrows pan the camera (speed scales with the zoom distance, so it
covers the same fraction of the screen at any zoom), Q and E turn it while
held, `[` and `]` zoom while held and the wheel or a trackpad two-finger scroll
zooms a step at a time; right-drag pans grab-the-world style (past
`GameCamera.DragThreshold`) and middle-drag turns. `Space` toggles pause and
`+` and `-` (main row or keypad) step the speed through 1x, 3x and 8x; the top
bar's transport buttons (`II` `1×` `3×` `8×`) do the same with exactly one of
them reading as pressed, next to the clock's period and week and a progress bar
for the semester. The speed buttons unpause as well as choose the speed, while
the keys only move the speed — stepping while paused picks what will run once
it is unpaused. `B` or the `Build` button, in the action bar at the bottom-left
corner, opens the build panel: categories (with their counts) on the left, and
on the right a card per type in the chosen category, with its price, what it
adds, its upkeep and its footprint, greyed out while it costs more than the
cash, and a footer naming the hovered or armed type. Choosing a card arms it
and closes the panel — a translucent ghost then follows the cursor, green where
`Campus.canBuild` accepts it and red where it does not (taken ground and too
high a price both read red, so an unaffordable type still shows a ghost, it
just never builds), `,` and `.` turn it while held
(`BuildController.RotateSpeedDegrees`), and LMB builds it. The tool stays armed
at the same angle, so a row of dorms is one click each. A right click or Esc
puts the tool away; closing the panel no longer does. `X` or the action bar's
`Demolish` button toggles the destroy tool the same way — arming it, or putting
it away when it is already armed — reddening whichever building is under the
cursor while it is armed, and LMB removes it. `Build` reads as pressed while
the panel is open, `Demolish` while the destroy tool is armed. ☰, the game menu
at the bar's left, holds Save, Load, New Game and Quit. Next to it, the crest
opens the university menu — `Tab` toggles it too — Admissions Office, Finances
and Reputation under University, Housing and Dining (each with its building
count) under Services; Admissions Office and Dining select their first open
building and move the camera there, and are disabled with none open, while
Finances, Reputation and Housing open their dropdown instead. `F2` opens the side panel on the Admissions Office
directly, the way clicking its row does; `F3` toggles the Money dropdown
directly, without opening the university menu. Six slots, read live off the
university every frame, fill the rest of the bar — Students, Beds, Cash,
Monthly expenses, Fees and Reputation — and clicking one opens its dropdown:
Students and Reputation their own, Beds the Housing dropdown, any of Cash,
Monthly expenses or Fees the Money dropdown (what `F3` opens too), with exactly
the slot last clicked reading pressed while Money is open. The dropdowns carry
jumps onward to what they don't already show — Students to Housing and
Reputation, Reputation to Housing, and Housing's "Room & meal plan prices →"
to the Admissions pane, disabled with no office open. With no tool armed, LMB
selects the building under the cursor — or clears the selection when it hits
nothing — and the docked side panel on the right opens with it: the header
names it, its category and what it holds, with a status pill while it is still
going up. Below, the pane depends on what stands there — while under
construction, what opening will add and when; an open Admissions Office, next
fall's applicants and intake with the price and minimum-grade levers; an open
academic building, dorm or dining hall, its own numbers against the campus
total and a jump onward. Its own Demolish button destroys the selected
building. A new building goes up translucent and stands under construction
until the next semester begins — September or February, always a later month
than the one it was placed in — then turns solid by itself. It takes up its
ground and can be selected the whole time, and Demolish, from the action bar or
the side panel, gives the full price back while it is unfinished and nothing at
all once it has opened. Building and destroying work while paused. Every open
building costs upkeep, charged at the start of each month with the interest on
any debt; a bill bigger than the cash is borrowed automatically, plus a fee,
and Money's Borrow and Repay draw on and pay back the credit line in
`Finances.LoanStep` steps. Top-right, under the bar, alerts stack for whatever
is wrong now and for what just happened — an automatic loan, a building opening
— each dated the week it appeared; a click opens its place and × dismisses it,
and the stack shifts left of the side panel while it is open. Every semester
start opens the report popup and pauses the game; Continue or Esc resumes
whatever was running before it. Esc, while the popup is showing, does what
Continue does; Space, `B`, `X`, `Tab`, `F2` and `F3` do nothing while it is up.
`F5` saves the game to the quicksave and `F9` loads it back; every launch is a
new game, from the start state. Otherwise Esc closes an open popover, then puts
the tool away, then clears the selection, and then opens the Game menu (☰),
whose Quit quits.

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
