# UI Feedback 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the user's second round of HUD feedback:
- **Overlays:** they become dimmed, click-away panels at 80% of the play area, and they block the world's keys.
- **Money slots:** all three light up together.
- **Notifications:** a top-left bell with a count badge and a small panel replaces the top-right alerts.
- **Building panel:** it is anchored at the bottom, taking 3/4 of the screen.
- **Links:** the building panels lose their links to top-level screens, and a few other links and inline texts go.
- **Semester popup:** it closes on any click and has no (?).

**Architecture:** This is view and theme work, plus two small key gates:
- `GameCamera.keysEnabled` and `BuildController.keysEnabled` stop the per-frame polled keys.
- `Hud` flips both gates whenever an overlay opens or closes.

The alert machinery (`Alerts`, `AlertRow`, `AlertFeed`, `AlertEntry` and their tests) is deleted. A `Notifications` view lists `University.problems()` directly.

**Tech Stack:** Godot 4.7, fully typed GDScript, gdUnit4, LimboConsole plus a TCP remote console.

**Spec:** this plan carries the user's decisions of 2026-09-24. Add them in Task 1 as a short "UI feedback 2 (2026-09-24)" section at the end of `docs/superpowers/specs/2026-09-22-students-money-hud-design.md`, listing the bullets in the Goal and the four decisions:
- notifications show current problems only
- clicking a notification opens its place
- only Esc, Space and +/− work while an overlay is open
- the building panel takes 3/4 of the screen

## Global Constraints

- **Paths.** The repo root is `/Users/noel/Development/University/game`. The Godot project is `university/`, so `res://` is `university/`.
- **`CLAUDE.md` governs.**
  - camelCase for variables and functions; PascalCase for classes, constants and signals. Conditions are parenthesized: `if (x):`.
  - Fully typed GDScript, with warnings treated as errors. That covers shadowing (including `shadowed_global_identifier`), integer division, unsafe access and `int_as_enum_without_match`.
  - gdUnit silently drops a suite that fails to parse, so compare the case count against this plan's table.
  - No magic numbers: every displayed string and number is a named const.
  - Surgical changes, and remove any orphans a change creates.
- **The user's UI rules** (from memory `ui-preferences`):
  - Icons are user-supplied PNGs, never SVG.
  - Large text, and little of it.
  - Only the five label styles (`Title`, `Heading`, `Value*`, `Body*`, `Caption*`), plus `Pill*`.
  - No shortcut hints.
  - Explanations go behind (?) tooltips.
  - The accent is blue. Amber means warnings only.
- **Theme and colour.** Colours come only from `ui_theme.tres`. `load_steps` must equal ext_resources + sub_resources + 1 in every touched `.tscn` and `.tres`.
- **Scenes.**
  - Layout lives in `.tscn`. Scene nodes are reached through `%UniqueName`.
  - Buttons use `focus_mode = 0`.
  - Button icons are capped through the theme's `icon_max_width`.
- **Layout facts.**
  - The top bar is 72 px high.
  - The screen is 1920×1080 in design pixels.
  - The play area is everything under the top bar.
- **Tests** assert behaviour, never content values. Views are verified by LAUNCH-CHECK screenshots.
- **Commits** go on `main`, local only, never pushed. Commit each `.uid` and `.import` file with its source. Every message ends with:

  ```
  Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
  ```

### Named procedures

**REGISTER**, after adding or removing a `class_name` script or a `.tscn`:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --editor --quit-after 20 2>&1 | grep -E "ERROR|WARNING|Parse Error" ; true
```

**IMPORT**, after adding PNGs:
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --import 2>&1 | grep -E "ERROR|WARNING" ; true
```

