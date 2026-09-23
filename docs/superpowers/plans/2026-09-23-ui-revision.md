# UI Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the user's revision of the finished HUD:
- remove the campus markers, the keyboard hints and "Look at housing"
- replace the SVG icons with PNGs
- five label styles, larger text, and a blue accent
- move explanations into (?) tooltips
- turn Students, Housing, Money and Reputation into screen-sized overlays

**Architecture:** No state changes, except `GameCalendar.clockLine` and removing `Campus.centroid`. Everything else is views and the theme: `ui_theme.tres` shrinks from ~110 type variations to the five text styles (with tones) plus the box and button styles the scenes need. A new `HelpIcon` component carries the tooltips.

**Tech Stack:** Godot 4.7, fully typed GDScript, gdUnit4, LimboConsole + TCP remote console.

**Spec:** `docs/superpowers/specs/2026-09-22-students-money-hud-design.md`, section **UI revision (2026-09-23)**. That section wins over the rest of the spec and over the mockup.

## Global Constraints

- **Paths.** The repo root is `/Users/noel/Development/University/game`; the Godot project is `university/`, and `res://` is `university/`.
- **`CLAUDE.md` governs.**
  - Naming: camelCase for variables and functions; PascalCase for classes, constants and signals. Conditions are parenthesized, `if (x):`.
  - Fully typed GDScript, with warnings treated as errors:
    - shadowing, including `shadowed_global_identifier`
    - integer division
    - unsafe access
    - `int_as_enum_without_match`
  - A parse error silently drops a gdUnit suite, so compare the total case count against this plan's table.
  - No magic numbers. Use named consts, including for every displayed string.
  - Surgical changes. When a change orphans something, remove the orphan.
- **Colours only through `ui_theme.tres`.** Never a literal `Color` in a `.tscn` or a script. `load_steps` must equal ext_resources + sub_resources + 1, in every `.tscn` and `.tres` you touch.
- **UI layout lives in `.tscn`.** Code only sets dynamic text, visibility, tones and dynamic tooltip text.
- **Use `%UniqueName`.** Buttons get `focus_mode = 0`.
- **The five label styles.** Every Label in the game uses exactly one of these `theme_type_variation`s, or `Pill*`:

| Style | Font | Size | Colour | Tone variants |
|---|---|---|---|---|
| `Title` | `SerifBold` (the Cormorant FontVariation) | 26 | text | none |
| `Heading` | Barlow Semi Condensed SemiBold | 16 | text | none |
| `Value` | Barlow Semi Condensed SemiBold | 24 | text | `ValueGood`, `ValueWarn`, `ValueBad`, `ValueDim` |
| `Body` | Barlow Regular | 18 | text | `BodyGood`, `BodyWarn`, `BodyBad`, `BodyDim` |
| `Caption` | Barlow Semi Condensed Medium | 14 | muted | `CaptionGood`, `CaptionWarn`, `CaptionBad`, `CaptionDim` |

  - Tones change the colour only: good, warn, bad and dim from the palette.
  - `Pill`, `PillGood`, `PillWarn`, `PillBad` and `PillDim` keep their coloured background boxes, but take `Caption`'s font and size.
  - `Heading` labels are authored with `uppercase = true`, as the section titles already are.
- **Button fonts map onto the same five.**

| Buttons | Font and size |
|---|---|
| menu items, building rows, category buttons, cards, Ghost/Primary buttons, and the base `Button` | `Body` |
| speed buttons, action buttons, jump links | `Heading` |
| glyph buttons: ×, −, + (`CloseButton`, `AlertClose`, `StepButton`) | `Value` |

  The theme's `default_font` is Barlow Regular and `default_font_size` is 18.
- **Palette.** `Palette/colors/*` keeps `chrome`, `chrome2`, `chrome3`, `line`, `line2`, `text`, `muted`, `dim`, `good`, `warn` (amber, unchanged), `bad` and `maroon`, and changes these:

| Old | New | Value |
|---|---|---|
| `gold` | `accent` | #4a90e2, `Color(0.290, 0.565, 0.886)` |
| `gold2` | `accent2` | #8cc2ff, `Color(0.549, 0.761, 1.0)` |
| `onGold` | `onAccent` | #0b1422, `Color(0.043, 0.078, 0.133)` |
| `info` | removed | merges into `accent` |

  Every theme stylebox or colour that used gold, gold2, onGold or info uses accent, accent2 or onAccent instead.
