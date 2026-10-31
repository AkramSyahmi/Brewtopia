class_name TitleScreen
extends Control
## Title screen: the café (with the player's decorations) behind the Brewtopia logo.
## Continue (shows the saved day/level/money), New Game (asks first if there is a save),
## Music and Sound toggles, Credits, and Quit on desktop. Music starts here and keeps
## playing into the game (Audio autoload).
## Look: the logo with a wooden subtitle plaque between its lettering and its bean line,
## then pixel-art wooden sign buttons (cream for Continue) with icons, in Pixelify Sans.
## The frames and icons come from tools/make_menu_art.gd (assets/ui/main_menu/).

const GAME := "res://scenes/cafe/cafe_shift.tscn"
## Shown by the Credits button here and at the end of the story (CafeShift.show_credits).
const CREDITS := "BREWTOPIA\nUXHMAC 2026 entry\n\nGame design, story and code: our team\nEngine: Godot 4\n3D characters and furniture: Kenney (kenney.nl), CC0\nFonts: Pixelify Sans and Silkscreen (SIL Open Font License)\nSound effects and music: original, made for this game\n\nTerima kasih for playing!"
const LOGO := "res://assets/art/ui/brewtopia_logo.png"
const FONT := "res://assets/fonts/PixelifySans.ttf"  # SIL OFL 1.1, see PixelifySans-OFL.txt
const UI := "res://assets/ui/main_menu/%s.png"
const LOGO_W := 640.0  # on screen
const LOGO_TOP := Rect2(0, 120, 2172, 410)  # logo image px: the lettering
const LOGO_LINE := Rect2(460, 530, 1260, 100)  # logo image px: the bean line under it
const COL_AT := Vector2(44, 18)
const MENU_W := 580.0
const ESPRESSO := Color("#36251D")
const DARK_TEXT := Color("#3B2314")
const CREAM := Color("#FBF4EA")
const CREAM_TEXT := Color("#F6E7C8")

