extends SceneTree
## Generates placeholder background PNGs (see ART_LIST.md) into res://assets/art/.
## Run: Godot_console.exe --headless --path . --script res://tools/gen_backgrounds.gd

const OUT := "res://assets/art/"
var KEEP: Array = ArtKeep.names()  # replaced by real art (assets/art/KEEP.txt); never overwrite



func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if not "counter_bg" in KEEP:
		counter_bg()  # first: the bar backgrounds reuse its skyline
	if not "station_bg" in KEEP:
		station_bg()
	if not "topping_bg" in KEEP:
		topping_bg()
	if not "counter_front" in KEEP:
		counter_front()
	quit()


const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func dither(a: Color, b: Color, t: float, x: int, y: int) -> Color:
	return b if t * 16.0 > BAYER[(y % 4) * 4 + x % 4] + 0.5 else a


## Front counter background: an evening KL skyline (Petronas Twin Towers, KL Tower)
## seen through the café window, with fairy lights. 640x360; the counter covers y >= 200.
func counter_bg() -> void:
	var img := Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)
	var stops := [Color("#2E2348"), Color("#5B3A6A"), Color("#A35E78"), Color("#E89A72")]
	for y in 200:
		var t := float(y) / 199.0 * (stops.size() - 1)
		var i := mini(int(t), stops.size() - 2)
		for x in 640:
			img.set_pixel(x, y, dither(stops[i], stops[i + 1], t - i, x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:  # stars
		img.set_pixel(rng.randi_range(0, 639), rng.randi_range(0, 70), Color("#F5E7CA"))
	# far skyline
	var x := 0
	while x < 640:
		var w := rng.randi_range(14, 34)
		var h := rng.randi_range(40, 90)
		building(img, x, 200 - h, w, h, Color("#4A3558"), 0.25, rng)
		x += w + rng.randi_range(0, 4)
	kl_tower(img, 108)
	petronas(img, 420)
	# near buildings
	x = -10
	while x < 640:
		var w := rng.randi_range(30, 60)
		var h := rng.randi_range(30, 70)
		if x < 380 or x > 500:
			building(img, x, 200 - h, w, h, Color("#7A4A66"), 0.45, rng)
		x += w + rng.randi_range(6, 20)
	# window frame and fairy lights
	for px in [0, 210, 430, 636]:
		img.fill_rect(Rect2i(px, 0, 4, 200), Color("#2A1A16"))
	img.fill_rect(Rect2i(0, 0, 640, 4), Color("#2A1A16"))
	for i in 3:
		for lx in range(0, 210, 2):
			var gx: int = i * 213 + lx
			var sag := int(14.0 * sin(PI * lx / 210.0))
			img.set_pixel(gx, 8 + sag, Color("#3A2A22"))
			if lx % 14 == 0:
				img.fill_rect(Rect2i(gx - 1, 9 + sag, 3, 3), Color("#FFE08A"))
	img.fill_rect(Rect2i(0, 188, 640, 12), Color("#3A2219"))  # back counter edge
	img.fill_rect(Rect2i(0, 188, 640, 2), Color("#5E3A2A"))
	img.save_png(ProjectSettings.globalize_path(OUT + "counter_bg.png"))


func building(img: Image, x: int, y: int, w: int, h: int, c: Color, lit: float, rng: RandomNumberGenerator) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)
	for wy in range(y + 4, y + h - 2, 6):
		for wx in range(x + 3, x + w - 3, 5):
			if rng.randf() < lit:
				img.fill_rect(Rect2i(wx, wy, 2, 3), Color("#FFD58A"))


func petronas(img: Image, cx: int) -> void:
	var c := Color("#6A4E7A")
	for tx in [cx - 22, cx + 22]:
		for seg in 6:  # stepped tower, narrowing upwards
			var w := 22 - seg * 3
			var y0 := 200 - 22 * (seg + 1)
			img.fill_rect(Rect2i(tx - w / 2, y0, w, 22), c)
			for wy in range(y0 + 3, y0 + 20, 4):
				img.fill_rect(Rect2i(tx - w / 2 + 2, wy, w - 4, 1), Color("#D9B7E0"))
		img.fill_rect(Rect2i(tx - 1, 200 - 160, 2, 28), Color("#C9B0D0"))  # spire
	img.fill_rect(Rect2i(cx - 14, 120, 28, 4), c)  # skybridge
	img.fill_rect(Rect2i(cx - 14, 121, 28, 1), Color("#FFD58A"))


func kl_tower(img: Image, cx: int) -> void:
	var c := Color("#5E4470")
	img.fill_rect(Rect2i(cx - 3, 80, 6, 120), c)
	img.fill_rect(Rect2i(cx - 10, 70, 20, 12), c)
	img.fill_rect(Rect2i(cx - 8, 74, 16, 2), Color("#FFD58A"))
	img.fill_rect(Rect2i(cx - 1, 40, 2, 30), Color("#C9B0D0"))


## Dark wooden counter (y 200..360 of the screen) with an under-counter shelf.
func counter_front() -> void:
	var img := Image.create_empty(640, 160, false, Image.FORMAT_RGBA8)
	img.fill(Color("#5A3526"))
	for y in range(6, 96, 9):
		for x in range(0, 640, 23):  # wood grain
			img.fill_rect(Rect2i(x + (y * 7) % 11, y, 14, 1), Color("#4E2D20"))
	img.fill_rect(Rect2i(0, 0, 640, 5), Color("#7A4C36"))
	img.fill_rect(Rect2i(0, 5, 640, 2), Color("#3A2219"))
	img.fill_rect(Rect2i(0, 112, 640, 48), Color("#2E1A13"))  # under-counter shelf
	img.fill_rect(Rect2i(0, 112, 640, 3), Color("#6A4231"))
	for sx in [0, 160, 320, 480, 636]:
		img.fill_rect(Rect2i(sx, 112, 4, 48), Color("#4A2C20"))
	img.fill_rect(Rect2i(214, 14, 212, 86), Color("#6A4231"))  # central work mat
	img.fill_rect(Rect2i(218, 18, 204, 78), Color("#5E3A2A"))
	img.save_png(ProjectSettings.globalize_path(OUT + "counter_front.png"))




## Back bar in the café's daytime look (brewtopia 2 reference, same palette as CafeRoom):
## a light grey wall with a wood-framed window (patterned privacy film), a poster and an
## outlet along the top; the beige stone counter top below. Used by station_bg and topping_bg.
const WALL := Color("#CDCDCB")
const WALL_SHADE := Color("#C2C2C0")
const TOP := Color("#D8CFC1")
const TOP_SHADE := Color("#CEC4B5")
const FRAME := Color("#8C5A3A")
const GLASS := Color("#BFDCE3")
const FILM := Color("#EEF3F7")
const LINE := Color("#36251D")


func bar_base() -> Image:
	var img := Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 640, 104), WALL)
	for x in range(0, 640, 2):  # soft shading towards the counter
		for y in range(84, 100):
			img.set_pixel(x + (y % 2), y, dither(WALL, WALL_SHADE, (y - 84) / 16.0, x, y))
	# window with a patterned film on its lower half
	img.fill_rect(Rect2i(452, 4, 172, 98), FRAME)
	img.fill_rect(Rect2i(458, 10, 160, 88), GLASS)
	img.fill_rect(Rect2i(458, 56, 160, 42), FILM)
	for i in 14:  # little blue "%" marks
		var mx := 466 + (i % 7) * 22
		var my := 62 + (i / 7) * 18 + (i % 2) * 6
		for k in 5:
			img.set_pixel(mx + k, my + 4 - k, Color("#4E6FC4"))
	img.fill_rect(Rect2i(536, 10, 4, 88), FRAME)  # window bar
	for k in 3:  # glare
		img.fill_rect(Rect2i(470 + k * 4, 14 + k * 6, 2, 26), Color("#E2F1F4"))
	# poster and outlet
	img.fill_rect(Rect2i(176, 14, 30, 44), LINE)
	img.fill_rect(Rect2i(178, 16, 26, 40), Color("#2F3A30"))
	img.fill_rect(Rect2i(184, 22, 14, 14), Color("#8C6A3E"))
	img.fill_rect(Rect2i(182, 42, 18, 2), Color("#E9E4D8"))
	img.fill_rect(Rect2i(414, 74, 18, 10), Color("#F2F2F0"))
	img.fill_rect(Rect2i(418, 78, 2, 3), LINE)
	img.fill_rect(Rect2i(426, 78, 2, 3), LINE)
	# counter top: beige stone with a lighter front edge line at the wall
	img.fill_rect(Rect2i(0, 104, 640, 256), TOP)
	img.fill_rect(Rect2i(0, 102, 640, 2), LINE)
	img.fill_rect(Rect2i(0, 104, 640, 3), Color("#E6DED2"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 900:  # stone speckles
		img.set_pixel(rng.randi_range(0, 639), rng.randi_range(108, 359), TOP_SHADE)
	return img


func station_bg() -> void:
	bar_base().save_png(ProjectSettings.globalize_path(OUT + "station_bg.png"))


## Topping station: same back bar plus a light-wood syrup shelf and two cup slot mats
## (EspressoStation.SLOTS).
func topping_bg() -> void:
	var img := bar_base()
	img.fill_rect(Rect2i(60, 126, 480, 10), Color("#D7B77E"))  # syrup shelf
	img.fill_rect(Rect2i(60, 136, 480, 3), Color("#B8955E"))
	for cx in [360, 460]:
		img.fill_rect(Rect2i(cx - 46, 226, 92, 88), LINE)  # rubber cup mat
		img.fill_rect(Rect2i(cx - 44, 228, 88, 84), Color("#4A4446"))
		for y in range(232, 310, 6):
			img.fill_rect(Rect2i(cx - 40, y, 80, 1), Color("#5A5456"))
	img.save_png(ProjectSettings.globalize_path(OUT + "topping_bg.png"))
