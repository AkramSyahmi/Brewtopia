extends SceneTree
## Generates Brewtopia's code-drawn pixel art into res://assets/sprites/.
## Run: Godot_console.exe --headless --path . --script res://tools/gen_art.gd
## Base resolution 640x360 (shown x2). Palette: GDD 8.1 plus helper shades.

const OUT := "res://assets/sprites/"

const ESPRESSO := Color("#36251D")
const BEAN := Color("#65422F")
const CARAMEL := Color("#BE895B")
const CREAM := Color("#F5E7CA")
const SAGE := Color("#8F9C7B")
const SAGE_DARK := Color("#66735A")
const WALL := Color("#D8B48A")
const WALL_LOW := Color("#A9774F")
const STEEL := Color("#9A9AA3")
const STEEL_DARK := Color("#5E5E68")
const STEEL_LIGHT := Color("#C9C9D1")
const GRINDER_BODY := Color("#3E3B40")
const PORCELAIN := Color("#FBF6EC")
const COFFEE := Color("#4A2A18")
const CREMA := Color("#C58B52")
const BLUSH := Color("#E89A8A")
const GLASS := Color(0.85, 0.93, 0.95, 0.75)

## 3x5 pixel font, rows top to bottom.
const FONT := {
	"A": "010101111101101", "B": "110101110101110", "R": "110101110101101",
	"W": "101101111111101", "Y": "101101010010010", "S": "111100111001111", "E": "111100110100111", "H": "101101111101101",
	"I": "111010010010111", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "111101101101111",
	"P": "111101111100100", "T": "111010010010010", "U": "101101101101111",
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	background()
	counter()
	grinder()
	scale_sprite()
	machine()
	cups()
	jar("jar_dark", COFFEE)
	jar("jar_light", Color("#8A5A36"))
	bar()
	dial()
	portafilters()
	tamper()
	cup_mid()
	push_button("grinder_button", Color("#C0504D"), 28, 16)
	push_button("brew_button", SAGE, 32, 18)
	character("mentor", Color("#C68B5E"), Color("#2A1B14"), "bun", CREAM, SAGE)
	character("student", Color("#E2B48A"), Color("#C0504D"), "cap", Color("#5B7DB1"), null)
	character("office", Color("#8D5A3B"), Color("#1E1410"), "short", Color("#6E8FA8"), null)
	character("enthusiast", Color("#D9A57A"), Color("#5A4033"), "short", Color("#7A4E6E"), null, true, true)
	print("art generated")
	quit()


# ---------- helpers ----------

func new_img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func frame(img: Image, x: int, y: int, w: int, h: int, t: int, c: Color) -> void:
	rect(img, x, y, w, t, c)
	rect(img, x, y + h - t, w, t, c)
	rect(img, x, y, t, h, c)
	rect(img, x + w - t, y, t, h, c)


func disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r + r \
					and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)


## Blends a soft light circle over existing pixels.
func glow(img: Image, cx: int, cy: int, r: int, c: Color, strength: float) -> void:
	for y in range(maxi(cy - r, 0), mini(cy + r + 1, img.get_height())):
		for x in range(maxi(cx - r, 0), mini(cx + r + 1, img.get_width())):
			var d := Vector2(x - cx, y - cy).length() / r
			if d < 1.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, strength * (1.0 - d)))


func text(img: Image, x: int, y: int, s: String, c: Color) -> void:
	for ch in s:
		if FONT.has(ch):
			var bits: String = FONT[ch]
			for i in 15:
				if bits[i] == "1":
					img.set_pixel(x + i % 3, y + i / 3, c)
		x += 4


## Adds a 1px dark outline around every opaque shape.
func outline(img: Image, c := ESPRESSO) -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and src.get_pixel(p.x, p.y).a > 0.5:
					img.set_pixel(x, y, c)
					break


func save(img: Image, sprite_name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + sprite_name + ".png"))


# ---------- scenery ----------

func background() -> void:
	var img := new_img(640, 360)
	rect(img, 0, 0, 640, 360, WALL)
	for y in range(16, 170, 12):
		rect(img, 0, y, 640, 1, WALL.darkened(0.05))
	rect(img, 0, 0, 640, 8, BEAN)
	rect(img, 0, 170, 640, 190, WALL_LOW)
	rect(img, 0, 170, 640, 3, BEAN)
	for x in range(0, 640, 16):
		rect(img, x, 173, 1, 187, BEAN)
	window(img, 24, 30, 160, 112)
	menu_board(img, 236, 26, 150, 96)
	shelf(img, 430, 92)
	plant(img, 398, 120)
	lamp(img, 206)
	lamp(img, 412)
	save(img, "cafe_background")


