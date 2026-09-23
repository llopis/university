# Students, money and the HUD

Date: 2026-09-22. Status: approved in chat, section by section. Builds on
`2026-09-21-time-money-construction-design.md`. The state/view separation in
`CLAUDE.md` still governs. The HUD reference is
`2026-09-22-hud-mockup.html`: the approved adaptation of
`~/Downloads/Universitas HUD.html`. Its blue dashed outlines mark what changed
from the original, and hovering one says why.

## Goal

The **Do now** list in `Prototype.md`:
- save/load
- a start state that is an authored save
- starting cash plus a line of credit with monthly interest
- building upkeep
- the toolbar
- prices and a minimum grade in the Admissions panel
- the semester report
- the student loop: applicants, admission, cohorts, fees, housing overflow,
  dining, satisfaction and reputation

All of it sits under the mockup's prototype-mode HUD, cut down to what these
systems produce.

## Decisions taken

- **Structure.** One spec, five implementation plans. Each plan ends playable
  and committed (see **Phases**).
- **Scope beyond Do now.**
  - In: the minimum entry grade, weeks in the clock, the university's name
    (shown only).
  - Out: colleges, Reach and overlays, the Move tool, state funding, renaming.
  - **No demand indicator anywhere**, even though the mockup had one. That
    means no Needs or RCI widget, no "Demand: High", and no "seats nearly
    full" problem, because full classes are fine. There's also no keystroke
    cheatsheet.
- **Start state.** An authored save of a university that is already running:
  open buildings, four cohorts, prices, reputation, cash.
- **Loans.** A credit line with interest only. The player borrows and repays
  explicitly. A monthly bill bigger than the cash borrows the shortfall
  automatically, plus a fee. Cash never goes negative.
- **Price brake.** Applicants respond to the **total** price per semester:
  tuition + room + meal plan.
- **Price timing.** Prices are yearly. What the player sets applies from the
  next fall, for the whole year. Applicants are only counted in fall, so a
  spring price would otherwise escape the brake.
- **Satisfaction** has three parts: housing overflow past a threshold, dining
  crowding past its recommended load, and dining shortfall past a hard limit.
  Full classes cost nothing.
- **Dining.** Each dining building serves a *recommended* number of students.
  Past that it gets crowded and satisfaction falls. Past a hard limit the rest
  can't eat: they buy no meal plan and satisfaction falls harder. Only housed
  students eat on campus.
- **Weeks.** 4 weeks a month.
  - Fall: Sep–Jan, 20 weeks.
  - Spring: Feb–May, 16 weeks.
  - Summer: Jun–Aug, 12 weeks. Summer is only a label; the sim still has two
    semester starts, September and February.
- **Tuning.** Named consts in one state class, plus a `simulate` console
  command that prints the loop's trajectory.
- **Menus.** A ☰ Game menu (Save, Load, New game, Quit) sits apart from the
  crest's university menu. Esc with nothing open, armed or selected opens the
  Game menu instead of quitting.

## Data

New columns in the Sheet's `Buildings` tab. A missing or blank cell reads as
0 or false, as `costM` does.

| Column | Type | `BuildingInfo` field |
|---|---|---|
| `seats` | int | `seats`: academic seats |
| `beds` | int | `beds` |
| `meals` | int | `meals`: the recommended number of diners |
| `upkeepK` | number (may be fractional) | `upkeep`: whole dollars per month. `DollarsPerK` converts it in the constructor and nowhere else, as `DollarsPerM` does for cost. |
| `admissionsOffice` | TRUE / blank | `admissionsOffice`: this type grants the price and minimum-grade levers |

Suggested starting values. The Sheet is yours, so these go in with your OK:

| Type | Column values |
|---|---|
| Dorm | beds 120, upkeepK 150 |
| Engineering | seats 400, upkeepK 210 |
| Dining Commons | meals 650, upkeepK 220 |
| Admissions | admissionsOffice TRUE, upkeepK 90 |

