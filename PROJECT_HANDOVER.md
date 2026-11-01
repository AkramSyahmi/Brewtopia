# BREWTOPIA: project handover

This was written on 2026-11-01 for a new collaborator taking over from the original developer. Everything here comes from
the repository's source code, data, git history (17 commits, 2026-10-21 → 2026-11-01, author `AkramSyahmi`) and
the screenshots in `docs/screenshots/`. Where the original developer's intent can't be verified, it's marked
**unknown**. `CLAUDE.md` is the short reference, and `TESTING_CHECKLIST.md` is the manual test pass.

---

## 1. What the game is

*BREWTOPIA: A Malaysian café story* is a cosy barista game for Android, built in Godot 4.7.2 for the 5th
UMPSA × HUAWEI GameCenter Mobile App Competition (UXHMAC 2026), Category B (README).

The player is a new barista taught by a mentor. Customers come to the counter and order. The player makes every
drink by hand at a 2D pixel-art espresso bar, then a toppings bar. The drink is scored, the mentor gives one
specific tip, and four regulars (Student, Office Worker, Coffee Lover and Makcik) slowly become friends. Each
regular has a three-part story, and once all four are finished a finale and credits play. After that the café carries on.

Malaysian flavour: gula melaka, pandan and condensed-milk syrups, *Kopi Susu Ais*, "kaw" (strong) espresso,
Makcik's greetings ("Assalamualaikum, adik!"), prices in RM, and a "KOPI" sack in the café.

## 2. The gameplay loop

### 2.1 Screens and flow
```
Title (scenes/ui/title_screen.tscn)
  Continue (needs a save) / New Game (confirms if a save exists, deletes it)
        │ change_scene_to_file
        ▼
CafeShift (scenes/cafe/cafe_shift.tscn), one day = a list of orders
  for each order:
    customer walks in (3D café) → story beat (if earned) + intro dialogue (CHOICE lines are cosmetic)
    → order bubble appears, patience starts draining → BAR (2D station)
    → drink dragged to SERVE → DrinkModel.evaluate → RESULT strip + mentor tip
         score < 40 → "Make it again" (back to BAR)
         else "Continue" → friendship points, reaction line → customer leaves
  end of day → SUMMARY: wage + tips → money, XP → level, "new recipes tomorrow"
         Shop (upgrades / decor) · Next day (finale + credits the first time all stories are done)
```
`CafeShift.step` cycles through `DIALOGUE → BAR → RESULT → SUMMARY` (`show_step()`). The café view and the station are
sibling nodes that are shown and hidden, so there's no scene change between them. The in-game **Menu** pauses the
tree. "Main menu" returns to the title, and the day restarts from its first order next time.

### 2.2 Days
- **Day 1** (`data/orders/ch1_first_shift.json`): Double Espresso (assist `full`) → Latte (`hints`) →
  "kaw" Double Espresso (`none`, overrides: 30 g in 20–25 s) → Gula Melaka Latte (`hints`). Wage RM 40, patience 150 s.
- **Day 2+** (`scripts/cafe/day_plan.gd` + `data/orders/daily.json`): seeded with `day × 7919`. There are 3 + day orders
  (max 8), and the regulars rotate with no one twice in a row. Any newly unlocked recipe is ordered first, with a mentor
  explanation. From day 3, 30% of orders are pairs ("Two Lattes"); 35% are vague riddles (if the recipe has `riddles`).
  The Coffee Lover's espresso is always "kaw". Patience drops 8% a day down to 50%. Wage = 45 + 5·(day − 2).

### 2.3 Recipes (`data/recipes/*.json`)
All recipes use 18 g in, 36 g out, 25–30 s and ideal grind 5 (only the "kaw" override differs).