func window(img: Image, x: int, y: int, w: int, h: int) -> void:
	var top := Color("#6D5A9C")
	var mid := Color("#D9777F")
	var low := Color("#F4B76E")
	for row in h:
		var t := float(row) / h
		var c := top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(low, (t - 0.5) * 2.0)
		rect(img, x, y + row, w, 1, c)
	disc(img, x + 46, y + h - 30, 12, Color("#FFE2A6"))
	var heights := [34, 52, 26, 44, 60, 30, 48, 38]
	for i in heights.size():
		var bh: int = heights[i]
		rect(img, x + i * 20, y + h - bh, 18, bh, Color("#4E3F63"))
		for wy in range(y + h - bh + 6, y + h - 4, 8):
			img.set_pixel(x + i * 20 + 5, wy, Color("#FFD58A"))
			img.set_pixel(x + i * 20 + 11, wy, Color("#FFD58A"))
	frame(img, x, y, w, h, 4, BEAN)
	rect(img, x + w / 2 - 1, y, 3, h, BEAN)
	rect(img, x, y + h / 2 - 1, w, 3, BEAN)
	rect(img, x - 6, y + h, w + 12, 5, CARAMEL)
	rect(img, x - 6, y + h + 5, w + 12, 1, BEAN)


func menu_board(img: Image, x: int, y: int, w: int, h: int) -> void:
	rect(img, x, y, w, h, Color("#2E2622"))
	frame(img, x, y, w, h, 4, BEAN)
	text(img, x + w / 2 - 8, y + 9, "MENU", CREAM)
	var items := ["KOPI", "KOPI O", "TEH", "LATTE"]
	for i in items.size():
		var iy := y + 24 + i * 15
		text(img, x + 12, iy, items[i], CREAM)
		for dx in range(x + 44, x + w - 22, 3):
			img.set_pixel(dx, iy + 4, CARAMEL.darkened(0.3))
		rect(img, x + w - 18, iy, 6, 5, CARAMEL)


func shelf(img: Image, x: int, y: int) -> void:
	rect(img, x, y, 130, 4, BEAN)
	rect(img, x + 8, y + 4, 3, 6, BEAN)
	rect(img, x + 119, y + 4, 3, 6, BEAN)
	for i in 3:
		var cx := x + 8 + i * 14
		rect(img, cx, y - 8, 10, 8, PORCELAIN)
		rect(img, cx + 10, y - 6, 2, 4, PORCELAIN)
	for i in 2:
		var jx := x + 56 + i * 16
		rect(img, jx, y - 16, 12, 16, GLASS)
		rect(img, jx + 1, y - 9, 10, 8, COFFEE if i == 0 else Color("#8A5A36"))
		rect(img, jx + 1, y - 18, 10, 2, BEAN)
	rect(img, x + 100, y - 10, 12, 10, CARAMEL)
	disc(img, x + 106, y - 14, 5, SAGE)


func plant(img: Image, x: int, y: int) -> void:
	for row in 18:
		var inset := row / 6
		rect(img, x + inset, y + 32 + row, 26 - inset * 2, 1, CARAMEL.darkened(0.1))
	rect(img, x - 2, y + 30, 30, 3, CARAMEL)
	disc(img, x + 13, y + 16, 11, SAGE)
	disc(img, x + 5, y + 22, 7, SAGE_DARK)
	disc(img, x + 21, y + 22, 7, SAGE_DARK)
	disc(img, x + 13, y + 6, 6, SAGE.lightened(0.15))


func lamp(img: Image, x: int) -> void:
	rect(img, x, 8, 1, 28, ESPRESSO)
	for row in 9:
		var hw := 3 + row
		rect(img, x - hw, 36 + row, hw * 2 + 1, 1, CARAMEL if row < 7 else BEAN)
	glow(img, x, 52, 40, Color("#FFE9B8"), 0.45)
	rect(img, x - 2, 45, 5, 2, Color("#FFF4D6"))