var logo: TextureRect
var header: Control  # logo + plaque; floats gently
var menu: VBoxContainer
var credits: PanelContainer
var confirm: ConfirmationDialog
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = Theme.new()
	var font := FontVariation.new()
	font.base_font = load(FONT)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}  # bold, chunky
	theme.default_font = font
	theme.default_font_size = 28
	var focus := StyleBoxFlat.new()  # keyboard/controller focus: a gold pixel frame
	focus.draw_center = false
	focus.border_color = Color("#F0C978")
	focus.set_border_width_all(3)
	focus.set_expand_margin_all(3)
	theme.set_stylebox("focus", "Button", focus)
	var save := SaveGame.load_save()
	var cafe := CounterScreen.new()
	add_child(cafe)
	cafe.set_decor(save.decor)
	var grad := Gradient.new()
	grad.set_color(0, Color(CREAM, 0.92))
	grad.set_color(1, Color(CREAM, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_to = Vector2(1, 0)
	var wash := TextureRect.new()
	wash.texture = tex
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.position = Vector2.ZERO
	wash.size = Vector2(760, 720)
	wash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(wash)

	var col := VBoxContainer.new()
	col.position = COL_AT
	col.add_theme_constant_override("separation", 12)
	col.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art frames and icons
	add_child(col)
	build_header(col)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 10)
	col.add_child(indent)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	menu.custom_minimum_size.x = MENU_W
	menu.size_flags_horizontal = SIZE_SHRINK_BEGIN  # buttons stay MENU_W, not the logo's width
	indent.add_child(menu)

	var has_save := SaveGame.exists()
	var cont := menu_button("Continue", "continue", menu, Vector2(MENU_W, 76), true)
	var info := Label.new()  # save details, right of a divider
	info.text = "Day %d  ·  Lv %d  ·  RM %d" % [save.day, SaveGame.level(save), save.money] if has_save else "No saved café yet"
	PixelUI.number_label(info, 24, 700)
	info.add_theme_color_override("font_color", Color("#6A3E1F"))
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var divider := ColorRect.new()
	divider.color = Color("#C9963F")
	divider.custom_minimum_size = Vector2(3, 40)
	divider.size_flags_vertical = SIZE_SHRINK_CENTER
	var row: HBoxContainer = cont.get_meta("row")
	row.add_child(divider)
	row.add_child(info)
	cont.disabled = not has_save
	row.modulate.a = 1.0 if has_save else 0.55  # greyed out: nothing to continue
	cont.pressed.connect(start_game)
	for side in 2:  # small gold accents either side of Continue
		var spark := TextureRect.new()
		spark.texture = load(UI % "sparkle")
		spark.flip_h = side == 1
		spark.mouse_filter = MOUSE_FILTER_IGNORE
		spark.position = Vector2(-28 if side == 0 else MENU_W + 4, 14)
		cont.add_child(spark)
	menu_button("New Game", "new_game", menu, Vector2(MENU_W, 66)).pressed.connect(func():
		if SaveGame.exists():
			confirm.dialog_text = "Start a new café? Your Day %d progress will be lost." % save.day
			confirm.popup_centered()
		else:
			start_game())
	var audio = Sfx.audio()  # the Audio autoload (looked up, not named, so tools compile)
	if audio:
		var toggles := HBoxContainer.new()
		toggles.add_theme_constant_override("separation", 14)
		menu.add_child(toggles)
		var half := Vector2((MENU_W - 14) / 2.0, 62)
		var music := menu_button("", "music", toggles, half, false, 24)
		var sound := menu_button("", "sound", toggles, half, false, 24)
		var music_label: Label = music.get_meta("label")
		var sound_label: Label = sound.get_meta("label")
		music_label.text = "Music: On" if audio.music_on else "Music: Off"
		sound_label.text = "Sound: On" if audio.sfx_on else "Sound: Off"
		music.pressed.connect(func():
			audio.set_music_on(not audio.music_on)
			music_label.text = "Music: On" if audio.music_on else "Music: Off")
		sound.pressed.connect(func():
			audio.set_sfx_on(not audio.sfx_on)
			sound_label.text = "Sound: On" if audio.sfx_on else "Sound: Off")
	menu_button("Credits", "credits", menu, Vector2(MENU_W, 66)).pressed.connect(func(): credits.visible = not credits.visible)
	if not OS.has_feature("mobile"):
		menu_button("Quit", "quit", menu, Vector2(MENU_W, 66)).pressed.connect(func(): get_tree().quit())
	(cont if has_save else menu.get_child(1)).grab_focus.call_deferred()  # keyboard/controller start

	confirm = ConfirmationDialog.new()
	confirm.title = "New game"
	confirm.ok_button_text = "Start fresh"
	confirm.confirmed.connect(func():
		SaveGame.reset()
		start_game())
	add_child(confirm)
	build_credits()
	Sfx.music("title")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


## The logo in two slices (lettering, then its bean line) with the subtitle plaque between.
func build_header(parent: Control) -> void:
	var holder := Control.new()
	var s := LOGO_W / 2172.0
	var top_h := LOGO_TOP.size.y * s
	holder.custom_minimum_size = Vector2(LOGO_W, top_h + 74)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	header = Control.new()
	header.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(header)
	logo = logo_slice(LOGO_TOP, Vector2.ZERO, s)
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", frame("banner", 18, 18, 15, 18))
	plaque.position = Vector2((LOGO_W - 380) / 2.0, top_h - 8)
	plaque.custom_minimum_size = Vector2(380, 48)
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(plaque)
	var sub := Label.new()
	sub.text = "A Malaysian café story"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", DARK_TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(sub)
	logo_slice(LOGO_LINE, Vector2(LOGO_LINE.position.x * s, top_h + 44), s)


func logo_slice(region: Rect2, at: Vector2, s: float) -> TextureRect:
	var a := AtlasTexture.new()
	a.atlas = load(LOGO)
	a.region = region
	var r := TextureRect.new()
	r.texture = a
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT  # never distorted
	r.position = at
	r.size = region.size * s
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # big downscale: smooth, no shimmer
	r.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(r)
	return r


## A 9-slice pixel frame (art drawn at 3 px per pixel, so it is used 1:1).
func frame(file: String, left: int, right: int, top: int, bottom: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(UI % file)
	s.texture_margin_left = left
	s.texture_margin_right = right
	s.texture_margin_top = top
	s.texture_margin_bottom = bottom
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE  # keeps the wood grain
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return s


## A wooden sign button (cream = the Continue style): icon + label in a row. The row dips
## 3 px while held, as the sign does; the meta "label"/"row" give access to them.
func menu_button(text: String, icon: String, parent: Node, size_px: Vector2, cream := false, font_px := 30) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size_px
	var kind := "cream" if cream else "wood"
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, frame("button_%s_%s" % [kind, state], 15, 15, 15, 18))
	b.add_theme_stylebox_override("hover_pressed", frame("button_%s_pressed" % kind, 15, 15, 15, 18))
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -22
	row.offset_bottom = -4  # the frame's drop shadow
	row.add_theme_constant_override("separation", 16)
	b.add_child(row)
	var ic := TextureRect.new()
	ic.texture = load(UI % ("icon_%s_%s" % [icon, "dark" if cream else "light"]))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(42, 42)
	ic.size_flags_vertical = SIZE_SHRINK_CENTER
	ic.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", DARK_TEXT if cream else CREAM_TEXT)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(l)
	b.button_down.connect(func(): row.position.y = 3.0)
	b.button_up.connect(func(): row.position.y = 0.0)
	b.set_meta("label", l)
	b.set_meta("row", row)
	parent.add_child(b)
	return b


func build_credits() -> void:
	credits = PanelContainer.new()
	var s := frame("button_cream_normal", 15, 15, 15, 18)
	s.set_content_margin_all(28)
	credits.add_theme_stylebox_override("panel", s)
	credits.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	credits.position = Vector2(660, 120)
	credits.custom_minimum_size = Vector2(560, 0)
	add_child(credits)
	var l := Label.new()
	l.text = CREDITS
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", ESPRESSO)
	credits.add_child(l)
	credits.hide()


func start_game() -> void:
	var t2 := create_tween()
	t2.tween_property(self, "modulate:a", 0.0, 0.35)
	t2.tween_callback(func(): get_tree().change_scene_to_file(GAME))


func _process(delta: float) -> void:
	t += delta
	header.position.y = sin(t * 1.6) * 3.0  # the logo floats gently
