# Campus builder — first pass

Date: 2026-09-20. Status: approved in chat.

## Goal

Replace the 2D starter template with the first 3D slice of the university
builder: a grass plane with a scale grid, an Anno-style camera, building
definitions loaded from the Google Sheet, a build menu, free placement at any
rotation, selection with an info panel, and destroy. Building is instant and
free. The state/view separation in `CLAUDE.md` is the governing constraint.

## Decisions taken

- **Rotate while placing:** `,` and `.` held, smooth (Anno / Two Point Campus).
  The wheel stays zoom.
- **Overlap:** state rejects a placement that intersects an existing building
  or leaves the campus bounds. The ghost is red while invalid.
- **Footprint:** long side = `diameter` from the sheet, short side =
  `diameter * Building.DepthRatio`, height `Building.Height`. Constants until
  real models arrive.
- **Camera mouse:** right-drag pans, middle-drag rotates, wheel zooms. A right
  *click* (travel under the drag threshold) cancels the current tool.
- **Commands, not an order queue.** The controller calls command methods on
  state (`Campus.place`, `Campus.destroy`); state validates, mutates and emits
  a signal. State never reads input and never knows a view exists. Heist's
  tick-stamped order queue existed for timeline replay, which this game has no
  use for. `CLAUDE.md`'s "Orders, not input" bullet is reworded to say so; the
  command methods are the one seam where a command log could be added later.
- **`Campus` replaces the template's `Level`.**

## Units and conventions

1 world unit = 1 metre, Y up. State positions are `Vector2` with `x` = world X
and `y` = world Z. A rect's `angle` (radians) is the direction of its own long
axis in that plane, `(cos a, sin a)`. A node's y rotation turns the other way,
so the view converts in exactly one place, `BuildingView.showRect`:
`rotation.y = -angle`. Degrees appear only in UI-facing constants and console
commands, converted in one place each.

## State (`university/src/data/`, `university/src/state/`)

Plain `class_name` classes, no nodes.

### `BuildingInfo`, `BuildingInfoDB` (`src/data/`)

Mirror Airport's `ObjectInfo` / `ObjectInfoDB`.

- `BuildingInfo._init(data: Dictionary)` reads `id`, `name`, `category`,
  `cost` (int), `buildTime` (float, seconds), `diameter` (float, metres).
  Values arrive as `Variant` from `CsvLoader`; blank or non-numeric cells
  coerce to 0 through `_toInt` / `_toFloat` helpers. Columns with an empty
  header (the sheet has trailing blanks) are ignored by never being read.
- `BuildingInfoDB`: `db: Dictionary[String, BuildingInfo]`,
  `all: Array[BuildingInfo]` in sheet order, `info(id)`,
  `static loadFrom(path)`.
- `Global.buildingDB` is loaded in `Global._ready` from
  `res://data/buildings.txt`, before `Global.gameState` is built.

### `OrientedRect` (`src/state/`)