func counter() -> void:
	var img := new_img(640, 360)
	rect(img, 0, 228, 640, 8, Color("#E6CFA6"))
	rect(img, 0, 228, 640, 1, CREAM)
	rect(img, 0, 236, 640, 3, CARAMEL)
	rect(img, 0, 239, 640, 121, BEAN)
	for x in range(0, 640, 24):
		rect(img, x, 239, 1, 121, ESPRESSO)
		rect(img, x + 1, 239, 1, 121, BEAN.lightened(0.12))
	rect(img, 0, 350, 640, 10, ESPRESSO)
	save(img, "counter")


# ---------- equipment ----------

func grinder() -> void:
	var img := new_img(30, 62)
	for y in range(3, 20):
		var hw := 10 - (y - 3) / 4
		rect(img, 15 - hw, y, hw * 2, 1, GLASS)
	for y in range(10, 20):
		for x in range(6, 25):
			if img.get_pixel(x, y).a > 0.1 and (x + y * 2) % 3 == 0:
				img.set_pixel(x, y, COFFEE if (x + y) % 2 == 0 else BEAN)
	rect(img, 4, 0, 22, 3, GRINDER_BODY)
	rect(img, 7, 20, 16, 32, GRINDER_BODY)
	rect(img, 8, 21, 2, 30, GRINDER_BODY.lightened(0.2))
	disc(img, 15, 31, 4, CARAMEL)
	rect(img, 15, 28, 1, 3, ESPRESSO)
	rect(img, 22, 41, 5, 3, STEEL_DARK)
	rect(img, 4, 52, 22, 10, STEEL_DARK)
	rect(img, 4, 52, 22, 1, STEEL)
	outline(img)
	save(img, "grinder")


func scale_sprite() -> void:
	var img := new_img(40, 12)
	rect(img, 0, 4, 40, 8, STEEL_DARK)
	rect(img, 2, 1, 36, 3, STEEL_LIGHT)
	rect(img, 4, 6, 14, 4, Color("#9FD39A"))
	rect(img, 6, 7, 1, 2, ESPRESSO)
	rect(img, 9, 7, 1, 2, ESPRESSO)
	rect(img, 12, 7, 3, 2, ESPRESSO)
	rect(img, 30, 7, 4, 2, CARAMEL)
	outline(img)
	save(img, "scale")


func machine() -> void:
	var img := new_img(88, 66)
	rect(img, 2, 6, 84, 38, STEEL)
	rect(img, 2, 6, 84, 5, STEEL_DARK)
	rect(img, 3, 12, 2, 30, STEEL_LIGHT)
	rect(img, 6, 1, 8, 5, PORCELAIN)
	rect(img, 18, 1, 8, 5, PORCELAIN)
	rect(img, 2, 18, 84, 4, CARAMEL)
	for gx in [16, 72]:
		disc(img, gx, 30, 5, CREAM)
		rect(img, gx, 27, 1, 3, ESPRESSO)
	rect(img, 36, 34, 16, 6, STEEL_DARK)
	rect(img, 52, 36, 16, 3, ESPRESSO)
	rect(img, 40, 40, 2, 3, STEEL_DARK)
	rect(img, 46, 40, 2, 3, STEEL_DARK)
	rect(img, 76, 40, 2, 14, STEEL_LIGHT)
	rect(img, 4, 44, 6, 22, STEEL_DARK)
	rect(img, 78, 44, 6, 22, STEEL_DARK)
	rect(img, 14, 58, 60, 4, STEEL_DARK)
	for x in range(16, 72, 4):
		img.set_pixel(x, 59, STEEL_LIGHT)
	outline(img)
	save(img, "machine")


func cups() -> void:
	for full in [false, true]:
		var img := new_img(14, 11)
		rect(img, 1, 1, 9, 9, PORCELAIN)
		rect(img, 2, 9, 7, 1, PORCELAIN.darkened(0.1))
		frame(img, 10, 3, 3, 5, 1, PORCELAIN)
		if full:
			rect(img, 2, 1, 7, 2, CREMA)
			rect(img, 3, 1, 3, 1, CREMA.lightened(0.3))
		outline(img)
		save(img, "cup_full" if full else "cup_empty")


func jar(sprite_name: String, beans: Color) -> void:
	var img := new_img(16, 24)
	rect(img, 1, 3, 14, 21, GLASS)
	for y in range(8, 24):
		for x in range(2, 14):
			img.set_pixel(x, y, beans if (x + y) % 3 else beans.darkened(0.3))
	rect(img, 3, 0, 10, 3, BEAN)
	rect(img, 4, 12, 8, 6, CREAM)
	rect(img, 5, 14, 6, 1, BEAN)
	outline(img)
	save(img, sprite_name)


