extends SceneTree
## Builds the app / launcher icons from the steaming-cup UI icon (assets/ui/hud/icon_cup_big.png,
## 3 screen px per art px), scaled up by whole numbers so the pixels stay square and crisp.
## Writes new files only (assets/icon/):
##   icon.png                   192x192: cream sign, brown rim, the cup (project icon, Android main icon)
##   adaptive_fg.png            432x432: the cup alone, inside the 264 px safe zone (Android adaptive foreground)
##   adaptive_bg.png            432x432: plain cream (Android adaptive background)
## Run: Godot_console.exe --headless --path . --script res://tools/make_app_icon.gd

const OUT := "res://assets/icon/"
const CUP := "res://assets/ui/hud/icon_cup_big.png"
const CREAM := Color("#F5E7CA")
const RIM := Color("#8A4A26")
const OUTLINE := Color("#3A2416")
const GOLD := Color("#F2C14E")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var cup := (load(CUP) as Texture2D).get_image()
	cup.convert(Image.FORMAT_RGBA8)
	var art := Image.create(cup.get_width() / 3, cup.get_height() / 3, false, Image.FORMAT_RGBA8)
	for y in art.get_height():  # back to 1 px per art px (the UI icon is drawn at 3x): sample each block's centre
		for x in art.get_width():
			art.set_pixel(x, y, cup.get_pixel(x * 3 + 1, y * 3 + 1))
	art = art.get_region(art.get_used_rect())

	var main := Image.create(192, 192, false, Image.FORMAT_RGBA8)
	plaque(main, 6)
	stamp(main, art, 6)
	main.save_png(OUT.path_join("icon.png"))

	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	stamp(fg, art, 10)
	fg.save_png(OUT.path_join("adaptive_fg.png"))

	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(CREAM)
	bg.save_png(OUT.path_join("adaptive_bg.png"))
	print("wrote icon.png, adaptive_fg.png, adaptive_bg.png")
	quit()


## A cream sign filling the image: dark outline, wood rim, gold inner line, corners cut by
## pixel steps (u = screen px per art px).
func plaque(img: Image, u: int) -> void:
	var n := img.get_width() / u
	for y in n:
		for x in n:
			var edge := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var corner := mini(x, n - 1 - x) + mini(y, n - 1 - y)  # cut the corners
			var c := Color(0, 0, 0, 0)
			if corner >= 3:
				c = OUTLINE if edge == 0 or corner == 3 else RIM if edge <= 2 or corner == 4 else GOLD if edge == 3 else CREAM
			img.fill_rect(Rect2i(x * u, y * u, u, u), c)


## The cup art, each art px drawn as a k x k block, centred (nudged down a little: the steam
## makes the top look heavy).
func stamp(img: Image, art: Image, k: int) -> void:
	var at := (Vector2i(img.get_width(), img.get_height()) - art.get_size() * k) / 2 + Vector2i(0, k / 2)
	for y in art.get_height():
		for x in art.get_width():
			var c := art.get_pixel(x, y)
			if c.a > 0.5:
				img.fill_rect(Rect2i(at.x + x * k, at.y + y * k, k, k), c)
