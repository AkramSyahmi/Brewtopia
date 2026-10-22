class_name EspressoStation
extends Control
## Front-view 2D bar in pixel art (Good Coffee, Great Coffee style), two pages:
##  1. Espresso: grinder, tamper, 2-group machine (two portafilters, two scales), cup rack,
##     plastic iced cups, milk pitcher, steam wand, fridge with an ice bin.
##  2. Toppings: syrup pumps and topping containers.
## Drag a portafilter grinder -> mat -> a group head, tap the tamper, take a glass, latte
## cup or iced cup, tap the group head to pull the shot (timing bar with a green zone),
## fill the pitcher at the fridge, steam it under the wand (thermometer + froth meter) or
## pour it cold for iced drinks, drop iced cups on the ice bin, add syrups/toppings, then
## drag the drink into SERVE. Up to two cups and two shots at once.
## Nothing forces an order; mistakes show in the score. World = 640x360 base px drawn x2;
## sprites come from res://assets/art/ (see ART_LIST.md).
## Drop and tap targets are SnapZones (Area2D + Marker2D) found by a physics point query.
## Each portafilter, group head and the steam wand run a small enum state machine.

signal served(drink: Dictionary)
signal changed
signal message(text: String)
signal shot_finished(quality: String, shot: Dictionary)  ## "Perfect", "Good" or "Bad"
signal milk_frothed(quality: String, milk: Dictionary)  ## {temp, foam}; same ratings

## What is in a portafilter basket.
enum PfState { EMPTY, DOSED, TAMPED, USED }
## A group head.
enum ShotState { IDLE, EXTRACTING }
## The steam wand popup: closed, open with the pitcher under the wand, or steaming.
enum SteamState { CLOSED, OPEN, STEAMING }

const ART := "res://assets/art/%s.png"
const SCALE := 2
const PAGE_W := 640.0
const MAX_YIELD_G := 70.0
const CUP_FULL_G := 40.0
const COFFEE := Color("#4A2A18")
const MILK := Color("#F3E6D2")
const MAX_CUPS := 2

# Espresso page (sprite top-left, base px). Must match the art in ART_LIST.md.
const GRINDER_AT := Vector2(12, 70)
const BAG_AT := Vector2(104, 182)
const MAT_AT := Vector2(8, 292)
const KNOCK_AT := Vector2(150, 306)
const MACHINE_AT := Vector2(205, 46)
const RACK_AT := Vector2(255, 14)
const ICED_STACK_AT := Vector2(166, 108)
const PITCHERS_AT := Vector2(512, 60)
const FRIDGE_AT := Vector2(570, 116)
const ICE_BIN_AT := Vector2(577, 293)  # over the fridge's bottom drawer
const TAMPER_REST := Vector2(108, 262)
const PITCHER_HOME := Vector2(492, 250)
const STEAM_ZONE := Rect2(430, 170, 80, 90)  # under the steam wand
const SERVE_RECT := Rect2(452, 296, 108, 58)
const GROUP_DX := 117.0  # the right group head is this far right of the left one
const PF_SPOTS := {  # portafilter sprite top-left at each resting spot
	"fork": Vector2(26, 196),  # under the grinder spout
	"mat": Vector2(40, 270),  # on the tamping mat
	"group0": Vector2(238, 196),  # locked into the left group head
	"group1": Vector2(238 + GROUP_DX, 196),  # locked into the right group head
}
const PF_BASKET := Vector2(46, 14)  # basket centre inside the portafilter sprite = its anchor
const PF_SNAP_RADIUS := 34.0
const TAP_SLOP := 4.0  # base px a press may move and still count as a tap
const TRAY_CENTRE := Vector2(276, 280)  # cup centre on the left drip-tray scale
const DIAL_AT := Vector2(8, 252)  # grind -/+ buttons under the grinder
const SHOT_BAR := Rect2(232, 330, 90, 8)  # timing bar under the left scale
const DOUBLE_SHOT_G := 14.0  # doses from here up count as a double shot
const AERATE_PER_S := 0.14  # froth gained per second with the wand tip at the surface
const FOAM_DEFAULT := Vector2(0.25, 0.4)  # green froth zone when the recipe sets none

# Topping page (base px, page origin at x = 640)
const SYRUPS := ["vanilla", "caramel", "chocolate", "pandan", "gula_melaka", "condensed_milk"]
const TOPPINGS := ["cream", "choc_chips", "cinnamon", "cocoa"]
const SYRUP_AT := Vector2(80, 30)  # first bottle; bottles every 80 px
const TOPPING_AT := Vector2(20, 250)  # first container; every TOPPING_STEP px
const TOPPING_STEP := 72
const SLOTS := [Vector2(360, 270), Vector2(460, 270)]  # cup slots on the topping page
const SERVE2_RECT := Rect2(520, 250, 110, 80)

## Cup kinds: sprite and the rectangle inside it where the drink shows.
const CUPS := {
	"glass": {"tex": "cup_espresso", "inside": Rect2(6, 8, 24, 24), "label": "glass"},
	"cup": {"tex": "cup_latte", "inside": Rect2(11, 3, 30, 7), "label": "latte cup"},
	"iced": {"tex": "cup_iced", "inside": Rect2(6, 6, 20, 42), "label": "plastic iced cup"},
}


class Portafilter:
	var sprite: Sprite2D
	var state := PfState.EMPTY
	var dose_g := 0.0
	var grind := 8  # grind setting of the coffee in the basket
	var spot := "mat"


class Group:
	var index := 0
	var state := ShotState.IDLE
	var sim_time := 0.0
	var flow := 0.0
	var dose_g := 0.0  # captured when the shot starts
	var grind := 0
	var tamped := false
	var stream: ColorRect
	var bar: Control
	var marker: ColorRect
	var green: ColorRect
	var bubble: Label


class Cup:
	var sprite: Sprite2D
	var kind := ""
	var spot := ""  # "tray0", "tray1", "counter", "slot0", "slot1"
	var yield_g := 0.0
	var ice := false
	var drink := {}  # filled once a shot lands; milk/ice/syrups/toppings added later
	var coffee: ColorRect
	var milk: ColorRect
	var ice_layer: Node2D
	var garnish: Node2D
	var back_pos := Vector2.ZERO  # where it waits on the espresso page
	var back_spot := "counter"


