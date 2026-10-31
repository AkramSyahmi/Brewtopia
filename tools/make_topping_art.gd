extends SceneTree
## Paints assets/art/topping_bg.png (640x360, the topping page's base resolution, 1 px =
## 2 screen px): a cream tiled café wall, a wood dado and wainscot, a window, a chalkboard
## menu, a cup shelf with a hanging plant, the long syrup shelf (bottles stand on SHELF_TOP),
## side ledges with a straw holder, paper cups, a potted plant, a napkin box and glasses, the
## beige counter with two rubber cup mats (EspressoStation.SLOTS) and the wood cabinet front.
## Only scenery: every bottle, container, cup and the SERVE box is drawn by the station on top.
## Run: Godot_console.exe --headless --path . --script res://tools/make_topping_art.gd
## Also paints station_bg.png, the espresso page behind the equipment (station_bg()), and the
## espresso prep sprites: grinder, bean_bag, tamp_mat, tamper, portafilter_* (prep_sprites()).
## (Both are listed in assets/art/KEEP.txt, so tools/gen_backgrounds.gd skips them.)

const W := 640
const H := 360
const SHELF_TOP := 202  # syrup shelf top surface: EspressoStation.SYRUP_AT.y + 96 lands inside 202..209
const SHELF_X := Vector2i(80, 508)
const MATS := [360, 460]  # cup mat centres (EspressoStation.SLOTS x)
const DADO_Y := 150  # tiles above, wood wainscot below
## Syrup row: keep in step with EspressoStation.SYRUP_AT / SYRUP_STEP / SYRUP_TAG.
const SYRUPS := {"vanilla": "#F3E3A6", "caramel": "#D2843F", "chocolate": "#5A2E1A", "pandan": "#5DBE4A",
	"gula_melaka": "#9A4E1E", "condensed_milk": "#F6EDCF"}
## Topping row: keep in step with EspressoStation.TOPPING_AT / TOPPING_STEP / TOPPING_SIZE / TOPPING_TAG.
const TOPPINGS := ["cream", "choc_chips", "cinnamon", "cocoa"]
const TOPPING_AT := Vector2i(20, 250)
const TOPPING_STEP := 72
const CONTAINER := Vector2i(64, 60)
const SERVE := Rect2i(520, 250, 110, 80)  # = EspressoStation.SERVE2_RECT
const RIM := 24  # container front rim row: the topping heaps in the opening above it
const BOTTLE_X0 := 92
const BOTTLE_STEP := 72
const TAG := Vector2i(66, 12)  # name tag hanging under each bottle, top at SHELF_TOP + 22
const MAT_Y := Vector2i(240, 328)  # EspressoStation.SLOTS y 284 = the centre

const OUTLINE := Color("#3A2416")
const TILE := Color("#EFE2C8")
const TILE_LO := Color("#E2D0AE")
const TILE_HI := Color("#F7EEDB")
const GROUT := Color("#D6C3A0")
const WOOD_HI := Color("#E0AE74")
const WOOD := Color("#C98E55")
const WOOD_FRONT := Color("#A86C3C")
const WOOD_DARK := Color("#7A4A2A")
const WOOD_DEEP := Color("#5A341C")
const PANEL := Color("#8E5E3A")
const TOP := Color("#E8D7BA")
const TOP_SPECK := Color("#DCC9A8")
const TOP_SHADE := Color("#CDB894")
const WHITE := Color("#F7F3EA")
const WHITE_LO := Color("#D9D0C0")
const GREY_LINE := Color("#8C8278")
const LEAF := Color("#4E8A3A")
const LEAF_HI := Color("#74B04F")
const LEAF_LO := Color("#2F5E2A")
const GLASS_LINE := Color("#9DB6C0")
const GLASS_FILL := Color("#DCEAEE")

var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 7
	wall()
	window(452, 14, 188, 106)
	chalkboard(330, 22, 98, 68)
	upper_shelf(226, 70, 96)
	hanging_plant(300, 70)
	left_shelf()
	wainscot()
	counter()
	ledge(0, 72)
	ledge(516, W)
	shelf()
	for i in SYRUPS.size():
		var bx: int = BOTTLE_X0 + i * BOTTLE_STEP
		box(bx + 6, SHELF_TOP + 3, 34, 2, WOOD_FRONT)  # soft shadow round the bottle's foot
		box(bx + 9, SHELF_TOP + 5, 30, 1, WOOD.darkened(0.12))
		tag(bx + 22)
		bottle(SYRUPS.keys()[i])
	serve_area(SERVE, 34)
	for cx in MATS:
		mat(cx)
	for i in TOPPINGS.size():
		var tx: int = TOPPING_AT.x + i * TOPPING_STEP
		box(tx + 3, TOPPING_AT.y + CONTAINER.y, CONTAINER.x - 1, 3, TOP_SHADE)  # shadow under the container
		container(TOPPINGS[i])
	straw_holder(10, SHELF_TOP)
	paper_cups(42, SHELF_TOP)
	potted_plant(546, SHELF_TOP)
	napkins(576, SHELF_TOP)
	glasses(608, SHELF_TOP)
	im.save_png("res://assets/art/topping_bg.png")
	print("topping_bg.png written")
	prep_sprites()  # before station_bg: its contact shadows read these sprites
	im = Image.create(W, H, false, Image.FORMAT_RGBA8)
	station_bg()
	im.save_png("res://assets/art/station_bg.png")
	print("station_bg.png written")
	quit()


# ---------- espresso page ----------

## station_bg.png: warm plaster wall (lighter behind the machine, shaded under the ceiling and
## along the counter), a wood window on each side (the right one behind the fridge), the same
## counter and drawers as the topping page, and a soft shadow under each piece of equipment,
## placed from EspressoStation's own constants and each sprite's drawn area.
func station_bg() -> void:
	const WALL_Y := 120  # first counter row
	var plaster := Color("#D9CEBF")
	for y in WALL_Y:
		for x in W:
			var c := plaster.lerp(Color("#E6DCCD"), clampf(1.0 - absf(x - 330) / 260.0, 0.0, 1.0) * 0.6)  # warm light on the machine
			if y < 8:
				c = dither(c.darkened(0.06), c, y / 8.0, x, y)  # under the ceiling
			elif y >= WALL_Y - 10:
				c = dither(c, c.darkened(0.07), (y - WALL_Y + 10) / 10.0, x, y)  # behind the counter
			px(x, y, c)
	for i in 160:  # faint plaster texture
		px(rng.randi_range(0, W - 1), rng.randi_range(10, WALL_Y - 12), plaster.darkened(0.04))
	window(128, -6, 76, 112)
	window(452, -6, 188, 120)
	box(0, WALL_Y - 1, W, 1, Color("#B8A894"))  # where the wall meets the counter
	counter(WALL_Y, 342)
	serve_area(Rect2i(EspressoStation.SERVE_RECT), 9)
	var mat_at := Vector2i(EspressoStation.PITCHER_HOME) + Vector2i(-4, 58)  # the pitcher's platform
	box(mat_at.x + 2, mat_at.y + 7, 68, 2, TOP_SHADE)
	box(mat_at.x, mat_at.y, 68, 7, Color("#2E2A2C"))
	box(mat_at.x, mat_at.y, 68, 1, Color("#56525A"))
	box(mat_at.x, mat_at.y + 6, 68, 1, Color("#1C181A"))
	outline(mat_at.x - 1, mat_at.y - 1, 70, 9, OUTLINE)
	for item in [["grinder", EspressoStation.GRINDER_AT], ["bean_bag", EspressoStation.BAG_AT], ["tamp_mat", EspressoStation.MAT_AT],
			["knock_box", EspressoStation.KNOCK_AT], ["machine", EspressoStation.MACHINE_AT], ["iced_cups", EspressoStation.ICED_STACK_AT],
			["milk_fridge", EspressoStation.FRIDGE_AT], ["ice_bin", EspressoStation.ICE_BIN_AT]]:
		var used := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/%s.png" % item[0])).get_used_rect()
		var at: Vector2i = Vector2i(item[1]) + used.position
		box(at.x + 3, at.y + used.size.y, used.size.x - 1, 2, TOP_SHADE)  # contact shadow, light from the top left
		box(at.x + 5, at.y + used.size.y + 2, used.size.x - 5, 1, TOP_SHADE.lightened(0.06))


