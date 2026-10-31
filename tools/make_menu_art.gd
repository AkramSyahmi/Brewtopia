extends SceneTree
## Paints the UI pixel art (each art pixel = 3 px). Title menu, into res://assets/ui/main_menu/:
## wooden and cream 9-slice button frames (normal/hover/pressed/disabled), the subtitle
## banner, the gold accents and the menu icons (cream for wood buttons, dark for cream).
## Gameplay HUD, dialogue bubble and order ticket, into res://assets/ui/hud/ (make_hud_art).
## Run: Godot_console.exe --headless --path . --script res://tools/make_menu_art.gd

const OUT_DIR := "res://assets/ui/main_menu/"
const PX := 3
const BW := 22  # button art size; 9-slice margins 5,5,5,6 (x3 in the StyleBox)
const BH := 17
const OUTLINE := Color("#2E1A0E")
const SHADOW := Color(0.16, 0.09, 0.05, 0.55)

const WOOD := {"hi": Color("#B9844F"), "lo": Color("#6A3E1F"), "groove": Color("#4A2814"),
	"surf": Color("#7A4322"), "grain": Color("#6E3B1D"), "rivet": Color("#D9A866")}
const CREAM := {"hi": Color("#F0C978"), "lo": Color("#A8742F"), "groove": Color("#C9963F"),
	"surf": Color("#F7E9CC"), "grain": Color("#EFDDB9"), "rivet": Color("#B98236")}

const ICONS := {
	"continue": [
		"....s..s......",
		"...s..s.......",
		"....s..s......",
		"..............",
		".##########...",
		".#oooooooo#...",
		".#oooooooo####",
		".#oooooooo#..#",
		".#oooooooo#..#",
		".#oooooooo####",
		"..#oooooo#....",
		"...######.....",
		"############..",
		".##########...",
	],
	"new_game": [
		".....ss.......",
		".....ss.......",
		"...ssssss.....",
		".....ss.......",
		".##########...",
		".#oooooooo#...",
		".#oooooooo####",
		".#oooooooo#..#",
		".#oooooooo#..#",
		".#oooooooo####",
		"..#oooooo#....",
		"...######.....",
		"..............",
		"..............",
	],
	"music": [
		"......###.....",
		"......#oo#....",
		"......#oho#...",
		"......#o#oo#..",
		"......#o#.#o#.",
		"......#o#..##.",
		"......#o#.....",
		"......#o#.....",
		"..#####o#.....",
		".#ooooooo#....",
		"#oohoooooo#...",
		"#ooooooooo#...",
		".#ooooooo#....",
		"..#######.....",
	],
	"sound": [
		"..............",
		".......#......",
		"......##...s..",
		".....#o#....s.",
		".#####o#..s..s",
		".#ooooo#...s.s",
		".#ooooo#...s.s",
		".#ooooo#...s.s",
		".#ooooo#...s.s",
		".#####o#..s..s",
		".....#o#....s.",
		"......##...s..",
		".......#......",
		"..............",
	],
	"credits": [
		"..########....",
		"..#oooooo##...",
		"..#oooooo#o#..",
		"..#oooooo####.",
		"..#o#####ooo#.",
		"..#ooooooooo#.",
		"..#o#######o#.",
		"..#ooooooooo#.",
		"..#o#######o#.",
		"..#ooooooooo#.",
		"..#o#####ooo#.",
		"..#ooooooooo#.",
		"..###########.",
		"..............",
	],
	"quit": [
		"....#########.",
		"....#ooooooo#.",
		"....#o#####o#.",
		"....#o#ooo#o#.",
		".s..#o#ooo#o#.",
		"ss..#o#oo##o#.",
		"sssss.#ooo#o#.",
		"ss..#o#ooo#o#.",
		".s..#o#ooo#o#.",
		"....#o#ooo#o#.",
		"....#o#####o#.",
		"....#ooooooo#.",
		"....#########.",
		"..............",
	],
}

const SPARKLE := [
	"oo....",
	".ooo..",
	"...o..",
	"......",
	"oooo..",
	"......",
	"...o..",
	".ooo..",
	"oo....",
]


