# BREWTOPIA: regression checklist

Use this after any change. First run the automated checks, then walk the manual sections that touch what you
changed. Mark each item ✅ pass / ❌ fail / ⏭ not run, and report what was skipped. Expected values come from the
current code and data (see `PROJECT_HANDOVER.md` §2). If the game disagrees with the checklist, check the code before
assuming either one is wrong.

## Verified outcomes: `feature/adeeb-brewtopia-work`, 2026-11-01 (Phase 7, uncommitted bug fixes 1–6)

Run with Godot 4.7.2 on Windows (Intel Iris Xe, Vulkan, Forward Mobile). "Scratch" = one-off check scripts kept outside
the repo; they drive the real game code, mostly through real mouse events.

| Area | How | Result |
|---|---|---|
| Script parse | `--check-only` on all 26 scripts in `scripts/` and `tests/` | ✅ 0 errors |
| Scoring unit tests | `tests/test_espresso_model.gd` | ✅ PASS |
| Click-through (Gula Melaka Latte) | `tests/regression_flow.gd` at 1280×720, 1600×900, 1024×576 | ✅ FLOW PASS at all three (one intermittent failure earlier in Phase 6, see §0) |
| Screenshots | `tests/capture_views.gd` + pixel diff against pre-fix screenshots | ✅ 12 views, no errors. The only changes are the requested ones: hints-mode text and outline-only highlight, Undo button, Skip button. Recipe Book, steam popup and shop are identical. |
| Full day, real input | Scratch: day 1 (Double Espresso full assist, Latte hints, kaw espresso no assist, Gula Melaka Latte hints) + day 2 Mocha and Cappuccino | ✅ All six drinks 100 with real grind, tamp, lock, shot, steam (hold and drag), latte-art tap, toppings and serve. Friendship +3 each; summary RM40 wage + RM17 tips = RM57 and XP +80 (level 2), matching the formulas; save file matches; day 2 saved; title Continue shows "Day 2 · Lv 2 · RM 57". |
| 1. Assist modes | Scratch, 6 recipes × every objective state × full/hints/none | ✅ Levels differ as documented; lines ≤ 2; panel bottom 199 px in both; no scoring effect |
| 2. Mocha latte art | Scratch, scores and in-game result | ✅ Art 0.9 / 0.65 / 0.2 → 100 / 98 / 93, same as the other latte-art drinks; drinks without art unchanged |
| 3. Milk states | Scratch, real fridge / steam / Done / pour paths | ✅ COLD < 20 °C, WARM 20–39 °C, STEAMED ≥ 40 °C agree for tag, pour, cup, latte art and objective; scores use the real temperature |
| 4. Latte-art exits | Scratch, real clicks | ✅ Normal, early skip, skip after pour, timeout, pause during the timeout and the hold, repeated clicks, three drinks in a row: always exactly one completion |
| 5. Discard | Scratch, real drags | ✅ Espresso, milk, toppings, after art, ice-only, both cups out; reuse a fresh cup and serve a new drink; save unchanged; nothing served or rewarded |
| 6. Undo | Scratch, real clicks | ✅ One or many pumps, mixed order, empty history, two cups, leaving and re-entering the page, serve and discard after undo |

**Font and ticket fix (A + B, uncommitted, 2026-11-01):**

| Area | How | Result |
|---|---|---|
| Parse, unit tests, click-through | all 32 tracked scripts; `test_espresso_model.gd`; `regression_flow.gd` at 1280×720, 1600×900, 1024×576 | ✅ 0 errors; PASS; FLOW PASS ×3 |
| Fix checks 1–6 and the full day | the same scratch scripts as above | ✅ all PASS (assist, Mocha, milk, latte art, discard, undo, full day) |
| Objective line length | every full-assist line (worst-case values) measured with `numbers()` | ✅ all ≤ 2 lines at 16 px (17 px would make 6 of them 3 lines) |
| Ticket vs head | `head_rect()` of the customer at the counter vs the ticket rect, plus 5 worst-case slips | ✅ ticket x 1048–1268, head ends at 1055 (rect) / ~1035 (drawn); all slips fit, long names wrap to 2 lines |
| Screenshots | `capture_views.gd` pixel diff against the commit `3063dd4` | ✅ only the objective panel, ticket and dialogue differ (plus café animation noise); the shop, Recipe Book and latte-art windows are unchanged |