# ---------- helpers ----------

func box(x: int, y: int, w: int, h: int, c: Color) -> void:
	im.fill_rect(Rect2i(x, y, w, h), c)


func outline(x: int, y: int, w: int, h: int, c := OUTLINE) -> void:
	box(x, y, w, 1, c)
	box(x, y + h - 1, w, 1, c)
	box(x, y, 1, h, c)
	box(x + w - 1, y, 1, h, c)


func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and x < im.get_width() and y >= 0 and y < im.get_height():
		im.set_pixel(x, y, c)


## 2x2 ordered dither between a and b (t 0..1), so shading stays in whole pixels.
func dither(a: Color, b: Color, t: float, x: int, y: int) -> Color:
	const M := [0.125, 0.625, 0.875, 0.375]
	return b if t > M[(y % 2) * 2 + (x % 2)] else a


# ---------- wall ----------

## Cream ceramic tiles (16x12 with 1 px grout), each a touch lighter or darker, a light top
## edge, and warm shading towards the dado.
func wall() -> void:
	for ty in range(0, DADO_Y, 12):
		for tx in range(0, W, 16):
			var tint := TILE.lerp(TILE_LO if rng.randf() < 0.5 else TILE_HI, rng.randf_range(0.0, 0.35))
			tint = tint.lerp(TILE_LO, clampf((ty - 60) / 90.0, 0.0, 0.6))  # warmer, darker rows near the dado
			for y in range(ty, mini(ty + 12, DADO_Y)):
				for x in range(tx, tx + 16):
					var c := GROUT if x == tx or y == ty else tint
					if y == ty + 1 and x > tx:
						c = c.lerp(TILE_HI, 0.5)
					px(x, y, c)


## Dark rail over a wood-plank wainscot (behind the syrup shelf).
func wainscot() -> void:
	box(0, DADO_Y, W, 2, WOOD_HI.darkened(0.15))
	box(0, DADO_Y + 2, W, 4, WOOD_DARK)
	box(0, DADO_Y + 6, W, 1, WOOD_DEEP)
	box(0, DADO_Y + 7, W, SHELF_TOP - DADO_Y - 7, PANEL)
	for x in range(0, W, 32):
		box(x, DADO_Y + 7, 1, SHELF_TOP - DADO_Y - 7, WOOD_DEEP)
		box(x + 1, DADO_Y + 7, 1, SHELF_TOP - DADO_Y - 7, PANEL.lightened(0.12))
	for i in 40:  # a little grain
		var x := rng.randi_range(2, W - 8)
		box(x, rng.randi_range(DADO_Y + 10, SHELF_TOP - 4), rng.randi_range(3, 7), 1, PANEL.darkened(0.12))


func window(x: int, y: int, w: int, h: int) -> void:
	box(x, y, w, h, WOOD_FRONT)
	outline(x, y, w, h)
	box(x + 1, y + 1, w - 2, 1, WOOD_HI)
	var gx := x + 6
	var gy := y + 6
	var gw := w - 12
	var gh := h - 14
	for yy in gh:
		for xx in gw:
			px(gx + xx, gy + yy, dither(Color("#BFE3F0"), Color("#93C6DE"), float(yy) / gh, xx, yy))
	outline(gx - 1, gy - 1, gw + 2, gh + 2, WOOD_DEEP)
	box(x + w / 2 - 2, gy, 4, gh, WOOD_FRONT)  # mullion
	box(x + w / 2 - 2, gy, 1, gh, WOOD_HI)
	for pane in [gx, x + w / 2 + 2]:  # two diagonal glints per pane
		for k in 22:
			for t in 2:
				px(pane + 10 + k, gy + 40 - k * 2 + t, Color("#E6F6FB"))
				px(pane + 22 + k / 2, gy + 70 - k * 2 + t, Color("#D4EEF7"))
	box(x - 4, y + h - 6, w + 8, 4, WOOD)  # sill
	box(x - 4, y + h - 6, w + 8, 1, WOOD_HI)
	box(x - 4, y + h - 2, w + 8, 2, WOOD_DARK)


## Dark chalkboard menu: chalk lines on the left, a cup drawing on the right.
func chalkboard(x: int, y: int, w: int, h: int) -> void:
	box(x, y, w, h, WOOD_DARK)
	outline(x, y, w, h)
	box(x + 1, y + 1, w - 2, 1, WOOD)
	box(x + 4, y + 4, w - 8, h - 8, Color("#2E3430"))
	for i in 60:  # chalk dust
		px(rng.randi_range(x + 5, x + w - 6), rng.randi_range(y + 5, y + h - 6), Color("#3A413C"))
	var chalk := Color("#C9CEC6")
	for row in 5:  # menu lines: a dot, a word, a price
		var ly := y + 10 + row * 10
		px(x + 9, ly, chalk)
		box(x + 13, ly, rng.randi_range(14, 24), 1, chalk)
		box(x + 42, ly, 6, 1, chalk.darkened(0.25))
	var cx := x + w - 30
	var cy := y + h - 24
	outline(cx, cy, 18, 12, chalk)  # cup
	box(cx + 1, cy + 11, 16, 1, Color("#2E3430"))
	box(cx + 2, cy + 11, 14, 1, chalk)
	outline(cx + 17, cy + 3, 5, 6, chalk)  # handle
	box(cx - 4, cy + 13, 26, 1, chalk)  # saucer
	for s in 2:  # steam
		for k in 6:
			px(cx + 5 + s * 7 + (k % 2), cy - 2 - k, chalk)
	box(x + w / 2 - 1, y - 3, 2, 3, Color("#4A4A4A"))  # nail


# ---------- shelves ----------

## Wall shelf: lit top, wood front, dark underside and two metal brackets.
func wall_shelf(x: int, y: int, w: int) -> void:
	box(x, y, w, 2, WOOD_HI)
	box(x, y + 2, w, 4, WOOD_FRONT)
	box(x, y + 6, w, 1, WOOD_DEEP)
	box(x, y + 7, w, 2, GROUT.darkened(0.08))  # shadow on the tiles
	for bx in [x + 8, x + w - 12]:
		box(bx, y + 7, 4, 2, Color("#4A3A30"))
		box(bx, y + 9, 2, 6, Color("#4A3A30"))


func upper_shelf(x: int, y: int, w: int) -> void:
	wall_shelf(x, y, w)
	for s in 3:  # stacks of white cups
		for k in 3:
			cup(x + 6 + s * 16, y - 6 - k * 6)
	for k in 4:  # a stack of small glasses
		var gy := y - 4 - k * 4
		box(x + 56, gy, 10, 4, GLASS_FILL)
		box(x + 56, gy, 10, 1, GLASS_LINE)
		box(x + 56, gy, 1, 4, GLASS_LINE)
		box(x + 65, gy, 1, 4, GLASS_LINE)


func cup(x: int, y: int) -> void:
	box(x, y, 12, 6, WHITE)
	box(x + 1, y, 10, 1, WHITE_LO)  # the rim of the cup above
	box(x + 9, y + 1, 3, 5, WHITE_LO)
	box(x, y + 5, 12, 1, GREY_LINE)
	box(x, y, 1, 6, GREY_LINE)
	box(x + 11, y, 1, 6, GREY_LINE)


## Small terracotta pot on the cup shelf with vines hanging over its edge.
func hanging_plant(x: int, shelf_y: int) -> void:
	for k in 3:  # vines first, so the pot covers their tops
		var vx := x + 2 + k * 7
		for vy in range(shelf_y, shelf_y + 18 + k * 9):
			var sway := int(round(sin(vy * 0.35 + k) * 1.2))
			px(vx + sway, vy, LEAF_LO)
			if vy % 4 == k % 4:
				px(vx + sway - 1, vy, LEAF)
				px(vx + sway + 1, vy + 1, LEAF_HI)
	box(x, shelf_y - 12, 18, 12, Color("#B8643A"))
	box(x, shelf_y - 12, 18, 2, Color("#D07A4A"))
	outline(x, shelf_y - 12, 18, 12, Color("#6A3420"))
	for i in 26:  # leaf tuft
		var lx := x + rng.randi_range(-3, 19)
		var ly := shelf_y - 14 - rng.randi_range(0, 9)
		px(lx, ly, LEAF if i % 3 else LEAF_HI)
		px(lx + 1, ly, LEAF_LO)