# ---------- hands-on bar (barista POV), 640x360 base ----------
# Fixed equipment is baked into bar_background; movable things are separate sprites.
# Key coordinates (must match scripts/cafe/bar_station.gd):
#   knock box (12,266) 44x34 · grinder (60,70): dial centre (95,165), button (83,200),
#   spout tip x 140..146 y 226, fork y 262 · tamp mat (172,292) 64x6 ·
#   machine (280,110) 220x190: brew button (440,152), group head bottom y 227 centre x 390,
#   cup scale (360,280) · cup stack (512,252) · pass hatch (562,150).

const TILE := Color("#EFE3CC")
const GROUT := Color("#D4C2A3")
const PUCK := Color("#2A1A10")


func bar() -> void:
	var img := new_img(640, 360)
	rect(img, 0, 0, 640, 236, TILE)
	for row in range(0, 236, 10):
		rect(img, 0, row, 640, 1, GROUT)
		var off := 0 if (row / 10) % 2 == 0 else 10
		for x in range(off, 640, 20):
			rect(img, x, row, 1, 10, GROUT)
	rect(img, 0, 44, 640, 4, BEAN)
	for i in 8:
		rect(img, 170 + i * 14, 34, 10, 10, PORCELAIN)
		rect(img, 180 + i * 14, 37, 2, 4, PORCELAIN)
	for i in 3:
		rect(img, 330 + i * 26, 22, 18, 22, GLASS)
		rect(img, 331 + i * 26, 30, 16, 13, [COFFEE, Color("#8A5A36"), BEAN][i])
		rect(img, 331 + i * 26, 19, 16, 3, BEAN)
	glow(img, 320, 0, 240, Color("#FFE9B8"), 0.25)
	rect(img, 0, 236, 640, 64, Color("#C9A57A"))
	rect(img, 0, 236, 640, 2, CREAM)
	for y in range(246, 300, 11):
		for x in range((y * 7) % 40, 640, 90):
			rect(img, x, y, 55, 1, Color("#B8915F"))
	rect(img, 0, 300, 640, 60, BEAN)
	rect(img, 0, 300, 640, 3, CARAMEL)
	for x in range(0, 640, 24):
		rect(img, x, 303, 1, 57, ESPRESSO)

	# knock box
	rect(img, 12, 266, 44, 34, Color("#3A3236"))
	rect(img, 12, 266, 44, 4, STEEL_DARK)
	rect(img, 16, 274, 36, 3, STEEL)
	for i in 4:
		rect(img, 18 + i * 9, 284, 6, 3, PUCK)

	# grinder with built-in scale
	var gx := 60
	var gy := 70
	for r in 50:
		var hw := 35 - r * 13 / 50
		rect(img, gx + 35 - hw, gy + r, hw * 2, 1, GLASS)
	for yy in range(gy + 16, gy + 50):
		for xx in range(gx, gx + 70):
			var a := img.get_pixel(xx, yy).a
			if a > 0.1 and a < 0.9 and (xx + yy * 2) % 3 == 0:
				img.set_pixel(xx, yy, COFFEE if (xx + yy) % 2 == 0 else BEAN)
	rect(img, gx - 2, gy - 4, 74, 5, GRINDER_BODY)
	rect(img, gx + 10, gy + 50, 50, 130, GRINDER_BODY)
	rect(img, gx + 13, gy + 52, 4, 126, GRINDER_BODY.lightened(0.2))
	disc(img, 95, 165, 18, STEEL_DARK)
	rect(img, 81, 197, 32, 22, ESPRESSO)
	rect(img, gx + 60, gy + 144, 26, 8, STEEL_DARK)
	rect(img, 140, 222, 6, 4, STEEL_DARK)
	rect(img, gx + 6, 250, 58, 50, STEEL_DARK)
	rect(img, gx + 6, 250, 58, 2, STEEL)
	rect(img, 72, 274, 46, 12, Color("#9FD39A"))
	rect(img, 124, 262, 36, 3, STEEL_DARK)
	rect(img, 124, 262, 3, 38, STEEL_DARK)

	# tamping mat
	rect(img, 172, 292, 64, 6, Color("#2F2B2B"))
	rect(img, 172, 292, 64, 1, Color("#4A4545"))

	# espresso machine
	var mx := 280
	var my := 110
	for i in 4:
		rect(img, mx + 20 + i * 16, my, 11, 8, PORCELAIN)
	rect(img, mx, my + 8, 220, 5, STEEL_DARK)
	rect(img, mx, my + 13, 220, 92, STEEL)
	rect(img, mx + 3, my + 16, 3, 86, STEEL_LIGHT)
	rect(img, mx, my + 34, 220, 6, CARAMEL)
	rect(img, mx + 70, my + 18, 80, 12, Color("#2E2622"))
	text(img, mx + 92, my + 22, "BREWTOPIA", CREAM)
	for gauge_x in [mx + 40, mx + 76]:
		disc(img, gauge_x, my + 70, 11, CREAM)
		disc(img, gauge_x, my + 70, 8, PORCELAIN)
		rect(img, gauge_x, my + 62, 1, 8, ESPRESSO)
	rect(img, 436, 148, 40, 26, STEEL_DARK)
	rect(img, 370, 213, 40, 3, STEEL_LIGHT)
	rect(img, 374, 215, 32, 12, STEEL_DARK)
	rect(img, mx + 190, my + 105, 3, 45, STEEL_LIGHT)
	rect(img, mx + 6, my + 105, 16, 85, STEEL_DARK)
	rect(img, mx + 198, my + 105, 16, 85, STEEL_DARK)
	rect(img, 330, 292, 120, 8, STEEL_DARK)
	for x in range(334, 446, 6):
		rect(img, x, 294, 3, 2, STEEL_LIGHT)
	rect(img, 360, 280, 60, 12, STEEL_DARK)
	rect(img, 360, 280, 60, 2, STEEL_LIGHT)
	rect(img, 364, 284, 34, 7, Color("#9FD39A"))

	# cup stack
	for i in 4:
		var cy := 290 - i * 10
		rect(img, 514, cy, 30, 10, PORCELAIN)
		rect(img, 514, cy + 9, 30, 1, PORCELAIN.darkened(0.15))
	rect(img, 544, 266, 4, 8, PORCELAIN)

	# pass hatch
	rect(img, 562, 150, 4, 150, BEAN)
	rect(img, 634, 150, 4, 150, BEAN)
	rect(img, 562, 150, 76, 22, BEAN)
	rect(img, 566, 154, 68, 14, Color("#2E2622"))
	text(img, 592, 158, "PASS", CREAM)
	rect(img, 566, 282, 68, 6, CARAMEL)
	rect(img, 566, 288, 68, 2, BEAN)
	save(img, "bar_background")