**RUN-TESTS:**
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Overall Summary|Executed test|FAILED|Parse Error|SCRIPT ERROR|leaked"
```

Expected totals:

| After task | Cases | Suites |
|---|---|---|
| start | 229 | 23 |
| 1 | 229 | 23 |
| 2 | 225 | 22 |
| 3 | 225 | 22 |

**LAUNCH-CHECK:**
```
cd /Users/noel/Development/University/game
mkdir -p /tmp/university
(for i in $(seq 1 20); do sleep 0.2; osascript -e 'tell application "System Events" to set visible of process "Godot" to false' 2>/dev/null; done) &
./bin/run.sh > /tmp/university/run.log 2>&1 &
sleep 8
grep -nE "SCRIPT ERROR|Parse Error|ERROR|WARNING" /tmp/university/run.log
# console: echo "<command>" | nc -w 10 localhost 9999    (sleep 0.3 before a screenshot)
echo screenshot | nc -w 10 localhost 9999
pkill -f "Godot"
```
- The grep must print nothing.
- LOOK at `/tmp/university/screenshot.png` (3840×2160) with the Read tool. Halve or crop it with PIL first, and say what you saw.
- Run `pause` first whenever you read numbers.

Console reference:
- `hud <name>`: `gamemenu`, `unimenu`, `students`, `housing`, `money`, `reputation`, `build`, `popup`, `admissions`, `academic`, `dorm`, `dining`, `construction`, `none`. Task 2 adds `notifications`.
- `mousedown` / `mouseup` / `mousemove <x> <y>` take design coordinates (1920×1080).
- `action <name> <down|up>`, `state`, `advance <months>`.
- `eval …get_global_rect()` prints nothing, so read `.global_position` and `.size` instead.
- `find_child` finds the first match, so go through the parent.

---

### Task 1: Overlays: 80%, dimmed, click-away, key-blocking; the Money slots light together

**Files:**
- Modify:
  - `university/src/ui/students_dropdown.tscn` and `.gd`
  - `university/src/ui/housing_dropdown.tscn` and `.gd`
  - `university/src/ui/money_dropdown.tscn` and `.gd`
  - `university/src/ui/reputation_dropdown.tscn` and `.gd`
  - `university/src/ui/hud.gd`
  - `university/src/ui/top_bar.gd`
  - `university/src/views/game_camera.gd`
  - `university/src/views/build_controller.gd`
  - `university/src/ui/ui_theme.tres`
  - `docs/superpowers/specs/2026-09-22-students-money-hud-design.md`
  - `CLAUDE.md`

**Interfaces:**
- **Produces:**
  - `GameCamera.keysEnabled: bool` (default true). While it is false, `_process` polls no pan, turn or zoom keys.
  - `BuildController.keysEnabled: bool` (default true). While it is false, the ghost's rotate keys do nothing.
  - Each overlay keeps `signal CloseRequested`. It now fires on a click outside the panel, and there is no × button.

- [ ] **Step 1: Restructure each overlay into a dim plus a centred panel**

  The four roots change from an `Overlay` PanelContainer to a plain `Control`:
  - Full rect, with `offset_top = 72` (the play area).
  - `visible = false`.
  - Default `mouse_filter` (STOP), so nothing reaches the world.
  - The root keeps the script and its class name.

  Its children, in order:
  1. `Dim`: a Panel with the `PopupDim` theme variation, which already exists (black at 0.45). Full rect, `mouse_filter = 0` (STOP).
  2. `Frame`: a PanelContainer with the `Overlay` variation. It covers 80% of the play area, centred: `anchor_left = 0.1`, `anchor_top = 0.1`, `anchor_right = 0.9`, `anchor_bottom = 0.9`, with offsets 0.

  `Frame` holds the existing `Scroll`, `Center` and `Content` tree, with its header row, KPIs, columns and foot. Delete the header's `CloseButton` and remove its connection. Keep every `%Unique` name and every `HelpIcon`.

  `Content` is currently a 1440 px wide VBox. The frame is now 1536 px wide less the `Overlay` margins, so drop `Content`'s `custom_minimum_size.x` to 1360. Keep it centred.

  Keep the fixes to `load_steps`.
- [ ] **Step 2: Click-away closes the overlay**

  In each overlay script's `_ready`, connect `%Dim`'s `gui_input` (mark `Dim` unique). On a left press, emit `CloseRequested` and accept the event.

  Clicks inside `Frame` stop at the PanelContainer and never reach the dim. `Hud` already connects `CloseRequested` to `closePopover`, so keep that.

  Delete any const or var the removed × leaves orphaned.
- [ ] **Step 3: The key gates**

  In `game_camera.gd`:
  - Add `var keysEnabled: bool = true`, with a `##` comment saying the Hud turns it off while an overlay covers the view.
  - `_process` returns before polling when it is false.

  In `build_controller.gd`:
  - Add the same `var keysEnabled: bool = true`.
  - The rotate `Input.get_axis` in `_process` applies only while it is true. Keep the ghost update.

  The mouse wheel needs nothing: while an overlay is open, the dim or the panel takes it as a GUI event.