## The shelf under the objective panel: a couple of bean jars.
func left_shelf() -> void:
	wall_shelf(0, 96, 168)
	for jx in [24, 46, 120]:
		box(jx, 82, 14, 14, GLASS_FILL)
		box(jx + 1, 87, 12, 9, Color("#6A3E22"))
		for b in 6:
			px(jx + 2 + (b * 5) % 10, 88 + (b * 3) % 7, Color("#8C5A3A"))
		box(jx - 1, 80, 16, 3, WOOD_DARK)  # lid
		outline(jx, 82, 14, 14, GLASS_LINE)


## Thick light-wood syrup shelf standing on the counter.
func shelf() -> void:
	var x := SHELF_X.x
	var w := SHELF_X.y - SHELF_X.x
	box(x, SHELF_TOP, w, 8, WOOD)
	box(x, SHELF_TOP, w, 1, WOOD_HI)
	for i in 30:
		box(rng.randi_range(x + 2, x + w - 10), rng.randi_range(SHELF_TOP + 2, SHELF_TOP + 6), rng.randi_range(4, 9), 1, WOOD.darkened(0.08))
	box(x, SHELF_TOP + 8, w, 11, WOOD_FRONT)
	box(x, SHELF_TOP + 8, w, 1, WOOD.lightened(0.1))
	box(x, SHELF_TOP + 19, w, 1, WOOD_DEEP)
	outline(x, SHELF_TOP, w, 20)
	box(x + 2, SHELF_TOP + 20, w - 2, 3, TOP_SHADE)  # shadow on the counter


## Darker side ledges that the side props stand on.
func ledge(x0: int, x1: int) -> void:
	box(x0, SHELF_TOP, x1 - x0, 6, PANEL.lightened(0.1))
	box(x0, SHELF_TOP, x1 - x0, 1, WOOD)
	box(x0, SHELF_TOP + 6, x1 - x0, 8, WOOD_DARK)
	box(x0, SHELF_TOP + 14, x1 - x0, 1, WOOD_DEEP)
	box(x0, SHELF_TOP + 15, x1 - x0, 2, TOP_SHADE)


## Cream name tag on two short cords under the shelf front; the station writes the name on it.
func tag(cx: int) -> void:
	var x := cx - TAG.x / 2
	for k in [x + 8, x + TAG.x - 9]:
		box(k, SHELF_TOP + 20, 1, 2, WOOD_DEEP)
	tag_box(x, SHELF_TOP + 22, TAG.x, TAG.y)
	box(x + 1, SHELF_TOP + 22 + TAG.y, TAG.x - 1, 1, TOP_SHADE)  # drop shadow


## Cream parchment tag: brown border, light top edge, little corner studs (syrups, containers).
func tag_box(x: int, y: int, w: int, h: int) -> void:
	box(x, y, w, h, Color("#F3E6CC"))
	box(x + 1, y + 1, w - 2, 1, Color("#FBF4E4"))
	box(x + 1, y + h - 2, w - 2, 1, Color("#E2D0AE"))
	outline(x, y, w, h, WOOD_DARK)
	for c in [Vector2i(x + 2, y + 2), Vector2i(x + w - 3, y + 2), Vector2i(x + 2, y + h - 3), Vector2i(x + w - 3, y + h - 3)]:
		px(c.x, c.y, WOOD_FRONT)


## syrup_<name>.png, 44x96: curved black pump, white neck and collar, round shoulders, a
## shaded body in the syrup colour with a cream label and a coffee bean, a dark outline.
func bottle(syrup: String) -> void:
	var b := Image.create(44, 96, false, Image.FORMAT_RGBA8)
	var liquid := Color(SYRUPS[syrup])
	var black := Color("#1E1A1A")
	var black_hi := Color("#4A4446")
	b.fill_rect(Rect2i(19, 6, 6, 28), black)  # pump stem
	b.fill_rect(Rect2i(19, 6, 1, 28), black_hi)
	b.fill_rect(Rect2i(18, 1, 17, 6), black)  # head, then the spout curving down
	b.fill_rect(Rect2i(19, 1, 15, 1), black_hi)
	b.fill_rect(Rect2i(34, 2, 3, 5), black)
	b.fill_rect(Rect2i(35, 7, 4, 7), black)
	b.fill_rect(Rect2i(35, 7, 1, 6), black_hi)
	b.fill_rect(Rect2i(16, 34, 12, 7), Color("#F2F2EE"))  # white neck
	b.fill_rect(Rect2i(24, 34, 4, 7), Color("#CFCFC8"))
	b.fill_rect(Rect2i(14, 41, 16, 4), Color("#E4E4DE"))  # collar ring
	b.fill_rect(Rect2i(14, 41, 16, 1), Color("#FFFFFF"))
	b.fill_rect(Rect2i(26, 41, 4, 4), Color("#BDBDB6"))
	for y in range(45, 95):
		var hw := 15.0
		if y < 55:
			hw = 7.0 + 8.0 * sin((y - 45) / 10.0 * PI / 2.0)  # round shoulders
		elif y == 94:
			hw = 13.0
		var x0 := int(round(22 - hw))
		var x1 := int(round(22 + hw))
		for x in range(x0, x1):
			var t := float(x - x0) / (x1 - x0)
			var c := liquid
			if t < 0.2 and t > 0.06:
				c = liquid.lightened(0.35)
			elif t > 0.85:
				c = liquid.darkened(0.3)
			elif t > 0.7:
				c = liquid.darkened(0.15)
			if y < 50 and t > 0.25 and t < 0.6:
				c = c.lightened(0.15)  # light on the shoulder
			b.set_pixel(x, y, c)
	b.fill_rect(Rect2i(12, 62, 20, 22), Color("#F6EBD2"))  # label
	b.fill_rect(Rect2i(12, 62, 20, 1), Color("#FFF8E8"))
	b.fill_rect(Rect2i(12, 83, 20, 1), Color("#D9C7A2"))
	for y in 12:  # coffee bean, 8x12, with its crease
		var w := int(round(4.0 * sin((y + 0.5) / 12.0 * PI)))
		for x in range(22 - w, 22 + w):
			b.set_pixel(x, 67 + y, Color("#5A341C") if x > 22 - w else Color("#3A2416"))
		if y > 1 and y < 10:
			b.set_pixel(21 + (1 if y > 3 and y < 8 else 0), 67 + y, Color("#A87850"))
	b.set_pixel(20, 69, Color("#8C5A3A"))
	with_outline(b).save_png("res://assets/art/syrup_%s.png" % syrup)


## A copy of `b` with a 1 px dark outline round every opaque shape.
func with_outline(b: Image) -> Image:
	var out := b.duplicate()
	for y in b.get_height():
		for x in b.get_width():
			if b.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < b.get_width() and n.y >= 0 and n.y < b.get_height() and b.get_pixel(n.x, n.y).a > 0.0:
					out.set_pixel(x, y, Color("#1F1612"))
					break
	return out


