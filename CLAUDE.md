# University

Godot 4.7 (GDScript). The Godot project is `university/`; the repo root is
`/Users/noel/Development/University/game`. This is the starting prototype: what
is in `university/src/` today is the 2D starter template (a `Node2D` level with a
player and wandering enemies in a 1920x1080 world), kept as a scaffold for the
autoload, remote console, status bar and test runner. The game itself is a
university management sim — campus view, no grid, buildings placed at any
orientation, every student simulated. The prototype scope is listed in
`Prototype.md` below.

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

5. **Dictionary.get() returns Variant.** Never pass it to `int()`, `bool()`, or typed function params. Use helper functions:
   ```gdscript
   static func _to_int(value: Variant) -> int:
       return value
   static func _to_bool(value: Variant) -> bool:
       return value
   ```
   `str()` works directly. For reference types use `as Dictionary`, `as Array`.

6. **Never guess Godot APIs.** Do NOT assume a property or method exists on a Godot class. If you haven't seen it used in this codebase, search the project for existing usage first. Godot 4.x APIs change between minor versions — a property that exists in docs or training data may not exist in Godot 4.7. When in doubt, grep the codebase or check the engine source. Getting this wrong causes `Parse Error` (treated as fatal) and wastes the user's time.

## Architecture

Strict state/view separation:
- **State** (`university/src/state/`): pure logic classes (`GameState`, `Level`, and what the sim grows) — no engine/node dependencies, plain `class_name` classes, not Nodes. This is what makes the sim deterministic and testable without the engine. A state class may read an autoload-owned data DB (the Info/DB pattern below) while building itself; nothing else.
- **Views** (`university/src/views/`, `university/src/ui/`): Godot nodes that read from state and draw it. A view owns no simulation truth — position, timers and counts live in state and the view copies them each frame.
- State must NEVER know about views. Communication from state toward views must use signals only (`Level.EnemyAdded` is the shape to follow).
- **Orders, not input.** State never reads input. Views translate clicks and keys into orders on a state object, applied on the next step. This is what keeps the sim deterministic and a future timeline/replay a replay of orders. (`PlayerView` writing `player.vel` directly is starter-template code, not the pattern to copy as the sim grows.)
- Time: the view calls `GameState.update(dt)` once per frame with real dt. `GameState` runs a FIXED-STEP accumulator over `Level.tick` (`GameState.TickStepDuration`, 0.01 s); anything the sim reads must be advanced there. `Level.update(dt)` is the per-frame, non-deterministic-safe part and may not touch anything `tick` reads.
- **Data.** Content tables follow the Info/DB pattern: an `Info` class with a typed constructor, a `DB` class holding them keyed by id, loaded from CSV via `CsvLoader` (`university/src/utils/csv_loader.gd`) and owned by the `Global` autoload. Declare a table directly in code only until its sheet exists.
- `Global` (autoload, `university/src/utils/global.gd`) owns the single `GameState` and spins up the remote console. Views fetch state through `Global.gameState`. Build anything that reads another autoload in `_ready`, not as a field initialiser — the autoload name is unbound while its own members initialise.
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

There is **no spreadsheet pipeline wired up yet**. `bin/GetDataFromGoogleSheets.py`
is a leftover copied from an earlier project — its sheet key and output paths
point at another game — and `university/src/utils/csv_loader.gd` is the CSV
reader that pairs with it. When the pipeline is set up (the prototype scope
calls for it), the rule from the previous projects applies: **the Sheet is the
absolute source of truth**, exported CSVs are generated artefacts and are never
hand-edited.

## LimboConsole

LimboConsole is available as an autoload (toggle with the backtick key in-game). When debug commands are added, register them in `university/src/debug/debug_commands.gd` and list them here.

Registered debug commands:
- `screenshot` — save a screenshot to /tmp/university/screenshot.png.

Command-line flags (`university/src/utils/command_line.gd`, passed after `--`): `--nomusic`, `--nosound` mute the `Music` / `SFX` audio buses if they exist.

### Console automation limits

`eval` runs against the SceneTree via `Expression`, which does NOT resolve
global class names or autoload names — `Global.foo` fails with "Invalid named
index". Reach everything through `get_root()`:
`get_root().get_node("Global")`, `get_root().find_child("LevelView", true, false)`.
Statics are callable on the instance, which is how you reach them. No lambdas either.

Keyboard cannot be injected, and `warp_mouse` does nothing while the window is
hidden — so anything that follows the OS cursor usually draws off-screen and
cannot be screenshotted. Add console commands that drive state directly
(selection, orders, camera) rather than trying to fake input, and verify those
by asserting state over `eval`, not by looking. Synthetic mouse events pushed
through the root viewport's GUI routing are the one exception worth building
when UI hit-testing has to be tested.

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