The current `costM` values ($1M–$10M) are well below Funding.md's $15–30M for
a plain academic building. They're worth a pass.

## State

```
GameState        clock (tickCount, speed, pause) + university
└ University     name, reputation, satisfactionSamples, lastIntakeGrade, reports
  ├ Campus       buildings, placement, construction, month, as today minus money
  ├ Finances     cash, debt
  ├ StudentBody  cohorts
  └ Policy       current Prices, next Prices, minimumGrade
UniversityRules  static: the tuning consts and pure formulas of the loop
```

`gameState.campus` becomes `gameState.university.campus` everywhere.

### `Campus`

Keeps buildings, placement, construction and `month`. Money moves out:
`Campus` gets a `Finances` reference, so `canAfford(info)`, `place` and the
refund in `destroy` keep today's names and rules.

It adds totals over **open** buildings: `seats()`, `beds()`, `meals()`,
`upkeep()` and `hasOpenAdmissionsOffice()`. `startMonth` returns the buildings
it opened, as well as emitting `BuildingOpened`, so the semester report can
list them.

Buildings only open at semester starts, so capacity changes only then or when
something is destroyed.

### `Finances`

`cash` and `debt`, both whole dollars and both never negative. `_set` is the
one writer and emits `MoneyChanged`.

| Command | Rule |
|---|---|
| `canAfford(amount)` / `spend` / `refund` | Building uses cash only. To build past your cash you borrow first. `place` refuses whatever `canBuild` rejects. |
| `borrow(amount)` | Takes `min(amount, CreditLimit − debt)` and returns what it took. |
| `repay(amount)` | Pays `min(amount, debt, cash)` and returns it. |
| `receive(amount)` | Fees coming in. |
| `charge(amount)` | The monthly bill. If cash covers it, it's paid. Otherwise cash goes to 0, `debt += shortfall + roundi(shortfall × ShortfallFee)`, and it emits `AutoBorrowed(shortfall, fee)`. This automatic draw **can go past `CreditLimit`**. There's no bankruptcy; a full line only means `borrow` gives nothing. |
| `interest()` | `roundi(debt × MonthlyInterestRate)` |

Consts:
- `CreditLimit` $50M
- `AnnualInterestRate` 0.06, with `MonthlyInterestRate` derived next to it
- `ShortfallFee` 0.05
- `LoanStep` $5M, what one Borrow or Repay button moves

`Campus.StartingMoney` goes away. A new game's cash and debt come from the
start state, and a blank `Finances` starts at 0 and 0.

### `StudentBody`

`cohorts: Array[Cohort]`. A `Cohort` has `size`, `entryGrade` and
`semestersCompleted`.

- `enrolled()`
- `completeSemester() -> int`: every cohort completes one; those reaching
  `SemestersToGraduate` (8) leave. Returns how many graduated.
- `admit(size, grade)`: adds a cohort at 0.
- `graduatingByNextFall(month)`: the students whose cohorts reach 8 by the
  next fall start.

For display, a cohort is the **Class of Year N**, the academic year whose
spring it finishes. That's derived from `semestersCompleted` and the current
month in one place.

### `Policy`

- `Prices`: `tuition`, `room` and `mealPlan` in whole dollars per semester,
  and `total()`.
- `current`: this academic year's prices. `next`: what the player has set.
  `minimumGrade`: 0 means off.
- Commands clamp their input: prices ≥ 0, and the grade to 0–`MaxGrade`.
  They're callable at any time. The UI only offers them in the Admissions
  panel.
- `lockYear(hasOffice)` runs at the fall start. `current` becomes `next`, or
  `DefaultPrices` with no open Admissions Office.
- The minimum used at admission is `minimumGrade` if an office is open, else
  0: with no office, the default policy applies.
- Consts:
  - `DefaultPrices`: $9,606, $4,542, $4,136 (UMass 2026-27 in-state)
  - `PriceStep`: $100
  - `GradeStep`: 0.1