## topping_<name>.png, 64x60: a steel container seen from the front and a little above (back
## rim, dark inside, the topping heaped in the opening, front rim, brushed front with lighter /
## darker side panels) and a cream name tag on the front (the station writes the name).
func container(topping: String) -> void:
	var bg := im
	im = Image.create(CONTAINER.x, CONTAINER.y, false, Image.FORMAT_RGBA8)  # the helpers draw into `im`
	box(1, 8, 62, 3, Color("#C8CED3"))  # back rim
	box(1, 11, 62, RIM - 11, Color("#6E757C"))  # side rims round the opening
	box(4, 11, 56, RIM - 11, Color("#3E4448"))  # dark inside
	box(4, 11, 56, 1, Color("#2C3134"))
	call(topping)
	box(1, RIM, 62, 2, Color("#E2E7EA"))  # front rim
	box(1, RIM + 2, 62, 1, Color("#9AA1A7"))
	box(1, RIM + 3, 62, 55 - RIM, Color("#A9B0B6"))  # front
	box(1, RIM + 3, 4, 55 - RIM, Color("#C3C9CE"))  # lit left panel
	box(5, RIM + 3, 1, 55 - RIM, Color("#B4BBC1"))
	box(57, RIM + 3, 1, 55 - RIM, Color("#979EA5"))
	box(58, RIM + 3, 5, 55 - RIM, Color("#8A9198"))  # shaded right panel
	for y in range(RIM + 7, 56, 6):  # brushed steel
		box(6, y, 51, 1, Color("#B2B9BF"))
	box(1, 56, 62, 2, Color("#7C838A"))
	tag_box(4, 40, 56, 12)
	with_outline(im).save_png("res://assets/art/topping_%s.png" % topping)
	im = bg


## Whipped cream: soft peaks of different sizes, lit from the left, each with a curled tip.
func cream() -> void:
	box(4, RIM - 6, 56, 6, Color("#EFE6D6"))
	for p in [[10, 5, 14], [27, 6, 15], [44, 5, 14], [56, 3, 10], [18, 8, 14], [36, 9, 15], [50, 7, 12]]:  # back row, then front
		var cx: int = p[0]
		var top: int = RIM - 8 - p[1]
		for y in range(top, RIM):
			var hw: float = p[2] / 2.0 * pow(float(y - top + 1) / (RIM - top), 0.4)  # round dollops with a small tip
			var x0 := int(round(cx - hw))
			var x1 := int(round(cx + hw))
			for x in range(maxi(x0, 4), mini(x1 + 1, 60)):
				var t := float(x - x0) / maxf(x1 - x0, 1)
				var c := Color("#FBF7F0")
				if t < 0.3:
					c = Color("#FFFFFF")
				elif t > 0.7:
					c = Color("#E6DCCB")
				if (x + y) % 5 == 0 and y > top + 1 and t > 0.3:
					c = Color("#EDE4D4")  # swirl ridge
				px(x, y, c)
		px(cx + 1, top - 1, Color("#FFFFFF"))  # curled tip
		px(cx + 1, top, Color("#E6DCCB"))


## Chocolate chips: a domed heap of irregular dark pieces with small highlights.
func choc_chips() -> void:
	var surface := func(x: int) -> int: return 9 + int(6.0 * pow((x - 31.5) / 28.0, 2.0))
	for x in range(4, 60):
		box(x, surface.call(x), 1, RIM - surface.call(x), Color("#2E170C"))
	var chips := []
	for i in 70:
		var x := rng.randi_range(5, 57)
		chips.append(Vector2i(x, rng.randi_range(surface.call(x), RIM - 2)))
	chips.sort_custom(func(a, b): return a.y < b.y)  # back first
	var shades := [Color("#4A2614"), Color("#5A3018"), Color("#3A1E10"), Color("#663821")]
	for c: Vector2i in chips:
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(2, 3)
		box(c.x, c.y, w, h, shades[rng.randi() % shades.size()])
		box(c.x + w - 1, c.y + h - 1, 1, 1, Color("#24120A"))
		if w > 2:
			px(c.x, c.y, Color("#8A5A3A"))


## Powder heap (cinnamon, cocoa): an uneven surface, grains of three shades, lit on top.
func powder(base: Color, grains: Array, light: Color, rise: float) -> void:
	for x in range(4, 60):
		var top := 13 + int(round(rise * sin(x * 0.31) + 0.8 * sin(x * 0.9 + 2.0)))
		for y in range(top, RIM):
			var c := base
			var r := rng.randf()
			if r < 0.45:
				c = grains[rng.randi() % grains.size()]
			if y == top or (y == top + 1 and r < 0.4):
				c = light
			px(x, y, c)


func cinnamon() -> void:
	powder(Color("#A0623A"), [Color("#B87446"), Color("#8A5230"), Color("#C07C4C"), Color("#94582F")], Color("#CD915F"), 1.8)


func cocoa() -> void:
	powder(Color("#5A3220"), [Color("#6B3A20"), Color("#4A2818"), Color("#7A4A30"), Color("#523020")], Color("#80533A"), 1.2)


# ---------- counter ----------

## Beige counter, lit towards the front (three tones, dithered only where they meet), stone
## speckles, a rounded front edge and a row of wood drawers with bevelled panels and handles.
## `top` = first counter row (behind everything), `edge` = the front edge; both pages use it.
func counter(top := SHELF_TOP, edge := 334) -> void:
	var back := TOP.darkened(0.03)
	var front := TOP.lightened(0.035)
	for y in range(top, edge):
		for x in W:
			var c := back if y < top + 34 else TOP if y < edge - 38 else front
			if y >= top + 34 and y < top + 40:
				c = dither(back, TOP, (y - top - 34) / 6.0, x, y)
			elif y >= edge - 38 and y < edge - 32:
				c = dither(TOP, front, (y - edge + 38) / 6.0, x, y)
			px(x, y, c)
	for i in int(520 * (edge - top) / 132.0):
		px(rng.randi_range(0, W - 1), rng.randi_range(top + 4, edge - 2), TOP_SPECK if i % 4 else TOP.lightened(0.08))
	box(0, edge, W, 1, Color("#F7EDD9"))  # rounded front edge
	box(0, edge + 1, W, 1, Color("#EDE0C6"))
	box(0, edge + 2, W, 1, Color("#E0D0B2"))
	box(0, edge + 3, W, 1, TOP_SHADE)
	box(0, edge + 4, W, 1, OUTLINE)
	box(0, edge + 5, W, H - edge - 5, WOOD_DARK)  # cabinet
	box(0, edge + 5, W, 1, WOOD_FRONT)
	box(0, edge + 6, W, 1, Color("#6A3E22"))  # shadow under the counter
	var py := edge + 9  # drawer panels
	var ph := H - 2 - py
	for sx in range(0, W, 80):
		box(sx, edge + 7, 1, H - edge - 7, WOOD_DEEP)
		box(sx + 4, py, 72, ph, Color("#82502E"))
		box(sx + 4, py, 72, 1, Color("#9A6640"))  # lit top / left bevel
		box(sx + 4, py, 1, ph, Color("#9A6640"))
		box(sx + 4, py + ph - 1, 72, 1, Color("#4E2C16"))  # shaded bottom / right bevel
		box(sx + 75, py, 1, ph, Color("#4E2C16"))
		for g in 4:  # grain
			box(sx + 8 + rng.randi_range(0, 50), rng.randi_range(py + 2, py + ph - 3), rng.randi_range(6, 14), 1, Color("#764628"))
		var hy := py + ph / 2 - 2
		box(sx + 32, hy, 16, 3, Color("#4A2A16"))  # handle
		box(sx + 32, hy, 16, 1, Color("#B08060"))
		box(sx + 33, hy + 3, 15, 1, Color("#3A2010"))
	box(0, H - 1, W, 1, WOOD_DEEP)


## A SERVE area (topping page: SERVE2_RECT, espresso page: SERVE_RECT): cream fill, soft shading,
## a dashed brown border, a soft shadow and a mug icon. The station writes "SERVE" under it.
func serve_area(r: Rect2i, mug_y: int) -> void:  # mug_y: the mug top, from r.position.y
	box(r.position.x + 2, r.end.y, r.size.x, 2, TOP_SHADE)
	box(r.end.x, r.position.y + 2, 2, r.size.y, TOP_SHADE)
	box(r.position.x, r.position.y, r.size.x, r.size.y, Color("#F1E4CB"))
	box(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1, Color("#F8EEDC"))
	box(r.position.x + 1, r.end.y - 4, r.size.x - 2, 3, Color("#E9DABD"))
	box(r.end.x - 3, r.position.y + 1, 2, r.size.y - 2, Color("#E9DABD"))
	var ink := Color("#8A6A4A")
	for x in range(r.position.x, r.end.x, 7):  # dashes: 4 on, 3 off
		box(x, r.position.y, mini(4, r.end.x - x), 1, ink)
		box(x, r.end.y - 1, mini(4, r.end.x - x), 1, ink)
	for y in range(r.position.y, r.end.y, 7):
		box(r.position.x, y, 1, mini(4, r.end.y - y), ink)
		box(r.end.x - 1, y, 1, mini(4, r.end.y - y), ink)
	var cx := r.position.x + r.size.x / 2 - 11  # mug, 18x14 plus handle, a saucer and steam
	var cy := r.position.y + mug_y
	box(cx, cy, 18, 14, Color("#FBF4E6"))
	outline(cx, cy, 18, 14, ink)
	box(cx + 1, cy + 1, 16, 2, Color("#B98A5E"))  # coffee
	outline(cx + 17, cy + 3, 6, 7, ink)
	box(cx - 3, cy + 14, 24, 1, ink)
	for s in 2:
		for k in 5:
			px(cx + 5 + s * 7 + (k % 2), cy - 2 - k, ink.lightened(0.2))


