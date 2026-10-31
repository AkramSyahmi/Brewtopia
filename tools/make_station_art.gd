extends SceneTree
## Paints station sprites at the station's base resolution (1 px = 2 screen px):
## milk_fridge.png, a freestanding steel fridge with a glass door, two shelves of milk
## cartons, a door handle and a plinth. (The COLD MILK plate is drawn by the station.)
## Run: Godot_console.exe --headless --path . --script res://tools/make_station_art.gd

const OUTLINE := Color("#1F1612")
const STEEL := Color("#B8BEC4")
const STEEL_HI := Color("#D8DDE1")
const STEEL_LO := Color("#8C939A")
const FRAME := Color("#6E757C")
const GLASS := Color("#BFE0EE")
const GLASS_BACK := Color("#9CC6D8")
const GLINT := Color("#EAF6FB")
const SHELF := Color("#7F98A4")
const CARTON := Color("#F7F6F0")
const CARTON_LO := Color("#D9D8D0")
const BAND := Color("#D9473F")
const W := 74
const H := 116
const DOOR := Rect2i(5, 5, 64, 96)  # glass door incl. its frame (keep in sync with FRIDGE_DOOR)


func _initialize() -> void:
	var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			im.set_pixel(x, y, body(x, y))
	for row in [14, 60]:  # two shelves, two cartons each
		for col in [16, 40]:
			carton(im, col, row)
		hline(im, DOOR.position.x + 3, DOOR.end.x - 4, row + 22, SHELF)
	for k in 30:  # a diagonal reflection across the glass
		var x := DOOR.position.x + 6 + k
		var y := DOOR.end.y - 8 - k * 2
		for t in 2:
			if y - t > DOOR.position.y + 2 and im.get_pixel(x, y - t) == GLASS_BACK:
				im.set_pixel(x, y - t, GLINT)
	im.save_png("res://assets/art/milk_fridge.png")
	print("milk_fridge.png written")
	quit()


func body(x: int, y: int) -> Color:
	if (x == 0 or x == W - 1) and (y == 0 or y == H - 1):
		return Color.TRANSPARENT
	if y >= H - 6 and (x < 4 or x > W - 5) and y > H - 3:
		return Color.TRANSPARENT
	if x == 0 or x == W - 1 or y == 0 or y == H - 1:
		return OUTLINE
	if y >= H - 12:  # plinth with vent slots
		if y == H - 12:
			return OUTLINE
		if (y == H - 8 or y == H - 6) and x > 10 and x < W - 11 and x % 3 != 0:
			return Color("#3A3F45")
		return STEEL_LO
	if DOOR.has_point(Vector2i(x, y)):
		var d := Vector2i(x, y) - DOOR.position
		if d.x == 0 or d.y == 0 or d.x == DOOR.size.x - 1 or d.y == DOOR.size.y - 1:
			return OUTLINE
		if d.x <= 2 or d.y <= 2 or d.x >= DOOR.size.x - 3 or d.y >= DOOR.size.y - 3:
			return FRAME.lightened(0.15) if d.y <= 2 or d.x <= 2 else FRAME
		return GLASS_BACK if d.y > 4 else GLASS  # light catches the top of the glass
	if x <= 2:
		return STEEL_HI
	if x >= W - 3:
		return STEEL_LO
	if (x == 2 or x == 3) and y > 40 and y < 70:
		return STEEL_HI
	return STEEL


func hline(im: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		im.set_pixel(x, y, c)


## A milk carton (13x21) standing with its base on row y+21: gable top, red band.
func carton(im: Image, x0: int, y0: int) -> void:
	for y in 21:
		for x in 13:
			var c := Color.TRANSPARENT
			if y < 5:  # gable roof
				var half := y + 1
				if absi(x - 6) <= half:
					c = OUTLINE if absi(x - 6) == half or y == 0 else CARTON
			elif x == 0 or x == 12 or y == 20:
				c = OUTLINE
			elif y >= 7 and y <= 11:
				c = BAND
			elif x >= 10:
				c = CARTON_LO
			else:
				c = CARTON
			if c.a > 0:
				im.set_pixel(x0 + x, y0 + y, c)