- **The top bar is 72 px high** (it was 58). Everything positioned under it moves down with it.
- **Tests** assert behaviour, never content values. Views are verified by LAUNCH-CHECK screenshots.
- **Commits** go to `main`, locally only, with no push. Commit each `.import` and `.uid` next to its source. End every message with `Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>`.

### Named procedures

**REGISTER** (after adding or removing a `class_name` script or `.tscn`):
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --editor --quit-after 20 2>&1 | grep -E "ERROR|WARNING|Parse Error" ; true
```

**IMPORT** (after adding or replacing PNGs):
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university --headless --import 2>&1 | grep -E "ERROR|WARNING" ; true
```

**RUN-TESTS:**
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/noel/Development/University/game/university -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Overall Summary|Executed test|FAILED|Parse Error|SCRIPT ERROR|leaked"
```

| After task | Cases | Suites |
|---|---|---|
| start | 230 | 23 |
| 1 | 229 | 23 |
| 2–4 | 229 | 23 |

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
- LOOK at `/tmp/university/screenshot.png` (3840×2160) with the Read tool. Use PIL to crop regions or halve the size, and say what you saw.
- Run `pause` first whenever you are reading numbers.
- Console names:
  - `hud <name>`: `gamemenu`, `unimenu`, `students`, `housing`, `money`, `reputation`, `build`, `popup`, `admissions`, `academic`, `dorm`, `dining`, `construction`, `none`
  - `build <id> <x> <z> <deg>`, `select <n>`, `tool`, `state`, `mousemove`/`mousedown`/`mouseup <x> <y>` (design space, 1920×1080), `action <name> <down|up>`, `advance <months>`
- `eval …get_global_rect()` prints nothing, so read `.global_position` and `.size` instead.
- `find_child` finds the first match, so reach a node through its parent.

---

### Task 1: Removals, and PNG icons

**Files:**
- Delete:
  - `university/src/ui/campus_markers.gd` and `.uid`
  - `university/src/ui/campus_marker.tscn`, `campus_marker.gd` and `.uid`
  - every `university/assets/icons/*.svg` and `*.svg.import`
- Create: `university/assets/icons/*.png`, the same ten names, plus `help.png`
- Modify:
  - `university/src/ui/hud.tscn` and `hud.gd`
  - `university/src/ui/semester_popup.tscn` and `semester_popup.gd`
  - `university/src/ui/game_menu.tscn`
  - `university/src/ui/university_menu.tscn`
  - `university/src/ui/action_bar.tscn`
  - `university/src/ui/top_bar.tscn`
  - `university/src/ui/ui_theme.tres`
  - `university/src/state/campus.gd`
  - `university/tests/CampusTest.gd`
  - `CLAUDE.md`

- [ ] **Step 1: Campus markers go**
  - Remove the `CampusMarkers` node and its ext_resource from `hud.tscn`.
  - In `hud.gd`, remove the `campusMarkers` var, its `setup` wiring and the `setClickable` call in `_onToolChanged`. Keep `_onToolChanged`'s other lines.
  - `git rm` the marker files.
  - Remove the `MarkerBox`, `MarkerText`, `MarkerSmall` and `MarkerStem` variations and their sub_resources from the theme.
  - `Campus.centroid` is now unused. Remove it and `CampusTest.test_the_centroid_is_the_middle_of_the_buildings`, together with its `CentroidEpsilon` const if nothing else uses it.
  - `AlertRow.accentFor` and its accent consts stay. Alerts still use them.
- [ ] **Step 2: "Look at housing" goes**
  - Remove the `HousingButton` from `semester_popup.tscn`.
  - In `semester_popup.gd`, remove the `HousingWanted` signal and its handler.
  - In `hud.gd`, remove `_onHousingWanted` and its connection.
  - Continue and Esc stay exactly as they are.
- [ ] **Step 3: Keyboard hints go**
  - Remove the `Key` labels (F5, F9, F2 and F3) from `game_menu.tscn` and `university_menu.tscn`, and the B and X `Key` labels from `action_bar.tscn`.
  - Remove the `MenuKey` and `ActionKey` variations from the theme.
  - The keys themselves keep working.
- [ ] **Step 4: PNG icons**
  - Write a throwaway headless script in `/tmp/university/`, not in the repo. For each `university/assets/icons/*.svg`, it reads the file text, calls `Image.load_svg_from_string(text, scale)` with a scale that gives 64×64 (the SVGs are 24×24), and saves `<name>.png` beside it with `save_png`. `Image.load_svg_from_string` and `save_png` were probed and confirmed in 4.7.
  - The same script makes `help.png`, 64×64, from an in-memory SVG string that is never saved as a file: a white stroked circle with a white "?" inside, for example `<circle cx="12" cy="12" r="9"/>` plus a "?" path such as `<path d="M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14"/><path d="M12 17h.01"/>` inside the same wrapper as the other icons.
  - Delete every `.svg` and `.svg.import` with `git rm`.
  - Point every scene reference at the `.png`. That's `top_bar.tscn` (menu, users, bed, coin, flow, cal, star and pause) and `action_bar.tscn` (hammer and trash). Grep `university/src` for `.svg`: none may remain.
  - Run IMPORT. Commit the PNGs and their `.import` files.
  - These PNGs are placeholders: the user will overwrite them with their own, keeping the same names.
- [ ] **Step 5: REGISTER, RUN-TESTS (229 cases in 23 suites), LAUNCH-CHECK**
  - `screenshot`: no markers over the campus. The icons still show (the PNG placeholders). The action buttons have no B or X.
  - `hud gamemenu` and `hud unimenu`: no F-key labels.
  - `hud popup`: only Continue.
- [ ] **Step 6: Update `CLAUDE.md`**
  - Remove `CampusMarkers`, `Campus.centroid`, "Look at housing", and every mention of shortcut labels in menus or action buttons.
  - Say the icons are PNGs in `university/assets/icons/`, supplied by the user.
  - Then commit.

```bash
git add -A university/src/ui university/src/state/campus.gd university/tests/CampusTest.gd university/assets/icons CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Drop the campus markers, the key hints and "Look at housing"; icons become PNGs

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Five label styles, bigger text, a blue accent

**Files:**
- Modify:
  - `university/src/ui/ui_theme.tres`, rewritten per the Global Constraints
  - every `university/src/ui/*.tscn` and `*.gd` that sets a `theme_type_variation` or asks the theme for a colour
  - `university/src/ui/ui_tone.gd`, `kpi.gd`, `info_row.gd`, `slot.gd`, `stepper.gd` and `meter_bar.gd` (the tone bases and palette names)
  - `university/src/state/game_calendar.gd` (`clockLine`)
  - `university/tests/GameCalendarTest.gd`
  - `CLAUDE.md`

- [ ] **Step 1: The theme**
  - Add `Title`, `Heading`, `Value`, `Body` and `Caption`, with their tones, as in the table.
  - Make `Pill*` use Caption's font and size.
  - Set the button fonts and sizes as in the button table.
  - Set `default_font` and `default_font_size` to 18.
  - Rename the palette entries (gold → accent, and so on). Replace every gold, gold2, onGold and info colour, in every stylebox and every `font_*_color`, with the accent equivalent.
  - Delete every other Label variation. The old names, from the survey:
    - `SlotValue*`, `SlotSub*`, `SlotCaption`
    - `CrestName`, `CrestSub`, `ShieldLetter`
    - `ClockValue`, `ClockCaption`
    - `MenuGroup`, `SectionTitle`, `SectionNote`
    - `KpiValue*`, `KpiCaption`
    - `TableHeader`, `RowKey`, `RowValue*`
    - `Note*`
    - `PopupTitle`, `PopupSub`
    - `StepCaption`, `StepValue*`
    - `PaneTitle`, `PaneSub`
    - `StageValue`, `StageCaption`, `StageNote`
    - `MiniLabel`, `LeverTitle`
    - `CategoryCount`
    - `CardTitle`, `CardCost`, `CardFx`
    - `AlertText`, `AlertWhen`
  - Keep the box and button styles the scenes use, and delete any that end up unused.
- [ ] **Step 2: Map every Label onto the five**

| Old | New |
|---|---|
| CrestName, PopupTitle, PaneTitle, ShieldLetter | `Title` |
| SectionTitle, MenuGroup, TableHeader, ClockValue, LeverTitle, CardTitle | `Heading` |
| SlotValue\*, KpiValue\*, StageValue | `Value` (same tone) |
| RowValue\*, StepValue (Dim → `BodyDim`), AlertText, CardCost, and the notes that stay (`NoFallsNote`, `SpringNote`, `NoDiningNote` → `BodyWarn`) | `Body` |
| SlotSub\*, SlotCaption, CrestSub, ClockCaption, SectionNote, KpiCaption, RowKey, PopupSub, StepCaption, PaneSub, StageCaption, StageNote, MiniLabel, CardFx, CategoryCount, AlertWhen, and the remaining small `Note`/`NoteWarn` labels | `Caption` (same tone) |

  - Change the code-side bases to match:
    - `KpiView.ValueBase` → `"Value"`
    - `InfoRow.ValueBase` → `"Body"`
    - `SlotView.ValueBase` → `"Value"` and `SubBase` → `"Caption"`
    - `Stepper.ValueBase` → `"Body"`
  - Grep every `theme_type_variation` and every `&"…"` variation name in `university/src/ui/*.gd`. `students_dropdown.gd`'s and `housing_dropdown.gd`'s `_addCell`, `admissions_pane.gd`'s chart labels and `build_panel.gd`'s cards all name variations in code, and every one must name a variation that exists. `UiTone.variation` over the new bases must only produce the variants that exist.
  - `slot.gd` reads `get_theme_color("gold", "Palette")`. Change it to `"accent"`. Grep for any other palette names that were renamed.
  - `MeterBar`'s `fill` colour becomes accent.
- [ ] **Step 3: Sizes and layout**
  - The top bar goes to 72 px: `top_bar.tscn`'s `offset_bottom`, and the slots' and buttons' minimum heights.
  - Everything that sat at `offset_top = 58` moves to 72: the game menu, University menu, the four dropdowns and the side panel. The alerts move from 72 to 86.
  - The crest's shield grows to 44×50 so the `Title` letter fits. The speed buttons grow to 40×40, and the action buttons to 72×72.
  - Grow any other fixed-size control that clips its new text, in the scene.
- [ ] **Step 4: The clock line**
  - `GameCalendar.clockLine(weekIndex)` becomes `"Week %d of %d"` of `weekInPeriod` and `weeksInPeriod`, keeping its doc comment updated. The Fees slot already counts down to the next semester, and the shorter line keeps the bigger top bar within 1920.
  - In `GameCalendarTest`, `test_the_clock_line_names_the_week_and_the_next_period` becomes a test that the line names the week and the period's length (for example, it contains `"Week 1 of %d" % weeksInPeriod(0)`). The count stays the same.
  - `nextPeriodName` stays if anything else uses it. Otherwise remove it and its use.
- [ ] **Step 5: REGISTER, RUN-TESTS (229 cases in 23 suites), LAUNCH-CHECK**
  - With `pause`, screenshot each of these and LOOK at it:
    - the start screen (top bar, action bar, alerts)
    - `hud students`, `hud housing`, `hud money`, `hud reputation`
    - `hud unimenu`, `hud gamemenu`
    - `hud admissions`, `hud academic`, `hud dorm`, `hud dining`
    - `build dorm 30 15 0` then `hud construction`
    - `hud build`
    - `hud popup`
  - For every screenshot, check:
    - Is the text larger?
    - Are only the five styles in use?
    - Is everything that was gold now blue, with amber warnings still amber?
    - Does the top bar fit within 1920 with nothing clipped?
    - Does nothing overlap?
  - Fix what's wrong in the scenes.
- [ ] **Step 6: Update `CLAUDE.md`**
  - Describe the five styles, the tones and pills, the button mapping, the blue accent and the palette names, and the 72 px bar.
  - Update every mention of an old variation name.
  - Then commit.

```bash
git add -A university/src university/tests/GameCalendarTest.gd CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Five label styles, larger text and a blue accent across the HUD

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Explanations become (?) tooltips

**Files:**
- Create: `university/src/ui/help_icon.tscn` and `university/src/ui/help_icon.gd`
- Modify:
  - `ui_theme.tres` (the tooltip styles)
  - the scenes and scripts listed in Step 3
  - `CLAUDE.md`

**Interfaces:**
- **Produces:** `HelpIcon` (TextureRect). Its text is the node's `tooltip_text`, authored in the scene, or set by the owning view when it depends on numbers.

- [ ] **Step 1: `HelpIcon`**

  `help_icon.tscn` has one node, `HelpIcon`:
  - a TextureRect with `texture = help.png`
  - `custom_minimum_size = Vector2(20, 20)`, `expand_mode = 1`, `stretch_mode = 5`
  - `mouse_filter = 0` (STOP, so the tooltip shows)
  - `size_flags_vertical = 4`
  - script `help_icon.gd`

  `help_icon.gd`:

```gdscript
class_name HelpIcon
extends TextureRect
## A (?) beside something that needs explaining: hovering it shows the
## explanation as a tooltip. The text is the node's tooltip_text, authored in
## the scene, or set by the owning view when it depends on numbers.

# Tooltips wrap at this width, so a long explanation reads as a paragraph.
const WrapWidth: float = 360.0
const TooltipStyle: StringName = &"Body"


func _ready() -> void:
	self_modulate = get_theme_color(&"muted", &"Palette")


func _make_custom_tooltip(forText: String) -> Object:
	var label: Label = Label.new()
	label.text = forText
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WrapWidth
	label.theme_type_variation = TooltipStyle
	return label
```

  The `Control._make_custom_tooltip` virtual was probed and confirmed in 4.7. Check that `TextServer.AUTOWRAP_WORD_SMART` is used in the codebase, or probe it. Setting `autowrap_mode` on a Label is already done in scenes (`autowrap_mode = 3`).
- [ ] **Step 2: The tooltip style**

  In the theme:
  - `TooltipPanel/styles/panel` is a StyleBoxFlat: chrome2, a 1 px line2 border, radius 4, content margins 12/10.
  - `TooltipLabel` gets Body's font, size and colour.

  `TooltipPanel` (panel) and `TooltipLabel` (`font_size`, `font_color`) were probed and exist in the default theme.
- [ ] **Step 3: Move each explanation into a (?)**

  Rule: text that explains how something works moves. Delete its Label, and put a `HelpIcon` beside the heading or value it explains, carrying that text. Text that states a number or a fact stays. Every tooltip string is a named const, or `tooltip_text` in the scene.

| Where | The (?) sits beside | Its text |
|---|---|---|
| Students dropdown | the title | "Admissions each fall · graduation before the next fall" |
| Students dropdown | "Next fall" | "At today's reputation and next year's prices." |
| Housing dropdown | the Off campus KPI | the overflow note ("Off-campus students pay tuition only: …") |
| Money dropdown | "Every month" | the shortfall note, dynamic with the fee % |
| Money dropdown | the fees title | "Fees arrive as a lump at the start of each semester, at today's enrolment." |
| Reputation dropdown | "Target" | "Reputation moves N% of the way to its target each fall. Reputation sets how many apply; price does too: see the Admissions Office." Dynamic N%. Its `HeaderNote` and the note label go. |
| Admissions pane | "Next intake" | "At today's reputation and next year's prices. Seats fill from the top of the applicant list; how many apply depends on reputation and on the total price. Empty seats are upkeep with no tuition." Its `SectionNote` and `Note` go. |
| Admissions pane | "Minimum entry grade" | the "Off: every seat …" explanation |
| Admissions pane | "Room and meal plan" | the total-price note, dynamic |
| Academic pane | "Seats" | "All academic buildings. " + the graduate note, dynamic |
| Dorm pane | "Housing" | the housing note, dynamic threshold |
| Dorm pane | "Money" | the room-price note |
| Dining pane | "Load" | "All dining halls, housed students. " + the load note, dynamic |
| The side panel's Demolish button | the button | the refund rule, dynamic: "Demolishing it before it opens refunds the full $X. Once it has opened, nothing comes back." while under construction, and "Demolishing an open building refunds nothing." once open |
| Semester popup | the title | "Admissions resolved · buildings opened · fees collected" in fall, and "Buildings opened · fees collected" in spring |

  - For the Demolish row, the construction pane's `RefundNote` label goes.
  - For the semester popup, `PopupSub` goes.
  - The dynamic tooltips are set in the owning script's `_process` (or `display`/`showReport`) on the HelpIcon's `tooltip_text`, reusing the existing format consts.
  - Delete the consts and nodes this orphans.
- [ ] **Step 4: REGISTER, RUN-TESTS (229 in 23), LAUNCH-CHECK**
  - Screenshot each surface from the Step 3 table, and check that no explanatory paragraph remains.
  - Prove a tooltip shows: with `hud admissions` open, read the Next intake HelpIcon's `global_position` and `size` through the pane (`find_child("AdmissionsPane", …).find_child(<its name>, …)`), `mousemove` onto its centre, sleep 1.0 s (the tooltip delay is 0.5 s), then screenshot. The wrapped tooltip should show beside the (?).
  - If a hidden-window screenshot can't show tooltips, say so, and prove the text instead with `eval` on `tooltip_text`.
- [ ] **Step 5: Update `CLAUDE.md`**
  - Describe `HelpIcon` and the rule for what becomes a tooltip.
  - Then commit.

```bash
git add -A university/src/ui CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Move explanations behind (?) tooltips

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Students, Housing, Money and Reputation become screen-sized overlays

**Files:**
- Modify:
  - `university/src/ui/students_dropdown.tscn` and `.gd`
  - `university/src/ui/housing_dropdown.tscn` and `.gd`
  - `university/src/ui/money_dropdown.tscn` and `.gd`
  - `university/src/ui/reputation_dropdown.tscn` and `.gd`
  - `university/src/ui/hud.gd`
  - `ui_theme.tres`
  - `CLAUDE.md`

**Interfaces:**
- **Produces:** each overlay has `signal CloseRequested`. `Hud` connects all four to `closePopover`.
- **Unchanged:** the class names (`StudentsDropdown`, and so on), the popover names, and how they open (their slot, menus, jumps and `hud <name>`).

- [ ] **Step 1: The overlay style**

  In the theme, add `Overlay` (PanelContainer): chrome, no border, content margins 48 left/right and 32 top/bottom. The `Dropdown` variation goes once nothing uses it.
- [ ] **Step 2: Each dropdown becomes an overlay**

  **Root.** The root becomes an `Overlay`:
  - anchors full rect: left 0, top 0, right 1, bottom 1
  - `offset_top = 72` (under the top bar), other offsets 0
  - default mouse_filter (STOP, so nothing reaches the world under it)

  **Header.** Its first child is a header row (HBox):
  - the title Label (`Title`, dynamic text as today)
  - any `HelpIcon` from Task 3
  - a spacer
  - a `CloseButton` "×" (`focus_mode = 0`) that emits `CloseRequested`

  **Body.** Below the header, the content is laid out for the full width in columns (HBox of VBoxes, each `size_flags_horizontal = 3`, separation 48), with the KPIs in one row at the top:

| Overlay | KPI row | Columns |
|---|---|---|
| Students | its five KPIs | left: the cohort table; right: Housing, then Next fall |
| Housing | its KPIs | left: the dorm table; right: Dining |
| Money | cash, per month, cash at semester start | three columns: Every month, Credit line, next fees |
| Reputation | its three KPIs | two columns: Target, Satisfaction |

  The existing `%Unique` names, scripts, consts and behaviour stay. This is a layout change. Only move nodes, and adjust `load_steps`.
- [ ] **Step 3: `Hud` wires the ×**

  In `_ready`, connect each overlay's `CloseRequested` to `closePopover`.

  Check that Esc, and clicking the overlay's own slot, still close it. A click inside the overlay must not close it: the GUI takes it, so it never reaches `Hud._unhandled_input`'s left-press close.
- [ ] **Step 4: REGISTER, RUN-TESTS (229 in 23), LAUNCH-CHECK**

  With `pause`, run `hud students`, `hud housing`, `hud money` and `hud reputation`, and screenshot each. Each should fill the screen under the top bar, with the top bar still visible, the × at the top right, and the content in columns with nothing clipped.

  Then check the close paths:
  - Click the ×, aiming through the overlay. The overlay closes.
  - Open Money from its slot and click the slot again. It closes.
  - `action ExitGame down`, then `up`. It closes.
  - With the game unpaused, `state` shows the clock still running while an overlay is open.
- [ ] **Step 5: Update `CLAUDE.md`**

  Describe the four as screen-sized overlays: under the top bar, closed by ×, their slot or Esc, and the game keeps running. Then commit.

```bash
git add -A university/src/ui CLAUDE.md
git status --short
git commit -m "$(cat <<'EOF'
Open Students, Housing, Money and Reputation as screen-sized overlays

Co-Authored-By: Claude <the model you actually are> <noreply@anthropic.com>
EOF
)"
```