| Fonts (follow-up) | `make_digit_font.gd` re-run (`CHARS` = `012356789/`); `tools/patch_pixelify.py` → `PixelifySansBrew.ttf`; zoomed screenshots | ✅ full stops and colons are Pixelify ("please." not "please_"); 4 is Pixelify ("ORDER 4/4"); "MAKCIK", "Recipes", "Excellent", "cup of coffee", "CURRENT OBJECTIVE", "portafilter" all read correctly; Godot import settings identical to the original font |
| Squared 5 (follow-up) | `patch_pixelify.py` re-run; 5 vs S rendered at 15–24 px, weights 600/700, game import settings; Recipe Book screenshot | ✅ 5 has a square corner and flat top at every size ("5S", "55" vs "SS"); Recipe Book reads "25 to 30 seconds"; unit tests, `regression_flow.gd` ×3, `capture_views.gd`, full day PASS; title 600 frames: no script errors (1 of 4 runs printed an exit-time "resources still in use" warning, like the known leak warnings) |
| After the font change | unit tests, `regression_flow.gd` ×3 sizes, `capture_views.gd`, scratch checks, title 600 frames, objective line lengths | ✅ see the final report (all PASS, lines ≤ 2) |

**C (patience) + D (discoverability), uncommitted, 2026-11-01:**

| Area | How | Result |
|---|---|---|
| Patience holds | Scratch: drain over 1 s at the bar, with the Recipe Book open, during latte art, and after each closes | ✅ 0.0068/s normally; 0 with the book open; 0 during latte art; drains again after both |
| Undo nudges | Scratch, real clicks on the topping page | ✅ 2 pumps (recipe amount): normal message; 3rd pump: "Too many pumps of gula melaka. Tap Undo."; vanilla / cocoa (not in the recipe): "No … in this recipe. Tap Undo."; recipe topping: no message; one panel line each |
| No spoilers | Same, on a no-assist order | ✅ plain "1 pump of …" message, no topping message |
| Day-1 tips | `ch1_first_shift.json` parsed; each mentor line paginated | ✅ Skip/timeout, discard and Undo lines present; each fits 2 bubble pages |
| Regression | parse (all scripts), unit tests, `regression_flow.gd` ×3, `capture_views.gd`, every scratch check, full day | ✅ all PASS |

Not checked for C + D: playing day 1 by hand to read the new mentor lines in context.

**E (save only at the day summary), uncommitted, 2026-11-01:**

| Area | How | Result |
|---|---|---|
| Mid-day quit (day 1) | Scratch: serve order 1 with real input, reach order 2's intro, quit, reopen | ✅ no save file written mid-day; restart is day 1 exactly as it began (friends {}, story beats {}, money 0, XP 0) |
| Menu note | Same | ✅ "Leaving now restarts today." shows mid-day, hidden on the summary |
| Summary | Finish day 1 | ✅ save has day 2, RM 57, XP 80, friendship +3 each, story beats and recipes_seen; summary still reads "DAY 1 COMPLETE" and the clock "Day 1" |
| Summary quit | Buy an upgrade on the summary, quit, title, Continue | ✅ title "Day 2 · Lv 2 · RM 27"; day 2 starts with no second payment and the upgrade kept |
| Mid-day quit (day 2) | Serve day 2 order 1, quit, reopen | ✅ save file byte-identical; same 5-order day-2 plan and recipes_seen |
| Finale | `play_finale` after the summary | ✅ finale_seen saved with day 3 |

**Dialogue per speaker, uncommitted, 2026-11-01:**