func _initialize() -> void:
	for style in [["wood", WOOD], ["cream", CREAM]]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			save(button_art(style[1], state), "button_%s_%s" % [style[0], state])
	save(banner_art(), "banner")
	for icon in ICONS:
		save(icon_art(ICONS[icon], Color("#F6E7C8"), OUTLINE, Color("#F6E7C8")), "icon_%s_light" % icon)
		save(icon_art(ICONS[icon], Color("#FFF8EC"), Color("#3B2314"), Color("#3B2314")), "icon_%s_dark" % icon)
	save(outlined(icon_art(SPARKLE, Color("#E8B04A"), Color("#E8B04A"), Color("#E8B04A"))), "sparkle")
	print("menu art written to ", OUT_DIR)
	make_hud_art()
	print("hud art written to ", HUD_DIR)
	quit()


func save(im: Image, file: String, dir := OUT_DIR) -> void:
	var big := im.duplicate() as Image
	big.resize(im.get_width() * PX, im.get_height() * PX, Image.INTERPOLATE_NEAREST)
	big.save_png(dir + file + ".png")


# ---------- gameplay HUD, dialogue and order ticket (res://assets/ui/hud/) ----------

const HUD_DIR := "res://assets/ui/hud/"
const CHARCOAL := {"hi": Color("#8C7B6E"), "lo": Color("#3E332D"), "groove": Color("#4E423B"),
	"surf": Color("#5A4C44"), "grain": Color("#54473F"), "rivet": Color("#5A4C44")}
const HUD_ICONS := {
	"sun": [
		".....y.....",
		"..y..y..y..",
		"...y...y...",
		"....###....",
		"yy.#YYY#.yy",
		"...#YYY#...",
		"....###....",
		"...y...y...",
		"..y..y..y..",
		".....y.....",
		"...........",
	],
	"moon": [
		"...####....",
		"..#YY#.....",
		".#YY#......",
		".#YY#......",
		"#YYY#......",
		"#YYY#......",
		"#YYYY#..#..",
		".#YYYY##Y#.",
		".#YYYYYYY#.",
		"..##YYYY#..",
		"....####...",
	],
	"smiley": [
		"...#####...",
		"..#YYYYY#..",
		".#YYYYYYY#.",
		"#YY#YYY#YY#",
		"#YY#YYY#YY#",
		"#YYYYYYYYY#",
		"#Y#YYYYY#Y#",
		"#YY#####YY#",
		".#YYYYYYY#.",
		"..#YYYYY#..",
		"...#####...",
	],
	"cup_big": [
		"......s..s..........",
		".....s..s...........",
		"......s..s..........",
		".....s..s...........",
		"....................",
		".##############.....",
		"#cccccccccccccc#....",
		"#cCCCCCCCCCCCCc####.",
		"#wcccccccccccccw##w#",
		"#wwwwwwwwwwwwwww#..w#",
		"#hwwwwwwwwwwwwww#..w#",
		"#hwwwwwwwwwwwwww#.w#.",
		"#hwwwwwwwwwwwwwww##..",
		".#wwwwwwwwwwwwww#....",
		".#wwwwwwwwwwwwgw#....",
		"..#wwwwwwwwwwgg#.....",
		"...############......",
	],
	"cup_small": [
		"....s..s......",
		"...s..s.......",
		"....s..s......",
		"..............",
		"#########.....",
		"#ccccccc#.....",
		"#wwwwwww####..",
		"#hwwwwww#..w#.",
		"#hwwwwww#..w#.",
		"#hwwwwww####..",
		".#wwwwgw#.....",
		"..#####.......",
		"..............",
	],
	"bean": [
		".####.",
		"#bbBb#",
		"#bBbb#",
		"#bbBb#",
		".####.",
	],
	"arrow": [
		"oo...",
		".oo..",
		"..oo.",
		".oo..",
		"oo...",
	],
	"clipboard": [
		"....###....",
		"...#ddd#...",
		".###ddd###.",
		".#ooooooo#.",
		".#o#####o#.",
		".#ooooooo#.",
		".#o####oo#.",
		".#ooooooo#.",
		".#o#####o#.",
		".#ooooooo#.",
		".#o###ooo#.",
		".#ooooooo#.",
		".#########.",
	],
	"book": [
		".##...##.",
		"#oo#.#oo#",
		"#ooo#ooo#",
		"#o##o##o#",
		"#ooo#ooo#",
		"#o##o##o#",
		"#ooo#ooo#",
		".###.###.",
		".........",
	],
	"menu": [
		".........",
		"ooooooooo",
		"ooooooooo",
		".........",
		"ooooooooo",
		"ooooooooo",
		".........",
		"ooooooooo",
		"ooooooooo",
	],
	"bulb": [
		"..#####..",
		".#YYYYY#.",
		"#YYhYYYY#",
		"#YYYYYYY#",
		".#YYYYY#.",
		"..#YYY#..",
		"..#ddd#..",
		"..#ddd#..",
		"...###...",
	],
	"jar": [
		"..#####..",
		".#ddddd#.",
		".#######.",
		"#ooooooo#",
		"#oBBBBBo#",
		"#oBBBBBo#",
		"#ooooooo#",
		"#ooooooo#",
		".#######.",
	],
	"arrow_down": [
		"o...o",
		"oo.oo",
		".ooo.",
		"..o..",
	],
	"clip": [
		"..####..",
		".#LLLL#.",
		"#LdddDL#",
		"#LddddL#",
		"#LddddL#",
		"########",
		"..#oo#..",
		"..#oo#..",
		"...##...",
	],
}
const HUD_COLORS := {"#": Color("#2A170C"), "Y": Color("#FFD34D"), "y": Color("#FFC93C"),
	"c": Color("#4A2614"), "C": Color("#7A4322"), "w": Color("#FFF8EC"), "h": Color("#FFFFFF"),
	"g": Color("#D8CBB8"), "s": Color("#C9BBA8"), "b": Color("#6A3E1F"), "B": Color("#A8622F"),
	"o": Color("#F6E7C8"), "L": Color("#C08A55"), "d": Color("#8A5634"), "D": Color("#5A3414")}