var recipe: Dictionary
var dispense_g_per_s := 4.0
var sim_speed := 2.0
var green_zone_g := 2.0  # +/- grams of the green zone (Shot Timer upgrade widens it)
var steam_rate := 12.0  # degrees C per second while steaming (Steam Control slows it)

var grind := 8
var pfs: Array[Portafilter] = []
var groups: Array[Group] = []
var cups: Array[Cup] = []
var active_cup: Cup  # the cup the player touched last (syrups and toppings go here)
var steam_state := SteamState.CLOSED
var zones := {}  # name -> SnapZone

# Milk
var pitcher: Sprite2D
var pitcher_milk := false
var milk_temp := 5.0
var milk_foam := 0.0  # 0 = flat, 1 = all foam
var pitcher_depth := 0.0  # 0 = wand tip at the milk surface (adds air), 1 = deep (only heats)

var grinding := false
var page := 0
var dragging: Sprite2D
var drag_offset := Vector2.ZERO
var drag_start := Vector2.ZERO
var warned := ""

var world: Node2D
var tamper: Sprite2D
var grounds_stream: ColorRect
var grind_box: Control
var grind_label: Label
var dose_bubble: Label
var steam_panel: PanelContainer
var art_panel: LatteArtPanel
var art_cup: Cup  # the cup getting latte art
var thermo_fill: ColorRect
var thermo_green: ColorRect
var temp_label: Label
var froth_green: ColorRect
var froth_marker: ColorRect
var steam_pitcher: Control  # the pitcher inside the popup; moves up and down
var steam_foam: ColorRect
var to_toppings: Button
var to_espresso: Button
var add_ins: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	build_zones()
	build_espresso_page()
	build_topping_page()
	for i in 2:
		build_group(i)
	build_grind_buttons()
	build_steam_panel()
	art_panel = LatteArtPanel.new()
	add_child(art_panel)
	art_panel.finished.connect(on_art_finished)
	build_nav()
	dose_bubble = bubble()
	set_grind(grind)


# ---------- building ----------

func tex(n: String) -> Texture2D:
	return load(ART % n)