| Area | How | Result |
|---|---|---|
| Customer line | Scratch screenshots of day 1 | ✅ cream sign at (296, 64), left of the customer's head, pointer on its right edge aimed at the head; clear of the HUD and ticket |
| Mentor line | Same, plus the result screen | ✅ brown/gold sign with the cup at (335, 348), left of the mentor, pointer at the mentor's head; on RESULT it stays above the result strip |
| Player | First CHOICE and the picked answer | ✅ charcoal box at the bottom centre with "You" and the answer buttons (no pointer); the picked answer shows as a "You" line until Next |
| Faces | `tools/render_portraits.gd` → 5 portraits (32×32); screenshots of customer, mentor and result lines | ✅ each customer / mentor line shows that character's face at 96 px (whole head, hair or headscarf, shoulders), matching the café model; the player's box has no face |
| Regression | parse, unit tests, `regression_flow.gd` ×3, assist/art/undo/C+D/E checks, full day, title 600 frames | ✅ see the report |

**Faster grinder and shot (fast, then slow near the target), uncommitted, 2026-11-01:**

| Area | How | Result |
|---|---|---|
| Grinder | Scratch: the station's own rule, latte recipe | ✅ 18 g in 3.1 s (was 4.5 s); let-go window ±0.5 g = 0.40 s (was 0.25 s) |
| Shot | Scratch: `shot_speed()` for grinds 1, 3, 5, 6, 8, 10 | ✅ target reached at 11.5 / 8.8 / 7.1 / 6.4 / 5.6 / 4.5 s real (was 33.6 / 21.5 / 13.8 / 11.0 / 7.0 / 4.5 s); green-zone windows unchanged (3.73 / 2.39 / 1.52 / 1.22 / 0.78 / 0.50 s); the shot clock still shows simulated seconds (28 s at the ideal grind) |
| Regression | parse, unit tests, `regression_flow.gd` ×3, `capture_views.gd`, full day (real input, every drink ≥ 90), all scratch checks | ✅ all PASS |

**Mentor faces the player while she talks, uncommitted, 2026-11-01:** screenshots of a mentor line, a customer line and the
result screen: ✅ she faces the camera (face matches her portrait, clear of the bubble) on her lines and the result note, and
turns back to the counter for the customer's line; the bubble still aims at her head.

**Steam popup redesign, uncommitted, 2026-11-01:** screenshots (open, steaming, both in the green, over, a "hints" order):
✅ "Steam Milk" banner and red X; Froth gauge | pitcher | thermometer with °C box | numbered "How to Steam" steps and Done;
gauges are drawn pixel tubes (ticks, pale-green band with green edge lines, a green bracket beside the tube, level pointer;
the fill turns green inside the band); steam clouds rise from the rim only while steaming; the legend shows the exact targets
on "full" orders only (hidden on "hints"/"none"). Same footprint as before (x 690 →), so the left group head stays in view.
Regression: parse, unit tests, `regression_flow.gd` ×3, `capture_views.gd`, assist / undo / milk / cd / full-day checks ✅ all PASS.

**Name, icon, remake patience, New Game sign, vibration, uncommitted, 2026-11-01:** scratch click-through ✅: config name
BREWTOPIA and the icon loads; New Game opens the cream sign with Cancel focused and the day named; Cancel and Esc close it and
keep the save; Start fresh resets the save and opens the café; a failed drink at 10% patience → "Make it again" → 50%; at 80% it
stays 80%; `Sfx.buzz` is silent on desktop. Not checked: vibration and the launcher icon on a real phone (needs an APK).

**Brew buttons, uncommitted, 2026-11-01:** the two knobs on `machine.png` start and stop their group's shot (`knob0`/`knob1`
zones, 34×34 base px, clear of the portafilters and drop zones); the portafilter tap still works. Screenshots: ✅ the brew step
outlines the left knob ("Tap the brew button above the portafilter to start.", 2 lines); the knob glows green while the shot runs.
`regression_flow.gd` now expects the brew step's guide on `knob0` (was `group0`, an intended change), starts with the portafilter
tap and stops with the knob: ✅ FLOW PASS ×3. Parse, unit tests, `capture_views.gd`, assist / undo / milk / cd / full-day checks ✅.

Not checked for the timing: how it feels by hand on a phone (touch delay in the 1.5 s green window).