## Ribbed rubber cup mat (keep in step with EspressoStation.SLOTS).
func mat(cx: int) -> void:
	var x := cx - 46
	var w := 92
	var y0 := MAT_Y.x
	var h := MAT_Y.y - MAT_Y.x
	box(x + 3, y0 + h, w - 1, 3, TOP_SHADE)  # soft shadow on the counter
	box(x + w, y0 + 3, 2, h, TOP_SHADE)
	box(x, y0, w, h, Color("#1E1818"))  # outline
	box(x + 1, y0 + 1, w - 2, h - 2, Color("#4A3E3A"))  # raised frame
	box(x + 1, y0 + 1, w - 2, 1, Color("#6A5C56"))  # lit top edge
	box(x + 1, y0 + 1, 1, h - 2, Color("#5C4E48"))
	box(x + 1, y0 + h - 2, w - 2, 1, Color("#3A302C"))
	box(x + 5, y0 + 5, w - 10, h - 10, Color("#2E2626"))  # sunken well
	box(x + 5, y0 + 5, w - 10, 2, Color("#1E1818"))  # its top and left walls in shadow
	box(x + 5, y0 + 5, 2, h - 10, Color("#241D1D"))
	box(x + 5, y0 + h - 6, w - 10, 1, Color("#5A4C46"))  # lit lower lip
	for y in range(y0 + 10, y0 + h - 7, 5):  # grooves
		box(x + 9, y, w - 18, 1, Color("#1A1414"))
		box(x + 9, y + 1, w - 18, 1, Color("#3C3232"))


# ---------- side props ----------

func straw_holder(x: int, base_y: int) -> void:
	for s in 6:  # black stirrers, leaning a little
		var sx := x + 3 + s * 4
		for k in 30:
			px(sx + (k / 12 if s % 2 else -k / 14), base_y - 22 - k, Color("#2A2422") if k % 9 else Color("#4A4442"))
	box(x, base_y - 24, 26, 24, WOOD_FRONT)
	box(x, base_y - 24, 26, 2, WOOD_HI)
	box(x + 20, base_y - 22, 6, 22, WOOD_DARK)
	outline(x, base_y - 24, 26, 24)


func paper_cups(x: int, base_y: int) -> void:
	for k in 9:  # a tall stack of white paper cups, each rim a line
		var y := base_y - 6 - k * 4
		box(x + 1, y, 20, 6, WHITE)
		box(x, y, 22, 1, WHITE_LO)
		box(x + 16, y + 1, 4, 5, WHITE_LO)
	box(x + 2, base_y - 6, 18, 6, WHITE)
	box(x + 2, base_y - 1, 18, 1, GREY_LINE)
	box(x, base_y - 42, 1, 37, GREY_LINE)
	box(x + 21, base_y - 42, 1, 37, GREY_LINE)
	box(x, base_y - 43, 22, 1, GREY_LINE)


func potted_plant(x: int, base_y: int) -> void:
	for i in 70:  # spiky leaves fanning up from the pot
		var a := rng.randf_range(-1.2, 1.2)
		var r := rng.randf_range(4, 26)
		var lx := x + 13 + int(sin(a) * r)
		var ly := base_y - 18 - int(cos(a) * r)
		px(lx, ly, LEAF_LO if r < 10 else LEAF if i % 3 else LEAF_HI)
		px(lx, ly + 1, LEAF_LO)
	box(x + 2, base_y - 18, 22, 18, Color("#D8CFC0"))
	box(x + 2, base_y - 18, 22, 3, Color("#E8E1D4"))
	box(x + 18, base_y - 15, 6, 15, Color("#BDB2A0"))
	outline(x + 2, base_y - 18, 22, 18, Color("#6A5E50"))


func napkins(x: int, base_y: int) -> void:
	box(x + 3, base_y - 22, 24, 8, WHITE)  # napkins sticking out
	box(x + 3, base_y - 22, 24, 1, WHITE_LO)
	box(x, base_y - 16, 30, 16, WOOD_FRONT)
	box(x, base_y - 16, 30, 2, WOOD_HI)
	box(x + 6, base_y - 10, 18, 4, WOOD_DARK)  # slot
	outline(x, base_y - 16, 30, 16)


func glasses(x: int, base_y: int) -> void:
	for k in 8:  # a stack of clear glasses
		var y := base_y - 6 - k * 4
		box(x + 1, y, 22, 6, GLASS_FILL)
		box(x, y, 24, 1, GLASS_LINE)
		box(x + 4, y + 2, 2, 3, Color("#F4FAFC"))
	box(x, base_y - 38, 1, 38, GLASS_LINE)
	box(x + 23, base_y - 38, 1, 38, GLASS_LINE)
	box(x, base_y - 1, 24, 1, GLASS_LINE)


# ---------- espresso prep sprites ----------
# Same sizes as before, and every point EspressoStation measures from the art is kept:
# grinder spout x 50, chute bottom y 120, fork rim y 134 (GRINDER_*); portafilter rim (45,7),
# basket half width 12, spouts down to y 28 (PF_*). Re-measure those if this art changes.

var _canvas: Image  # the page being painted while a sprite borrows `im`


func begin_sprite(w: int, h: int) -> void:
	_canvas = im
	im = Image.create(w, h, false, Image.FORMAT_RGBA8)


func end_sprite(sprite_name: String) -> void:
	with_outline(im).save_png("res://assets/art/%s.png" % sprite_name)
	im = _canvas


func prep_sprites() -> void:
	grinder()
	bean_bag()
	tamp_mat()
	tamper()
	for state in ["empty", "dosed", "tamped", "used"]:
		portafilter(state)
	machine()
	cups_rack()
	pitcher()
	knock_box()
	ice_bin()


## A row of a symmetric shape around x `cx`: lit left edge, shaded right edge.
func shaded_row(cx: float, y: int, hw: float, c: Color, lit := 0.25, shade := 0.25) -> void:
	var x0 := int(round(cx - hw))
	var x1 := int(round(cx + hw))
	for x in range(x0, x1):
		var t := float(x - x0) / maxf(x1 - x0, 1)
		px(x, y, c.lightened(lit) if t < 0.18 else c.darkened(shade) if t > 0.8 else c)


## A small coffee bean (4x3 or 3x4) with a dark crease and a highlight.
func bean(x: int, y: int, c: Color, upright: bool) -> void:
	var s := Vector2i(3, 4) if upright else Vector2i(4, 3)
	box(x, y, s.x, s.y, c)
	px(x + 1, y + 1, Color("#2A160A"))  # crease
	px(x + (1 if upright else 2), y + (2 if upright else 1), Color("#2A160A"))
	px(x + s.x - 1, y, c.lightened(0.3))


