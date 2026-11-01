class_name PixelUI
## The game's shared pixel-art UI pieces: the font (Pixelify Sans, SIL OFL 1.1) and the
## 9-slice frames in res://assets/ui/ (painted by tools/make_menu_art.gd at 3 screen px per
## art pixel, so they are used 1:1). One place for the look of every panel and label.

## Pixelify Sans with wider C/c openings (they read as O/o), a square-topped 5 (it read as S)
## and no fi/fl/ff ligatures: made from
## PixelifySans.ttf by tools/patch_pixelify.py.
const FONT := "res://assets/fonts/PixelifySansBrew.ttf"
## Numbers that must read at a glance (the result score): Silkscreen Bold (SIL OFL 1.1, see
## assets/fonts/Silkscreen-OFL.txt). Its 5 is not an S, its 0 not an O. Imported with
## antialiasing, hinting and subpixel positioning off; use sizes in steps of 8 (40 = 5 px
## per font pixel) so it stays crisp.
const NUMBER_FONT := "res://assets/fonts/Silkscreen-Bold.ttf"
const NUMBER_PX := 40
## Silkscreen Bold with only 0-9 . : / mapped (tools/make_digit_font.gd).
const DIGITS_FONT := "res://assets/fonts/BrewtopiaDigits.ttf"
const HUD := "res://assets/ui/hud/%s.png"
const MENU := "res://assets/ui/main_menu/%s.png"

static var _numbers := {}  # weight -> Font


static func font(weight := 600) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(FONT)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


## The font for number readouts ("RM 12", "36.0 g · 27 s", "Day 2 · 8:40 AM"): digits and
## . : / from Silkscreen, everything else from Pixelify (its fallback), so a label can mix
## them freely. Use sizes in steps of 8 (16, 24, 32, 40) to keep the digits crisp.
static func numbers(weight := 600) -> Font:
	if not _numbers.has(weight):
		var f := FontVariation.new()
		f.base_font = load(DIGITS_FONT)
		var letters := font(weight)
		letters.spacing_space = 2  # Silkscreen digits have no left bearing; a wider gap keeps "quality 100" apart
		f.fallbacks = [letters]
		_numbers[weight] = f
	return _numbers[weight]


## Makes `l` a number readout: numbers() font at `size_px` (keep it a multiple of 8).
static func number_label(l: Label, size_px: int, weight := 600) -> Label:
	l.add_theme_font_override("font", numbers(weight))
	l.add_theme_font_size_override("font_size", size_px)
	return l


## A 9-slice frame; `margin` = texture margins (l, t, r, b), `content` = padding (or -1).
static func frame(path: String, margin: Vector4i, content: Vector4 = Vector4(-1, -1, -1, -1)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margin.x
	s.texture_margin_top = margin.y
	s.texture_margin_right = margin.z
	s.texture_margin_bottom = margin.w
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	if content.x >= 0:
		s.content_margin_left = content.x
		s.content_margin_top = content.y
		s.content_margin_right = content.z
		s.content_margin_bottom = content.w
	return s


## Cream sign with a gold rim: popups (steam, latte art, recipe book, shop, credits).
static func cream_panel(pad := 22.0) -> StyleBoxTexture:
	return frame(MENU % "button_cream_normal", Vector4i(15, 15, 15, 18), Vector4(pad, pad, pad, pad + 3))


## Dark wood pill (HUD badges, small readouts).
static func wood_pill(pad_x := 14.0) -> StyleBoxTexture:
	return frame(HUD % "pill", Vector4i(12, 9, 12, 12), Vector4(pad_x, 4, pad_x, 8))