func sprite(n: String, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(n)
	s.centered = false
	s.position = at
	world.add_child(s)
	return s


func rect(c: Color, at: Vector2, size_px: Vector2, parent: Node = null) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = at
	r.size = size_px
	r.mouse_filter = MOUSE_FILTER_IGNORE
	(parent if parent else world).add_child(r)
	return r


func world_label(text: String, at: Vector2, size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	l.position = at
	l.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(l)
	return l


func dashed(r: Rect2, c: Color) -> void:
	for x in range(int(r.position.x), int(r.end.x), 6):
		rect(c, Vector2(x, r.position.y), Vector2(3, 1))
		rect(c, Vector2(x, r.end.y), Vector2(3, 1))
	for y in range(int(r.position.y), int(r.end.y), 6):
		rect(c, Vector2(r.position.x, y), Vector2(1, 3))
		rect(c, Vector2(r.end.x, y), Vector2(1, 3))


func tray_centre(i: int) -> Vector2:
	return TRAY_CENTRE + Vector2(GROUP_DX * i, 0)


## Drop and tap targets. Portafilter zones snap the basket centre; cup/pitcher zones snap
## the item's centre.
func build_zones() -> void:
	for spot in PF_SPOTS:
		var c: Vector2 = PF_SPOTS[spot] + PF_BASKET
		add_zone(spot, Rect2(c - Vector2.ONE * PF_SNAP_RADIUS, Vector2.ONE * PF_SNAP_RADIUS * 2.0), c)
	for i in 2:
		add_zone("tray%d" % i, Rect2(tray_centre(i) - Vector2(32, 32), Vector2(64, 64)), tray_centre(i))
		add_zone("brew%d" % i, Rect2(MACHINE_AT + Vector2(60 + GROUP_DX * i, 150), Vector2(80, 60)))
	add_zone("knock", Rect2(KNOCK_AT, Vector2(56, 44)).grow(10))
	add_zone("rack", Rect2(RACK_AT, Vector2(200, 70)))
	add_zone("iced_stack", Rect2(ICED_STACK_AT, Vector2(34, 70)))
	add_zone("grinder", Rect2(GRINDER_AT + Vector2(10, 60), Vector2(76, 120)))
	add_zone("ice", Rect2(ICE_BIN_AT, Vector2(56, 48)).grow(6))
	add_zone("fridge", Rect2(FRIDGE_AT, Vector2(70, 170)))  # above the ice bin
	add_zone("steam", STEAM_ZONE)
	add_zone("serve", SERVE_RECT.grow(6))
	add_zone("serve2", Rect2(SERVE2_RECT.position + Vector2(PAGE_W, 0), SERVE2_RECT.size).grow(6))
	for i in SLOTS.size():
		var c: Vector2 = SLOTS[i] + Vector2(PAGE_W, 0)
		add_zone("slot%d" % i, Rect2(c - Vector2(45, 45), Vector2(90, 90)), c)


func add_zone(zone_name: String, area: Rect2, snap_at := Vector2.INF) -> void:
	var z := SnapZone.make(zone_name, area, area.get_center() if snap_at == Vector2.INF else snap_at)
	world.add_child(z)
	zones[zone_name] = z


## Names of the zones under a station-world point (base px).
func zones_at(p: Vector2) -> Array[String]:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = world.to_global(p)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var names: Array[String] = []
	for found in get_world_2d().direct_space_state.intersect_point(q, 16):
		var z := found.collider as SnapZone
		if z:
			names.append(String(z.name))
	return names


func snap(zone_name: String) -> Vector2:
	return (zones[zone_name] as SnapZone).snap_point()


func build_espresso_page() -> void:
	sprite("station_bg", Vector2.ZERO)
	sprite("grinder", GRINDER_AT)
	sprite("bean_bag", BAG_AT)
	sprite("tamp_mat", MAT_AT)
	sprite("knock_box", KNOCK_AT)
	sprite("machine", MACHINE_AT)
	sprite("cups_rack", RACK_AT)
	sprite("iced_cups", ICED_STACK_AT)
	sprite("pitcher_rack", PITCHERS_AT)
	sprite("milk_fridge", FRIDGE_AT)
	sprite("ice_bin", ICE_BIN_AT)
	world_label("ICE", ICE_BIN_AT + Vector2(18, 34), 8, Color("#36251D"))
	dashed(SERVE_RECT, Color("#8A6A4A"))
	world_label("SERVE", SERVE_RECT.position + Vector2(38, 44), 10, Color("#8A6A4A"))
	grounds_stream = rect(COFFEE, Vector2(60, 186), Vector2(2, 18))
	grounds_stream.hide()
	for i in 2:  # the first portafilter waits on the mat, the second sits in the right group
		var p := Portafilter.new()
		p.spot = "mat" if i == 0 else "group1"
		p.sprite = sprite("portafilter_empty", snap(p.spot) - PF_BASKET)
		pfs.append(p)
	tamper = sprite("tamper", TAMPER_REST)
	tamper.z_index = 1
	pitcher = sprite("pitcher", PITCHER_HOME)
	pitcher.z_index = 1


func build_topping_page() -> void:
	sprite("topping_bg", Vector2(PAGE_W, 0))
	for i in SYRUPS.size():
		sprite("syrup_" + SYRUPS[i], Vector2(PAGE_W, 0) + SYRUP_AT + Vector2(i * 80, 0))
		world_label(SYRUPS[i].replace("_", " ").capitalize(), Vector2(PAGE_W, 0) + SYRUP_AT + Vector2(i * 80 - 6, 112),
			8, Color("#36251D"))
	for i in TOPPINGS.size():
		sprite("topping_" + TOPPINGS[i], Vector2(PAGE_W, 0) + TOPPING_AT + Vector2(i * TOPPING_STEP, 0))
		world_label(TOPPINGS[i].replace("_", " ").capitalize(), Vector2(PAGE_W, 0) + TOPPING_AT + Vector2(i * TOPPING_STEP, 54),
			8, Color("#36251D"))
	dashed(Rect2(SERVE2_RECT.position + Vector2(PAGE_W, 0), SERVE2_RECT.size), Color("#8A6A4A"))
	world_label("SERVE", SERVE2_RECT.position + Vector2(PAGE_W + 44, 60), 10, Color("#8A6A4A"))
	add_ins = world_label("", Vector2(PAGE_W + 250, 190), 9, Color("#36251D"))


## A group head: its coffee stream, its GCGC-style timing bar (stop the marker in the
## green zone) and its scale readout.
func build_group(i: int) -> void:
	var g := Group.new()
	g.index = i
	g.stream = rect(COFFEE, Vector2(285 + GROUP_DX * i, 216), Vector2(2, 50))
	g.stream.hide()
	g.bar = Control.new()
	g.bar.position = SHOT_BAR.position + Vector2(GROUP_DX * i, 0)
	g.bar.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(g.bar)
	rect(Color("#36251D"), Vector2(-1, -1), SHOT_BAR.size + Vector2(2, 2), g.bar)
	rect(Color("#9BA39E"), Vector2.ZERO, SHOT_BAR.size, g.bar)
	g.green = rect(Color("#6BD46B"), Vector2.ZERO, Vector2(8, SHOT_BAR.size.y), g.bar)
	g.marker = rect(Color("#FFFFFF"), Vector2(0, -2), Vector2(2, SHOT_BAR.size.y + 4), g.bar)
	g.bar.hide()
	g.bubble = bubble(20)
	groups.append(g)


func small_button(text: String, size_px: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size_px
	return b


func build_grind_buttons() -> void:
	var box := HBoxContainer.new()
	box.position = DIAL_AT * SCALE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	grind_box = box
	var minus := small_button("-", Vector2(34, 34))
	minus.pressed.connect(func(): set_grind(grind - 1))
	box.add_child(minus)
	grind_label = Label.new()
	grind_label.add_theme_font_size_override("font_size", 18)
	grind_label.add_theme_color_override("font_color", Color("#36251D"))
	grind_label.custom_minimum_size = Vector2(70, 34)
	grind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(grind_label)
	var plus := small_button("+", Vector2(34, 34))
	plus.pressed.connect(func(): set_grind(grind + 1))
	box.add_child(plus)


## GCGC-style steaming popup: a froth meter along the top, a thermometer, and the pitcher
## under the wand. Hold on the pitcher to steam; drag it down (wand tip at the surface)
## to add air, up (wand deep) to only heat. Let go and press Done with both in the green.
func build_steam_panel() -> void:
	steam_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#F5ECE2")
	s.border_color = Color("#65422F")
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(18)
	steam_panel.add_theme_stylebox_override("panel", s)
	steam_panel.position = Vector2(690, 70)
	steam_panel.z_index = 10  # above the world sprites (pitcher, cups)
	steam_panel.custom_minimum_size = Vector2(560, 480)
	add_child(steam_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	steam_panel.add_child(rows)
	var froth_row := HBoxContainer.new()
	froth_row.add_theme_constant_override("separation", 12)
	rows.add_child(froth_row)
	var froth_label := Label.new()
	froth_label.text = "Froth"
	froth_label.add_theme_font_size_override("font_size", 20)
	froth_label.add_theme_color_override("font_color", Color("#36251D"))
	froth_row.add_child(froth_label)
	var froth := Control.new()
	froth.custom_minimum_size = Vector2(440, 24)
	froth_row.add_child(froth)
	rect(Color("#65422F"), Vector2(0, 0), Vector2(440, 24), froth)
	rect(Color("#FFFFFF"), Vector2(3, 3), Vector2(434, 18), froth)
	froth_green = rect(Color("#6BD46B"), Vector2(3, 3), Vector2(40, 18), froth)
	froth_marker = rect(Color("#36251D"), Vector2(3, -4), Vector2(4, 32), froth)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	rows.add_child(row)
	var thermo := Control.new()
	thermo.custom_minimum_size = Vector2(70, 380)
	row.add_child(thermo)
	rect(Color("#65422F"), Vector2(20, 0), Vector2(34, 330), thermo)
	rect(Color("#FFFFFF"), Vector2(24, 4), Vector2(26, 322), thermo)
	thermo_green = rect(Color("#6BD46B"), Vector2(24, 0), Vector2(26, 10), thermo)
	thermo_fill = rect(Color("#D9534F"), Vector2(30, 300), Vector2(14, 20), thermo)
	rect(Color("#D9534F"), Vector2(14, 326), Vector2(46, 46), thermo)  # bulb
	# the pitcher under the steam wand; press and drag here
	var area := Control.new()
	area.custom_minimum_size = Vector2(170, 380)
	area.mouse_filter = MOUSE_FILTER_STOP
	area.clip_contents = true
	area.gui_input.connect(on_steam_input)
	row.add_child(area)
	rect(Color("#9EA3AA"), Vector2(78, 0), Vector2(10, 230), area)  # steam wand
	rect(Color("#6E737C"), Vector2(76, 222), Vector2(14, 8), area)  # wand tip
	steam_pitcher = Control.new()
	steam_pitcher.mouse_filter = MOUSE_FILTER_IGNORE
	area.add_child(steam_pitcher)
	var art := TextureRect.new()
	art.texture = tex("pitcher")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size = Vector2(160, 170)
	art.mouse_filter = MOUSE_FILTER_IGNORE
	steam_pitcher.add_child(art)
	steam_foam = rect(Color("#FFFFFF"), Vector2(40, 30), Vector2(80, 4), steam_pitcher)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	row.add_child(col)
	var title := Label.new()
	title.text = "Steam the milk"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#36251D"))
	col.add_child(title)
	temp_label = Label.new()
	temp_label.add_theme_font_size_override("font_size", 40)
	temp_label.add_theme_color_override("font_color", Color("#36251D"))
	col.add_child(temp_label)
	var help := Label.new()
	help.text = "Hold on the pitcher to steam.\nDrag it DOWN to add air,\nUP to just heat.\nGet both bars into\nthe green, then Done."
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("#65422F"))
	col.add_child(help)
	var done := small_button("Done", Vector2(180, 60))
	done.pressed.connect(close_steam)
	col.add_child(done)
	steam_panel.hide()


func build_nav() -> void:
	to_toppings = small_button("Toppings  >", Vector2(150, 50))
	to_toppings.position = Vector2(1120, 300)
	to_toppings.pressed.connect(func(): go_page(1))
	add_child(to_toppings)
	to_espresso = small_button("<  Espresso", Vector2(150, 50))
	to_espresso.position = Vector2(10, 300)
	to_espresso.pressed.connect(func(): go_page(0))
	to_espresso.hide()
	add_child(to_espresso)


func bubble(font_size := 26) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#36251D", 0.92)
	s.border_color = Color("#BE895B")
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(6)
	l.add_theme_stylebox_override("normal", s)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.hide()
	add_child(l)
	return l


## Shows `text` at a base-pixel point (top-left, or centred on x); green when `grams` is
## close to `target`, red when over.
func show_bubble(l: Label, at: Vector2, text: String, grams: float, target: float, centred := false) -> void:
	l.text = text
	var c := Color("#F5E7CA")
	if absf(grams - target) <= 0.5:
		c = Color("#9FE08A")
	elif grams > target + 1.0:
		c = Color("#FF8A7A")
	l.add_theme_color_override("font_color", c)
	l.reset_size()
	l.position = (at + world.position / SCALE) * SCALE
	if centred:
		l.position.x -= l.size.x / 2.0
	l.show()


# ---------- lookups ----------

func pf_at(spot: String) -> Portafilter:
	for p in pfs:
		if p.spot == spot and dragging != p.sprite:
			return p
	return null


func cup_at(spot: String) -> Cup:
	for c in cups:
		if c.spot == spot and dragging != c.sprite:
			return c
	return null


func cup_of(s: Sprite2D) -> Cup:
	for c in cups:
		if c.sprite == s:
			return c
	return null


func pf_of(s: Sprite2D) -> Portafilter:
	for p in pfs:
		if p.sprite == s:
			return p
	return null


## The group a portafilter is locked into, or null.
func group_of(p: Portafilter) -> Group:
	return groups[int(p.spot.right(1))] if p.spot.begins_with("group") else null


func extracting_into(c: Cup) -> bool:
	return c.spot.begins_with("tray") and groups[int(c.spot.right(1))].state == ShotState.EXTRACTING


# ---------- order lifecycle ----------

func start_order(new_recipe: Dictionary) -> void:
	recipe = new_recipe
	clear_cups()
	go_page(0, false)
	changed.emit()


func clear_cups() -> void:
	for c in cups:
		c.sprite.queue_free()
	cups.clear()
	active_cup = null
	for g in groups:
		g.bar.hide()
		g.bubble.hide()


func remove_cup(c: Cup) -> void:
	cups.erase(c)
	c.sprite.queue_free()
	if active_cup == c:
		active_cup = null


func set_grind(value: int) -> void:
	grind = clampi(value, 1, 10)
	grind_label.text = "Grind %d" % grind
	changed.emit()


## Page 1 = toppings: drinks waiting on the espresso page move to the topping slots and
## come back to where they were on page 0.
func go_page(p: int, animate := true) -> void:
	page = p
	to_toppings.visible = p == 0
	to_espresso.visible = p == 1
	grind_box.visible = p == 0
	for c in cups:
		if dragging == c.sprite:
			continue
		if p == 1 and not c.spot.begins_with("slot") and not c.drink.is_empty() and not extracting_into(c):
			var free := free_slot()
			if free < 0:
				continue
			c.back_pos = c.sprite.position
			c.back_spot = c.spot
			c.spot = "slot%d" % free
			c.sprite.position = snap(c.spot) - c.sprite.texture.get_size() / 2
		elif p == 0 and c.spot.begins_with("slot"):
			var taken: Cup = cup_at(c.back_spot) if c.back_spot != "counter" else null
			c.spot = c.back_spot if taken == null else "counter"
			c.sprite.position = c.back_pos
	var x := -PAGE_W * SCALE * p
	if animate:
		create_tween().tween_property(world, "position:x", x, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		world.position.x = x
	changed.emit()


func free_slot() -> int:
	for i in SLOTS.size():
		if cup_at("slot%d" % i) == null:
			return i
	return -1


# ---------- per-frame ----------

func _process(delta: float) -> void:
	var at_fork := pf_at("fork")
	grounds_stream.visible = grinding
	if grinding:
		if at_fork == null:
			once("Put a portafilter under the grinder first. Coffee is going everywhere!")
		elif at_fork.state == PfState.USED:
			once("There are used grounds in the basket. Knock them out first.")
		else:
			at_fork.dose_g += dispense_g_per_s * delta
			at_fork.grind = grind
			at_fork.state = PfState.DOSED  # fresh grounds on top undo any tamping
			update_pf(at_fork)
	if page == 0 and not recipe.is_empty() and at_fork:
		show_bubble(dose_bubble, GRINDER_AT + Vector2(100, 120), "%.1f g / %d g" % [at_fork.dose_g, recipe.dose_g],
			at_fork.dose_g, recipe.dose_g)
	else:
		dose_bubble.hide()

	for g in groups:
		var c := cup_at("tray%d" % g.index)
		if g.state == ShotState.EXTRACTING:
			var step := delta * sim_speed
			g.sim_time += step
			if c:
				c.yield_g += g.flow * step
				update_cup_visual(c)
			if g.sim_time * g.flow >= MAX_YIELD_G:
				toggle_brew(g.index)
		var bar_on: bool = page == 0 and not recipe.is_empty() and c != null and (g.state == ShotState.EXTRACTING or c.yield_g > 0.0)
		g.bar.visible = bar_on
		if bar_on:
			var w := SHOT_BAR.size.x
			g.green.position.x = (recipe.target_yield_g - green_zone_g) / MAX_YIELD_G * w
			g.green.size.x = 2.0 * green_zone_g / MAX_YIELD_G * w
			g.marker.position.x = clampf(c.yield_g / MAX_YIELD_G * w, 0.0, w - 2.0)
			show_bubble(g.bubble, Vector2(tray_centre(g.index).x, 306), "%.1f g · %d s" % [c.yield_g, int(g.sim_time)],
				c.yield_g, recipe.target_yield_g, true)
		else:
			g.bubble.hide()

	if steam_state == SteamState.STEAMING:
		milk_temp = minf(milk_temp + steam_rate * delta, 90.0)
		milk_foam = minf(milk_foam + AERATE_PER_S * (1.0 - pitcher_depth) * delta, 1.0)
	if steam_state != SteamState.CLOSED:
		update_steam_ui()


# ---------- machine and milk ----------

## Tap a group head: start its shot, or stop it and rate where the marker stopped.
func toggle_brew(i: int) -> void:
	var g := groups[i]
	var p := pf_at("group%d" % i)
	var c := cup_at("tray%d" % i)
	if g.state == ShotState.EXTRACTING:
		g.state = ShotState.IDLE
		g.stream.hide()
		if p:
			p.state = PfState.USED
			update_pf(p)
		if c and c.yield_g > 0.0:
			c.drink = {"dose": g.dose_g, "grind": g.grind, "tamped": g.tamped, "yield": c.yield_g,
				"time": g.sim_time, "cup": c.kind, "milk_temp": -1.0, "syrups": {}, "toppings": [],
				"ice": c.ice, "shot": "double" if g.dose_g >= DOUBLE_SHOT_G else "single"}
			c.drink.shot_rating = rate_shot(c.yield_g)
			shot_finished.emit(c.drink.shot_rating, c.drink.duplicate(true))
		else:
			say("The shot went down the drain. Put a cup under the group head before brewing.")
		changed.emit()
		return
	if p == null:
		say("Lock a portafilter into this group head first.")
	elif p.state == PfState.USED:
		say("Those grounds are already used. Knock them out and grind fresh coffee.")
	elif p.state == PfState.EMPTY or p.dose_g < 0.5:
		say("The portafilter is empty. Grind some coffee first.")
	elif c and not c.drink.is_empty():
		say("That cup already has coffee in it.")
	else:
		g.dose_g = p.dose_g
		g.grind = p.grind
		g.tamped = p.state == PfState.TAMPED
		g.flow = EspressoModel.flow_rate(recipe, g.dose_g, g.grind, g.tamped)
		g.state = ShotState.EXTRACTING
		g.sim_time = 0.0
		g.stream.show()
		if c == null:
			say("No cup under the group head! The coffee is going down the drain.")
		changed.emit()


## Perfect = stopped inside the green zone, Good = just outside it, Bad = far off.
func rate_shot(yield_g: float) -> String:
	var off := yield_g - float(recipe.target_yield_g)
	if absf(off) <= green_zone_g:
		say("Perfect! Stopped right in the green zone.")
		return "Perfect"
	var late := off > 0.0
	if absf(off) <= green_zone_g * 2.5:
		say("Good shot, a little %s." % ("long" if late else "short"))
		return "Good"
	say("Over-extracted: stopped too late, the shot will taste burnt." if late
		else "Under-extracted: stopped too early, the shot will taste sour.")
	return "Bad"


func tamp() -> void:
	var p := pf_at("mat")
	if p == null:
		say("Put a portafilter on the tamping mat first.")
	elif p.state == PfState.USED:
		say("Those grounds are used. Knock them out first.")
	elif p.state == PfState.EMPTY or p.dose_g < 0.5:
		say("There's nothing to tamp yet.")
	else:
		var press_at := p.sprite.position + PF_BASKET - Vector2(20, 52)
		var t := create_tween()
		t.tween_property(tamper, "position", press_at, 0.12)
		t.tween_property(tamper, "position", press_at + Vector2(0, 5), 0.12)
		t.tween_callback(func():
			p.state = PfState.TAMPED
			update_pf(p)
			say("Tamped! Nice and level.")
			changed.emit())
		t.tween_property(tamper, "position", TAMPER_REST, 0.2)


func open_steam() -> void:
	to_toppings.hide()
	steam_state = SteamState.OPEN
	pitcher_depth = 0.0
	steam_panel.show()
	update_steam_ui()


## Press/drag on the pitcher in the popup: hold to steam, height sets the aeration.
func on_steam_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		steam_state = SteamState.STEAMING if event.pressed else SteamState.OPEN
		if not event.pressed:
			changed.emit()
	if steam_state == SteamState.STEAMING and (event is InputEventMouseButton or event is InputEventMouseMotion):
		pitcher_depth = clampf((210.0 - event.position.y) / 120.0, 0.0, 1.0)


func close_steam() -> void:
	to_toppings.visible = page == 0
	steam_state = SteamState.CLOSED
	steam_panel.hide()
	create_tween().tween_property(pitcher, "position", PITCHER_HOME, 0.15)
	var t := temp_range()
	var f := foam_range()
	var hits := int(milk_temp >= t.x and milk_temp <= t.y) + int(milk_foam >= f.x and milk_foam <= f.y)
	var quality: String = ["Bad", "Good", "Perfect"][hits]
	say("%s milk: %d°C, %s." % [quality, roundi(milk_temp), foam_words(milk_foam, f)])
	milk_frothed.emit(quality, {"temp": milk_temp, "foam": milk_foam})
	changed.emit()


func temp_range() -> Vector2:
	return Vector2(recipe.milk.temp_min, recipe.milk.temp_max) if recipe.has("milk") else Vector2(60, 65)


func foam_range() -> Vector2:
	if recipe.has("milk") and recipe.milk.has("foam_min"):
		return Vector2(recipe.milk.foam_min, recipe.milk.foam_max)
	return FOAM_DEFAULT


func foam_words(foam: float, f: Vector2) -> String:
	return "too flat" if foam < f.x else "too foamy" if foam > f.y else "silky foam"


func update_steam_ui() -> void:
	var h := 322.0
	var to_y := func(deg: float) -> float: return 4.0 + h * (1.0 - clampf(deg / 90.0, 0.0, 1.0))
	var t := temp_range()
	thermo_green.position.y = to_y.call(t.y)
	thermo_green.size.y = to_y.call(t.x) - to_y.call(t.y)
	thermo_fill.position.y = to_y.call(milk_temp)
	thermo_fill.size.y = 330.0 - thermo_fill.position.y
	temp_label.text = "%d°C" % roundi(milk_temp)
	var c := Color("#36251D")
	if milk_temp >= t.x and milk_temp <= t.y:
		c = Color("#3E9E3E")
	elif milk_temp > t.y:
		c = Color("#C8463C")
	temp_label.add_theme_color_override("font_color", c)
	var w := 434.0
	var f := foam_range()
	froth_green.position.x = 3.0 + f.x * w
	froth_green.size.x = (f.y - f.x) * w
	froth_marker.position.x = 1.0 + milk_foam * (w - 2.0)
	steam_pitcher.position = Vector2(4, 200.0 - pitcher_depth * 110.0)
	steam_foam.size.y = 4.0 + milk_foam * 30.0
	steam_foam.position.y = 34.0 - steam_foam.size.y


func pour_milk(c: Cup) -> void:
	c.drink.milk_temp = milk_temp
	c.drink.milk_foam = milk_foam
	var cold := milk_temp < 20.0
	pitcher_milk = false
	milk_temp = 5.0
	milk_foam = 0.0
	pitcher.texture = tex("pitcher")
	create_tween().tween_property(pitcher, "position", PITCHER_HOME, 0.15)
	update_cup_visual(c)
	if not cold and c.kind == "cup":  # hot milk into a ceramic cup: latte art time
		art_cup = c
		art_panel.start()
		return
	say("Poured cold milk over the coffee." if cold else "Poured the milk.")
	changed.emit()


func on_art_finished(score: float) -> void:
	if art_cup and art_cup in cups:
		art_cup.drink.art = score
		update_cup_visual(art_cup)
	say("Beautiful heart!" if score >= 0.8 else "Nice heart." if score >= 0.5 else "The heart came out lopsided...")
	changed.emit()


func add_ice(c: Cup) -> void:
	if c.ice:
		say("It already has ice.")
		return
	c.ice = true
	if not c.drink.is_empty():
		c.drink.ice = true
	update_cup_visual(c)
	say("Scooped ice into the %s." % CUPS[c.kind].label)
	changed.emit()


# ---------- input ----------

func local(screen_pos: Vector2) -> Vector2:
	return (screen_pos - world.position) / SCALE


func hit(s: Sprite2D, p: Vector2) -> bool:
	return s != null and Rect2(s.position, s.texture.get_size()).grow(2).has_point(p)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or steam_panel.visible or art_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := local(event.position)
		if event.pressed:
			press(p)
		else:
			release()
	elif event is InputEventMouseMotion and dragging:
		dragging.position = local(event.position) + drag_offset


func press(p: Vector2) -> void:
	for i in range(cups.size() - 1, -1, -1):  # topmost first
		var c := cups[i]
		if hit(c.sprite, p):
			active_cup = c
			if extracting_into(c):
				say("Wait for the shot to finish.")
			else:
				start_drag(c.sprite, p)
			return
	if page == 1:
		press_toppings(p)
		return
	var under := zones_at(p)
	if hit(pitcher, p):
		start_drag(pitcher, p)
		return
	for pf in pfs:
		if hit(pf.sprite, p):
			# A locked portafilter covers the group head: tapping it starts/stops the
			# shot (see release()), dragging it takes it out.
			var g := group_of(pf)
			if g and g.state == ShotState.EXTRACTING:
				toggle_brew(g.index)
			else:
				start_drag(pf.sprite, p)
			return
	if hit(tamper, p):
		tamp()
	elif "rack" in under or "iced_stack" in under:
		if cups.size() >= MAX_CUPS:
			say("You already have two cups out.")
		else:
			var kind := "iced" if "iced_stack" in under else "cup" if p.x < RACK_AT.x + 100 else "glass"
			var c := new_cup(kind, p)
			start_drag(c.sprite, p)
	elif "brew0" in under:
		toggle_brew(0)
	elif "brew1" in under:
		toggle_brew(1)
	elif "grinder" in under:
		grinding = true
		warned = ""


func press_toppings(p: Vector2) -> void:
	var base := Vector2(PAGE_W, 0)
	for i in SYRUPS.size():
		if Rect2(base + SYRUP_AT + Vector2(i * 80, 0), Vector2(44, 96)).has_point(p):
			add_syrup(SYRUPS[i])
			return
	for i in TOPPINGS.size():
		if Rect2(base + TOPPING_AT + Vector2(i * TOPPING_STEP, 0), Vector2(70, 50)).has_point(p):
			add_topping(TOPPINGS[i])
			return


## Syrups and toppings go into the cup touched last, or the first cup on a slot.
func topping_cup() -> Cup:
	if active_cup and active_cup.spot.begins_with("slot") and not active_cup.drink.is_empty():
		return active_cup
	for c in cups:
		if c.spot.begins_with("slot") and not c.drink.is_empty():
			return c
	say("Bring a drink with espresso in it first. It goes on a mat in the middle.")
	return null


func add_syrup(s: String) -> void:
	var c := topping_cup()
	if c == null:
		return
	c.drink.syrups[s] = int(c.drink.syrups.get(s, 0)) + 1
	say("1 pump of %s (%d total)." % [s.replace("_", " "), c.drink.syrups[s]])
	update_cup_visual(c)
	changed.emit()


func add_topping(t: String) -> void:
	var c := topping_cup()
	if c == null:
		return
	if t in c.drink.toppings:
		say("It already has %s." % t.replace("_", " "))
		return
	c.drink.toppings.append(t)
	update_cup_visual(c)
	changed.emit()


## A new empty cup centred on `at`.
func new_cup(kind: String, at: Vector2) -> Cup:
	var c := Cup.new()
	c.kind = kind
	c.sprite = sprite(CUPS[kind].tex, Vector2.ZERO)
	c.sprite.position = at - c.sprite.texture.get_size() / 2
	c.sprite.z_index = 2
	var inside: Rect2 = CUPS[kind].inside
	c.coffee = rect(COFFEE, Vector2(inside.position.x, inside.end.y), Vector2(inside.size.x, 0), c.sprite)
	c.milk = rect(MILK, inside.position, Vector2(inside.size.x, 0), c.sprite)
	c.ice_layer = Node2D.new()
	c.sprite.add_child(c.ice_layer)
	c.garnish = Node2D.new()
	c.sprite.add_child(c.garnish)
	c.spot = "counter"
	cups.append(c)
	active_cup = c
	return c


## Puts a cup on a zone's snap point (tray or slot).
func put_cup(c: Cup, spot: String) -> void:
	c.spot = spot
	create_tween().tween_property(c.sprite, "position", snap(spot) - c.sprite.texture.get_size() / 2, 0.1)


func start_drag(s: Sprite2D, p: Vector2) -> void:
	dragging = s
	drag_offset = s.position - p
	drag_start = s.position
	s.z_index = 3


func release() -> void:
	if grinding:
		grinding = false
		changed.emit()
	if dragging == null:
		return
	var s := dragging
	dragging = null
	var c := cup_of(s)
	var p := pf_of(s)
	s.z_index = 2 if c else (1 if s == pitcher else 0)
	if p and group_of(p) and s.position.distance_to(drag_start) < TAP_SLOP:
		s.position = drag_start  # a tap, not a drag: brew
		toggle_brew(group_of(p).index)
	elif p:
		drop_pf(p, s.position + PF_BASKET)
	elif c:
		drop_cup(c, s.position + s.texture.get_size() / 2)
	elif s == pitcher:
		drop_pitcher(s.position + s.texture.get_size() / 2)
	changed.emit()


## `at` = basket centre. Snaps to the grinder fork, tamping mat or a group head if that
## spot is free; the knock box empties the basket; anywhere else it goes back.
func drop_pf(p: Portafilter, at: Vector2) -> void:
	var under := zones_at(at)
	if "knock" in under:
		if p.state != PfState.EMPTY:
			p.dose_g = 0.0
			p.state = PfState.EMPTY
			update_pf(p)
			say("Knocked out the old grounds.")
		place_pf(p, "mat" if pf_at("mat") == null else p.spot)
		return
	for spot in PF_SPOTS:
		if spot in under and pf_at(spot) == null:
			place_pf(p, spot)
			return
	place_pf(p, p.spot)


func place_pf(p: Portafilter, spot: String) -> void:
	p.spot = spot
	create_tween().tween_property(p.sprite, "position", snap(spot) - PF_BASKET, 0.12)
	update_pf(p)


## `at` = cup centre.
func drop_cup(c: Cup, at: Vector2) -> void:
	var under := zones_at(at)
	if ("serve" if page == 0 else "serve2") in under:
		if c.drink.is_empty():
			say("The cup is empty.")
		else:
			var d := c.drink.duplicate(true)
			remove_cup(c)
			served.emit(d)
			return
	if page == 1:
		var slot := c.spot if c.spot.begins_with("slot") else "slot%d" % maxi(free_slot(), 0)
		put_cup(c, slot)
		return
	if "ice" in under:
		add_ice(c)
		c.sprite.position = drag_start
		return
	for i in 2:
		var tray := "tray%d" % i
		if tray in under:
			if cup_at(tray) == null:
				put_cup(c, tray)
			else:
				say("There's already a cup on that scale.")
				c.sprite.position = drag_start
			return
	if ("rack" in under or "iced_stack" in under) and c.drink.is_empty() and not c.ice:
		remove_cup(c)
	else:
		c.sprite.position.y = clampf(c.sprite.position.y, 110.0, 310.0)
		c.spot = "counter"


## `at` = pitcher centre.
func drop_pitcher(at: Vector2) -> void:
	var under := zones_at(at)
	if "fridge" in under:
		pitcher_milk = true
		milk_temp = 5.0
		milk_foam = 0.0
		pitcher.texture = tex("pitcher")
		say("Filled the pitcher with cold milk.")
	elif "steam" in under:
		if not pitcher_milk:
			say("The pitcher is empty. Fill it with milk from the fridge first.")
		else:
			pitcher.position = snap("steam") - pitcher.texture.get_size() / 2
			open_steam()
			return
	else:
		for c in cups:
			if hit(c.sprite, at):
				if not pitcher_milk:
					say("The pitcher is empty.")
				elif c.drink.is_empty():
					say("Pull the espresso into the cup before adding milk.")
				else:
					pour_milk(c)
					return
				break
	create_tween().tween_property(pitcher, "position", PITCHER_HOME, 0.15)


# ---------- visuals and feedback ----------

func update_cup_visual(c: Cup) -> void:
	var inside: Rect2 = CUPS[c.kind].inside
	var coffee_h := clampf(c.yield_g / CUP_FULL_G, 0.0, 1.0) * inside.size.y
	if c.kind == "iced":
		coffee_h *= 0.6  # a tall cup: the shot only fills the bottom
	var milk_h := 0.0
	if c.drink.get("milk_temp", -1.0) >= 0.0:
		milk_h = inside.size.y * (0.75 if c.kind == "iced" else 1.0) - coffee_h * 0.4
		coffee_h *= 0.4
	c.coffee.position.y = inside.end.y - coffee_h
	c.coffee.size.y = coffee_h
	c.milk.position.y = inside.end.y - coffee_h - milk_h
	c.milk.size.y = milk_h
	for n in c.ice_layer.get_children():
		n.queue_free()
	if c.ice:  # a few cubes floating in the cup
		for k in 4:
			rect(Color("#D8F1FA", 0.85), inside.position + Vector2(2 + (k % 2) * 9, 4 + k * 8), Vector2(7, 6), c.ice_layer)
	for n in c.garnish.get_children():
		n.queue_free()
	var top := Vector2(inside.position.x + inside.size.x / 2, inside.position.y)
	if milk_h > 0.0 and c.kind != "iced":  # tiny latte-art heart, off-centre if poured badly
		var off := Vector2((1.0 - c.drink.get("art", 1.0)) * 8.0, 0)
		for px in [Vector2(-2, 1), Vector2(1, 1), Vector2(-3, 2), Vector2(-1, 2), Vector2(0, 2), Vector2(2, 2), Vector2(-2, 3), Vector2(-1, 3), Vector2(0, 3), Vector2(1, 3), Vector2(-1, 4), Vector2(0, 4)]:
			rect(Color("#B97F52"), top + px + off, Vector2(1, 1), c.garnish)
	var colors := {"cream": Color("#FFFFFF"), "choc_chips": Color("#3A1E10"), "cinnamon": Color("#A0623A"), "cocoa": Color("#6B3A20")}
	var tops: Array = c.drink.get("toppings", [])
	for i in tops.size():
		for k in 4:
			rect(colors[tops[i]], top + Vector2(-6 + k * 4, -2 - i * 2), Vector2(2, 2), c.garnish)
	var lines := []
	for s in c.drink.get("syrups", {}):
		lines.append("%s x%d" % [s.replace("_", " "), c.drink.syrups[s]])
	for t in tops:
		lines.append(t.replace("_", " "))
	add_ins.text = "\n".join(lines)


## The cup furthest along, for hints.
func hint_cup() -> Cup:
	var best: Cup = null
	for c in cups:
		if best == null or (best.drink.is_empty() and not c.drink.is_empty()):
			best = c
	return best


## The portafilter furthest along (locked and tamped > tamped > dosed > empty > used).
func hint_pf() -> Portafilter:
	var best: Portafilter = null
	var best_rank := -1
	for p in pfs:
		var rank: int = [1, 2, 3, 0][p.state] * 2 + int(p.spot.begins_with("group"))
		if rank > best_rank:
			best = p
			best_rank = rank
	return best


func next_hint() -> String:
	var wants_milk := recipe.has("milk")
	var want_cup: String = recipe.get("cup", "glass")
	for g in groups:
		if g.state == ShotState.EXTRACTING:
			return "Watch the bar under the cup. Tap the group head again when the marker is in the green zone (about %d g)." % recipe.target_yield_g
	var c := hint_cup()
	if c == null or c.drink.is_empty():
		var p := hint_pf()
		if p.state == PfState.USED:
			return "Drag the portafilter to the black knock box to empty the old grounds."
		if p.dose_g < recipe.dose_g - 1.0:
			if p.spot != "fork":
				return "Drag a portafilter under the grinder."
			return "Set the grind with - and +, then press and hold the grinder until the scale shows about %d g." % recipe.dose_g
		if p.state != PfState.TAMPED:
			if p.spot != "mat":
				return "Move the portafilter onto the black tamping mat."
			return "Tap the tamper to press the coffee flat."
		var g := group_of(p)
		if g == null:
			return "Drag the portafilter up into a free group head."
		if c == null or c.spot != "tray%d" % g.index:
			var where := "the plastic cups left of the machine" if want_cup == "iced" else \
				"the rack on top of the machine (%s side)" % ("left" if want_cup == "cup" else "right")
			return "Take a %s from %s and put it under that group head." % [CUPS[want_cup].label, where]
		return "Tap the group head to start the shot."
	if recipe.get("ice", false) and not c.ice:
		return "Drag the cup onto the ice bin at the bottom of the fridge."
	if wants_milk and c.drink.milk_temp < 0.0:
		if not pitcher_milk:
			return "Drag the milk pitcher onto the fridge to fill it with milk."
		if recipe.get("ice", false):
			return "Iced drinks use cold milk: drag the pitcher straight onto the cup. No steaming!"
		if milk_temp < recipe.milk.temp_min:
			return "Drag the pitcher under the steam wand. Hold on it to steam: low adds froth, high only heats. Aim for %d–%d°C and the green froth zone." % [recipe.milk.temp_min, recipe.milk.temp_max]
		return "Drag the pitcher onto the cup to pour the milk."
	var need := []
	for s in recipe.get("syrups", {}):
		if int(c.drink.syrups.get(s, 0)) < int(recipe.syrups[s]):
			need.append("%d pumps of %s" % [recipe.syrups[s], s.replace("_", " ")])
	for t in recipe.get("toppings", []):
		if not t in c.drink.toppings:
			need.append(t.replace("_", " "))
	if not need.is_empty():
		if page == 0:
			return "Tap 'Toppings >' and add: %s." % ", ".join(need)
		return "Tap the bottles and containers to add: %s." % ", ".join(need)
	return "Drag the drink into the dashed SERVE area."


func say(text: String) -> void:
	message.emit(text)


func once(text: String) -> void:
	if warned != text:
		warned = text
		say(text)


func update_pf(p: Portafilter) -> void:
	p.sprite.texture = tex("portafilter_" + ["empty", "dosed", "tamped", "used"][p.state])