## grinder.png, 96x180: dark round lid, glass hopper full of beans, dark collar, cream body
## with a brown "1" dial, red light, yellow arrow, spout and fork slots, black scale base with
## a green screen (EspressoStation writes the live dose on it, GRINDER_SCREEN).
func grinder() -> void:
	begin_sprite(96, 180)
	var cx := 50.0
	box(45, 2, 10, 4, Color("#3A383E"))  # lid knob
	box(46, 2, 4, 1, Color("#5C5A62"))
	for y in range(6, 21):  # lid: a low dome, widest at the rim
		var hw := 33.0 if y >= 18 else 22.0 + 11.0 * sin(float(y - 6) / 12.0 * PI / 2.0)
		shaded_row(cx, y, hw, Color("#2C2A2E") if y < 18 else Color("#1E1C20"), 0.35, 0.2)
	box(24, 8, 22, 1, Color("#56545C"))  # lid sheen
	for y in range(21, 62):  # glass hopper, tapering
		var hw := 28.0 - 10.0 * (y - 21) / 41.0
		var x0 := int(round(cx - hw))
		var x1 := int(round(cx + hw))
		box(x0, y, x1 - x0, 1, Color("#3A2010"))  # behind the beans
		px(x0, y, Color("#C8DCE4"))  # glass walls
		px(x1 - 1, y, Color("#A9BCC6"))
	var beans := []
	for i in 150:
		var y := rng.randi_range(25, 58)
		var hw := 28.0 - 10.0 * (y - 21) / 41.0 - 3.0
		beans.append(Vector2i(rng.randi_range(int(cx - hw), int(cx + hw) - 3), y))
	beans.sort_custom(func(a, b): return a.y < b.y)
	var shades := [Color("#6B3E22"), Color("#7A4628"), Color("#5A321A"), Color("#8A5530")]
	for b: Vector2i in beans:
		bean(b.x, b.y, shades[rng.randi() % shades.size()], rng.randf() < 0.4)
	for y in range(23, 58):  # glass glare over the beans
		px(int(cx - 22 + (y - 21) * 0.25), y, Color("#D8E6EC"))
	box(int(cx) - 28, 21, 56, 2, Color("#D8E6EC"))  # glass rim
	for y in range(62, 72):  # dark collar
		shaded_row(cx, y, 20.0, Color("#2E2C30"), 0.3, 0.25)
	box(31, 62, 38, 1, Color("#5C5A62"))
	box(31, 69, 38, 1, Color("#3E3C42"))
	for y in range(72, 146):  # cream body
		shaded_row(cx, y, 25.0, Color("#F2E6D0"), 0.15, 0.12)
	box(25, 72, 50, 2, Color("#D6C7AA"))  # shadow under the collar
	for y in range(-7, 8):  # brown dial with a "1"
		for x in range(-7, 8):
			var d := Vector2(x, y).length()
			if d <= 7.2:
				px(39 + x, 90 + y, Color("#5A3218") if d > 6.0 else Color("#A8683A") if x + y < -5 else Color("#8A5230"))
	box(39, 86, 1, 8, Color("#F2E6D0"))
	px(38, 87, Color("#F2E6D0"))
	box(38, 93, 3, 1, Color("#F2E6D0"))
	for y in range(-3, 4):  # red light
		for x in range(-3, 4):
			if Vector2(x, y).length() <= 3.2:
				px(60 + x, 89 + y, Color("#D9473F"))
	px(59, 88, Color("#FF9A8A"))
	for r in 6:  # yellow arrow pointing at the spout
		box(int(cx) - 5 + r, 100 + r, 11 - r * 2, 1, Color("#F2C230") if r < 4 else Color("#C8961E"))
	box(46, 110, 8, 10, Color("#2A2626"))  # spout, open at y 120
	box(46, 110, 1, 10, Color("#4A4446"))
	box(47, 119, 6, 1, Color("#141010"))
	for sx in [31, 65]:  # fork slots the basket rests between
		box(sx, 124, 4, 18, Color("#2A2626"))
		box(sx, 124, 4, 1, Color("#141010"))
	for y in range(146, 177):  # black scale base
		shaded_row(cx, y, 32.0, Color("#26232A") if y > 150 else Color("#3A3740"), 0.2, 0.25)
	box(18, 146, 64, 1, Color("#56535C"))
	box(30, 157, 40, 13, Color("#0F0E10"))  # screen
	box(31, 158, 38, 11, Color("#8FD07A"))
	box(31, 158, 38, 1, Color("#B5E8A0"))
	end_sprite("grinder")


## bean_bag.png, 56x70: kraft paper bag with a folded top, shaded side and a bean label.
func bean_bag() -> void:
	begin_sprite(56, 70)
	box(9, 14, 39, 54, Color("#C98B4E"))  # bag
	box(9, 14, 5, 54, Color("#DDA466"))
	box(40, 14, 8, 54, Color("#A86E38"))  # side
	box(39, 14, 1, 54, Color("#B87C44"))
	box(10, 4, 37, 11, Color("#E0AE70"))  # folded top
	for x in range(10, 47, 4):  # zig-zag top edge
		box(x, 3, 2, 1, Color("#E0AE70"))
	box(10, 12, 37, 2, Color("#B07840"))  # fold crease
	box(40, 4, 7, 8, Color("#C08A50"))
	box(16, 30, 22, 24, Color("#F6EBD2"))  # label
	box(16, 30, 22, 1, Color("#FFF8E8"))
	box(16, 53, 22, 1, Color("#D9C7A2"))
	for y in 12:  # coffee bean
		var w := int(round(4.0 * sin((y + 0.5) / 12.0 * PI)))
		box(27 - w, 36 + y, w * 2, 1, Color("#5A341C"))
		px(27 - w, 36 + y, Color("#3A2416"))
		if y > 1 and y < 10:
			px(26 + (1 if y > 3 and y < 8 else 0), 36 + y, Color("#A87850"))
	end_sprite("bean_bag")


## tamp_mat.png, 150x40: dark rubber mat with a lit top edge and an inner border.
func tamp_mat() -> void:
	begin_sprite(150, 40)
	box(3, 4, 144, 32, Color("#2E2A2C"))
	box(3, 4, 144, 1, Color("#4E494C"))  # lit top edge
	box(3, 34, 144, 2, Color("#221E20"))
	outline(6, 7, 138, 26, Color("#262224"))  # inner border
	box(7, 8, 136, 1, Color("#3A3638"))
	for i in 14:  # rubber sheen
		box(rng.randi_range(10, 130), rng.randi_range(10, 30), rng.randi_range(3, 8), 1, Color("#363234"))
	end_sprite("tamp_mat")


## tamper.png, 40x56: round wooden knob on a waisted wooden neck, a steel collar and short
## shaft, and a wide steel base (lit bevel on top) whose bottom row (53) stands on the mat.
func tamper() -> void:
	begin_sprite(40, 56)
	for y in range(6, 27):  # wooden knob: a dome, widest at y 12, narrowing to the neck
		var hw := 9.0 * sin(float(y - 5) / 7.0 * PI / 2.0) if y < 12 else 9.0 - 5.0 * pow(float(y - 12) / 14.0, 0.8)
		shaded_row(20.0, y, hw, Color("#8A4A26"), 0.3, 0.3)
	box(15, 8, 3, 1, Color("#D09060"))  # shine on the dome
	box(14, 9, 2, 2, Color("#C07A48"))
	for y in range(27, 30):  # steel collar
		shaded_row(20.0, y, 5.0, Color("#C8CED3"), 0.3, 0.3)
	for y in range(30, 39):  # shaft
		shaded_row(20.0, y, 3.0, Color("#B8BEC4"), 0.35, 0.35)
	for y in range(39, 42):  # base: lit bevel
		shaded_row(20.0, y, 10.0 + (y - 39), Color("#DDE2E6"), 0.2, 0.25)
	for y in range(42, 54):  # base: the steel puck
		shaded_row(20.0, y, 12.0, Color("#B8BEC4"), 0.3, 0.35)
	box(12, 43, 1, 9, Color("#EEF2F4"))  # vertical glint
	box(8, 52, 24, 2, Color("#7C838A"))  # bottom edge
	end_sprite("tamper")