- [ ] **Step 4: `Hud` blocks the other keys while an overlay is open**

  In `hud.gd`:
  - Add `const Overlays: Array[StringName] = [PopoverStudents, PopoverHousing, PopoverMoney, PopoverReputation]` and a helper `func _overlayOpen() -> bool`, which returns `Overlays.has(_open)`.
  - In `openPopover` and `closePopover`, after `_open` changes, set:
    - `camera.keysEnabled = not _overlayOpen()`
    - `controller.keysEnabled = not _overlayOpen()`
  - In `_unhandled_input`, after the popup branch and the Esc-closes-a-popover branch, add: while `_overlayOpen()`, any key event (`InputEventKey`) or action (`InputEventAction`) that is not `TogglePause`, `SpeedUp` or `SpeedDown` is marked handled and returns. `TogglePause`, `SpeedUp` and `SpeedDown` fall through to `CampusView`.

  Order check: the `Hud` sees unhandled input before `BuildController`, `Camera` and `CampusView`. That's reverse tree order, with `Hud` under the `UI root` CanvasLayer. So this blocks X, B, Tab, F2, F3, `,` and `.` too.

  The `action` console command feeds `InputEventAction`s, so those are blocked the same way. Esc has already closed the overlay by the time this branch runs.
- [ ] **Step 5: The Money slots light together**

  In `top_bar.gd`, `setOpen(&"money", open)` sets Cash, Monthly expenses and Fees all pressed while Money is open, and all released when it closes.

  Delete `_moneySlot` and `_onMoneySlotPressed` (the three slots emit `MoneyPressed` directly again), and their comment.
- [ ] **Step 6: The spec section**

  Append the "UI feedback 2 (2026-09-24)" section to the spec, as the header of this plan describes.
- [ ] **Step 7: REGISTER, RUN-TESTS (229 in 23), LAUNCH-CHECK**

  Screenshot each of `hud students`, `hud housing`, `hud money` and `hud reputation` with `pause`. Each should show a centred panel at 80% of the play area, with the dimmed 3D view around it and no ×. Money's screenshot should also show all three money slots underlined.

  Then check the behaviour:
  - Click on the dim outside the panel (for example, design point `(100, 600)`). The overlay closes. Check with `eval str(get_root().find_child("Hud", true, false).popoverOpen())`.
  - Click inside the panel. It stays open.
  - With an overlay open, send `action MoveRight down`, wait 0.5 s, then `action MoveRight up`, and run `state`. The camera target hasn't moved.
  - `action Demolish down` / `up` leaves the tool at none.
  - `action TogglePause down` / `up` still toggles pause.
  - After closing, `action MoveRight` moves the camera again.
- [ ] **Step 8: `CLAUDE.md`, then commit**

  Update `CLAUDE.md` to describe:
  - the overlays: 80% of the play area, the dim, click-away and Esc
  - the keys an overlay allows (Esc, Space, +/−)
  - `keysEnabled`
  - the Money slots lighting together

  Remove the ×.

  Then commit:

```bash
git add -A university/src/ui university/src/views/game_camera.gd university/src/views/build_controller.gd docs/superpowers/specs/2026-09-22-students-money-hud-design.md CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Overlays at 80% over the dimmed campus, closed by a click away, blocking the world's keys

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Notifications replace the alerts

**Files:**
- **Delete:**
  - `university/src/ui/alerts.tscn`, `alerts.gd` and its `.uid`
  - `university/src/ui/alert_row.tscn`, `alert_row.gd` and its `.uid`
  - `university/src/ui/alert_feed.gd` and its `.uid`
  - `university/src/ui/alert_entry.gd` and its `.uid`
  - `university/tests/AlertFeedTest.gd` and its `.uid`
- **Create:**
  - `university/src/ui/notifications_button.tscn` and `.gd`
  - `university/src/ui/notifications_panel.tscn` and `.gd`
  - `university/assets/icons/bell.png`, a placeholder
- **Modify:**
  - `university/src/ui/hud.tscn` and `hud.gd`
  - `university/src/ui/ui_theme.tres`
  - `university/src/debug/debug_commands.gd`
  - `CLAUDE.md`

**Interfaces:**
- **Produces:**
  - `NotificationsButton` (Button): `signal Pressed`, provided by Button's own `pressed`, and `setCount(count: int)`.
  - `NotificationsPanel` (PanelContainer): `signal ProblemWanted(kind: Problem.Kind)`, and `var university: University`.
  - The popover name `&"notifications"`, as `Hud.PopoverNotifications`.
  - The console command `hud notifications`.

- [ ] **Step 1: The bell icon**

  Make `bell.png` at 64×64, white on transparent, the same way `help.png` was made: a throwaway script in `/tmp/university/` renders an in-memory SVG string with `Image.load_svg_from_string` and saves it with `save_png`. The SVG is never written to a file. Use the other icons' wrapper, with the inner markup `<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>`.

  Run IMPORT. The user will overwrite the placeholder with their own `bell.png`.
- [ ] **Step 2: Delete the alerts**

  `git rm` every file in the Delete list. Also remove:
  - The `Alerts` node and its ext_resource from `hud.tscn`.
  - From `hud.gd`: the `alerts` var, `alerts.setup`, the `PlaceWanted` wiring, `_openPlace`, `AlertsMargin`, and the `_process` code that shifts the alerts. If `_process` is left empty, remove it.
  - From the theme: `AlertBox`, `AlertText` (if still present), `AlertWhen`, `AlertClose`, `AlertAccentWarn`, `AlertAccentBad` and `AlertAccentInfo`, with their sub_resources.

  `Hud.openProblem(kind)` stays, because the notifications use it.

  Grep `university/src`, `university/tests` and `CLAUDE.md` for `Alert`: nothing may remain, apart from the word inside other names such as `AutoBorrowed`.

  After this step, RUN-TESTS shows 225 cases in 22 suites.
- [ ] **Step 3: `NotificationsButton`**

  `notifications_button.tscn` is a Button:
  - variation `SlotButton` (flat, with its hover and pressed styles)
  - `toggle_mode = true`, `focus_mode = 0`
  - `icon = bell.png`
  - 56×56, placed at the top left of the play area: `offset_left = 16`, `offset_top = 72 + 12 = 84`

  It has a child `Badge`: a PanelContainer, unique, with the new `NotificationBadge` variation (bad background, fully rounded, radius 12, content margins 6/0). It is anchored to the button's top-right corner and `mouse_filter = 2`. `Badge` holds `Count`: a Label, unique, `Body` style (the text colour reads on red), centred.

  Its script:

```gdscript
class_name NotificationsButton
extends Button
## The bell at the top left of the play area: its badge counts what is wrong
## right now, and pressing it opens the notifications panel.

@onready var badge: PanelContainer = %Badge
@onready var countLabel: Label = %Count


func setCount(count: int) -> void:
	badge.visible = (count > 0)
	countLabel.text = str(count)
