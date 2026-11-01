extends SceneTree
## Builds the app / launcher icons from the Brewtopia café badge (tools/icon_source/brewtopia_badge.png,
## 1254 px, transparent background; kept under tools/ so the export filter leaves it out of the APK).
## The badge is cropped to its solid edge and scaled down with Lanczos (it is drawn finer than any
## icon size, so a whole-number pixel scale isn't possible).
## Writes (assets/icon/):
##   icon.png         192x192: the badge filling the icon (project icon, Android main icon)
##   adaptive_fg.png  432x432: the badge inside the 288 px area every launcher mask shows (Android adaptive foreground)
##   adaptive_bg.png  432x432: the badge's cream rim colour, so masks that show more than the badge stay on-style
## Run: Godot_console.exe --headless --path . --script res://tools/make_app_icon.gd

const OUT := "res://assets/icon/"
const SOURCE := "res://tools/icon_source/brewtopia_badge.png"
const BG := Color("#FBE9CB")  # the badge's cream rim
const MAIN_PX := 188  # badge size in the 192 px icon (2 px breathing room)
const FG_PX := 288  # adaptive icons: 432 px canvas, the middle 288 px are always visible


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	src.convert(Image.FORMAT_RGBA8)
	var badge := solid_crop(src)

	var main := Image.create(192, 192, false, Image.FORMAT_RGBA8)
	place(main, badge, MAIN_PX)
	main.save_png(OUT.path_join("icon.png"))

	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	place(fg, badge, FG_PX)
	fg.save_png(OUT.path_join("adaptive_fg.png"))

	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(BG)
	bg.save_png(OUT.path_join("adaptive_bg.png"))
	print("wrote icon.png, adaptive_fg.png, adaptive_bg.png from ", SOURCE)
	quit()


## The square around the badge's solid pixels (faint edge pixels ignored), centred on it.
func solid_crop(img: Image) -> Image:
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var side := maxi(hi.x - lo.x, hi.y - lo.y) + 1
	var centre := (lo + hi) / 2
	var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
	sq.blit_rect(img, Rect2i(centre - Vector2i(side, side) / 2, Vector2i(side, side)), Vector2i.ZERO)
	return sq


## `badge` scaled to `px` and centred on `img`.
func place(img: Image, badge: Image, px: int) -> void:
	var b := badge.duplicate() as Image
	b.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var at := (Vector2i(img.get_width(), img.get_height()) - Vector2i(px, px)) / 2
	img.blend_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), at)
