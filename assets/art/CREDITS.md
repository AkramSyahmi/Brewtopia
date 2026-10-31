# Art credits

Where every replaced image came from (AI tool + plan, asset pack + licence, or who drew it).

## 3D models (café and customers)

- **Mini Characters** by Kenney (www.kenney.nl), CC0 1.0 (public domain). `assets/models/characters/` (licence: `License.txt` there).
- **Furniture Kit** by Kenney (www.kenney.nl), CC0 1.0 (public domain). `assets/models/furniture/` (licence: `License.txt` there).

Everything else in the café (counter, espresso machine, grinders, walls) is built in code (`scripts/iso/`).

## 2D sprites (barista station)

`tools/import_art.gd` adds a row here for every image it imports. Fill in the source.

| Sprite | Source file | Source / licence |
|---|---|---|
| `assets/fonts/PixelifySans.ttf` (title menu font) | google/fonts `ofl/pixelifysans/PixelifySans[wght].ttf` | Pixelify Sans, © 2021 The Pixelify Sans Project Authors (github.com/eifetx/Pixelify-Sans), SIL Open Font License 1.1 (licence text: `assets/fonts/PixelifySans-OFL.txt`) |
| `assets/ui/main_menu/*.png`, `assets/ui/hud/*.png` (menu + HUD frames, dialogue, ticket, icons) | painted by `tools/make_menu_art.gd` | original, made for this game |
| `assets/fonts/Silkscreen-Bold.ttf` (result score digits) | google/fonts `ofl/silkscreen/Silkscreen-Bold.ttf` | Silkscreen, © 2001 The Silkscreen Project Authors (github.com/googlefonts/silkscreen), SIL Open Font License 1.1 (licence text: `assets/fonts/Silkscreen-OFL.txt`) |
| `assets/fonts/BrewtopiaDigits.ttf` (number readouts) | made by `tools/make_digit_font.gd` from Silkscreen-Bold.ttf (character map cut to 0-9 . : /, glyphs unchanged) | Silkscreen, © 2001 The Silkscreen Project Authors, SIL Open Font License 1.1 (modified version; licence text: `assets/fonts/Silkscreen-OFL.txt`) |