## Grind dial, drawn pointing up; the game rotates it.
func dial() -> void:
	var img := new_img(40, 40)
	disc(img, 20, 20, 15, CARAMEL)
	disc(img, 20, 20, 10, CARAMEL.lightened(0.15))
	for a in range(0, 360, 30):
		var p := Vector2(20, 20) + Vector2.from_angle(deg_to_rad(a)) * 13.5
		img.set_pixel(int(p.x), int(p.y), BEAN)
	rect(img, 19, 7, 3, 10, ESPRESSO)
	outline(img)
	save(img, "dial")


func push_button(sprite_name: String, c: Color, w: int, h: int) -> void:
	for pressed in [false, true]:
		var img := new_img(w, h)
		var top := 3 if pressed else 0
		rect(img, 1, h - 4, w - 2, 4, c.darkened(0.45))
		rect(img, 1, top, w - 2, h - 4, c.darkened(0.2) if pressed else c)
		if not pressed:
			rect(img, 3, 1, w - 6, 2, c.lightened(0.35))
		outline(img)
		save(img, sprite_name + ("_pressed" if pressed else ""))


## Portafilter, 64x16: basket x 0..28 (centre x 14), handle to the right, spouts below.
## One sprite per basket state.
func portafilters() -> void:
	for state in ["empty", "dosed", "tamped", "used"]:
		var img := new_img(64, 16)
		rect(img, 0, 3, 28, 10, STEEL)
		rect(img, 0, 3, 28, 2, STEEL_LIGHT)
		match state:
			"empty":
				rect(img, 3, 5, 22, 2, STEEL_DARK)
			"dosed":
				rect(img, 3, 2, 22, 3, COFFEE)
				rect(img, 7, 0, 14, 2, COFFEE)
				for x in range(4, 24, 3):
					img.set_pixel(x, 2, BEAN)
			"tamped":
				rect(img, 3, 4, 22, 2, COFFEE)
				rect(img, 3, 4, 22, 1, BEAN)
			"used":
				rect(img, 3, 4, 22, 2, PUCK)
				img.set_pixel(8, 4, COFFEE)
				img.set_pixel(17, 5, COFFEE)
		rect(img, 28, 6, 6, 4, STEEL_DARK)
		rect(img, 34, 5, 30, 6, ESPRESSO)
		rect(img, 36, 6, 24, 1, BEAN)
		rect(img, 8, 13, 3, 3, STEEL_DARK)
		rect(img, 17, 13, 3, 3, STEEL_DARK)
		outline(img)
		save(img, "pf_" + state)