## portafilter_<state>.png, 64x40, seen from the side: a tapered wooden handle (thick at the
## steel ferrule, rounded end), a steel neck into a chrome basket (rim from y 7, centred on
## x 45, half width 12) with one spout block and two nozzles down to y 27; contents by state.
func portafilter(state: String) -> void:
	begin_sprite(64, 40)
	for x in range(2, 23):  # wooden handle: 6 rows at the end, 8 at the ferrule
		var t := float(x - 2) / 20.0
		var top := 13 - int(round(t))
		var bot := 18 + int(round(t))
		if x == 2:
			top += 1
			bot -= 1
		box(x, top, 1, bot - top + 1, Color("#8A4A26"))
		px(x, top, Color("#B8743F"))  # lit top edge
		px(x, bot, Color("#5A2E14"))
		if x % 5 != 0:
			px(x, (top + bot) / 2, Color("#7A4020"))  # grain line
	box(23, 11, 3, 10, Color("#C8CED3"))  # steel ferrule
	box(23, 11, 3, 1, Color("#EEF2F4"))
	box(25, 11, 1, 10, Color("#8C939A"))
	for x in range(26, 35):  # neck, rising a touch into the basket
		var lift := 1 if x > 30 else 0
		box(x, 12 - lift, 1, 7, Color("#B8BEC4"))
		px(x, 12 - lift, Color("#DDE2E6"))
		px(x, 18 - lift, Color("#7C838A"))
	for y in range(10, 20):  # chrome basket, tapering
		shaded_row(45.0, y, 12.0 - (y - 10) * 0.25, Color("#B8BEC4"), 0.35, 0.35)
	box(37, 11, 2, 8, Color("#EEF2F4"))  # chrome glint
	box(35, 19, 21, 2, Color("#7C838A"))  # bottom plate
	box(41, 21, 9, 3, Color("#9AA1A7"))  # spout block
	box(41, 21, 9, 1, Color("#C8CED3"))
	for sx in [41, 47]:  # two nozzles
		box(sx, 24, 3, 3, Color("#8C939A"))
		box(sx, 24, 1, 3, Color("#C8CED3"))
	box(33, 8, 24, 2, Color("#DDE2E6"))  # rim
	box(34, 7, 22, 1, Color("#EEF2F4"))
	box(33, 9, 24, 1, Color("#A9B0B6"))
	match state:
		"empty":
			box(36, 8, 18, 1, Color("#4A4F54"))  # looking into the empty basket
		"dosed":
			for y in range(3, 9):  # loose mound of grounds
				var hw := 10.0 * sqrt(float(y - 2) / 6.0)
				for x in range(int(45 - hw), int(45 + hw)):
					px(x, y, [Color("#5A3220"), Color("#6B3A20"), Color("#4A2818")][rng.randi() % 3])
			px(42, 4, Color("#8A5A3A"))
			px(46, 3, Color("#8A5A3A"))
		"tamped":
			box(35, 7, 20, 2, Color("#4A2A18"))  # flat, smooth puck
			box(35, 7, 20, 1, Color("#6A4028"))
		"used":
			box(35, 7, 20, 2, Color("#2E1A0E"))  # spent puck with cracks
			for x in [38, 44, 51]:
				px(x, 7, Color("#1A0E06"))
				px(x + 1, 8, Color("#1A0E06"))
			px(41, 7, Color("#4A2E1C"))
	end_sprite("portafilter_" + state)


## Filled disc of radius r at (cx, cy), lit at the top left.
func disc(cx: int, cy: int, r: float, c: Color, lit := 0.2) -> void:
	for y in range(-int(r), int(r) + 1):
		for x in range(-int(r), int(r) + 1):
			if Vector2(x, y).length() <= r:
				px(cx + x, cy + y, c.lightened(lit) if x + y < -r * 0.6 else c.darkened(lit * 0.7) if x + y > r * 0.7 else c)


## machine.png, 300x290. Kept from the old art (EspressoStation measures them): group head
## centres x 82 / 197 with their bottom row ending at y 182, scale pads with their edge at
## y 232 and top at y 236 (CUP_STAND_Y), the steam wand down to about (266, 186).
func machine() -> void:
	begin_sprite(300, 290)
	var steel := Color("#B8BEC4")
	for px_x in [16, 256]:  # corner posts
		box(px_x, 14, 8, 60, Color("#A9B0B6"))
		box(px_x, 14, 2, 60, Color("#D8DDE1"))
		box(px_x + 6, 14, 2, 60, Color("#7C838A"))
		box(px_x - 1, 12, 10, 3, Color("#C8CED3"))
	box(24, 26, 232, 4, Color("#4A484E"))  # cup warmer top
	box(24, 30, 232, 40, Color("#34323A"))  # upper housing
	box(24, 34, 232, 1, Color("#45434A"))
	box(24, 66, 232, 4, Color("#8C939A"))  # steel trim
	box(24, 66, 232, 1, Color("#C8CED3"))
	box(16, 74, 248, 82, Color("#2A282C"))  # main body
	box(16, 74, 248, 1, Color("#46444A"))
	box(16, 74, 2, 82, Color("#3A383E"))
	box(32, 90, 216, 40, Color("#D9A05A"))  # control panel
	box(32, 90, 216, 2, Color("#EDBE7E"))
	box(32, 127, 216, 3, Color("#B07C3E"))
	box(32, 90, 2, 40, Color("#E6B070"))
	box(246, 90, 2, 40, Color("#B88440"))
	outline(31, 89, 218, 42, Color("#1E1C20"))
	for s in [Vector2i(36, 94), Vector2i(242, 94), Vector2i(36, 124), Vector2i(242, 124)]:  # screws
		box(s.x, s.y, 3, 3, Color("#8C939A"))
		px(s.x, s.y, Color("#DDE2E6"))
	for kx in [67, 212]:  # knobs
		disc(kx, 110, 11.5, Color("#1A181C"), 0.0)
		disc(kx, 110, 10.0, Color("#34323A"), 0.25)
		box(kx - 1, 109, 3, 3, Color("#1A181C"))
	disc(140, 110, 17.5, Color("#1E1C20"), 0.0)  # pressure gauge
	disc(140, 110, 15.5, Color("#B8BEC4"), 0.3)
	disc(140, 110, 13.0, Color("#FBFBF6"), 0.0)
	for k in 12:  # ticks
		var a := k * TAU / 12.0
		px(140 + int(round(sin(a) * 11.0)), 110 - int(round(cos(a) * 11.0)), Color("#1E1C20"))
		if k % 3 == 0:
			px(140 + int(round(sin(a) * 10.0)), 110 - int(round(cos(a) * 10.0)), Color("#1E1C20"))
	for r in 10:  # red needle, pointing up and a little left
		px(140 + int(round(sin(-0.5) * r)), 110 - int(round(cos(-0.5) * r)), Color("#D9473F"))
	box(139, 109, 3, 3, Color("#1E1C20"))
	box(16, 156, 16, 92, Color("#D9A05A"))  # wood side panels
	box(16, 156, 3, 92, Color("#EDBE7E"))
	box(248, 156, 16, 92, Color("#C08A48"))
	box(261, 156, 3, 92, Color("#A87436"))
	box(32, 156, 216, 80, Color("#2A2628"))  # brew recess
	box(32, 156, 216, 6, Color("#1C181A"))
	for hx in [82, 197]:  # group heads
		box(hx - 24, 156, 48, 6, Color("#4A4F54"))  # mount plate
		box(hx - 24, 156, 48, 1, Color("#6E757C"))
		for y in range(162, 174):
			shaded_row(hx, y, 20.0 - (y - 162) * 0.2, steel, 0.35, 0.3)
		box(hx - 18, 165, 4, 1, Color("#EEF2F4"))  # chrome glint
		for y in range(174, 178):  # collar
			shaded_row(hx, y, 22.0, Color("#8C939A"), 0.4, 0.3)
		for y in range(178, 182):  # gasket ring the basket locks into
			shaded_row(hx, y, 17.0, Color("#4A4F54"), 0.2, 0.3)
		box(hx - 22, 176, 3, 4, Color("#9AA1A7"))  # bayonet lugs
		box(hx + 19, 176, 3, 4, Color("#9AA1A7"))
	box(12, 218, 256, 58, Color("#2A2628"))  # dark base (clear of the knock box on its left)
	box(12, 218, 256, 1, Color("#46424A"))
	box(12, 272, 256, 4, Color("#1C181A"))
	box(20, 236, 240, 28, Color("#A9B0B6"))  # drip tray
	box(20, 236, 240, 2, Color("#D8DDE1"))
	for y in range(244, 260, 4):  # grooves
		box(24, y, 232, 1, Color("#7C838A"))
		box(24, y + 1, 232, 1, Color("#C3C9CE"))
	for x in range(26, 256, 5):  # perforations
		px(x, 240, Color("#6E757C"))
	box(20, 260, 240, 4, Color("#8C939A"))  # front lip
	box(20, 263, 240, 1, Color("#5A6066"))
	for hx in [82, 197]:  # scale pads, edge at 232, top at 236
		box(hx - 25, 232, 50, 5, Color("#4A484E"))
		box(hx - 25, 232, 50, 1, Color("#6A686E"))
		box(hx - 25, 237, 50, 12, Color("#2E2C30"))
		box(hx - 20, 244, 40, 3, Color("#6BD46B"))
		box(hx - 20, 244, 40, 1, Color("#A8F0A0"))
	box(263, 109, 28, 5, Color("#8C939A"))  # steam pipe from the post
	box(263, 109, 28, 1, Color("#C8CED3"))
	disc(291, 112, 4.0, Color("#A9B0B6"), 0.3)  # valve joint
	for k in 74:  # wand, down to its tip at about (266, 186)
		var x := 291 - int(round(k * 25.0 / 74.0))
		var y := 114 + k
		box(x - 1, y, 3, 1, steel)
		px(x - 1, y, Color("#DDE2E6"))
		px(x + 1, y, Color("#7C838A"))
	box(264, 186, 4, 3, Color("#4A4F54"))  # tip
	end_sprite("machine")