### `UniversityRules` (static, pure)

The tuning values below are starting points, not decisions.

**Applicants (fall).**
`A = Pool × 2^((R − ReputationReference) / RepDoubling) × 2^(−(P − ReferencePrice) / PriceHalving)`
- R is reputation. P is the total price.
- In words: every `RepDoubling` points of reputation doubles applicants, and
  every `PriceHalving` dollars above the market price halves them.
  `PriceHalving` is the price-elasticity knob.
- The formula stays finite at a price of $0.
- `Pool` is fixed, so each added seat dilutes selectivity.
- Pool 335; ReputationReference 50; RepDoubling 20; ReferencePrice $18,300;
  PriceHalving $6,000.
- Pool calibrated in phase 3 so the start campus (800 seats) settles at about
  2.5 applicants per open seat.

**Admission.** With S = open seats (seats minus enrolled, after graduation)
and m = the minimum in use:
- Cutoff: `c = GradeBase + GradeSpread × ln(A / S)`, clamped to 0–`MaxGrade`.
  This is Prototype.md's formula, read as the grade of the weakest admit.
- Admitted: `n = floor(min(A, S) × e^(−max(0, m − c) / GradeSpread))`
- Entry grade = `max(c, m)`.
- The class trails off above the cutoff with the same `GradeSpread`, so a
  minimum above the cutoff always trades students for grade and is never free.
- With S = 0 nobody is admitted, and `lastIntakeGrade` carries over.
- GradeBase 2.8; GradeSpread 0.35; MaxGrade 4.0.

**Housing and dining.** Worked out on the spot from `enrolled`, `beds()` and
`meals()`, never stored:
- `housed = min(enrolled, beds)`
- `offCampus = enrolled − housed`
- `mealPlans = min(housed, floor(DiningHardLimit × meals))`
- `unfed = housed − mealPlans`
- `diningLoad = housed / meals`

**Satisfaction** (0–100). `satisfaction(...)` returns a breakdown record:
base, housing, crowding, unfed and total. The dropdown shows the parts.
- Total: `SatisfactionBase − housing − crowding − unfed`, clamped to 0–100.
- Housing: `OverflowWeight × max(0, offCampus / enrolled − OverflowThreshold)`
- Crowding: `CrowdingWeight × clamp(diningLoad − 1, 0, DiningHardLimit − 1) × mealPlans / enrolled`
- Unfed: `UnfedWeight × unfed / enrolled`
- SatisfactionBase 75 (satisfaction only has penalties so far);
  OverflowThreshold 0.25; OverflowWeight 100; CrowdingWeight 50;
  DiningHardLimit 1.3; UnfedWeight 150.

**Reputation** (0–100, yearly at the fall start).
- `R += ReputationRate × (T − R)`
- `T = ReputationGradeWeight × lastIntakeGrade × GradeToScore + (1 − ReputationGradeWeight) × mean(satisfactionSamples)`
- `GradeToScore = 100 / MaxGrade`, derived. ReputationRate 0.3;
  ReputationGradeWeight 0.5.

**Stability.** Going once around grades → reputation → applicants has a gain
of `ReputationGradeWeight × GradeToScore × GradeSpread × ln 2 / RepDoubling`.
That's ≈ 0.15 with these values. The loop settles by itself while this stays
below 1, and a test guards it. Price and satisfaction decide *where* it
settles.

**Phase 3 tuning results.** With the values above, the loop settles at a fixed
point — entry grade 3.12, reputation 61.5, satisfaction 45 — and the start
state is set to it, so nothing drifts (Prototype.md's Later "baseline drift"
item is what addresses drift on top of a settled loop). Money never gets
tight doing nothing. The start campus opens with a housing shortfall (360
beds for 800 seats), and a pool sized to this campus can't fill much bigger
ones.

### `University`