func make_hud_art() -> void:
	for state in ["normal", "hover", "pressed"]:
		save(button_art(CHARCOAL, state), "button_%s" % state, HUD_DIR)
	save(pill_art(Color("#57341F"), Color("#7A4C30"), Color("#3E2415"), Color.TRANSPARENT), "pill", HUD_DIR)
	save(pill_art(Color("#7A4322"), Color("#A86A3E"), Color("#5A3016"), Color("#C9963F")), "badge", HUD_DIR)
	save(dialog_art(), "dialog", HUD_DIR)
	save(pointer_art(Color("#1A1310"), Color("#3A2F29")), "dialog_pointer", HUD_DIR)
	save(pointer_art(OUTLINE, Color("#7A4322")), "badge_pointer", HUD_DIR)  # speech bubble tail on the badge panel
	save(pointer_art(OUTLINE, CREAM.surf), "bubble_pointer", HUD_DIR)  # the customer's order bubble (cream)
	save(ticket_art(), "ticket", HUD_DIR)
	for state in ["normal", "hover", "pressed"]:
		save(close_art(state), "close_" + state, HUD_DIR)
	save(bar_art(Color("#2A1A10"), Color("#2A1A10")), "bar_bg", HUD_DIR)
	save(bar_art(Color("#D9B48A"), Color("#F0D6AE")), "bar_fill", HUD_DIR)
	for icon in HUD_ICONS:
		var rows: Array = HUD_ICONS[icon]
		var w := 0
		for r in rows:
			w = maxi(w, r.length())
		var im := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				var ch: String = rows[y][x]
				if HUD_COLORS.has(ch):
					im.set_pixel(x, y, HUD_COLORS[ch])
		if icon == "cup_big":  # little gold sparks around the cup
			for p in [Vector2i(17, 3), Vector2i(18, 2), Vector2i(18, 5), Vector2i(19, 5), Vector2i(0, 15), Vector2i(1, 16)]:
				im.set_pixel(p.x, p.y, Color("#E8B04A"))
		save(im, "icon_" + icon, HUD_DIR)


## HUD badge: a dark wood pill with stepped round ends, top highlight, bottom shade,
## optional inner gold line (the ORDER badge), and a drop shadow. 16x14 art, margins 5.
func pill_art(surf: Color, hi: Color, lo: Color, ring: Color) -> Image:
	var w := 16
	var h := 14
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color.TRANSPARENT
			var cut: Array[int] = [2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2]  # stepped ends per row
			if y == h - 1:
				c = SHADOW if x >= 3 and x <= w - 2 else c
			elif x >= cut[y] and x <= w - 1 - cut[y]:
				var edge: bool = x == cut[y] or x == w - 1 - cut[y] or y == 0 or y == h - 2 \
					or (y == 1 and (x <= 1 or x >= w - 2)) or (y == h - 3 and (x <= 1 or x >= w - 2))
				if edge:
					c = OUTLINE
				elif ring.a > 0 and (y == 2 or y == h - 4 or x == 2 or x == w - 3):
					c = ring
				elif y == 1 or (y == 2 and ring.a == 0):
					c = hi
				elif y >= h - 3:
					c = lo
				else:
					c = surf
			im.set_pixel(x, y, c)
	return im