```

  `SlotButton`'s `icon_max_width` (24) caps the icon. That's fine at 56 px.
- [ ] **Step 4: `NotificationsPanel`**

  `notifications_panel.tscn` is a PanelContainer:
  - variation `MenuPanel`
  - hidden
  - anchored top-left under the bell: `offset_left = 16`, `offset_top = 148`, width 480

  It holds `Rows` (a VBox, unique, separation 4) and `EmptyNote` (a Label, unique, `Caption` style, text "Nothing needs attention.").

  **Rows.** Rows are built in code, one per current problem. Rebuild only when the list of kinds changes; update the text every frame.

  Each row is a Button:
  - `MenuItemDotted` style, left-aligned, `focus_mode = 0`
  - its text is the problem's line
  - a child `StatusDot` (8×8, `mouse_filter = 2`) at the left, tinted through `get_theme_color` from the palette: `bad` for HousingOverflow, DiningUnfed and CreditMaxed; `warn` for DiningCrowded

  The texts, each a named const, reusing the old alert wording:

| Problem | Text |
|---|---|
| HousingOverflow | `"%s students without on-campus housing (%s)"`, with `count` and `percent(fraction)` |
| DiningCrowded | `"Dining at %s of its recommended load: crowded"`, with `percent(fraction)` |
| DiningUnfed | `"%s students can't eat"` |
| CreditMaxed | `"Credit line used up"` |

  There are no dates and no dismiss. A row's press emits `ProblemWanted(kind)`, typed as `Problem.Kind`.

  **Refresh.** `_process` returns early unless the panel is visible and `university` is set. Then it reads `university.problems()`, shows `EmptyNote` when that list is empty, and otherwise refreshes the rows.
- [ ] **Step 5: `Hud` wiring**

  In `hud.tscn`:
  - Add `NotificationsButton` (unique) after `SidePanel`.
  - Add `NotificationsPanel` (unique) under `Popovers`.

  In `hud.gd`:
  - Add `const PopoverNotifications: StringName = &"notifications"` and put the panel in `_popovers` under it.
  - Connect `notificationsButton.pressed` to `toggle.bind(PopoverNotifications)`.
  - Connect `notificationsPanel.ProblemWanted` to a handler that calls `closePopover()` then `openProblem(kind)`. `openProblem` opens its place.
  - `setup` sets `notificationsPanel.university`.
  - `_process` calls `notificationsButton.setCount(state.university.problems().size())`, guarded by `state != null`.
  - `openPopover` and `closePopover` keep the bell's pressed state in step with the panel, `notificationsButton.set_pressed_no_signal(_open == PopoverNotifications)`, the same way `actionBar.showBuildOpen` works.

  The panel is a popover: one open at a time, closed by a world click or Esc. It is not an overlay, so the keys stay live.

  In `debug_commands.gd`, `hud notifications` works through `hasPopover`. Update the `hud` description.
- [ ] **Step 6: REGISTER, RUN-TESTS (225 in 22), LAUNCH-CHECK**

  Take these screenshots with `pause`:
  1. The start: the bell at the top left, under the bar, with a red "1" badge (housing overflow). No top-right alerts.
  2. `hud notifications`: the panel under the bell, with one row "440 students without on-campus housing (55%)" and a bad dot.
  3. Click that row. The Housing overlay opens.
  4. `money 0`, then `borrow 50000000`, so the credit line is maxed. The badge shows 2, and the panel lists both.
- [ ] **Step 7: `CLAUDE.md`, then commit**

  In `CLAUDE.md`, replace every description of the alerts with the notifications:
  - the bell and its badge
  - the panel
  - problems only, no dates, no dismiss
  - a click opens the place

  Also add `bell.png` to the icon list and `hud notifications` to the console list.

  Then commit:

```bash
git add -A university/src/ui university/tests university/assets/icons university/src/debug/debug_commands.gd CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Replace the alerts with a notifications bell, its badge and a panel of current problems

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: The building panel at the bottom; links, inline texts and the popup

**Files:**
- Modify:
  - `university/src/ui/side_panel.tscn` and `.gd`
  - `university/src/ui/admissions_pane.tscn` and `.gd`
  - `university/src/ui/academic_pane.tscn` and `.gd`
  - `university/src/ui/dorm_pane.tscn` and `.gd`
  - `university/src/ui/dining_pane.tscn` and `.gd`
  - `university/src/ui/construction_pane.tscn` and `.gd`
  - `university/src/ui/reputation_dropdown.tscn` and `.gd`
  - `university/src/ui/build_panel.tscn` and `.gd`
  - `university/src/ui/semester_popup.tscn` and `.gd`
  - `university/src/ui/hud.gd`
  - `university/src/ui/ui_theme.tres`
  - `CLAUDE.md`