Not checked for A + B and the fonts: on a phone (text size at real scale), dialogue lines with digits shown in play, and
every screen for other letters that might read badly (only the screens in `capture_views.gd` were looked at).

**Not tested:** Android build and touch, a real 30 s latte-art wait (the clock was advanced to 29.6 s), live hand-play
by a person, days 3+ (pair orders, vague orders, story beats and finale in play), and save files from older builds.

## 0. Setup and automated checks

Godot 4.7.2 on this machine is `C:\Users\HP\Documents\Godot\Godot_console.exe` (adjust the path elsewhere). Run from the repo root.

- [ ] `git status` before and after: only the files you meant to change differ. Editor-made CRLF `.import` churn
      was already present on 2026-11-01; don't commit it by accident.
- [ ] Parse check every script you touched:
      `Godot_console.exe --headless --path . --check-only --script res://<path>.gd` → no `SCRIPT ERROR`, exit 0.
- [ ] Scoring unit tests: `Godot_console.exe --headless --path . --script res://tests/test_espresso_model.gd` → `PASS`.
- [ ] Click-through regression (needs a window): `Godot_console.exe --path . --script res://tests/regression_flow.gd -- <out_dir>`
      → `FLOW PASS`. Look through the screenshots in `<out_dir>` (keep it outside the repo). Baseline: 2 leak warnings at exit are normal.
      It runs in a real window: moving the real mouse over it during the run can turn its simulated taps into drags (seen
      once on 2026-11-01 as "tap did not start the shot"). Re-run without touching the mouse before treating it as a bug.
- [ ] Visual changes: `Godot_console.exe --path . --script res://tests/capture_views.gd -- <out_dir>` → 12 screenshots
      (counter, choices, brewing, steam, latte art, toppings, result, shop, decor, recipe book). Compare before and after.