| Recipe | Lv | Cup | Ice | Milk (°C / foam) | Art scored | Syrups | Toppings |
|---|---|---|---|---|---|---|---|
| Double Espresso | 1 | glass | – | – | – | – | – |
| Latte | 1 | cup | – | 60–65 / 0.25–0.40 | yes | – | – |
| Gula Melaka Latte | 1 | cup | – | 60–65 / 0.25–0.40 | yes | gula melaka 2 | cinnamon |
| Iced Latte | 2 | iced | yes | 0–10 / – | – | – | – |
| Cappuccino | 2 | cup | – | 60–65 / 0.50–0.70 | yes | – | cocoa |
| Iced Gula Melaka Latte | 3 | iced | yes | 0–10 / – | – | gula melaka 2 | – |
| Mocha | 3 | cup | – | 60–65 / 0.25–0.40 | yes | chocolate 2 | cream |
| Kopi Susu Ais | 4 | iced | yes | none | – | condensed milk 2 | – |
| Caramel Macchiato | 5 | cup | – | 60–65 / 0.25–0.40 | yes | vanilla 1, caramel 2 | – |

### 2.4 Making a drink (`scripts/station/espresso_station.gd`)
The station is a `Node2D` world drawn at ×2 (640×360 base px). Page 1 (espresso) is at x 0 and page 2 (toppings) at x 640;
switching pages slides the world. Drop and tap targets are `SnapZone`s (Area2D + Marker2D) found with a physics point query.

1. **Grind:** drag a portafilter (one waits on the mat, one in the right group head) into the grinder fork. Set the grind
   with −/+ (1 fine … 10 coarse; the day starts at 8, ideal 5) and **hold** the grinder: 4 g/s. The grinder screen and a bubble show
   grams (green within ±0.5 g). Extra grounds undo a tamp.
2. **Tamp:** drop the portafilter on the black mat and tap the tamper (pass/fail).
3. **Lock:** drop it on either group head.
4. **Cup:** take a latte cup (left half of the rack), a glass (right half) or a plastic iced cup (stack left of the
   machine) and put it on the scale under the portafilter. Dropping a cup on the ice bin adds ice.
5. **Shot:** tap the locked portafilter. Simulated time runs at ×2, and flow depends on grind, dose and tamping. A bar with a green
   zone (±2 g, wider with the upgrade) follows the cup's weight. Tap again to stop (it stops automatically at 70 g). The station rates
   the shot Perfect / Good / Bad straight away.
6. **Milk:** drag the pitcher to the COLD MILK fridge door → to the steam wand (popup: **hold** to heat at 12 °C/s,
   drag lower for more foam, higher to only heat; press Done) → onto the cup. Iced drinks get cold milk poured straight
   in. Hot milk into a ceramic cup opens **latte art**: the pitcher swings, and you tap when it's over the middle (score 0–1).
   A small **Skip** button, or 30 s without a tap, closes it with no pattern, scored as the lowest pour (0.0, art score 40).
   Skipping after the pour only skips the wait and keeps the real score.
7. **Toppings:** tap "Toppings >". Cups with coffee move to two mats. Tap syrups (one pump per tap) and toppings (once
   each). The small **Undo** button under the topping containers takes back the last pump or topping on the current
   cup, one at a time, newest first. It's greyed out when there's nothing to undo.
