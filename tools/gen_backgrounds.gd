extends SceneTree
## Generates placeholder background PNGs (see ART_LIST.md) into res://assets/art/.
## Run: Godot_console.exe --headless --path . --script res://tools/gen_backgrounds.gd

const OUT := "res://assets/art/"
const KEEP := []  # backgrounds replaced by AI/pack art; never overwrite these

const WALL_A := Color("#F6DFB0")
const WALL_B := Color("#EFD29A")
const COUNTER := Color("#F8EEE6")
const COUNTER_EDGE := Color("#E2CDBE")
const LINE := Color("#8C5A3C")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if not "station_bg" in KEEP:
		station_bg()
	if not "topping_bg" in KEEP:
		topping_bg()
	quit()


## Topping station: same wall and counter, plus a wooden syrup shelf.
func topping_bg() -> void:
	var img := Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)
	img.fill(COUNTER)
	for x in 640:
		var c := WALL_A if (x / 14) % 2 == 0 else WALL_B
		img.fill_rect(Rect2i(x, 0, 1, 104), c)
	img.fill_rect(Rect2i(0, 104, 640, 2), LINE)
	img.fill_rect(Rect2i(0, 106, 640, 3), COUNTER_EDGE)
	img.fill_rect(Rect2i(100, 126, 440, 10), Color("#A9774F"))  # syrup shelf
	img.fill_rect(Rect2i(100, 136, 440, 3), Color("#7A5236"))
	img.fill_rect(Rect2i(250, 214, 140, 104), Color("#EFE2D6"))  # cup slot mat
	img.fill_rect(Rect2i(254, 218, 132, 96), Color("#E6D3C3"))
	img.save_png(ProjectSettings.globalize_path(OUT + "topping_bg.png"))


func station_bg() -> void:
	var img := Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)
	img.fill(COUNTER)
	for x in 640:
		var c := WALL_A if (x / 14) % 2 == 0 else WALL_B
		img.fill_rect(Rect2i(x, 0, 1, 104), c)
	img.fill_rect(Rect2i(0, 104, 640, 2), LINE)
	img.fill_rect(Rect2i(0, 106, 640, 3), COUNTER_EDGE)
	for i in 40:  # faint speckles on the counter top
		img.set_pixel((i * 97) % 640, 120 + (i * 53) % 230, COUNTER_EDGE)
	img.save_png(ProjectSettings.globalize_path(OUT + "station_bg.png"))