- Holds `name`, `reputation`, `satisfactionSamples` (this academic year's),
  `lastIntakeGrade`, and `reports: Array[SemesterReport]`, every semester so
  far, for the popup and the applicants chart.
- Holds `campus`, `finances`, `students` and `policy`.
- Emits `SemesterStarted(report)`.

**`startMonth(m)`** is called by `GameState.step` when the month changes. In
order:
1. `campus.startMonth(m)` opens the buildings that are due.
2. **If a semester starts:**
   1. `students.completeSemester()`, and the count goes to the report.
   2. **Fall only:**
      - The reputation step, using `lastIntakeGrade` and the mean of the
        year's samples. Then the samples reset.
      - `policy.lockYear(campus.hasOpenAdmissionsOffice())`.
      - Applicants at the new reputation and `current.total()`.
      - Admission, a new cohort, and `lastIntakeGrade` updated.
   3. Satisfaction is computed and appended to the samples.
   4. `finances.receive(tuition × enrolled + room × housed + mealPlan × mealPlans)`
      at `current` prices.
   5. A `SemesterReport` is added and `SemesterStarted` is emitted.
3. **Every month:** `finances.charge(campus.upkeep() + finances.interest())`.
   It comes after the fees, so the fee lump pays that month's bill instead of
   setting off an automatic loan.

**Live queries for the HUD** (nothing stored):
- `satisfactionNow()`, the breakdown
- `reputationTarget()`
- `expectedApplicants()`: today's reputation at the prices that will apply
  next fall
- `seatsToFillNextFall()`: open seats plus `graduatingByNextFall`
- `expectedIntake()`
- `projectedFees()`: the next semester start's fees at today's enrollment and
  the prices that will apply then
- `cashAtSemesterStart()`: cash minus the monthly bill for each month start
  before the next semester start, floored at 0
- `monthlyExpenses()`: `upkeep + interest`

**`problems() -> Array[Problem]`** is the one list that alerts and markers
draw from, so every threshold lives in one place. Kinds:
- `HousingOverflow`: off campus past `OverflowThreshold`
- `DiningCrowded`: load over 1, within the hard limit
- `DiningUnfed`: unfed > 0
- `CreditMaxed`: debt ≥ `CreditLimit`

Each carries its numbers.

**`SemesterReport`** fields:
- `month`, `isFall`
- `applicants`, `openSeats`, `admitted`, `entryGrade`, `graduated`. These are
  0 in spring.
- `enrolled`, `housed`, `beds`, `offCampus`, `mealPlans`, `unfed`,
  `diningLoad`
- the fees by kind, and their total
- `reputation` and its change, `satisfaction` and its change
- `opened`: the names of the buildings that opened

**Rules throughout:**
- Money is whole dollars.
- Counts are rounded down; interest and fees to the nearest dollar.
- There's no randomness. The same save always plays out the same way.

### `GameCalendar`: weeks

- `WeeksPerMonth` 4. `GameState.week()` derives the week index from
  `tickCount`, using `TicksPerWeek`, which is derived next to `TicksPerMonth`.
- Periods: Fall (Sep–Jan), Spring (Feb–May), Summer (Jun–Aug).
- Functions: the period name, `semesterLabel(monthIndex)` ("Spring, Year 4"),
  the week within the period and the period's length, the next period and the
  weeks until it.
- The clock reads "Fall, Year 4 · Week 9 of 20 · Spring in 11 weeks".
- Construction reads "opens Spring, Year 4", replacing "Feb, Year 1". The
  month `label` stays for the console.

## Save / load

**Format.** JSON. Each state class has a pure `toDict()` and a
`static fromDict(data, …)`:

```
{ tickCount,
  university: { name, reputation, satisfactionSamples, lastIntakeGrade, reports,
    campus:   { month, buildings: [{ type, pos: [x, z], angle, underConstruction, opensAtMonth }] },
    finances: { cash, debt },
    students: { cohorts: [{ size, entryGrade, semestersCompleted }] },
    policy:   { current: { tuition, room, mealPlan }, next: { … }, minimumGrade } } }
```

- **Not saved:** speed, pause, the half-finished tick, the camera, and the
  armed tool or selection. A loaded game starts the way a new one does,
  running at 1×.
- **Buildings are saved by type id** and looked up in the `BuildingInfoDB`
  passed to `fromDict`. An id the Sheet no longer has is reported with
  `push_error` and that building is skipped.
- **Missing keys fail loudly.** An old save errors instead of quietly filling
  in defaults.
- **Floats are written at full precision**, so they come back bit-identical.
  Check the 4.7 `JSON.stringify` signature before relying on it. Numbers come
  back as floats, so they go through the typed `_toInt` helpers.
- **File I/O stays out of state.** `SaveFile` in `src/utils/` reads and writes
  a dictionary at a path.

**Loading.** `Global.loadGame(path)` builds a `GameState` from the file,
replaces `Global.gameState`, and calls `reload_current_scene()`.
`CampusView._ready` creates a view for every building that already exists.
Every other view connects to the new state as it starts up.

**Entry points**
- Launching the game is a new game: `Global._ready` loads
  `res://data/start_state.json`.
- F5 saves to and F9 loads from `user://quicksave.json`, through the input
  actions `QuickSave` and `QuickLoad`.
- The Game menu's Save, Load and New game call the same code.
- Console: `save [path]`, `load [path]` (both default to the quicksave) and
  `newgame`.

**The start state** is authored like this: build the campus in-game, run
`save res://data/start_state.json`, then hand-edit the parts that aren't built
(open buildings, tick 0, cohorts, prices, reputation, this year's fall
satisfaction sample, name, cash, debt). It grows with the phases, and phase 3 sets its numbers from a `simulate` run so
the game opens near its own balance point.

## HUD

The layout and look follow `2026-09-22-hud-mockup.html`.

**Theme.** The shared theme, `src/ui/ui_theme.tres`, takes the mockup's
palette and styles: dark chrome, gold accent, the good/warn/bad/info colours.
It carries theme type variations for the recurring text styles: slot value,
KPI, section heading, note, pill.

Fonts are Barlow, Barlow Semi Condensed and Cormorant Garamond (OFL), bundled
in `university/assets/fonts/` with their licences. Colours live in the theme,
not in code.

**Number formatting** lives in one place, extending `MoneyFormat`:
- short money: `$6.4M`, `$150K`
- signed money: `+$16.6M`, `−$1.9M`
- full prices: `$9,606`
- counts: `1,080`

Scenes live in `src/ui/`, laid out in `.tscn`. Code only fills in the
variable-count parts: cards, alerts, table rows, markers.

- **`Hud`** (root Control). Keeps one popover open at a time (dropdown, menu
  or build panel). The docked panel can stay open alongside one. It owns the
  key routing below.
- **`TopBar`**, which replaces `StatusBar`:
  - ☰ opens the **Game menu**.
  - The crest (shield initial, name, "University") opens the **University
    menu**, which has University (Admissions Office F2, Finances F3,
    Reputation) and Services (Housing, Dining). Choosing a building-backed
    entry selects that building and moves the camera to it. With no such
    building open, the entry is disabled.
  - Slots:
    - **Students** (enrolled / seats) opens the Students dropdown.
    - **Beds** (housed, "+N off campus", with a warning badge while there's a
      `HousingOverflow` problem) opens the Housing dropdown.
    - **Cash** (with "$X owed"), **Monthly expenses** and **Spring / Fall
      fees** (projected, "in N wk") open the Money dropdown.
    - **Reputation** (value and target) opens the Reputation dropdown.
  - The clock shows the period, the week line and a semester progress bar.
    Transport is pause, 1×, 3×, 8×, keeping today's rules.
  - The whole bar polls every frame, as `StatusBar` does now.
- **Students dropdown:**
  - KPIs: enrolled, open seats, admitted this fall, graduating before fall,
    this fall's entry grade.
  - A cohort table: Class of Year N, students, entry grade, semesters left.
  - Housing rows.
  - Next fall: seats to fill, expected applicants, expected intake, labelled
    "at today's reputation and next year's prices".
- **Housing dropdown:**
  - KPIs: beds filled, off campus and its %, the threshold, beds opening next
    semester.
  - The overflow note.
  - The dorm table: name, beds, upkeep, and status for dorms under
    construction.
  - A Dining block: diners against recommended and limit, and a load bar
    with marks at 100% and the hard limit.
- **Money dropdown:**
  - KPIs: cash, per month, cash at semester start.
  - The monthly lines, upkeep and interest, and their total, plus the
    automatic-borrow note.
  - Credit line: owed, the rate with interest per month, credit left, and
    **Borrow $5M** / **Repay $5M**.
  - Next semester's fees by kind at today's enrollment, their total, and cash
    after fees.
- **Reputation dropdown:**
  - KPIs: reputation, target, the value after the next fall's step.
  - The target as half the entry grade (and its score) and half this year's
    satisfaction.
  - The satisfaction breakdown: baseline, off campus, dining crowded, can't
    eat.
- **`SidePanel`** (docked right, 420 px), which replaces `InfoPanel`. It
  opens on selection and closes with it. The pane follows the building's
  function:
  - Admissions office:
    - next intake: seats to fill, expected applicants, expected intake
    - an applicants-per-fall chart from `reports`
    - levers: a stepper for the minimum entry grade, and one each for tuition,
      room and meal plan showing "this year $X" beside next year's value
    - all levers labelled "apply from Fall, Year N"
  - Seats: university seats and fill, entry grade, open seats, the
    graduation note, the list of academic buildings with "+ Add an academic
    building".
  - Beds: this dorm's beds filled (dorms fill evenly), university off campus,
    room fees and upkeep.
  - Meals: meal plans, load, can't eat, the load bar, meal fees and upkeep.
  - Under construction: an "opens Spring, Year N" pill; what opening changes
    (beds, seats or meals, off campus before and after, upkeep from then
    on); and the refund.
  - Every pane has Demolish, which arms nothing: it destroys the selected
    building, subject to today's refund rule.
- **`BuildPanel`**, which replaces the `BuildMenu` list:
  - Categories come from the Sheet's `category` column, in the order they
    first appear, with counts.
  - Cards show name, cost, capacity ("+400 seats"), upkeep and footprint. A
    card is greyed out while `canAfford` refuses it, and the armed type's card
    is highlighted.
  - The footer reads "cost · cash · borrow first, or wait for the next fees"
    and "placed now → under construction until <semester> starts".
  - Choosing a card arms it. Everything else about placing stays as today.
- **`ActionBar`:** **Build** (B) toggles the build panel. **Demolish** (X)
  arms today's destroy tool.
- **Alerts** (top right):
  - `problems()` entries show while their condition holds. × hides one until
    the condition clears and comes back.
  - Events show until dismissed, newest first, up to `MaxEventAlerts`:
    `AutoBorrowed` ("Monthly bill short by $X: borrowed automatically (+$Y
    fee)") and a building opening.
  - Each shows the week it appeared ("wk 1"), and clicking one opens its
    place.
- **Campus markers** are screen labels over 3D points, placed with
  `Camera3D.unproject_position`; check it before use.
  - `HousingOverflow` over the centroid of open dorms.
  - `DiningCrowded` / `DiningUnfed` over the centroid of open dining halls.
  - One over each building under construction ("Opens Spring, Year N · +120
    beds").
  - Clicking one opens its place.
- **Semester popup.** Shown on `SemesterStarted`. It pauses the clock, and
  Continue puts the previous pause state back.
  - Fall: New students (applicants, admitted of open seats, entry grade,
    graduated) and Campus (fees, beds, off campus, dining, reputation and
    satisfaction with their changes, opened).
  - Spring: one line saying there's no admission or graduation, plus Campus.
  - "Look at housing" opens the Housing dropdown.

**Keys:**
- B build panel, X demolish, Tab university menu, F2 Admissions panel, F3
  Money dropdown, F5 save, F9 load.
- Space and +/− keep their current jobs.
- Esc closes the open popover, then puts the tool away, then clears the
  selection, then opens the Game menu. The CLAUDE.md line "Esc with nothing
  armed and nothing selected quits" changes to match.
- Clicking empty ground closes the popover and clears the selection, as
  today.

**Left out** (the mockup, or ideas, had them):
- colleges and per-college anything
- Reach and overlays
- Move
- state funding
- faculty
- the Happiness dropdown
- demand in any form
- the keystroke cheatsheet
- renaming the university or buildings
- a founding year
- building name labels on the campus
- walking students
- the January/May applicant pipeline
- graphs
- a per-college profit and loss
- Settings

## Console

New commands, listed in CLAUDE.md as they land:
- `save [path]`, `load [path]`, `newgame`
- `borrow <amount>`, `repay <amount>`, `debt [amount]` (`money` stays for
  cash)
- `prices [tuition room meal]` prints or sets next year's prices;
  `minimum [grade]`
- `students` prints cohorts, enrolled, housed, off campus, meal plans and
  dining load
- `reputation [value]`, `report` (the last semester report)
- `simulate <years>` copies the live state through `toDict`/`fromDict`, plays
  the copy forward with no player input, and prints one row per semester:
  date, applicants, admitted, entry grade, enrolled, housed and off campus,
  dining load, satisfaction, reputation, fees, cash, debt. The live game is
  untouched.
- `hud <name>` opens any popover, pane or the popup by name, for screenshots
  with the window hidden.
- `state` adds debt, reputation, enrolled and the week line.

## Testing

Behaviour and relationships, never content values (CLAUDE.md).

- **`UniversityRules`:**
  - Applicants rise with reputation and fall with price.
  - Applicants equal to seats gives a cutoff at `GradeBase`.
  - A minimum above the cutoff admits fewer and sets the grade to the
    minimum; one below it changes nothing.
  - Satisfaction is untouched until overflow passes the threshold.
  - Dining costs nothing up to recommended, crowding grows up to the hard
    limit and then stops, and unfed starts past it.
  - Reputation covers `ReputationRate` of the gap.
  - The loop gain stays below 1.
- **`Finances`:**
  - A bill within cash is paid.
  - A shortfall borrows it plus the fee, even past the limit.
  - Borrowing is capped by the limit; repaying by debt and cash.
  - Cash never goes negative.
- **`StudentBody` / `Policy`:**
  - Graduation happens at 8 semesters.
  - Prices lock only at fall.
  - With no office, the defaults apply and the minimum is off.
- **`University`:**
  - Admission happens only in fall.
  - Fees arrive at every semester start, before that month's bill.
  - A building opening at a semester start counts toward that semester's
    capacity.
  - Overflow pays tuition only.
  - The report matches what happened.
- **Save:**
  - A round trip is identical.
  - **Determinism:** save, load and advance N months ends where advancing N
    months without saving does.
  - The shipped start state loads, and every building in it is where
    `canPlace` allows.
- **`GameCalendar`:** period boundaries, week counts, labels.
- **UI:** launch and screenshots with `hud <name>`, as CLAUDE.md requires.

## Phases

Each phase gets its own plan, ends playable, and is committed with its
CLAUDE.md updates.

1. **Save/load and the start state.**
   - `toDict`/`fromDict` for today's state, `SaveFile`, `Global.loadGame`
     with the scene reload, and `CampusView` building views for existing
     buildings.
   - F5/F9, `save`/`load`/`newgame`.
   - `University` arrives here holding `name` and `campus`, and
     `gameState.campus` becomes `gameState.university.campus`. Later phases
     add the rest of it.
   - `res://data/start_state.json` with today's building types, loaded on
     launch.
2. **Money.**
   - `Finances`, moving money off `Campus`.
   - The `upkeepK` column (Sheet edit, then export).
   - The monthly charge, the credit line, automatic borrowing with the fee.
   - Console commands. The start state gains debt.
   - Today's status bar keeps showing cash until phase 4.
3. **Students and the loop.**
   - The `seats`, `beds`, `meals` and `admissionsOffice` columns.
   - `StudentBody`, `Policy`, `UniversityRules`, `University` and its month
     sequence, reports, `problems()`.
   - `simulate` and the console commands.
   - The start state gains cohorts, prices and reputation.
   - A tuning pass with `simulate`, including the design doc's check that a
     campus left alone drifts into a visible problem within a few semesters.
4. **HUD part 1.**
   - Theme and fonts.
   - `TopBar` with the weeks clock (`GameCalendar` weeks land here).
   - The Game and University menus.
   - The four dropdowns, with loans in Money.
   - The semester popup.
   - `hud <name>` for the popovers and the popup.
   - Removes `StatusBar`. The Esc change.
5. **HUD part 2.**
   - `SidePanel` and its panes, replacing `InfoPanel`.
   - `BuildPanel` and `ActionBar`, replacing `BuildMenu`.
   - Alerts and campus markers.
   - The remaining keys (B, X, Tab, F2, F3).
   - `hud <name>` extended to the panes.

## UI revision (2026-09-23)

After playing the finished HUD, the user revised it. These decisions override the sections above, and the mockup, wherever they differ.

- **Campus markers are gone.** Alerts and the side panel carry everything the markers showed.
- **Icons are PNGs the user supplies.** They sit in `university/assets/icons/`, one per icon, same names as before, 64×64, a white glyph on transparent (the game tints them). Never SVG.
- **Text is larger, and there's less of it. There are five label styles:**
  - **Title**: serif, for the crest name and the overlay, pane and popup titles.
  - **Heading**: condensed semibold, for section headings, table headers and the clock period.
  - **Value**: condensed semibold and big, for numbers.
  - **Body**: Barlow Regular, for rows, menus, alerts and cards.
  - **Caption**: smaller and muted, for the labels under numbers, subtitles and notes.

  Value, Body and Caption also come in good, warn, bad and dim. Those are colour only, with the same size and font. Pills are Caption text on a coloured background. Buttons use the fonts and sizes of the same five.
- **No keyboard-shortcut hints anywhere in the UI.** A controls menu will list them later.
- **Explanations sit behind a (?) icon.** Text that explains how something works moves into a hover tooltip on a (?) beside the thing it explains. Text that states a number or a fact stays.
- **Students, Housing, Money and Reputation are screen-sized overlays.** They open under the top bar, which stays visible, and are closed by their slot, ×, or Esc. The game keeps running behind them. The side panel, build panel and menus stay as they are.
- **The accent is blue.** Gold becomes blue everywhere, and the info colour merges into it. Amber stays the warning colour.
- **The semester popup loses "Look at housing".** Continue and Esc are its only ways out.
- **The clock reads "Week N of M".** The Fees slot already counts down to the next semester.

## UI feedback 2 (2026-09-24)

After more use, the user gave a second round of feedback. These decisions override the sections above wherever they differ.

- **Overlays.** Students, Housing, Money and Reputation become dimmed, click-away panels at 80% of the play area, and they block the world's keys.
- **Money slots.** All three light up together.
- **Notifications.** A top-left bell with a count badge and a small panel replaces the top-right alerts.
- **Building panel.** It is anchored at the bottom, taking 3/4 of the screen.
- **Links.** The building panels lose their links to top-level screens, and a few other links and inline texts go.
- **Semester popup.** It closes on any click and has no (?).

Four decisions this round settles:
- Notifications show current problems only, not a history.
- Clicking a notification opens its place, as an alert used to.
- While an overlay is open, only Esc, Space and +/− still work.
- The building panel takes 3/4 of the screen.