The one place rectangle maths lives. Fields: `center: Vector2`,
`size: Vector2` (x along the rect's own long axis), `angle: float`.

- `corners() -> PackedVector2Array`
- `contains(point: Vector2) -> bool`
- `overlaps(other: OrientedRect) -> bool` — separating-axis test over both
  rects' two axes. Rects that only touch along an edge do not overlap
  (`OrientedRect.Epsilon`).
- `within(bounds: Rect2) -> bool` — every corner inside.
- `rayHit(origin: Vector3, dir: Vector3, height: float) -> float` — distance
  along the ray to the box standing on y = 0 with this footprint, or
  `OrientedRect.NoHit` (-1). Done by rotating the ray into the rect's frame
  and running a slab test.

### `Building`

`info: BuildingInfo`, `pos: Vector2`, `angle: float`. `rect() -> OrientedRect`
and `static rectFor(info, pos, angle)` so the ghost and `canPlace` use the same
derivation as a placed building. Constants `DepthRatio` (0.6) and `Height`
(10 m). Height is state, not view, because picking needs it.

### `Campus`

- `const Size: float = 1000.0`; `bounds() -> Rect2` centred on the origin.
- `buildings: Array[Building]`
- `canPlace(info, pos, angle) -> bool` — within bounds and overlapping nothing.
- `place(info, pos, angle) -> Building` — `null` when `canPlace` is false;
  otherwise appends and emits `BuildingAdded(building)`.
- `destroy(building)` — removes and emits `BuildingRemoved(building)`; a
  building not on the campus is ignored.
- `pick(origin: Vector3, dir: Vector3) -> Building` — nearest `rayHit`, or
  `null`. A ray against the box rather than the ground point in the footprint:
  at a pitched camera a click on a 10 m roof lands metres behind the footprint.
- `tick(dt)`, `update(dt)` exist and are empty for now.

### `GameState`

Keeps the fixed-step accumulator; `level` becomes `campus: Campus`.

## Views (`university/src/views/`, `university/src/ui/`)

### `CampusView` (`campus_view.tscn`, main scene)

`Node3D` root: `Sun` (`DirectionalLight3D`), `WorldEnvironment`, `%Ground`,
`%Camera`, `%Buildings` (parent of the `BuildingView`s), `%BuildController`,
and a `CanvasLayer` with `%StatusBar`, `%BuildMenu`, `%InfoPanel`. Lighting and
layout are authored in the scene. The script calls `gameState.update(dt)`,
creates/frees `BuildingView`s on the campus signals, and wires the UI signals
to the controller.

### `GroundView`

One `PlaneMesh` of `Campus.Size`, with `ground.gdshader`: a grass colour plus
thin lines every `grid_spacing` (10 m) computed from world position and
anti-aliased with `fwidth`, fading with distance so they never shimmer.
Colours and spacing are shader parameters set in the scene. Visual only.

### `GameCamera`

Ported from Heist3D's `game_camera.gd`: orbits a ground target at constant
pitch and FOV; zoom is distance; `setTarget(point)`, `setYaw`, `setZoom` are
the way the target, yaw and distance are moved, and `_applyTransform` is the
single place the transform is written and emits `ViewMoved`;
`groundPoint(screen)` returns a plain value, and callers that need a ray build
it from `project_ray_origin` / `project_ray_normal`. Changes from Heist: the Alt-to-turn capture
becomes middle-drag (`TurnDegreesPerPixel`), right-drag pans (past
`DragThreshold`), the focus glide and `resetView(geometry)` are dropped, the
target is clamped to `Campus.bounds()`, and the distance range is rescaled for
20–40 m buildings. Keys: WASD/arrows pan (speed scales with distance), Q/E
turn, wheel and trackpad scroll zoom.

### `BuildingView`

`MeshInstance3D` with a `BoxMesh` sized from `building.rect().size` and
`Building.Height`, transform copied from state once (buildings do not move).
`setHighlight(kind)` — `None`, `Selected`, `Destroy` — swaps the material
colour. Also used for the ghost through a `static createGhost()` that builds
the same box with a translucent material and `setValid(bool)`.

### `BuildController`

The only place input becomes commands. `enum Tool { None, Place, Destroy }`.

- `armPlace(info)`, `armDestroy()`, `cancel()`; signals `ToolChanged`,
  `SelectionChanged(building)`, `HoverChanged(building)`. The controller only
  announces which building is selected and which one the Destroy tool is over;
  `CampusView` listens to both and moves the `BuildingView` highlights, so the
  controller never touches a view.
- **Place:** the ghost follows `camera.groundPoint(mouse)`; `,` / `.` held turn
  `_angle` at `RotateSpeed` (90 °/s); validity from `campus.canPlace` every
  frame; LMB calls `campus.place` and stays armed with the same angle.
- **None:** LMB calls `campus.pick(ray)`; the result (or `null`) becomes the
  selection.
- **Destroy:** the building under the cursor is highlighted; LMB destroys it.
- RMB released with travel under `GameCamera.DragThreshold`, or Esc, cancels
  the tool; Esc with no tool armed and nothing selected quits, as before.
- A destroyed building that was selected clears the selection.
- All of it in `_unhandled_input`, so a click on a `Control` never reaches it.

### UI (scene-authored)

- `StatusBar` — the existing `status_bar` reworked: placeholder `Time` and
  `Money` labels. Static text for now.
- `BuildMenu` — bottom-left `Build` toggle button; open, it shows a panel with
  one button per `Global.buildingDB.all` (created in code, since the count is
  data) and a `Destroy` button. Signals `BuildingChosen(info)`,
  `DestroyChosen`, and `Closed` when the list is shut, which cancels the tool.
  The armed entry shows pressed; it follows `ToolChanged`.
- `InfoPanel` — bottom-right; shows the selected building's name, hidden when
  nothing is selected.

## Data pipeline

`bin/GetDataFromGoogleSheets.py` is rewritten after Airport's: `KEY`
`1SrPqAyHSve_LWaLmMrgl6orvEwqlx_luDhub1MSIFio`, `EXPORTS = [(948960558,
'../university/data/buildings.txt')]`, the `/export?format=csv&gid=` endpoint,
abort if the response is an HTML login page, CRLF normalised to LF. `.txt`
because Godot imports `*.csv` as a Translation. The sheet is the source of
truth; `buildings.txt` is committed and never hand-edited. `CLAUDE.md`'s Data
section is updated to describe the live pipeline.

## Debug console commands

Registered in `debug_commands.gd` and listed in `CLAUDE.md`:
`build <id> <x> <z> <deg>`, `destroy <n>`, `select <n>`, `buildings`,
`tool <id|destroy|none>`, `camera <x> <z> <distance> <yawDeg>`, and Heist's
synthetic `mousedown` / `mouseup` / `mousemove <x> <y>` in design space.

## Tests (gdUnit4, `university/tests/`)

- `OrientedRectTest` — overlap of axis-aligned and rotated rects, rects
  touching on an edge do not overlap, a rotated rect that overlaps only by its
  corner, `contains` on a rotated rect, `within`, `rayHit` on the roof, a side
  and a miss, and the nearer of two distances.
- `CampusTest` — place succeeds on empty ground, is refused on overlap and out
  of bounds, `BuildingAdded` / `BuildingRemoved` fire, destroy frees the ground
  for a new placement, `pick` returns the nearer of two buildings along a ray
  and `null` on a miss.
- `BuildingInfoTest` — blank numeric cells coerce to 0, lookup by id, `all`
  keeps record order. Fixture records, never the real data file's values.
- `SimpleTest.gd` is deleted.

## Removed

`Player`, `Enemy`, `PlayerView`, `EnemyView`, `LevelView`, `Level` and their
scenes. `res/Player.png` and `res/Enemy.png` stay until the user says
otherwise. The `MoveLeft/Right/Up/Down` input actions are reused for camera
pan; new actions are added for camera turn and building rotation.

## Out of scope

Money, build delay, save/load, students, paths, real models, edge scrolling,
snapping, multi-select.
