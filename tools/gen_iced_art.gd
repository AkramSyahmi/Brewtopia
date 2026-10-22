extends SceneTree
## Placeholder pixel art for iced drinks (ART_LIST.md section 1): the tall plastic cup,
## the stack of plastic cups and the ice bin. Run:
##   Godot_console.exe --headless --path . --script res://tools/gen_iced_art.gd
## then `--import`. Replace any PNG with better art of the same size and name.

const OUT := "res://assets/art/%s.png"
const LINE := Color("#36251D")
const PLASTIC := Color("#E4EEF2", 0.55)
const PLASTIC_EDGE := Color("#B7CBD3")
const STEEL := Color("#B9BEC6")
const STEEL_DARK := Color("#7D828A")
const ICE := Color("#D8F1FA")
const ICE_SHADE := Color("#A9D7EA")


func _init() -> void:
	var keep: Array = ArtKeep.names()  # never overwrite real art
	if not "cup_iced" in keep:
		cup_iced()
	if not "iced_cups" in keep:
		iced_cups()
	if not "ice_bin" in keep:
		ice_bin()
	quit()


func box(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


func outline(img: Image, r: Rect2i, c: Color) -> void:
	box(img, Rect2i(r.position.x, r.position.y, r.size.x, 1), c)
	box(img, Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), c)
	box(img, Rect2i(r.position.x, r.position.y, 1, r.size.y), c)
	box(img, Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), c)


## Tall clear plastic cup, slightly wider at the top. 32x52.
func plastic_cup(img: Image, ox: int, oy: int) -> void:
	for y in 48:
		var inset := 3 - int(y * 3 / 48.0)  # narrower at the bottom
		var x0 := ox + 2 + (3 - inset)
		var x1 := ox + 30 - (3 - inset)
		box(img, Rect2i(x0, oy + 4 + y, x1 - x0, 1), PLASTIC)
		img.set_pixel(x0, oy + 4 + y, LINE)
		img.set_pixel(x1 - 1, oy + 4 + y, LINE)
	box(img, Rect2i(ox + 1, oy + 2, 30, 3), PLASTIC_EDGE)  # rim
	outline(img, Rect2i(ox + 1, oy + 2, 30, 3), LINE)
	box(img, Rect2i(ox + 5, oy + 51, 22, 1), LINE)
	box(img, Rect2i(ox + 8, oy + 10, 2, 30), Color(1, 1, 1, 0.6))  # shine


func cup_iced() -> void:
	var img := Image.create_empty(32, 52, false, Image.FORMAT_RGBA8)
	plastic_cup(img, 0, -1)
	img.save_png(OUT % "cup_iced")


## Three upside-down plastic cups stacked on a small steel tray. 34x70.
func iced_cups() -> void:
	var img := Image.create_empty(34, 70, false, Image.FORMAT_RGBA8)
	for k in 3:
		var y := 4 + k * 8
		box(img, Rect2i(3, y, 28, 40), PLASTIC)
		outline(img, Rect2i(3, y, 28, 40), PLASTIC_EDGE)
		box(img, Rect2i(2, y + 38, 30, 3), PLASTIC_EDGE)
		outline(img, Rect2i(2, y + 38, 30, 3), LINE)
	box(img, Rect2i(0, 64, 34, 6), STEEL)
	outline(img, Rect2i(0, 64, 34, 6), LINE)
	img.save_png(OUT % "iced_cups")


## Steel ice bin full of cubes with a scoop. 56x48.
func ice_bin() -> void:
	var img := Image.create_empty(56, 48, false, Image.FORMAT_RGBA8)
	box(img, Rect2i(0, 8, 56, 40), STEEL)
	outline(img, Rect2i(0, 8, 56, 40), LINE)
	box(img, Rect2i(3, 11, 50, 34), STEEL_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:  # ice cubes heaped above the rim
		var x := rng.randi_range(3, 44)
		var y := rng.randi_range(4, 30)
		box(img, Rect2i(x, y, 9, 8), ICE)
		box(img, Rect2i(x, y + 6, 9, 2), ICE_SHADE)
		outline(img, Rect2i(x, y, 9, 8), PLASTIC_EDGE)
	box(img, Rect2i(36, 2, 6, 22), STEEL)  # scoop handle
	outline(img, Rect2i(36, 2, 6, 22), LINE)
	img.save_png(OUT % "ice_bin")