- [ ] **Step 1: The building panel takes the lower 3/4**

  `side_panel.tscn`'s root stays docked right, now anchored to the bottom 3/4 of the screen: `anchor_top = 0.25` with `offset_top = 0`, and the bottom at the screen's bottom. That is 810 of 1080 design px.

  Its body already scrolls. Check the header, scroll and footer layout still holds.
- [ ] **Step 2: The building panels lose their links to top-level screens**

  Delete these jump buttons and their wiring:
  - **Admissions pane:** "Students →" and "Finances →".
  - **Dorm pane:** "All housing →".
  - **Dining pane:** "Build a dining hall →".
  - **Academic pane:** "All students →" and "+ Add an academic building". Keep "Admissions →", which opens a building, not a screen.
  - **Construction pane:** its jump ("All housing →" or "All students →").

  Then delete what those removals orphan:
  - each pane's `PopoverWanted` or `BuildWanted` signal, if nothing else in the pane emits it
  - `SidePanel`'s relays and its `PopoverWanted` and `BuildWanted` signals, if no pane emits them any more
  - `Hud`'s connections to them
  - `Hud.openBuildPanel(category)`, if nothing calls it
  - the `BuildingRowAdd` theme variation and its sub_resources, if unused
  - the consts and `@onready` vars for the removed nodes

  Leave `AcademicPane.BuildingWanted` and `SidePanel.BuildingWanted` in place: the building rows and Admissions → still use them.
- [ ] **Step 3: Reputation loses its Housing link, and the inline texts go**

  In `reputation_dropdown`:
  - Delete the "Housing →" jump, its `HousingJumped` signal, and `Hud`'s connection to it.
  - The heading "Target: half grades, half satisfaction" becomes "Target". Keep its (?).

  In `build_panel`, delete the footer's warn line: the `FootWarn` label, the `WarnFormat` const and their code. The `FootInfo` and `FootOpens` lines stay.

  Leave the Students and Housing overlays' own jumps ("Housing →", "Reputation →", "Room & meal plan prices →") as they are. The user named only Reputation's.
- [ ] **Step 4: The semester popup**
  - **Delete from the title row:** the popup's `HelpIcon`, and the `SubFall` and `SubSpring` tooltip consts with the code that sets them. If the title row is now just the title, flatten it back to a single Label.
  - **Delete the Continue button:** remove `ContinueButton` and its button row.
  - **Any click dismisses:** a left press anywhere on the popup (the dim or the box) calls `dismiss()`.
    - Connect the root's `gui_input`.
    - Set the box, `PanelContainer` `Box`, to `mouse_filter = 1` (PASS), and any other container in between that would stop the event, so a press inside the box reaches the root too.
    - Accept the event.
  - **Esc still dismisses,** through `Hud`.
  - **Check:** grep for `ContinueButton`, `Continued` wiring and `PrimaryButton`. `Continued` is still the signal `dismiss()` emits, so keep it. If `PrimaryButton` is now unused, remove it from the theme.
- [ ] **Step 5: REGISTER, RUN-TESTS (225 in 22), LAUNCH-CHECK**

  Screenshot these with `pause`, and LOOK at each:
  - **The building panels:** `hud admissions`, `hud academic`, `hud dorm`, `hud dining`, and `build dorm 30 15 0` then `hud construction`. Each is docked right, from a quarter of the way down to the bottom, with no links to top-level screens. The academic panel keeps "Admissions →".
  - **The overlays:** `hud reputation` shows no Housing link, and its heading reads "Target".
  - **The build panel:** `hud build` shows no warn line in the footer.
  - **The popup:** `hud popup` shows no (?) and no Continue. Then click anywhere, for example on the box's centre, and run `eval get_root().find_child("SemesterPopup", true, false).visible`: it is false. Check that the clock's pause state went back to what it was before.
- [ ] **Step 6: `CLAUDE.md`, then commit**

  Update `CLAUDE.md`:
  - the building panel's size
  - which links each pane still has
  - the popup: any click or Esc dismisses it, and it has no Continue or (?)
  - the Reputation "Target" heading
  - the build footer

  Then commit:

```bash
git add -A university/src/ui CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Bottom-anchored building panel, fewer links and inline texts, and a popup any click dismisses

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```