- [ ] Compare the **full** `git status --porcelain` before and after every Godot run (don't filter `.import`).
- [ ] For manual play, start a clean game with **New Game**, or delete `user://brewtopia_save.json` (Godot:
      Project → Open User Data Folder). The tests use `user://test_save.json` instead.

## 1. Main menu (`scripts/ui/title_screen.gd`)
- [ ] Fades in; the logo bobs gently; "A Malaysian café story" plaque sits between the lettering and the bean line.
- [ ] The 3D café renders behind a cream wash on the left; the mentor stands bottom-right; bought decor appears.
- [ ] With no save: Continue is disabled and greyed, and says "No saved café yet"; New Game has keyboard focus.
- [ ] With a save: Continue shows `Day N · Lv N · RM N` in clear digits and starts the game.
- [ ] New Game with a save asks "Start a new café? Your Day N progress will be lost." Cancel keeps the save; "Start
      fresh" deletes it and starts day 1.
- [ ] Music and Sound toggles change their labels and take effect; the setting survives a restart (`user://settings.json`).
- [ ] Credits toggles the cream credits panel. Quit closes the game (desktop only; hidden on mobile).
- [ ] Every button clicks; held buttons dip; the title music ("Sunshine on the Saucer") plays and fades to the café track in-game.

## 2. Customer orders and dialogue (`scripts/cafe/cafe_shift.gd`, `scripts/counter/counter_screen.gd`)
- [ ] The bell rings; the customer walks in from the right to the counter; the mentor turns to them; "!" emote.
- [ ] Dialogue bubble (top-left): gold speaker name, cream text, at most 3 lines per page, and Next turns pages.
      CHOICE lines show answer buttons; the chosen line is said by "You".
- [ ] After the intro: an order bubble near the customer's head (cup with drink + "X, please!" + extras), or "?" for a
      vague order. The order ticket (top-right) shows name, "Friend n/3", order lines, and "18 g in · 36 g out" for espresso.
- [ ] The ✕ on the ticket hides it; tapping the ORDER badge brings it back; the ORDER n/N count is right.
- [ ] The next customer waits in the queue spot while the current one is served.
- [ ] Day 1 sequence: Student / Double Espresso → Office Worker / Latte → Coffee Lover / Double Espresso (kaw, no
      guidance) → Makcik / Gula Melaka Latte.
- [ ] Day 2+: 3 + day orders (max 8); a newly unlocked recipe comes first with a mentor explanation; vague orders hide
      the drink in the slip, objective and guide until it's served.

## 3. Coffee grinding and portafilter (`espresso_station.gd`)
- [ ] One portafilter on the mat, one locked in the right group head at the start of an order.
- [ ] Dragging a portafilter follows the pointer; dropping it near the grinder fork, mat or a free group head snaps it into place;
      dropping elsewhere returns it.
- [ ] The grind display starts at "Grind 8"; −/+ change it within 1–10.
- [ ] Holding the grinder with a portafilter in the fork: grounds stream, grinder sound, the scale screen and "x.x g / 18 g" bubble
      rise fast (8 g/s), then slow (2.5 g/s) for the last 3 g; the bubble turns green within ±0.5 g of the dose and red above +1 g.
- [ ] Holding the grinder with no portafilter warns "Coffee is going everywhere!" and adds nothing.
- [ ] Releasing over a button still stops the grinder; a drag released over a button still drops the item.
- [ ] Dropping a used portafilter on the knock box empties it (knock sound) and returns it to the mat if the mat is free.

## 4. Tamping
- [ ] Tapping the tamper with a dosed portafilter on the mat: the press animation plays, a thud sounds, the sprite becomes tamped,
      and the feedback reads "Tamped! Nice and level."
- [ ] No portafilter, an empty one or a used one gives the matching message, with no state change.
- [ ] Grinding more onto a tamped basket returns it to dosed.

## 5. Espresso extraction
- [ ] Taking a latte cup (left of the rack), a glass (right) or an iced cup (stack); a third cup is refused ("two cups out").
- [ ] A cup snaps onto either scale under the group head, centred, with a contact shadow, drawn behind the portafilter.
- [ ] Tapping the brew button (the round knob above each group head) starts that group's shot: stream, pour sound, a timing bar
      with a green zone, and "x.x g · n s"; the knob glows green while it runs. Tapping the locked portafilter does the same.
      Hovering a knob says "Brew button: tap to start or stop the shot". The tutorial outline (and arrow on "full") is on the knob.
- [ ] Tapping the knob (or the portafilter) again stops it: feedback Perfect / Good / Bad with a reason (fast or slow grind, short or long); the portafilter becomes used.
- [ ] Reference calculations (dose 18, tamped): grind 5 → pace about 27.5 s (in window); grind 8 → about 14 s ("ran fast").
- [ ] No cup → "going down the drain"; no portafilter, an empty one or a used one gives a message, and no shot starts.
- [ ] The shot stops by itself at 70 g. Both group heads can run at once.

## 6. Milk preparation
- [ ] Hovering the fridge door shows a tooltip and outline; dragging the pitcher there shows "Release to fill".
- [ ] Dropping it on the fridge: "Cold milk added!", the pitcher tag reads COLD, white milk shows in the pitcher.
- [ ] An empty pitcher on the steam wand is refused; a filled one opens the steam popup (on top of the HUD and order note).
- [ ] Holding on the pitcher heats it (thermometer, °C readout, steam sound, steam clouds off the rim); dragging lower fills
      the Froth gauge, higher only heats. A gauge's fill turns green inside its band. The red X does the same as Done. On a
      "full" order the legend shows the exact targets; on "hints"/"none" only "Target zones". Green zones: 60–65 °C, foam 0.25–0.40 (cappuccino 0.50–0.70).
- [ ] Done: STEAMED if ≥ 40 °C ("Steamed milk ready! … °C, silky foam / too flat / too foamy"); WARM if 20–39 °C ("only
      warm … not steamed yet"); COLD below 20 °C ("still cold"). The hover text matches the tag ("Warm Milk (30°C), not steamed yet").
- [ ] WARM milk: pouring it gives no latte art and "Poured warm milk (…°C)…", the cup shows flat milk, and the result says
      "too cool". Dropping it on the fridge pours it away and refills it cold. Steaming it again continues from its temperature.
- [ ] Iced drink with WARM or STEAMED milk in the pitcher: the objective says "This milk isn't cold. Refill the pitcher…" and
      points at the fridge. Pouring anyway scores "Milk warmed to …°C melts the ice!".
      The pitcher returns home with steam wisps.
- [ ] Dropping the pitcher on a cup with coffee pours it: the cup shows milk layers, and the pitcher resets to EMPTY. On an empty cup
      or with an empty pitcher you get a message.
- [ ] Iced drinks: cold milk poured straight in, with no latte art.

## 7. Latte art (`latte_art_panel.gd`)
- [ ] Hot milk into a ceramic latte cup opens the panel (dimmed backdrop; the objective panel hides).
- [ ] The pitcher swings; tapping near the middle makes a full rosetta with a heart ("Beautiful rosetta!"),
      a little off gives a lopsided rosetta, far off gives a blob. The panel closes about 2 s after the tap.
- [ ] Skip (small wood button under the cup): before tapping, it closes the panel, says "Latte art skipped.", draws no
      heart, and the result names "The latte art was skipped." (perfect drink otherwise: 91). After tapping, it only skips the
      wait and keeps the pour's score. Pressing it repeatedly does nothing more.
- [ ] Timeout: with no tap for 30 s the panel closes with "Time's up! Latte art skipped." (same score as a skip). The Menu
      pause stops the countdown. The next step (toppings or serve) is available after any ending.
- [ ] The cup then shows a pixel heart (brown on a foamy cappuccino cap, white on a latte), offset when poured badly.
- [ ] Clicks don't reach the bar while the panel is open.
- [ ] Latte art is scored for Latte, Gula Melaka Latte, Cappuccino, Caramel Macchiato and Mocha: with an otherwise perfect
      drink, art ≥ 0.8 → 100, 0.65 → 98, 0.2 → 93, and "Latte art" shows in the result breakdown. Iced drinks and the
      Double Espresso never open the panel.

## 8. Toppings (`espresso_station.gd`, page 2)
- [ ] Discard: dragging a cup with a drink (espresso, milk, toppings, latte art, or just ice) over the rack or plastic cup
      stack shows "Release to pour the drink away"; letting go removes it with "Drink discarded. Cup ready to reuse."
      Nothing is served, no result appears, money and friendship don't change. A new cup can be taken (even when both
      were out) and starts empty. Empty cups still go back silently.
- [ ] "Toppings >" slides to the toppings page; cups with coffee move onto the two mats; "< Espresso" slides back and
      returns them to their scale (or the counter if the scale was taken).
- [ ] The six syrup bottles and four topping tubs are labelled and line up with their tags.
- [ ] Tapping a syrup adds one pump ("1 pump of X (n total)"); tapping a topping adds it once ("It already has X" after that).
- [ ] Syrups and toppings go to the last-touched cup on a mat; with no drink on a mat you get "Bring a drink with espresso…".
- [ ] The cup shows the syrup tint and topping dots; the SERVE box lists the contents ("gula melaka x2", "cinnamon").
- [ ] Undo (small wood button under the Cream tub, topping page only): greyed out until something is added. Vanilla,
      chocolate, cinnamon → Undo removes cinnamon, then the chocolate pump, then vanilla. Each pump is undone separately
      ("Took back 1 pump of … (n left)"), counts never go below zero, and the cup tint, dots and SERVE list update at once.
      With two cups on the mats, Undo only changes the one touched last. History survives going to the espresso page and
      back, and is gone after serving or discarding that cup.

## 9. Serving and scoring (`drink_model.gd`, `espresso_model.gd`)
- [ ] Dragging a drink into SERVE (either page) serves it; an empty cup is refused ("The cup is empty").
- [ ] The result strip shows `Drink quality · Recipe accuracy · Service %`, the big score in clear digits, the grade word,
      per-category ratings, "To improve: …" (or "Everything was spot on!"), and Details with the raw numbers.
- [ ] The mentor note praises the parts that scored 100 and names one fix.
- [ ] A perfect drink scores 100 with all categories Excellent (see `docs/screenshots/result.png`).
- [ ] The wrong cup costs 30 accuracy; missing milk 40; missing ice 30; each syrup pump off 10; each topping missing or extra 10.
- [ ] Score < 40 → "?" emote and "Make it again" (back to the bar); the drink isn't counted. Patience comes back at 50% if it
      was lower (never lowered).
- [ ] Two-drink order: the first serve gives "Drink 1 of 2 served…" and you stay at the bar; the result after the second
      shows the average.
- [ ] Vague order: the result headline starts with "They wanted: <drink>".

## 10. Rewards and friendship (`friends.gd`, `shift_rewards.gd`)
- [ ] Continue: reaction line matching the grade; "<3" for Perfect or Great, ":)" otherwise; the customer walks out.
- [ ] Friendship: Perfect +3, Great +2, Good +1; at 4 / 10 / 18 points the mentor says "X likes you more now! (Friend n/3)";
      the ticket shows the new count.
- [ ] The next time that regular comes in, their story beat plays before their order.
- [ ] Day summary: "DAY N COMPLETE! Orders · Wage RM · Tips RM · XP +", coins sound; a level-up shows "LEVEL N!" and
      "New recipes tomorrow: …".
- [ ] The HUD money, level and XP bar update; the smiley % is the day's average score.
- [ ] Once all four stories are finished, "Next day" plays the mentor's farewell then the credits roll ("Keep the café
      open"), once only.

## 11. Shop and Recipe Book
- [ ] Shop (day summary only): Upgrades tab shows 3 upgrades with level bars and prices; Decor tab shows 5 items.
      Buying takes money, saves, and (decor) appears in the café. Unaffordable or maxed buttons are disabled.
- [ ] Recipe Book (HUD): lists 9 drinks; recipes above your level read "Locked (Lv N)"; selecting one shows ingredients and
      steps. Close, or a click on the dim backdrop, shuts it.

## 12. UI and navigation
- [ ] The HUD row fits: Lv + XP, Day · clock (sun icon), smiley %, RM, Recipes, Hint, Menu, ORDER. Captions drop to
      icons only if the row would overflow.
- [ ] Objective panel: "Step n of N: …" moves on only after the real action succeeds; the collapse arrow works; Hint adds
      a yellow hint line; feedback lines fade after about 4 s. It must not block drags or cover the equipment it points to.
- [ ] The yellow guide outline and arrow sit on the right equipment and follow moving cups.
- [ ] Assist levels (day 1: order 1 = full, orders 2 and 4 = hints, order 3 = none): full shows target values ("Set the grind
      to 5…18 g", "about 36 g… (25–30 s)", "60–65°C", pumps left) plus outline and bobbing arrow; hints shows short lines
      without exact numbers plus outline only, with the numbers on the Hint button; none shows no panel, highlight or Hint
      button, only feedback lines. Panel lines never wrap past 2 lines.
- [ ] Menu: pauses the game; the music volume slider (0–100%) is live; Music muted/on; Sound effects on/off; Resume; Main
      menu returns to the title.
- [ ] Modals (Recipe Book, Shop, Menu) block clicks to the game behind them.
- [ ] Numbers in HUD readouts, bubbles and the result use the clear digit font (5 isn't S, 0 isn't O).
- [ ] Nothing is cropped at 1280×720; optionally re-run `regression_flow.gd` at another size (`-- <out_dir> WxH`).

## 13. Save and load (`save_game.gd`)
- [ ] After finishing a day: quit, then Continue → the next day, with the same money, level, upgrades, decor and friendship.
- [ ] The save file `user://brewtopia_save.json` holds `money, xp, day, upgrades, friends, story_seen, decor,
      recipes_seen, finale_seen`, with no renamed or missing keys.
- [ ] An old save (from before your change) still loads with the same progress.
- [ ] A broken or empty save file starts a fresh game instead of crashing.
- [ ] Known behaviour: Main menu in the middle of a day restarts that day from order 1; friendship and story beats from
      that partial day stay saved, but money and XP don't.