## Dialogue panel: dark charcoal-brown, stepped corners, a lighter inner bevel, shadow.
## 20x19 art, 9-slice margins 6 (bottom 7).
func dialog_art() -> Image:
	var w := 20
	var h := 19
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cut: Array[int] = [2, 1]
	for y in h:
		for x in w:
			var c := Color.TRANSPARENT
			var by := y
			if by == h - 1:
				c = Color(0, 0, 0, 0.35) if x >= 2 else c
			else:
				var inset := 0
				if by < 2:
					inset = cut[by]
				elif by > h - 4:
					inset = cut[h - 2 - by]
				if x >= inset and x <= w - 1 - inset:
					if x == inset or x == w - 1 - inset or by == 0 or by == h - 2:
						c = Color("#1A1310")
					elif by == 1 or x == inset + 1 and by < h - 3:
						c = Color("#6E5D52")  # light bevel, top and left
					elif by == h - 3 or x == w - 2 - inset:
						c = Color("#241B17")
					elif by == 2 or x == 2 or by == h - 4 or x == w - 3:
						c = Color("#2E2420")  # inner line
					else:
						c = Color("#3A2F29")
			im.set_pixel(x, y, c)
	return im


## A speech pointer (sits over a panel's bottom edge): `line` outline, `surf` fill.
func pointer_art(line: Color, surf: Color) -> Image:
	var rows := [
		"#sssssss#",
		".#sssss#.",
		"..#sss#..",
		"...#s#...",
		"....#....",
	]
	var im := Image.create(9, 5, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 9:
			var ch: String = rows[y][x]
			if ch == "#":
				im.set_pixel(x, y, line)
			elif ch == "s":
				im.set_pixel(x, y, surf)
	return im


## Order ticket paper: parchment with punched holes along the top, torn left/right/bottom
## edges, edge shading, a few fibres, a folded bottom-right corner and a drop shadow.
## 24x24 art, 9-slice margins 7 (the pattern repeats every 2 px, so tiling is seamless).
func ticket_art() -> Image:
	var w := 24
	var h := 24
	var paper := Color("#F6E7C8")
	var shade := Color("#EAD5AE")
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color.TRANSPARENT
			var left := 1 + (y % 2)  # torn edges
			var right := w - 3 + (y % 2)
			var bottom := h - 3 + (x % 2)
			var fold := x + y > w + h - 13  # the folded corner (bottom right)
			if y >= 1 and y <= bottom and x >= left and x <= right and not fold:
				if x == left or x == right or y == 1 or y == bottom:
					c = OUTLINE
				elif y == 4 and (x == 4 or x == 9 or x == 14 or x == 19):
					c = Color("#8A6A4A")  # punched holes
				elif y == 3 and (x == 4 or x == 9 or x == 14 or x == 19):
					c = Color("#5A3F30")
				elif x <= left + 1 or y <= 2 or x >= right - 1 or y >= bottom - 1:
					c = shade
				elif (x * 5 + y * 3) % 17 == 0:
					c = shade  # paper fibres
				else:
					c = paper
			elif fold and x + y <= w + h - 8 and x <= right and y <= bottom:
				c = OUTLINE if x + y == w + h - 12 or x + y == w + h - 8 or x == right or y == bottom else Color("#D9BE8E")
			elif x >= 2 and y >= 2 and x <= right + 1 and y <= bottom + 1 and not fold and im.get_pixel(x - 1, y - 1).a > 0:
				c = Color(0, 0, 0, 0.2)  # drop shadow
			im.set_pixel(x, y, c)
	return im


## The order note's close button: a red square with a white X, stepped corners, a light
## top bevel and a drop shadow (11x12 art). Hover = brighter red; pressed = one pixel
## lower with no shadow.
func close_art(state: String) -> Image:
	var red := Color("#C8362E").lightened(0.15) if state == "hover" else Color("#C8362E")
	var dy := 1 if state == "pressed" else 0
	var im := Image.create(11, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 11:
			var by := y - dy
			var c := Color.TRANSPARENT
			if by == 11 and state != "pressed" and x >= 1:
				c = SHADOW
			elif by >= 0 and by <= 10:
				var corner := (x == 0 or x == 10) and (by == 0 or by == 10)
				if corner:
					c = Color.TRANSPARENT
				elif x == 0 or x == 10 or by == 0 or by == 10:
					c = OUTLINE
				elif by == 1:
					c = red.lightened(0.3)
				elif by == 9 or x == 9:
					c = red.darkened(0.25)
				elif (x == by or x + by == 10) and x >= 3 and x <= 7 and by >= 3 and by <= 7:
					c = Color.WHITE  # the X
				else:
					c = red
			im.set_pixel(x, y, c)
	return im


## XP bar end-caps + fill (5 px tall art, margins 2).
func bar_art(fill: Color, hi: Color) -> Image:
	var im := Image.create(6, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 6:
			var c := fill
			if (x == 0 or x == 5) and (y == 0 or y == 4):
				c = Color.TRANSPARENT
			elif x == 0 or x == 5 or y == 0 or y == 4:
				c = Color("#1A0F08")
			elif y == 1:
				c = hi
			im.set_pixel(x, y, c)
	return im


## A wooden (or cream) sign: dark outline, light top/left bevel, dark bottom/right bevel,
## an inner groove, a lightly grained surface, four rivets and a soft drop shadow.
## Pressed = the whole sign one pixel lower with no shadow.
func button_art(pal: Dictionary, state: String) -> Image:
	var p := pal.duplicate()
	if state == "hover":
		for k in ["hi", "surf", "grain"]:
			p[k] = p[k].lightened(0.12)
	elif state == "disabled":
		for k in p:
			p[k] = p[k].lerp(Color("#8A7D72"), 0.55)
	var im := Image.create(BW, BH, false, Image.FORMAT_RGBA8)
	var dy := 1 if state == "pressed" else 0
	for y in BH:
		for x in BW:
			var by := y - dy  # row in the sign's body
			var c := Color.TRANSPARENT
			if by == BH - 1:
				if state != "pressed" and x >= 1:
					c = SHADOW
			elif by >= 0:
				var corner := (x == 0 or x == BW - 1) and (by == 0 or by == BH - 2)
				if corner:
					c = Color.TRANSPARENT
				elif x == 0 or x == BW - 1 or by == 0 or by == BH - 2:
					c = OUTLINE
				elif x == 1 or by == 1:
					c = p.hi
				elif x == BW - 2 or by == BH - 3:
					c = p.lo
				elif x == 2 or by == 2 or x == BW - 3 or by == BH - 4:
					c = p.groove
				elif (x == 3 or x == BW - 4) and (by == 3 or by == BH - 5):
					c = p.rivet
				else:
					c = p.grain if (x + by * 2) % 6 == 0 else p.surf
			im.set_pixel(x, y, c)
	return im


## The subtitle plaque: wooden frame, cream inside, little dots at both ends, drop shadow.
func banner_art() -> Image:
	var w := 22
	var h := 13
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color.TRANSPARENT
			if y == h - 1:
				c = SHADOW if x >= 1 else c
			elif not ((x == 0 or x == w - 1) and (y == 0 or y == h - 2)):
				if x == 0 or x == w - 1 or y == 0 or y == h - 2:
					c = OUTLINE
				elif x == 1 or y == 1:
					c = WOOD.hi
				elif x == w - 2 or y == h - 3:
					c = WOOD.lo
				elif x == 2 or y == 2 or x == w - 3 or y == h - 4:
					c = Color("#9C6A3E")
				else:
					c = Color("#F6E7C8")
					if (x == 4 or x == w - 5) and y == 5:
						c = Color("#9C6A3E")  # end dots
			im.set_pixel(x, y, c)
	return im


## Icon from a char map: '#' outline, 'o' fill, 'h' highlight, 's' strokes that must show
## on the button (fill colour on dark wood, outline colour on cream).
func icon_art(rows: Array, fill: Color, line: Color, stroke: Color) -> Image:
	var im := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			var c := Color.TRANSPARENT
			match ch:
				"#": c = line
				"o": c = fill
				"h": c = Color.WHITE
				"s": c = stroke
			im.set_pixel(x, y, c)
	return im


## Adds a 1 px dark outline around the opaque pixels (grows the image by 1 on each side).
func outlined(src: Image) -> Image:
	var w := src.get_width() + 2
	var h := src.get_height() + 2
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ONE)
	var out := im.duplicate() as Image
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and im.get_pixelv(q).a > 0.0:
					out.set_pixel(x, y, Color("#5A3414"))
					break
	return out