8. **Serve:** drag the cup into a SERVE area (either page). To start again, drag a cup back onto the rack or plastic
   cup stack (espresso page): a tooltip warns "Release to pour the drink away", the drink is discarded ("Drink discarded.
   Cup ready to reuse.") and a fresh cup can be taken. Nothing is served, scored or saved.

The objective panel (top-left) always shows the next step, worked out from the live station state
(`objective()`), and a pulsing yellow outline marks the equipment. Expert orders (`assist: "none"`) hide both. For
vague orders, anything that would give the drink away is hidden.

### 2.5 Scoring (`scripts/brewing/`)
- **Shot quality** = 0.2·dose + 0.4·yield + 0.4·time. Dose is full marks within ±0.5 g. Yield is full marks inside the
  green zone. Time judges `pace_s`: how long the grind and tamping would take to reach the target yield at the recipe dose
  (untamped water runs 1.6× faster; each grind step 1.25×).
- **Milk drinks:** 0.6·shot + 0.4·milk, or 0.55 / 0.30 / 0.15 with scored latte art. Milk loses 8 per °C outside the
  range, and 150 × foam outside the range.
- **Accuracy** = 100 − wrong cup 30 − milk missing 40 / unwanted 20 − ice missing 30 / unwanted 20 − 10 per syrup pump
  difference − 10 per missing or extra topping.
- **Score = quality × accuracy / 100.** Grades: ≥ 90 Perfect Brew, ≥ 80 Great Cup, ≥ 70 Good Effort, ≥ 40 Needs Practice,
  < 40 Failed Order (must be remade). Two-drink orders average the two drinks.
- **Mentor note** (`DrinkModel.mentor_note`): praise for the parts that scored 100, then the single most useful fix (root
  causes first, such as a wrong drink, a dose off by more than 1 g, or no tamping; otherwise the costliest issue).
- **Service** (patience left when served) is shown on the result but only affects tips.
  `EspressoModel.order_score()` (a 70/20/10 formula marked "GDD 7.1") is only used by the unit test. The code says the
  quality × accuracy rule was a "playtest change". The GDD itself isn't in the repo (**unknown**).

### 2.6 Rewards, friendship and progression
- **Day summary:** money += wage + round(Σ tip(score) × service × friend bonus × (1 + 0.25·tip-jar level + 0.05·decor
  count)). tip(score): ≥ 90 → 5, ≥ 75 → 3, ≥ 60 → 1, else 0. XP += Σscores / 5, and level = 1 + XP / 60. The wage is paid
  regardless of quality; there are no money penalties.
- **Friendship** (`data/orders/stories.json`): Perfect +3, Great +2, Good +1 points. Hearts come at 4 / 10 / 18 points. Each heart
  unlocks the next story beat (played before that customer's next order) and +10% tips from them.
- **Shop** (day summary only): Shot Timer Pro (green zone +1 g per level), Steam Control (−2 °C/s per level), Bigger Tip
  Jar (+25% tips), and 5 decorations (+5% tips each, shown in the café).
- **Save** (`scripts/core/save_game.gd`): `user://brewtopia_save.json`, with types checked on load and written via .tmp then rename.
  It's saved at order start (recipes seen, story beat), after each Continue (friendship), at the day summary (money, XP),
  on next day, on purchases and on the finale. Audio settings are in `user://settings.json`.

## 3. Current development status

### 3.1 Implemented and working
Everything in the README feature list is wired up. On 2026-11-01:
- all 26 scripts in `scripts/` and `tests/` passed Godot's `--check-only` parse;
- `tests/test_espresso_model.gd` printed **PASS**;
- `tests/regression_flow.gd` printed **FLOW PASS**. It clicks through a whole Gula Melaka Latte with real mouse events: grind,
  tamp, lock, cup, shot, milk, latte art, syrups, toppings, serve.

Also on 2026-11-01:
- `tests/capture_views.gd` rendered 12 views (counter, choices, brewing, steam, latte art, toppings, result, shop, decor,
  recipe book) with no errors.
- The main scene ran for 600 frames with no errors.
- A one-off smoke script (kept outside the repo) passed. It loaded the title and day-1 café, loaded a day-3 save with all
  decor and upgrades (6 orders, upgrades applied), round-tripped the save, built `DayPlan` days 2–12 at levels 1/3/6
  (valid recipes and customers), and confirmed a corrupt save falls back to a fresh game.

Not tested by playing: full later days, friendship arcs and story beats in play, the finale, saving across real sessions,
and Android builds and touch input.

**Bug-fix branch `feature/adeeb-brewtopia-work` (2026-11-01; fixes 1–6 committed in `3063dd4`):** six fixes, all in section 4.1 (assist
levels, Mocha latte art, milk temperature, latte-art Skip and timeout, drink discard, syrup/topping Undo). Phase 7 regression:
- all scripts parse; unit tests pass;
- `regression_flow.gd` passes at three window sizes;
- `capture_views.gd` differs from the pre-fix screenshots only where requested;
- a scripted real-input run of day 1 plus a day-2 Mocha and Cappuccino scored 100 on every drink, with correct wage, tips,
  XP, friendship and saves.

Details and what wasn't tested: `TESTING_CHECKLIST.md` → "Verified outcomes".

### 3.2 History of the redesigns (from git)

| Date | Commit | What changed |
|---|---|---|
| 10-21 | `5afb910` | Espresso vertical slice, Android export, HMS plugin skeleton |
| 10-21 | `419bfde`, `bbee7fa` | Chapter 1 three-order shift with mentor dialogue; code-drawn pixel café and characters |
| 10-21 | `ca6220d` → `4761687` → `175df41` → `9339e48` | Brewing went from step menus → hands-on drag and drop → **first-person 3D pixel-art bar** (the unused "pov" code in `bar3d.gd` is from this stage), with large scale readouts |
| 10-21 | `4e2937c` | **Isometric 3D café** with walking customers |
| 10-21 | `ffec151` | **2D front-view espresso station** ("Good Coffee style"), placeholder sprites rendered from the 3D props (`tools/render_sprites.gd`) |
| 10-21 | `7a97af7` | GCGC-style counter, milk steaming, toppings, recipe book, shop, HUD, `DrinkModel`, `SaveGame` |
| 10-21 | `d5e462a` | **Evening** restyle: KL skyline at dusk, dark wooden counter, patience bar on the order bubble (`counter_bg.png` / `counter_front.png` are from this stage and are now unused) |
| 10-22 | `0a90765` | Iso café rebuilt "to the brewtopia 2 reference" with Kenney characters and furniture; SnapZones; 2 groups; iced drinks; steam popup; latte art; DayPlan; recipe unlocks; friendship; decor; **daytime** palette |
| 10-31 | `1871d64` | **Current visual design:** both stations repainted by `tools/make_topping_art.gd` (measured anchors kept); Silkscreen digits for readable numbers; café restyle; title screen; brown-sign dialogue, order note, objective panel, result breakdown; "fairer scoring"; story finale; generated audio; regression test |
| 10-31 | `edcac39` | Two BGM tracks; in-game Menu (volume, mute, sound, pause) |
| 10-31 | `19191e0`, `5408e06` | Unrelated GitHub "Initial commit" (README line) merged in |
| 11-01 | `b6419d0` | README with screenshots |

The "brewtopia 2 reference" and the GCGC references are mentioned in commits and comments but aren't in the repository.

### 3.3 Not implemented or unfinished
- **Huawei services:** `addons/HmsPlugin/` contains the .aar files and an export plugin (v0.0), but no game code calls it
  (README: "integration in progress").
- The project and package names are placeholders (`UXHMAC 2026`, `com.uxhmac.game`).
- `assets/art/CREDITS.md` doesn't record a source for the logo (`assets/art/ui/brewtopia_logo.png`) or the BGM.
  Commit `0a90765` says `tools/import_art.gd` can bring in "AI or pack art". Which current assets, if any, came that way is
  **unknown**. Commit `1871d64` says the station art was painted by `tools/make_topping_art.gd`.

## 4. Known issues

### 4.1 Confirmed (verified in code, data, arithmetic or screenshots)
1. ~~**Assist levels:** `"full"` and `"hints"` behave the same.~~ Fixed on `feature/adeeb-brewtopia-work` (uncommitted):
   full shows detailed lines with target values plus the guide arrow; hints shows short lines without exact
   measurements and the outline only; none is unchanged.
2. ~~**Mocha latte art:** the minigame runs but isn't scored.~~ Fixed on `feature/adeeb-brewtopia-work` (uncommitted), as
   the user chose: `mocha.json` now has `"latte_art": true`, so Mocha art is scored like the other latte-art drinks
   (shot 55% / milk 30% / art 15%). Remaining gap: the minigame still triggers on the cup type (`pour_milk`), not the
   recipe flag, so a future hot ceramic-cup recipe without `latte_art` would bring the same issue back.
3. ~~**Lukewarm milk:** labelled COLD but poured as hot.~~ Fixed on `feature/adeeb-brewtopia-work` (uncommitted): one
   temperature scale (`milk_heat()`: cold < 20 °C, warm 20–39 °C, steamed ≥ 40 °C) drives the pitcher tag (EMPTY / COLD /
   WARM / STEAMED), hover text, messages, cup drawing and the latte-art trigger. Warm milk can be refilled at the fridge,
   and iced drinks with warm or steamed milk point back to the fridge. Scoring was already using the real temperature and is
   unchanged.
4. **Moon icon unreachable:** the clock is 8:00 + 20 min × order index; max 8 orders → 10:20 AM, and the moon shows from 6 PM.
5. **Ambiguous text (fixed on feature/adeeb-brewtopia-work):** Pixelify's own glyphs showed 5 as "S", C as "O" and
   "fi" as "A" (`docs/screenshots/espresso_bar.png`: "Step S of 11", "about 2S-30 s", "portaAlter"; ticket "MAKOIK"; buttons
   "Reoipes", "Oontinue").
   - C and c: their openings were under one design pixel tall, and the 600/700 weights close them further. The game now
     uses `PixelifySansBrew.ttf`, made by `tools/patch_pixelify.py` (fontTools): C's opening grows one design pixel each
     way, c loses its bottom hook, 5 gets a square top-left corner and a flat top bar (it was drawn like S), and the `liga` feature (fi/fl/ff ligatures) is removed. The original `PixelifySans.ttf` is kept as the source.
   - Digits: the objective panel, ticket and dialogue use `PixelUI.number_label()`, like the HUD and result.
     `BrewtopiaDigits` no longer maps `.`, `:` (Silkscreen Bold's full stop is a bar: "please_") or `4` (a solid block).
6. **Ticket over the customer (fixed on feature/adeeb-brewtopia-work):** the ticket was 256 px wide with its left edge at
   x 1012, over the head (`head_rect` x 874–1055). It's now `TICKET_W` 220 (left edge 1048). The cup picture beside the
   order lines was dropped, so the text column grew from about 172 to 180 px. Long names ("OFFICE WORKER") wrap to 2 lines.
7. ~~**Mid-day quit:**~~ Fixed on feature/adeeb-brewtopia-work (uncommitted). Before: friendship and story beats were saved
   per order but money and XP only at the summary, and the day number only on "Next day", so a mid-day quit kept
   friendship (farmable by replaying), a summary quit paid the day twice, and the replayed day could differ (`recipes_seen`
   had grown). Now `CafeShift` writes the save once, at the summary, with `save.day` already moved to the next day
   (`shift_day` holds the day being played). Quitting mid-day restarts the day exactly as it began; quitting on the summary
   keeps it. No save keys changed. Trade-off: if the app is killed mid-day, that day's friendship is lost along with its
   money and XP.
8. **Patience** isn't reset by "Make it again", and reaching 0 has no effect beyond 0 tips. (Fixed on
   feature/adeeb-brewtopia-work: it no longer drains while the Recipe Book or the latte-art popup is open.)
9. ~~**No undo or discard:**~~ Fixed on `feature/adeeb-brewtopia-work` (committed in `3063dd4`): an Undo button for
   syrups and toppings, discarding a drink by dropping its cup back on the rack or cup stack, and a Skip button plus 30 s
   timeout for latte art. To make them discoverable (uncommitted): day-1 mentor lines in `ch1_first_shift.json` (latte order:
   Skip and the timeout; kaw order: discard; Gula Melaka order: Undo), and on guided orders a pump past the recipe or an
   extra not in it says "… Tap Undo."
10. **Unused leftovers:** `bar3d.gd` pov brewing mode; `char_*.png`, `counter_bg.png`, `counter_front.png`,
    `pitcher_rack.png`, `assets/audio/music.wav`, `assets/ui/hud/dialog.png` / `dialog_pointer.png`;
    `EspressoStation.next_hint()`; the `shot_finished` / `milk_frothed` signals have no listeners. Comments reference
    `ART_LIST.md`, which doesn't exist.
11. **Generators would overwrite current art:** `tools/render_sprites.gd` writes `milk_fridge.png` (not in `KEEP.txt`).
    `tools/gen_iced_art.gd` writes `ice_bin.png` without checking `KEEP.txt`. `tools/make_topping_art.gd` rewrites
    most station sprites by design.
12. `regression_flow.gd` exits with "2 ObjectDB instances leaked" and "1 resources still in use" warnings (the test
    still passes).
13. `Bar3D.steam_wisps()` (`bar3d.gd:145`) starts timers of up to 1.2 s whose callbacks use the steam puff nodes. If the
    café or title is freed before they fire, Godot prints "Lambda capture at index 0 was freed" and "Cannot call method
    'create_tween' on a null value". This was reproduced by freeing the scenes early. No gameplay effect.
14. More digit and letter confusion seen in `capture_views.gd` output: the Shop reads "tip 28%" for 25%, the Recipe Book
    "2S to 30 seconds", and the recipe buttons "Ioed Latte", "Oappuooino", "Mooha".

### 4.2 Suspected (not verified at runtime)
- The objective panel grows downward with hint or feedback lines and may cover the grinder hopper and the iced-cup stack.
- The New Game `ConfirmationDialog` probably uses Godot's default style rather than the pixel UI.
- The 3D café (outline shader on every mesh) renders behind the title and during dialogue; mobile performance is untested.
- Input is mouse-event based and relies on Godot's default touch-to-mouse emulation on Android; multi-touch isn't handled.
- The layout is fixed at 1280×720; phones with 19.5:9 or 20:9 screens will letterbox.
- The working tree has a local, uncommitted change to `assets/models/characters/Textures/colormap.png.import`
  (lossless → VRAM compressed). Its visual effect hasn't been checked.
- `SaveGame.write` doesn't check the result of the rename.

## 5. Areas needing caution
- **`espresso_station.gd` (≈1800 lines) and `cafe_shift.gd` (≈1230 lines)** mix state, input, drawing and layout.
  Make small edits only.
- **Coordinates tied to the art:** many station constants are pixel positions in specific PNGs. Move a sprite and
  its SnapZone together, keep each item's drop anchor (portafilter basket centre, cup centre, pitcher centre) in mind,
  and update the matching `guide_rect()` target.
- **The drink dictionary** is the only contract between the station and the scorer. Don't rename its keys.
- **Scoring and rewards** (`espresso_model.gd`, `drink_model.gd`, `shift_rewards.gd`, `friends.gd`, the tip formula in
  `cafe_shift.gd`) are covered by the unit test, and the mentor wording depends on the order of the issues.
- **Save schema** keys in `save_game.gd` and **data JSON keys** in `data/`.
- **Generated assets:** edit art through its painter in `tools/`, or replace a PNG at the same size and density and record
  it in `KEEP.txt` and `CREDITS.md`.
- **Line endings:** there's no `.gitattributes`, so Windows checkouts show CRLF-only changes on `.import` files.

## 6. Recommendations (for the team to decide; none of this has been done)
1. Keep running the three test entry points (see `CLAUDE.md`) before and after every change. Consider adding scripted
   checks for later-day systems (DayPlan, friendship, finale), because only day-1 order 4 is covered by the click-through.
2. Text legibility: done (item 5 above). On a phone, check that nothing else reads badly at real size.
3. Decide the intended behaviour for the confirmed issues (patience on "Make it again") before changing anything, because several of them affect scoring or saves.
4. Fill the provenance gaps in `assets/art/CREDITS.md` (logo, BGM) before submitting.
5. Plan the HMS integration and final app identity (name, package, icon) if the competition requires them.
6. Add a `.gitattributes` to stop CRLF churn, and decide whether to keep the `colormap.png.import` change.
7. Unused code and assets (section 4.1, item 10) could be removed in a dedicated clean-up change, after confirming nothing
   (including `tools/`) still needs them.