func tamper() -> void:
	var img := new_img(18, 26)
	rect(img, 5, 0, 8, 16, BEAN)
	rect(img, 6, 1, 2, 14, CARAMEL)
	rect(img, 7, 14, 4, 3, STEEL_DARK)
	rect(img, 1, 17, 16, 9, STEEL)
	rect(img, 1, 17, 16, 2, STEEL_LIGHT)
	outline(img)
	save(img, "tamper")


## Cup for the bar, 40x22; the game draws the coffee level inside (interior 3,2 26x18).
func cup_mid() -> void:
	var img := new_img(40, 22)
	rect(img, 0, 0, 32, 22, PORCELAIN)
	rect(img, 3, 2, 26, 18, Color(0, 0, 0, 0))
	rect(img, 0, 20, 32, 2, PORCELAIN.darkened(0.1))
	frame(img, 32, 5, 8, 11, 3, PORCELAIN)
	outline(img)
	save(img, "cup_mid")


# ---------- characters ----------

## Waist-up character, 40x84; the counter hides the lower body.
func character(sprite_name: String, skin: Color, hair: Color, style: String, shirt: Color,
		apron, glasses := false, beard := false) -> void:
	for happy in [false, true]:
		var img := new_img(40, 84)
		rect(img, 8, 25, 24, 59, shirt)
		rect(img, 4, 29, 4, 35, shirt)
		rect(img, 32, 29, 4, 35, shirt)
		rect(img, 4, 64, 4, 4, skin)
		rect(img, 32, 64, 4, 4, skin)
		rect(img, 8, 40, 1, 44, shirt.darkened(0.15))
		rect(img, 31, 40, 1, 44, shirt.darkened(0.15))
		if apron != null:
			rect(img, 12, 34, 16, 50, apron)
			rect(img, 13, 25, 2, 9, apron)
			rect(img, 25, 25, 2, 9, apron)
			rect(img, 16, 46, 8, 5, apron.darkened(0.2))
		rect(img, 17, 21, 6, 5, skin.darkened(0.12))
		rect(img, 12, 6, 16, 16, skin)
		rect(img, 11, 11, 1, 5, skin)
		rect(img, 28, 11, 1, 5, skin)

		match style:
			"cap":
				rect(img, 11, 9, 2, 5, ESPRESSO.lightened(0.1))
				rect(img, 27, 9, 2, 5, ESPRESSO.lightened(0.1))
				rect(img, 12, 3, 16, 6, hair)
				rect(img, 24, 8, 10, 2, hair.darkened(0.25))
			_:
				rect(img, 12, 4, 16, 5, hair)
				rect(img, 11, 6, 2, 6, hair)
				rect(img, 27, 6, 2, 6, hair)
				rect(img, 14, 9, 6, 2, hair)
				if style == "bun":
					disc(img, 20, 2, 3, hair)

		if beard:
			rect(img, 13, 17, 14, 6, hair)
		rect(img, 14, 17, 2, 1, BLUSH)
		rect(img, 24, 17, 2, 1, BLUSH)
		if happy:
			for ex in [15, 21]:
				img.set_pixel(ex, 14, ESPRESSO)
				rect(img, ex + 1, 13, 2, 1, ESPRESSO)
				img.set_pixel(ex + 3, 14, ESPRESSO)
			var mouth := CREAM if beard else ESPRESSO
			img.set_pixel(18, 18, mouth)
			rect(img, 19, 19, 3, 1, mouth)
			img.set_pixel(22, 18, mouth)
		else:
			rect(img, 16, 13, 2, 3, ESPRESSO)
			rect(img, 22, 13, 2, 3, ESPRESSO)
			rect(img, 19, 19, 3, 1, CREAM if beard else ESPRESSO.lightened(0.2))
		if glasses:
			frame(img, 14, 12, 6, 5, 1, ESPRESSO)
			frame(img, 20, 12, 6, 5, 1, ESPRESSO)

		outline(img)
		save(img, sprite_name + ("_happy" if happy else ""))