## pitcher.png, 60x64: steel milk pitcher, spout to the left, handle to the right. Its mouth
## is the oval PitcherMilk fills (centre (25.5, 5.5), radii 16 x 3.4): keep it there.
func pitcher() -> void:
	begin_sprite(60, 64)
	var steel := Color("#B8BEC4")
	for y in range(9, 62):  # bell-shaped body, widest low down
		var hw := 16.5 + 2.5 * sin(clampf((y - 9) / 46.0, 0.0, 1.0) * PI / 2.0)
		if y > 58:
			hw -= (y - 58) * 0.8
		shaded_row(25.5, y, hw, steel, 0.3, 0.3)
	for y in range(12, 58):  # vertical reflections
		px(14, y, Color("#E6EBEE"))
		px(15, y, Color("#D8DDE1"))
		px(33, y, Color("#C8CED3"))
	box(10, 59, 32, 1, Color("#7C838A"))  # base ring
	for x in range(41, 56):  # handle: top arm, back, bottom arm
		box(x, 12, 1, 3, Color("#A9B0B6"))
		box(x, 38, 1, 3, Color("#8C939A"))
	box(52, 12, 4, 29, Color("#9AA1A7"))
	box(52, 12, 1, 29, Color("#C8CED3"))
	box(45, 15, 7, 23, Color(0, 0, 0, 0))  # gap inside the handle
	for y in 9:  # rim: an oval band round the mouth
		for x in 40:
			var d := Vector2((x + 5.5 - 25.5) / 18.0, (y + 1.0 - 5.5) / 4.6).length()
			if d <= 1.0:
				px(x + 5, y + 1, Color("#DDE2E6") if d > 0.8 else Color("#3E434B"))
	box(1, 3, 6, 3, Color("#DDE2E6"))  # pouring spout, tipped up to the left
	box(0, 2, 3, 2, Color("#C8CED3"))
	end_sprite("pitcher")


## knock_box.png, 56x44: dark bin with a raised rim, a dark opening and a wooden knock bar
## with steel end caps across it.
func knock_box() -> void:
	begin_sprite(56, 44)
	for y in range(12, 43):  # body, a little narrower at the foot
		shaded_row(27.5, y, 24.0 - (y - 12) * 0.08, Color("#34302E"), 0.25, 0.35)
	box(6, 41, 44, 1, Color("#1C1816"))
	box(3, 14, 2, 26, Color("#4A4642"))  # lit left edge
	box(2, 3, 52, 10, Color("#4A4642"))  # raised rim
	box(2, 3, 52, 1, Color("#6E6A66"))
	box(5, 5, 46, 6, Color("#141012"))  # the opening
	box(5, 5, 46, 1, Color("#0A0808"))
	box(4, 7, 48, 3, Color("#8A4A26"))  # knock bar across the opening
	box(4, 7, 48, 1, Color("#B06A3A"))
	box(4, 9, 48, 1, Color("#5A2E14"))
	for cx in [1, 51]:  # steel end caps on the rim
		box(cx, 6, 4, 5, Color("#B8BEC4"))
		box(cx, 6, 4, 1, Color("#DDE2E6"))
		box(cx + 3, 7, 1, 4, Color("#7C838A"))
	box(2, 12, 52, 1, Color("#2A2624"))
	end_sprite("knock_box")


## ice_bin.png, 56x48: steel tray heaped with pale blue cubes and a scoop; the front panel
## is left plain for the station's "ICE" label (at 18, 34).
func ice_bin() -> void:
	begin_sprite(56, 48)
	box(2, 14, 52, 6, Color("#7C838A"))  # back rim
	var cubes := []
	for i in 44:
		cubes.append(Vector2i(rng.randi_range(3, 47), rng.randi_range(2 + absi(i % 9 - 4), 15)))  # heaped in the middle
	cubes.sort_custom(func(a, b): return a.y < b.y)
	for c: Vector2i in cubes:
		box(c.x, c.y, 6, 6, Color("#BFE3F4"))
		box(c.x, c.y, 6, 1, Color("#F2FBFF"))
		box(c.x, c.y, 1, 6, Color("#E2F4FC"))
		box(c.x + 5, c.y + 1, 1, 5, Color("#8CC4E0"))
		box(c.x + 1, c.y + 5, 5, 1, Color("#8CC4E0"))
	for k in 16:  # scoop handle leaning out of the ice
		box(44 - k / 2, 1 + k, 3, 1, Color("#6E757C"))
		px(44 - k / 2, 1 + k, Color("#A9B0B6"))
	box(32, 13, 9, 4, Color("#C8CED3"))  # scoop bowl
	box(1, 18, 54, 3, Color("#4A4F54"))  # dark front rim
	box(1, 18, 54, 1, Color("#8C939A"))
	box(2, 21, 52, 25, Color("#B8C2CA"))  # front panel
	box(2, 21, 3, 25, Color("#D8E0E6"))
	box(50, 21, 4, 25, Color("#8C969E"))
	for y in range(24, 44, 6):  # brushed lines
		box(6, y, 43, 1, Color("#C6CED4"))
	box(2, 45, 52, 1, Color("#6E757C"))
	end_sprite("ice_bin")


## cups_rack.png, 200x70: four white mugs (left half, x < 100) and four pale blue glasses
## (right half) on a dark shelf. EspressoStation splits a tap at x 100: mug or glass.
func cups_rack() -> void:
	begin_sprite(200, 70)
	box(4, 46, 192, 4, Color("#4A484E"))  # shelf top
	box(4, 46, 192, 1, Color("#6A686E"))
	box(4, 50, 192, 7, Color("#2E2C30"))
	for i in 4:  # mugs, handles to the right
		var x := 8 + i * 22
		for y in range(22, 46):
			shaded_row(x + 9, y, 9.0 - (y - 22) * 0.04, Color("#F4EEE2"), 0.2, 0.15)
		box(x + 1, 22, 16, 2, Color("#FFFFFF"))  # rim
		box(x + 2, 23, 14, 1, Color("#C9BFAE"))  # inside
		outline(x + 18, 27, 4, 10, Color("#E2D9C8"))  # handle
		box(x + 19, 28, 2, 8, Color(0, 0, 0, 0))
	for i in 4:  # glasses
		var x := 106 + i * 22
		for y in range(26, 46):
			shaded_row(x + 9, y, 8.0, Color("#A8D4EA"), 0.3, 0.2)
		box(x + 1, 26, 16, 2, Color("#DDF0FA"))
		box(x + 3, 29, 2, 14, Color("#E6F6FC"))  # glint
	end_sprite("cups_rack")
