# Time, money and construction

Date: 2026-09-21. Status: approved in chat. Builds on
`2026-09-20-campus-builder-design.md`; the state/view separation in `CLAUDE.md`
still governs.

## Goal

Game time that passes at three speeds and can be paused; a calendar of months
and academic years; money that building spends; and buildings that stand under
construction until the next semester begins.

## Decisions taken

- **Speeds:** 1x / 3x / 8x, Airport's `SpeedSteps`. Pause is its own control,
  not a speed. Buttons `II` `>` `>>` `>>>`, exactly one shown pressed. `Space`
  toggles pause; `+` / `-` (and keypad) step the speed.
- **Calendar:** one month is 45 s at 1x. All twelve months are simulated. The
  game starts in September of Year 1. Years are academic: Year 2 begins the
  next September. Shown as `Sep, Year 1`.
- **Semesters** start in September (Fall) and February (Spring).
- **Money:** start with $50,000,000. The sheet's `costM` column is in $M and
  may be fractional. (First built with $10,000,000 and a `cost` column in $K;
  changed 2026-09-21.)
  Placing a building deducts its cost; money never goes negative — a building
  that cannot be paid for is refused.
- **Construction:** a placed building is under construction until the beginning
  of the *next* semester (strictly after the month it was placed in), then
  opens. Under construction it still occupies its ground and can be selected.
- **Destroy:** full refund while under construction; nothing back, and no
  charge, once open.
- Building and destroying work while paused.

## State

### `GameCalendar` (new, `src/state/`)

Static, pure. The one place a month index becomes dates and semesters.
`SecondsPerMonth` 45, `MonthsPerYear` 12, `StartMonth` September,
`SemesterStartMonths` September and February, `FirstYear` 1. A *month index*
counts months since the game began (0 = September, Year 1). `calendarMonth(index)`,
`year(index)`, `monthName(index)`, `label(index)`, `isSemesterStart(index)`,
`nextSemesterStart(index)` (strictly after). Turning sim time into a month
index is not here: `GameState.month()` derives it from the integer tick count,
which has no boundary risk a float `time / 45` would carry.

### `GameState`

`paused`, `SpeedSteps`, `speedIndex`, `speedMultiplier()`; `changeSpeed(delta)`
and `setSpeedIndex(index)`, which leave pause alone; `setPaused(value)`,
the one writer of `paused`, `togglePause()` on top of it, and `runAt(index)`,
which unpauses and sets the speed: what a transport speed button means.
`tickCount`; `gameTime()` is
`tickCount * TickStepDuration`, never accumulated. `step()` runs one tick and,
when the month index changes, tells the campus (`Campus.startMonth`).
`update(dt)` runs no ticks while paused and `speedMultiplier()` times as many
otherwise, with the frame's dt capped (`MaxFrameDt`). `advanceMonths(n)` steps
to the start of the nth month ahead, for the console and tests.

### `Campus`

`money` (whole dollars, `StartingMoney`), written only through `setMoney`,
which emits `MoneyChanged(money)`. `month` (index), advanced by
`startMonth(newMonth)`, which opens every building whose `opensAtMonth` has
come and emits `BuildingOpened(building)` for each. `canAfford(info)`;
`canBuild(info, pos, angle)` is `canPlace` and `canAfford`; `place` requires
`canBuild`, deducts the cost and stamps `opensAtMonth`. `destroy` refunds the
cost of a building still under construction.

### `Building`, `BuildingInfo`

`Building.underConstruction` (true until opened) and `opensAtMonth`.
`BuildingInfo.cost` is whole dollars: the sheet's `costM` times `DollarsPerM`,
rounded, in that one place. `buildTime` stays unread — semesters replace it.

## Views

- **`StatusBar`** — transport buttons, the date, the money. Scene-authored;
  buttons take no keyboard focus; pressed states are polled each frame because
  speed and pause also change from keys and the console.
- **`MoneyFormat`** (`src/ui/`) — `short(dollars)`: `$10.0M`, `$950K`, `$0`.
- **Shared theme** — the pressed-button style moves from `build_menu.tscn` to
  `src/ui/ui_theme.tres`, used by the build menu and the status bar.
- **`CampusView`** — `TogglePause`, `SpeedUp`, `SpeedDown` actions; on
  `BuildingOpened` it makes the view solid and refreshes the info panel if that
  building is selected.
- **`BuildingView`** — under construction is translucent and casts no shadow;
  highlights keep working on top.
- **`BuildMenu`** — entries show the price and are disabled when unaffordable.
- **`BuildController`** — the ghost is valid when `Campus.canBuild`.
- **`InfoPanel`** — name and a status line: `Under construction — opens Feb,
  Year 1`, or `Open`.

## Console

`pause`, `speed <1-3>`, `money [amount]`, `advance <months>`; `buildings` adds
each building's status; `state` adds paused, speed, date and money.

## Tests

`GameCalendarTest`, `GameStateTest`, `MoneyFormatTest`; additions to
`CampusTest` (money, refusal, refund, opening), `BuildingInfoTest` (cost in
dollars) and `BuildingViewTest` (construction look).

## Out of scope

Reduced activity in January and July/August, income, running costs, loans, a
PAUSED badge, demolition cost.
