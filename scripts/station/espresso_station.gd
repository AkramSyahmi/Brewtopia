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
signal changed  ## station state changed: objectives and the guide refresh
signal message(text: String)
signal shot_finished(quality: String, shot: Dictionary)  ## "Perfect", "Good" or "Bad"
signal milk_frothed(quality: String, milk: Dictionary)  ## {temp, foam}; same ratings

## What is in a portafilter basket.
enum PfState { EMPTY, DOSED, TAMPED, USED }
## A group head.
enum ShotState { IDLE, EXTRACTING }
## What is in the milk pitcher. COLD = milk that isn't steamed (below STEAMED_MIN_C: fresh
## from the fridge, or only warmed at the wand); STEAMED = heated to STEAMED_MIN_C or more.
## Pouring empties it. milk_temp / milk_foam always keep the real values; milk_heat() names
## the temperature band that the tag, the hover text and pouring all go by.
enum MilkState { EMPTY, COLD, STEAMED }
## The steam wand popup: closed, open with the pitcher under the wand, or steaming.
enum SteamState { CLOSED, OPEN, STEAMING }

const ART := "res://assets/art/%s.png"
const SCALE := 2
const PAGE_W := 640.0
const MAX_YIELD_G := 70.0
const CUP_FULL_G := 40.0
const COFFEE := Color("#4A2A18")

const MAX_CUPS := 2

# Espresso page (sprite top-left, base px). Must match the art in ART_LIST.md.
const GRINDER_AT := Vector2(12, 94)  # lid and hopper clear of the objective panel
const BAG_AT := Vector2(104, 182)
const MAT_AT := Vector2(8, 300)  # tools stand on one baseline across it (y 330): portafilter spouts, tamper base
const KNOCK_AT := Vector2(160, 298)  # right of the tamping mat, fully above the tip bar (y 344)
const MACHINE_AT := Vector2(205, 46)
const RACK_AT := Vector2(255, 14)
const ICED_STACK_AT := Vector2(166, 108)
const FRIDGE_AT := Vector2(562, 172)  # freestanding glass-door fridge (74x116), right edge of the counter
const ICE_BIN_AT := Vector2(571, 292)  # on the counter under the fridge
const TAMPER_REST := Vector2(110, 277)  # base on the mat's y 330 baseline, right of the portafilter
const PITCHER_HOME := Vector2(496, 200)  # beside the steam wand, on its drip mat, clear of SERVE
const TOPPINGS_AT := Vector2(1122, 346)  # screen px: the Toppings button's TOP-RIGHT corner (it ends just left of the fridge), above the pitcher
const STEAM_ZONE := Rect2(430, 170, 80, 90)  # under the steam wand
const SERVE_RECT := Rect2(482, 292, 80, 48)  # clear counter right of the machine, under the pitcher
const KNOBS := [Vector2(67.5, 110.5), Vector2(212.5, 110.5)]  # brew button centres in machine.png (23 px round knobs)
const KNOB_ART := 23  # knob size in machine.png px; its tap zone is KNOB_TAP (bigger, for fingers)
const KNOB_TAP := 34.0
const GROUP_DX := 117.0  # the right group head is this far right of the left one
# Where the portafilter locks in, measured from the art (re-measure if machine.png or the
# portafilter sprites are replaced): group head centres and their bottom row in machine.png,
# and the basket's centre / rim top inside the portafilter sprite.
const GROUP0_HEAD_X := 82.0
const GROUP1_HEAD_X := 197.0  # whole pixels keep the pixel art crisp
const GROUP_HEAD_BOTTOM := 182.0
const PF_RIM := Vector2(45, 7)
const PF_BASKET_HALF_W := 12.0  # half the basket's width in the portafilter sprite (around PF_RIM.x)
const PF_SEAT := 3.0  # px the basket rim tucks up into the group head, so it looks locked on
# Grinder dispensing point, measured from grinder.png (re-measure if the art is replaced):
# chute and fork arms are centred at x 50; the basket rim rests in the fork at y 134.
const GRINDER_SPOUT_X := 50.0
const GRINDER_FORK_RIM_Y := 134.0
const GRINDER_CHUTE_Y := 120.0  # bottom of the chute: where the grounds start falling
const GRINDER_SCREEN := Rect2(31, 158, 38, 11)  # the green scale screen in grinder.png: live dose
const PF_SPOTS := {  # portafilter sprite top-left at each resting spot
	# in the grinder fork: basket opening centred under the spout, handle out to the left
	"fork": GRINDER_AT + Vector2(GRINDER_SPOUT_X - PF_RIM.x, GRINDER_FORK_RIM_Y - PF_RIM.y),
	"mat": Vector2(22, 303),  # on the tamping mat: spout tips on the y 330 baseline, left of the tamper
	# locked into the left / right group head: basket centred under the head, rim seated
	"group0": MACHINE_AT + Vector2(GROUP0_HEAD_X - PF_RIM.x, GROUP_HEAD_BOTTOM - PF_SEAT - PF_RIM.y),
	"group1": MACHINE_AT + Vector2(GROUP1_HEAD_X - PF_RIM.x, GROUP_HEAD_BOTTOM - PF_SEAT - PF_RIM.y),
}
const PF_BASKET_BOTTOM := 28.0  # lowest basket row in the portafilter sprite (spouts)
const PF_BASKET := Vector2(46, 14)  # basket centre inside the portafilter sprite = its anchor
const PF_SNAP_RADIUS := 34.0
const TAP_SLOP := 4.0  # base px a press may move and still count as a tap
const CUP_STAND_Y := 236.0  # top surface of the scale pads in machine.png (pad edge at row 232)
const DIAL_AT := Vector2(15, 276)  # grind -/+ row centred under the grinder base (x 62), 6 px below it, above the mat
const SHOT_BAR := Rect2(232, 330, 90, 8)  # timing bar under the left scale
const DOUBLE_SHOT_G := 14.0  # doses from here up count as a double shot
const AERATE_PER_S := 0.14  # froth gained per second with the wand tip at the surface
const FOAM_DEFAULT := Vector2(0.25, 0.4)  # green froth zone when the recipe sets none
const STEAMED_MIN_C := 40.0  # milk this hot or hotter counts as steamed
const COLD_MAX_C := 20.0  # milk below this is cold (as from the fridge); in between it is only warm
const GUIDE_PAD := 3.0  # base px between a highlighted thing and the yellow outline
const FRIDGE_DOOR := Rect2(5, 5, 64, 96)  # glass door within milk_fridge.png (see tools/make_station_art.gd)
const MILK_SOURCE := Rect2(FRIDGE_AT + FRIDGE_DOOR.position, FRIDGE_DOOR.size)  # the door with the milk (not the ice bin below)
const MILK_SIGN := Rect2(FRIDGE_AT + Vector2(7, 41), Vector2(60, 14))  # "COLD MILK" plate across the door, between the shelves

# Topping page (base px, page origin at x = 640)
const SYRUPS := ["vanilla", "caramel", "chocolate", "pandan", "gula_melaka", "condensed_milk"]
const TOPPINGS := ["cream", "choc_chips", "cinnamon", "cocoa"]
## Syrup row (tools/make_topping_art.gd paints the shelf, its shadows and the name tags to match):
## bottle i sits at SYRUP_AT + (i * SYRUP_STEP, 0), its foot on the shelf; clear of the objective
## panel and the order slip at 1280x720.
const SYRUP_AT := Vector2(92, 110)
const SYRUP_STEP := 72
const SYRUP_SIZE := Vector2(44, 96)  # the bottle sprite = its tap area
const SYRUP_TAG := Rect2(-11, 114, 66, 12)  # name tag, relative to the bottle
const TOPPING_AT := Vector2(20, 250)  # first container; every TOPPING_STEP px (make_topping_art.gd paints them)
const TOPPING_SIZE := Vector2(64, 60)  # the container sprite = its tap area
const TOPPING_TAG := Rect2(4, 40, 56, 12)  # name tag on the container front
const TOPPING_STEP := 72
const SLOTS := [Vector2(360, 284), Vector2(460, 284)]  # cup slots on the topping page (mats in topping_bg)
const SERVE2_RECT := Rect2(520, 250, 110, 80)

## Cup kinds: sprite and the rectangle inside it where the drink shows. Measured from each
## sprite (re-measure if the art changes): anchor = centre of the opening/base (x) and the
## bottom row (y), which stands on the machine's scale pad; rim_y = top of the opening;
## base_w = width of the contact shadow under it.
const CUPS := {
	"glass": {"tex": "cup_espresso", "inside": Rect2(6, 8, 24, 24), "label": "glass",
		"anchor": Vector2(18, 35), "rim_y": 0.0, "base_w": 12.0},
	"cup": {"tex": "cup_latte", "inside": Rect2(11, 3, 30, 7), "label": "latte cup",
		"anchor": Vector2(28, 43), "rim_y": 2.0, "base_w": 26.0},  # anchor = saucer centre; the handle sticks out right
	"iced": {"tex": "cup_iced", "inside": Rect2(6, 6, 20, 42), "label": "plastic iced cup",
		"anchor": Vector2(16, 50), "rim_y": 1.0, "base_w": 28.0},
}


class Portafilter:
	var sprite: Sprite2D
	var state := PfState.EMPTY
	var dose_g := 0.0
	var grind := 8  # grind setting of the coffee in the basket
	var spot := "mat"
	var shadow: ColorRect  # contact shadow under it while it lies on the mat


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
	var knob_lit: Sprite2D  # the brew button glowing green while this group pulls a shot


class Cup:
	var sprite: Sprite2D
	var kind := ""
	var spot := ""  # "tray0", "tray1", "counter", "slot0", "slot1"
	var yield_g := 0.0
	var ice := false
	var drink := {}  # filled once a shot lands; milk/ice/syrups/toppings added later
	var liquid: CupLiquid
	var ice_layer: Node2D
	var garnish: Node2D
	var shadow: ColorRect  # soft contact shadow, shown while it stands on a scale pad
	var back_pos := Vector2.ZERO  # where it waits on the espresso page
	var back_spot := "counter"
	var extras_log: Array = []  # this drink's syrup pumps / toppings in the order added, for Undo: ["syrup" | "topping", name]


var recipe: Dictionary
var dispense_g_per_s := 2.5  # grinder near the dose (the last GRIND_SLOW_FROM_G): slow, so letting go on time is fair
var grind_fast_g_per_s := 8.0  # grinder before that: the run-up goes quickly
var sim_speed := 2.0  # shot: simulated seconds per real second near the target and through the green zone
## Fast, then slow near the target, like a grinder's slow fill: the waiting part goes quickly and
## the part where the player reacts keeps today's pace. Only real time changes: the simulated
## shot clock, grams and every scored value are the same.
const GRIND_SLOW_FROM_G := 3.0  # grams short of the recipe dose where the grinder slows down
const SHOT_SLOW_FROM_G := 8.0  # grams short of the target yield where the shot slows to sim_speed
const SHOT_RUNUP_S := 4.0  # real seconds the run-up takes (any grind: a very fine one no longer means a long wait)
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
var milk_state := MilkState.EMPTY
var milk_status: Node2D  # milk surface, steam wisps and the status tag drawn on the pitcher
var milk_hover: Panel  # outline around the cold milk source (hover / drop target)
var tooltip: Label  # short hover text next to the pointer
var guide_on := true  # highlight the equipment for the current objective
var guide_strong := true  # also the bobbing arrow over it (CafeShift: "full" assist only)
var guide_target := ""  # objective().target being highlighted
var guide_box: Panel
var guide_arrow: Polygon2D
var grinder_bounds: Rect2  # drawn grinder (non-transparent pixels), world base px
var pf_bounds: Rect2  # drawn portafilter inside its sprite
var hover_t := 0.0  # drives the steam wisps
var milk_temp := 5.0
var milk_foam := 0.0  # 0 = flat, 1 = all foam
var pitcher_depth := 0.0  # 0 = wand tip at the milk surface (adds air), 1 = deep (only heats)
var pitcher_tween: Tween  # the pitcher sliding back to its spot (cancelled if grabbed again)

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
var grinder_screen: Label  # the dose on the grinder scale
var dose_bubble: Label
var steam_panel: PanelContainer
var art_panel: LatteArtPanel
var world_font := PixelUI.font()  # labels inside the scaled world (see pixel_text)
var art_cup: Cup  # the cup getting latte art
var temp_meter: Meter  # steam popup: the thermometer
var froth_meter: Meter  # steam popup: the froth gauge
var temp_label: Label
var steam_legend: Label  # "Froth 45-60%  Temp 60-65°C" ("full" assist only, see open_steam)
var steam_puffs: Array[Control] = []  # little steam clouds off the wand while steaming
var steam_pitcher: Control  # the pitcher inside the popup; moves up and down
var steam_milk: PitcherMilk  # the milk in the popup pitcher
var pitcher_milk: PitcherMilk  # the milk in the counter pitcher
var to_toppings: Button
var to_espresso: Button
var undo_button: Button  # topping page: takes back the last syrup pump / topping (undo_extra)
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
	# Latte art is a modal: on the modal UI layer (above the objective panel and the HUD),
	# behind a dim backdrop that swallows clicks so nothing on the bar can be pressed.
	var art_layer := CanvasLayer.new()
	art_layer.layer = 2
	add_child(art_layer)
	build_steam_panel(art_layer)  # also a popup: above the HUD and the order note
	var art_dim := ColorRect.new()
	art_dim.color = Color(0, 0, 0, 0.35)
	art_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	art_dim.mouse_filter = MOUSE_FILTER_STOP
	art_dim.hide()
	art_layer.add_child(art_dim)
	art_panel = LatteArtPanel.new()
	art_layer.add_child(art_panel)
	art_panel.finished.connect(on_art_finished)
	art_panel.visibility_changed.connect(func():
		art_dim.visible = art_panel.visible
		changed.emit())  # the objective switches to / from "Create latte art"
	build_nav()
	dose_bubble = PixelUI.number_label(bubble(), 24)
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
	pixel_text(l, size_px)
	l.add_theme_color_override("font_color", c)
	l.position = at
	l.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(l)
	return l


## Text inside the x2 world (labels on equipment): the game's pixel font, drawn at screen
## resolution (twice the size, half the scale) so it stays crisp instead of being blown up.
## (World nodes are not Controls under the UI theme, so the font is set here.)
func pixel_text(l: Label, size_px: int) -> void:
	l.add_theme_font_override("font", world_font)
	l.add_theme_font_size_override("font_size", size_px * 2)
	l.scale = Vector2(0.5, 0.5)


## Where a cup stands on group i's scale pad (its anchor goes here): right under the group
## head and the portafilter's spouts, on the pad's top surface.
func cup_stand(i: int) -> Vector2:
	return MACHINE_AT + Vector2(GROUP0_HEAD_X if i == 0 else GROUP1_HEAD_X, CUP_STAND_Y)


## About where the middle of a cup on that scale is (spawning cups, readouts).
func tray_centre(i: int) -> Vector2:
	return cup_stand(i) - Vector2(0, 20)


## Drop and tap targets. Portafilter zones snap the basket centre; cup/pitcher zones snap
## the item's centre.
func build_zones() -> void:
	for spot in PF_SPOTS:
		var c: Vector2 = PF_SPOTS[spot] + PF_BASKET
		add_zone(spot, Rect2(c - Vector2.ONE * PF_SNAP_RADIUS, Vector2.ONE * PF_SNAP_RADIUS * 2.0), c)
	for i in 2:
		add_zone("tray%d" % i, Rect2(cup_stand(i) + Vector2(-36, -64), Vector2(72, 70)), cup_stand(i))  # snap = cup anchor
		add_zone("brew%d" % i, Rect2(MACHINE_AT + Vector2(60 + GROUP_DX * i, 150), Vector2(80, 60)))
		add_zone("knob%d" % i, Rect2(MACHINE_AT + KNOBS[i] - Vector2.ONE * KNOB_TAP / 2.0, Vector2.ONE * KNOB_TAP))  # brew button
	add_zone("knock", Rect2(KNOCK_AT, Vector2(56, 44)).grow(10))
	add_zone("rack", Rect2(RACK_AT, Vector2(200, 70)))
	add_zone("iced_stack", Rect2(ICED_STACK_AT, Vector2(34, 70)))
	add_zone("grinder", Rect2(GRINDER_AT + Vector2(10, 60), Vector2(76, 120)))
	add_zone("ice", Rect2(ICE_BIN_AT, Vector2(56, 48)).grow(6))
	add_zone("fridge", MILK_SOURCE)  # the cold milk source: the fridge door, above the ice bin
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
	# The SERVE box (border, fill, mug) and the pitcher's platform are painted in station_bg.
	var serve := world_label("SERVE", SERVE_RECT.position + Vector2(0, 27), 10, Color("#7A5A3A"))
	serve.size = Vector2(SERVE_RECT.size.x, 16) * 2.0  # (world labels draw at half scale)
	serve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grinder := sprite("grinder", GRINDER_AT)
	var used := grinder.texture.get_image().get_used_rect()  # the drawn grinder, without empty margins
	grinder_bounds = Rect2(GRINDER_AT + Vector2(used.position), Vector2(used.size))
	grinder_screen = world_label("0.0g", GRINDER_AT + GRINDER_SCREEN.position, 8, Color("#1F4A1A"))
	grinder_screen.add_theme_font_override("font", PixelUI.numbers())
	grinder_screen.size = GRINDER_SCREEN.size * 2.0  # (world labels draw at half scale)
	grinder_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grinder_screen.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pf_used := tex("portafilter_empty").get_image().get_used_rect()
	pf_bounds = Rect2(Vector2(pf_used.position), Vector2(pf_used.size))
	sprite("bean_bag", BAG_AT)
	sprite("tamp_mat", MAT_AT)
	sprite("knock_box", KNOCK_AT)
	sprite("machine", MACHINE_AT)
	sprite("cups_rack", RACK_AT)
	sprite("iced_cups", ICED_STACK_AT)
	sprite("milk_fridge", FRIDGE_AT)
	sprite("ice_bin", ICE_BIN_AT)
	world_label("ICE", ICE_BIN_AT + Vector2(18, 34), 8, Color("#36251D"))
	grounds_stream = rect(COFFEE, GRINDER_AT + Vector2(GRINDER_SPOUT_X - 1, GRINDER_CHUTE_Y),
		Vector2(2, GRINDER_FORK_RIM_Y - GRINDER_CHUTE_Y))  # chute down into the basket
	grounds_stream.hide()
	for i in 2:  # the first portafilter waits on the mat, the second sits in the right group
		var p := Portafilter.new()
		p.spot = "mat" if i == 0 else "group1"
		p.sprite = sprite("portafilter_empty", snap(p.spot) - PF_BASKET)
		p.sprite.z_index = 2 if p.spot.begins_with("group") else 0
		p.shadow = rect(Color(0.12, 0.08, 0.06, 0.35), Vector2(4, 28), Vector2(56, 2), p.sprite)  # under the spouts
		p.shadow.show_behind_parent = true
		p.shadow.visible = p.spot == "mat"
		pfs.append(p)
	tamper = sprite("tamper", TAMPER_REST)
	tamper.z_index = 1
	var ts := rect(Color(0.12, 0.08, 0.06, 0.35), Vector2(7, 54), Vector2(26, 2), tamper)  # under its base
	ts.show_behind_parent = true
	pitcher = sprite("pitcher", PITCHER_HOME)
	pitcher.z_index = 1
	build_milk_feedback()
	build_guide()
	changed.connect(refresh_guide)


## Makes the cold milk source easy to find and the pitcher's milk easy to read:
## a "COLD MILK" plate on the fridge door, an outline when pointing at it or dragging the
## pitcher over it, a hover tooltip, and a milk surface + status tag on the pitcher.
func build_milk_feedback() -> void:
	rect(Color("#1F4E8C"), MILK_SIGN.position, MILK_SIGN.size)  # sign plate: dark blue border
	rect(Color("#EAF4FF"), MILK_SIGN.position + Vector2.ONE, MILK_SIGN.size - Vector2(2, 2))
	world_label("COLD MILK", MILK_SIGN.position + Vector2(7, -1), 8, Color("#1F4E8C"))
	milk_hover = Panel.new()
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(2)
	milk_hover.add_theme_stylebox_override("panel", s)
	milk_hover.position = MILK_SOURCE.position - Vector2(2, 2)
	milk_hover.size = MILK_SOURCE.size + Vector2(4, 4)
	milk_hover.mouse_filter = MOUSE_FILTER_IGNORE
	milk_hover.hide()
	world.add_child(milk_hover)
	pitcher_milk = PitcherMilk.new()
	pitcher.add_child(pitcher_milk)
	milk_status = Node2D.new()
	pitcher.add_child(milk_status)
	tooltip = bubble(16)
	tooltip.z_index = 5  # above the dragged items on the station page
	update_pitcher_visual()


## The pitcher's milk by temperature: "" (empty), "cold" (below COLD_MAX_C), "warm"
## (warmed at the wand but under STEAMED_MIN_C: not steamed) or "steamed".
func milk_heat() -> String:
	if milk_state == MilkState.EMPTY:
		return ""
	if milk_temp >= STEAMED_MIN_C:
		return "steamed"
	return "cold" if milk_temp < COLD_MAX_C else "warm"


## Milk surface in the pitcher's mouth (its real temperature and foam: white when cold,
## creamier with foam dots as it warms, steam wisps once steamed), plus a text tag under it
## (EMPTY / COLD / WARM / STEAMED) so the state never depends on colour alone.
func update_pitcher_visual() -> void:
	for n in milk_status.get_children():
		n.queue_free()
	var heat := milk_heat()
	var tag_text: String = {"": "EMPTY", "cold": "COLD", "warm": "WARM", "steamed": "STEAMED"}[heat]
	var steamed := milk_state == MilkState.STEAMED
	pitcher_milk.set_milk(milk_state != MilkState.EMPTY, milk_temp, milk_foam)
	if steamed:
		for k in 2:  # steam wisps, animated in _process
			var w := rect(Color(1, 1, 1, 0.7), Vector2(21 + k * 14, -4), Vector2(2, 5), milk_status)
			w.name = "Wisp%d" % k
	var plate := rect(Color("#36251D"), Vector2(0, 66), Vector2(60, 11), milk_status)
	var l := Label.new()
	l.text = tag_text
	pixel_text(l, 8)
	l.add_theme_color_override("font_color", {"": Color("#C9BFB5"), "cold": Color("#BFE3FF"), "warm": Color("#F5E7CA"), "steamed": Color("#FFD9A0")}[heat])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 22)  # = the 60x11 plate at half scale
	l.mouse_filter = MOUSE_FILTER_IGNORE
	plate.add_child(l)


func set_milk(state: MilkState) -> void:
	milk_state = state
	update_pitcher_visual()


## A short message that floats up from the pitcher and fades (e.g. "Cold milk added!").
func float_text(text: String) -> void:
	var l := bubble(18)
	l.text = text
	l.add_theme_color_override("font_color", Color("#9FE08A"))
	l.reset_size()
	l.position = (pitcher.position + world.position / SCALE) * SCALE + Vector2(60 - l.size.x / 2.0, -40)
	l.z_index = 5
	l.show()
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 40, 1.4)
	t.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)


func pitcher_words() -> String:
	match milk_heat():
		"cold":
			return "Cold Milk"
		"warm":
			return "Warm Milk (%d°C), not steamed yet" % roundi(milk_temp)
		"steamed":
			return "Steamed Milk (%d°C)" % roundi(milk_temp)
	return "Empty Pitcher"


## Hover help (mouse pointer): the cold milk source and the pitcher's contents. While the
## pitcher is dragged, the milk source lights up as a drop target; while a full cup is
## dragged over the rack or cup stack, it warns that letting go pours the drink away.
func update_hover(screen_pos: Vector2) -> void:
	var p := local(screen_pos)
	var text := ""
	var over_milk := page == 0 and "fridge" in zones_at(p if dragging != pitcher else pitcher.position + pitcher.texture.get_size() / 2)
	var held: Cup = cup_of(dragging) if dragging else null
	if dragging == pitcher:
		text = "Release to fill with cold milk" if over_milk else ""
	elif held and page == 0 and (not held.drink.is_empty() or held.ice):
		var under := zones_at(held.sprite.position + held.sprite.texture.get_size() / 2)  # the point drop_cup uses
		if "rack" in under or "iced_stack" in under:
			text = "Release to pour the drink away"
	elif dragging == null and page == 0:
		if hit(pitcher, p):
			text = pitcher_words()
		elif "knob0" in zones_at(p) or "knob1" in zones_at(p):
			text = "Brew button: tap to start or stop the shot"
		elif over_milk:
			text = "COLD MILK: drag the pitcher here to fill it"
	var style := milk_hover.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color("#3FD06B") if dragging == pitcher else Color("#5FA8E8")
	milk_hover.visible = over_milk and (dragging == null or dragging == pitcher)
	tooltip.visible = text != ""
	if text != "":
		tooltip.text = text
		tooltip.reset_size()
		tooltip.position = (screen_pos + Vector2(18, 18)).clamp(Vector2.ZERO, size - tooltip.size)


func build_topping_page() -> void:
	sprite("topping_bg", Vector2(PAGE_W, 0))
	for i in SYRUPS.size():
		sprite("syrup_" + SYRUPS[i], syrup_rect(i).position)
		tag_label(SYRUPS[i], Rect2(syrup_rect(i).position + SYRUP_TAG.position, SYRUP_TAG.size))
	for i in TOPPINGS.size():
		sprite("topping_" + TOPPINGS[i], topping_rect(i).position)
		tag_label(TOPPINGS[i], Rect2(topping_rect(i).position + TOPPING_TAG.position, TOPPING_TAG.size))
	# The SERVE area itself (dashed border, cream fill, mug) is painted in topping_bg.
	var serve := world_label("SERVE", SERVE2_RECT.position + Vector2(PAGE_W, 54), 12, Color("#7A5A3A"))
	serve.size = Vector2(SERVE2_RECT.size.x, 20) * 2.0  # (world labels draw at half scale)
	serve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_ins = world_label("", SERVE2_RECT.position + Vector2(PAGE_W + 6, 6), 8, Color("#5A341C"))  # what is in the cup: top of the SERVE box, under its guide arrow
	add_ins.add_theme_font_override("font", PixelUI.numbers())  # "x2": readable digits (font size 16 on screen)


## Syrup bottle i on the topping page (world px): sprite and tap area.
func syrup_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAGE_W, 0) + SYRUP_AT + Vector2(i * SYRUP_STEP, 0), SYRUP_SIZE)


## Topping container i on the topping page (world px): sprite and tap area.
func topping_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAGE_W, 0) + TOPPING_AT + Vector2(i * TOPPING_STEP, 0), TOPPING_SIZE)


## An ingredient's name centred on a painted cream tag (`r` in world px).
func tag_label(id: String, r: Rect2) -> void:
	var l := world_label(id.replace("_", " ").capitalize(), r.position, 8, Color("#5A341C"))
	l.size = r.size * 2.0  # (world labels draw at half scale)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## A group head: its coffee stream, its GCGC-style timing bar (stop the marker in the
## green zone) and its scale readout.
func build_group(i: int) -> void:
	var g := Group.new()
	g.index = i
	# the shot pours from the locked portafilter's spouts down into the cup
	var spot: Vector2 = PF_SPOTS["group%d" % i]
	var top := spot.y + PF_BASKET_BOTTOM
	g.stream = rect(COFFEE, Vector2(spot.x + PF_RIM.x - 1, top), Vector2(2, cup_stand(i).y - top))  # to the pad; set_stream() trims it to the cup
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
	g.bubble = PixelUI.number_label(bubble(), 24)
	g.knob_lit = Sprite2D.new()
	g.knob_lit.texture = lit_knob(i)
	g.knob_lit.centered = false
	g.knob_lit.position = MACHINE_AT + (KNOBS[i] - Vector2.ONE * KNOB_ART / 2.0).floor()
	g.knob_lit.z_index = 1  # over the machine sprite
	g.knob_lit.hide()
	world.add_child(g.knob_lit)
	groups.append(g)


## The brew button lit up: knob i cut from machine.png with its greys swapped for greens
## (shading kept, outline and centre dot stay dark, the panel around it transparent). Made
## at runtime from the existing sprite, so no art file changes.
func lit_knob(i: int) -> ImageTexture:
	var at := Vector2i((KNOBS[i] - Vector2.ONE * KNOB_ART / 2.0).floor())
	var img := tex("machine").get_image().get_region(Rect2i(at, Vector2i(KNOB_ART, KNOB_ART)))
	img.convert(Image.FORMAT_RGBA8)
	var greens := {Color8(102, 101, 107): Color("#CFF0A8"), Color8(52, 50, 58): Color("#7CC95A"), Color8(42, 41, 47): Color("#4E9A3A")}
	for y in KNOB_ART:
		for x in KNOB_ART:
			var c := img.get_pixel(x, y)
			if greens.has(c):
				img.set_pixel(x, y, greens[c])
			elif c != Color8(26, 24, 28):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


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
	var minus := small_button("-", Vector2(42, 42))
	minus.pressed.connect(func(): set_grind(grind - 1))
	box.add_child(minus)
	grind_label = Label.new()
	PixelUI.number_label(grind_label, 24)
	grind_label.add_theme_color_override("font_color", Color("#36251D"))
	grind_label.custom_minimum_size = Vector2(96, 42)
	grind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(grind_label)
	var plus := small_button("+", Vector2(42, 42))
	plus.pressed.connect(func(): set_grind(grind + 1))
	box.add_child(plus)
	for b: Button in [minus, plus]:  # wood signs, like Toppings / Espresso
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, PixelUI.frame(PixelUI.MENU % ("button_wood_" + state), Vector4i(15, 15, 15, 18), Vector4(4, 2, 4, 5)))
		b.add_theme_font_size_override("font_size", 28)
		b.add_theme_color_override("font_color", Color("#F3E6CC"))


## Steaming popup (layout in body px; the body sits inside the cream sign's padding):
## Froth gauge | pitcher under the wand | thermometer + readout | "How to Steam" steps + Done,
## a "Steam Milk" banner across the top edge and the target legend along the bottom.
## Hold on the pitcher to steam; drag it down (wand tip at the surface) to add air, up (wand
## deep) to only heat. Let go and press Done (or the X) with both in the green.
## Same footprint as before (x 690 to the right edge): the left group head and its shot readout stay in view.
func build_steam_panel(layer: CanvasLayer) -> void:
	steam_panel = PanelContainer.new()
	steam_panel.add_theme_stylebox_override("panel", PixelUI.cream_panel())  # pixel cream sign, gold rim
	steam_panel.position = Vector2(690, 96)
	layer.add_child(steam_panel)
	var body := Control.new()
	body.custom_minimum_size = Vector2(522, 526)
	steam_panel.add_child(body)
	var ink := Color("#36251D")
	var brown := Color("#5A3414")
	# banner across the top edge, and the red X in the corner (same as Done)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", PixelUI.frame(PixelUI.MENU % "banner", Vector4i(18, 18, 15, 18), Vector4(24, 8, 28, 12)))
	banner.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(banner)
	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 12)
	banner.add_child(banner_row)
	var cup_icon := TextureRect.new()
	cup_icon.texture = load(PixelUI.HUD % "icon_cup_small")
	cup_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cup_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner_row.add_child(cup_icon)
	var title := Label.new()
	title.text = "Steam Milk"
	title.add_theme_font_override("font", PixelUI.font(700))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ink)
	banner_row.add_child(title)
	banner.resized.connect(func(): banner.position = Vector2((body.custom_minimum_size.x - banner.size.x) / 2.0, -54))
	var close := TextureButton.new()
	close.texture_normal = load(PixelUI.HUD % "close_normal")
	close.texture_hover = load(PixelUI.HUD % "close_hover")
	close.texture_pressed = load(PixelUI.HUD % "close_pressed")
	close.position = Vector2(body.custom_minimum_size.x - 30, -12)
	close.tooltip_text = "Done steaming"
	close.pressed.connect(close_steam)
	body.add_child(close)
	# the two gauges, each under a cream name tag
	froth_meter = Meter.new()
	froth_meter.colors(Color("#D9A066"), Color("#F2C894"), Color("#A8693A"))
	froth_meter.position = Vector2(8, 78)
	body.add_child(froth_meter)
	steam_tag(body, "Froth", Vector2(-4, 24), 84.0)
	temp_meter = Meter.new()
	temp_meter.bulb = true
	temp_meter.colors(Color("#D9534F"), Color("#F08A7E"), Color("#A8322E"))
	temp_meter.position = Vector2(262, 78)
	body.add_child(temp_meter)
	steam_tag(body, "Temp", Vector2(250, 24), 84.0)
	var readout := PanelContainer.new()
	readout.add_theme_stylebox_override("panel", PixelUI.frame(PixelUI.MENU % "button_cream_normal", Vector4i(15, 15, 15, 18), Vector4(8, 4, 8, 8)))
	readout.custom_minimum_size = Vector2(88, 0)
	readout.position = Vector2(248, 426)
	readout.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(readout)
	temp_label = Label.new()
	PixelUI.number_label(temp_label, 24)
	temp_label.add_theme_color_override("font_color", ink)
	temp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_child(temp_label)
	# the pitcher under the steam wand; press and drag here (size and drag maths as before)
	var area := Control.new()
	area.size = Vector2(170, 380)
	area.position = Vector2(80, 66)
	area.mouse_filter = MOUSE_FILTER_STOP
	area.clip_contents = true
	area.gui_input.connect(on_steam_input)
	body.add_child(area)
	rect(Color("#3A2416"), Vector2(75, 0), Vector2(16, 6), area)  # wand joint
	rect(Color("#9EA3AA"), Vector2(78, 0), Vector2(10, 230), area)  # steam wand
	rect(Color("#C9CDD3"), Vector2(78, 0), Vector2(3, 230), area)  # its shine
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
	steam_milk = PitcherMilk.new()  # same milk drawing, scaled like the art (keep-aspect fit)
	var fit := minf(art.size.x / 60.0, art.size.y / 64.0)
	steam_milk.scale = Vector2.ONE * fit
	steam_milk.position = (art.size - Vector2(60, 64) * fit) / 2.0
	steam_pitcher.add_child(steam_milk)
	for i in 3:  # pixel steam clouds; update_steam_ui drifts them up from the rim while steaming
		var puff := Control.new()
		puff.mouse_filter = MOUSE_FILTER_IGNORE
		for part: Rect2 in [Rect2(3, 0, 12, 3), Rect2(0, 3, 18, 9), Rect2(3, 12, 12, 3), Rect2(12, -3, 9, 9)]:
			rect(Color("#B9AFA2"), part.position - Vector2(3, 3), part.size + Vector2(6, 6), puff)  # outline
		for part: Rect2 in [Rect2(3, 0, 12, 3), Rect2(0, 3, 18, 9), Rect2(3, 12, 12, 3), Rect2(12, -3, 9, 9)]:
			rect(Color("#FFFFFF"), part.position, part.size, puff)
		puff.hide()
		area.add_child(puff)
		steam_puffs.append(puff)
	# divider, then the numbered steps and Done
	for y in range(30, 470, 12):
		rect(Color("#D9C7A8"), Vector2(340, y), Vector2(3, 6), body)
	steam_tag(body, "How to Steam", Vector2(352, 24), 0.0)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 14)
	steps.position = Vector2(352, 84)
	steps.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(steps)
	var lines := ["Hold the pitcher to steam.", "Drag DOWN: more froth.",
		"Drag UP: just heat.", "Both bars in the green, then Done."]
	for i in lines.size():
		var step_row := HBoxContainer.new()
		step_row.add_theme_constant_override("separation", 10)
		step_row.mouse_filter = MOUSE_FILTER_IGNORE
		steps.add_child(step_row)
		var n := Label.new()
		PixelUI.number_label(n, 16)
		n.text = str(i + 1)
		n.add_theme_color_override("font_color", Color("#F3E6CC"))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", PixelUI.wood_pill(10.0))
		badge.size_flags_vertical = SIZE_SHRINK_BEGIN
		badge.custom_minimum_size = Vector2(36, 0)
		badge.add_child(n)
		step_row.add_child(badge)
		var l := Label.new()
		l.text = lines[i]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(126, 0)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", brown)
		step_row.add_child(l)
	var done := small_button("Done", Vector2(170, 60))
	done.position = Vector2(352, 418)
	done.pressed.connect(close_steam)
	body.add_child(done)
	# legend: what the green means; the exact targets only on "full" assist orders (open_steam)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	legend.position = Vector2(0, 474)
	legend.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(legend)
	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(21, 21)
	swatch.size_flags_vertical = SIZE_SHRINK_CENTER
	rect(Color("#4E9A3A"), Vector2.ZERO, Vector2(21, 21), swatch)
	rect(Color("#B5E78F"), Vector2(3, 3), Vector2(15, 15), swatch)
	legend.add_child(swatch)
	var zones := Label.new()
	zones.text = "Target zones"
	zones.add_theme_font_size_override("font_size", 16)
	zones.add_theme_color_override("font_color", brown)
	legend.add_child(zones)
	steam_legend = Label.new()  # second line, under the swatch
	PixelUI.number_label(steam_legend, 16)
	steam_legend.add_theme_color_override("font_color", brown)
	steam_legend.position = Vector2(0, 500)
	body.add_child(steam_legend)
	steam_panel.hide()


## A small cream name tag (the popup's section labels). width 0 = fit the text.
func steam_tag(parent: Control, text: String, at: Vector2, width: float) -> void:
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", PixelUI.frame(PixelUI.MENU % "button_cream_normal", Vector4i(15, 15, 15, 18), Vector4(15, 4, 15, 8)))
	tag.custom_minimum_size = Vector2(width, 0)
	tag.position = at
	tag.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(tag)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PixelUI.font(700))
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("#5A3414"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(l)


func build_nav() -> void:
	# Placed on the bare wall above the pitcher, clear of the fridge
	# (COLD MILK), the steam wand and every drop zone.
	to_toppings = small_button("Toppings  >", Vector2(0, 44))
	to_toppings.icon = load(PixelUI.HUD % "icon_jar")
	for state in ["normal", "hover", "pressed"]:  # slimmer padding than the theme: it fits between the wand and the fridge
		to_toppings.add_theme_stylebox_override(state, PixelUI.frame(PixelUI.MENU % ("button_wood_" + state), Vector4i(15, 15, 15, 18), Vector4(10, 8, 12, 11)))
	to_toppings.add_theme_font_size_override("font_size", 17)
	to_toppings.resized.connect(func(): to_toppings.position = TOPPINGS_AT - Vector2(to_toppings.size.x, 0))  # right-aligned: its width follows the font
	to_toppings.pressed.connect(func(): go_page(1))
	add_child(to_toppings)
	to_espresso = small_button("Espresso", Vector2(0, 46))
	var arrow := (load(PixelUI.HUD % "icon_arrow") as Texture2D).get_image()
	arrow.flip_x()  # the HUD's right chevron, pointing back
	to_espresso.icon = ImageTexture.create_from_image(arrow)
	to_espresso.add_theme_constant_override("h_separation", 10)
	for state in ["normal", "hover", "pressed"]:  # dark wood sign, same padding as Toppings
		to_espresso.add_theme_stylebox_override(state, PixelUI.frame(PixelUI.MENU % ("button_wood_" + state), Vector4i(15, 15, 15, 18), Vector4(14, 8, 18, 11)))
	to_espresso.add_theme_font_size_override("font_size", 20)
	to_espresso.add_theme_color_override("font_color", Color("#F3E6CC"))
	to_espresso.position = Vector2(10, 416)  # under the left ledge props, above the containers
	to_espresso.pressed.connect(func(): go_page(0))
	to_espresso.hide()
	add_child(to_espresso)
	undo_button = small_button("Undo", Vector2(110, 40))  # topping page: on the counter under the containers
	undo_button.tooltip_text = "Take back the last syrup pump or topping"
	for state in ["normal", "hover", "pressed", "disabled"]:  # the same wood sign; greyed out when there's nothing to undo
		undo_button.add_theme_stylebox_override(state, PixelUI.frame(PixelUI.MENU % ("button_wood_" + state), Vector4i(15, 15, 15, 18), Vector4(14, 6, 14, 9)))
	undo_button.add_theme_font_size_override("font_size", 18)
	undo_button.add_theme_color_override("font_color", Color("#F3E6CC"))
	undo_button.position = Vector2(40, 624)  # below the topping containers (they end at y 620), above the counter edge
	undo_button.pressed.connect(undo_extra)
	undo_button.hide()
	add_child(undo_button)
	changed.connect(refresh_undo)


func bubble(font_size := 26) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_stylebox_override("normal", PixelUI.wood_pill())  # dark wood readout, like the HUD
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
	if tooltip:
		tooltip.hide()
		milk_hover.hide()
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
			settle_look(c)
		elif p == 0 and c.spot.begins_with("slot"):
			var taken: Cup = cup_at(c.back_spot) if c.back_spot != "counter" else null
			c.spot = c.back_spot if taken == null else "counter"
			c.sprite.position = c.back_pos
			settle_look(c)
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
	sound_loops(at_fork)
	if guide_box:
		update_guide()
	hover_t += delta
	for k in 2:  # steamed milk: wisps drift up from the pitcher and fade
		var w := milk_status.get_node_or_null("Wisp%d" % k) as ColorRect
		if w:
			var phase := fmod(hover_t * 0.8 + k * 0.5, 1.0)
			w.position.y = -2.0 - phase * 10.0
			w.modulate.a = 1.0 - phase
	grounds_stream.visible = grinding
	if grinding:
		if at_fork == null:
			once("Put a portafilter under the grinder first. Coffee is going everywhere!")
		elif at_fork.state == PfState.USED:
			once("There are used grounds in the basket. Knock them out first.")
		else:
			var near: bool = at_fork.dose_g >= float(recipe.get("dose_g", 18.0)) - GRIND_SLOW_FROM_G
			at_fork.dose_g += (dispense_g_per_s if near else grind_fast_g_per_s) * delta
			at_fork.grind = grind
			at_fork.state = PfState.DOSED  # fresh grounds on top undo any tamping
			update_pf(at_fork)
	grinder_screen.text = "%.1fg" % (at_fork.dose_g if at_fork else 0.0)
	if page == 0 and not recipe.is_empty() and at_fork:
		show_bubble(dose_bubble, GRINDER_AT + Vector2(100, 120), "%.1f g / %d g" % [at_fork.dose_g, recipe.dose_g],
			at_fork.dose_g, recipe.dose_g)
	else:
		dose_bubble.hide()

	for g in groups:
		var c := cup_at("tray%d" % g.index)
		if g.state == ShotState.EXTRACTING:
			var step := delta * shot_speed(g, c)
			g.sim_time += step
			set_stream(g, c)
			if c:
				c.yield_g += g.flow * step
				update_cup_visual(c)
			if g.sim_time * g.flow >= MAX_YIELD_G:
				toggle_brew(g.index)
		g.knob_lit.visible = g.state == ShotState.EXTRACTING
		g.knob_lit.modulate.a = 0.8 + 0.2 * sin(hover_t * 6.0)
		var bar_on: bool = page == 0 and not recipe.is_empty() and c != null and (g.state == ShotState.EXTRACTING or c.yield_g > 0.0)
		g.bar.visible = bar_on
		if bar_on:
			var w := SHOT_BAR.size.x
			g.green.position.x = (recipe.target_yield_g - green_zone_g) / MAX_YIELD_G * w
			g.green.size.x = 2.0 * green_zone_g / MAX_YIELD_G * w
			g.marker.position.x = clampf(c.yield_g / MAX_YIELD_G * w, 0.0, w - 2.0)
			show_bubble(g.bubble, Vector2(cup_stand(g.index).x, 306), "%.1f g · %d s" % [c.yield_g, int(g.sim_time)],
				c.yield_g, recipe.target_yield_g, true)
		else:
			g.bubble.hide()

	if steam_state == SteamState.STEAMING:
		milk_temp = minf(milk_temp + steam_rate * delta, 90.0)
		milk_foam = minf(milk_foam + AERATE_PER_S * (1.0 - pitcher_depth) * delta, 1.0)
	if steam_state != SteamState.CLOSED:
		update_steam_ui()


## Simulated seconds per real second for a running shot: the run-up (until SHOT_SLOW_FROM_G short
## of the target) is paced to last SHOT_RUNUP_S real seconds, never slower than sim_speed; from there
## through the "good" zone (target + 2.5 × green zone) it runs at sim_speed, as before; past that
## (the stop was missed) it runs fast again to the end.
func shot_speed(g: Group, c: Cup) -> float:
	var target := float(recipe.get("target_yield_g", 36.0))
	var slow_from := maxf(target - SHOT_SLOW_FROM_G, 0.0)
	var fast := maxf(sim_speed, slow_from / maxf(g.flow, 0.01) / SHOT_RUNUP_S)
	var poured := c.yield_g if c else g.sim_time * g.flow
	return sim_speed if poured >= slow_from and poured <= target + green_zone_g * 2.5 else fast


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
				"ice": c.ice, "shot": "double" if g.dose_g >= DOUBLE_SHOT_G else "single", "green_g": green_zone_g}
			c.drink.shot_rating = rate_shot(c.yield_g, EspressoModel.pace_s(recipe, g.grind, g.tamped))  # same pace the score uses
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
## Looping sounds follow the station state: grinder running onto a portafilter, a shot
## pouring, the steam wand on. All stop when the station is hidden.
func sound_loops(at_fork: Portafilter) -> void:
	var on := is_visible_in_tree()
	var pouring := false
	for g in groups:
		pouring = pouring or g.state == ShotState.EXTRACTING
	Sfx.loop("grind", on and grinding)
	Sfx.loop("pour", on and pouring, -8.0)
	Sfx.loop("steam", on and steam_state == SteamState.STEAMING, -6.0)


## Rates a finished shot the way the mentor will score it: the weight against the green
## zone, and `time_s` (how long the shot takes to reach the recipe yield, i.e. the grind)
## against the recipe window. Green weight + good timing = Perfect; green weight with
## the wrong grind is only Good, and says why.
func rate_shot(yield_g: float, time_s: float) -> String:
	var off := yield_g - float(recipe.target_yield_g)
	var t_min: float = recipe.extraction_time_min_s
	var t_max: float = recipe.extraction_time_max_s
	var timing := ""  # what was wrong with the timing (2+ s outside the window), if anything
	if time_s < t_min - 2.0:
		timing = "the shot ran fast (%d s, aim for %d–%d s). Grind finer next time." % [roundi(time_s), t_min, t_max]
	elif time_s > t_max + 2.0:
		timing = "the shot ran slow (%d s, aim for %d–%d s). Grind coarser next time." % [roundi(time_s), t_min, t_max]
	if absf(off) <= green_zone_g:
		Sfx.buzz(40)  # stopped in the green: a small "got it" on phones
		if timing == "":
			say("Perfect! Right weight, right timing.")
			Sfx.play("perfect", 0.0)
			return "Perfect"
		say("Right weight, but " + timing)
		Sfx.play("good", 0.0)
		return "Good"
	var late := off > 0.0
	if absf(off) <= green_zone_g * 2.5:
		say(("Good shot, a little %s." % ("long" if late else "short")) + ("" if timing == "" else " Also, " + timing))
		Sfx.play("good", 0.0)
		return "Good"
	say("Over-extracted: stopped too late, the shot will taste burnt." if late
		else "Under-extracted: stopped too early, the shot will taste sour.")
	Sfx.play("fail", 0.0)
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
			Sfx.play("thud")
			update_pf(p)
			say("Tamped! Nice and level.")
			changed.emit())
		t.tween_property(tamper, "position", TAMPER_REST, 0.2)


func open_steam() -> void:
	to_toppings.hide()
	steam_state = SteamState.OPEN
	pitcher_depth = 0.0
	var t := temp_range()  # exact targets only where the order already gives them (no spoilers)
	var f := foam_range()
	steam_legend.text = "Froth %d-%d%%   Temp %d-%d°C" % [roundi(f.x * 100.0), roundi(f.y * 100.0), roundi(t.x), roundi(t.y)] if guide_on and guide_strong else ""
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
	return_pitcher()
	var t := temp_range()
	var f := foam_range()
	var hits := int(milk_temp >= t.x and milk_temp <= t.y) + int(milk_foam >= f.x and milk_foam <= f.y)
	var quality: String = ["Bad", "Good", "Perfect"][hits]
	if milk_temp >= STEAMED_MIN_C:
		set_milk(MilkState.STEAMED)
		say("Steamed milk ready! %s milk: %d°C, %s." % [quality, roundi(milk_temp), foam_words(milk_foam, f)])
		float_text("Steamed milk ready!")
	else:  # not hot enough to count as steamed (the tag shows COLD or WARM)
		set_milk(MilkState.COLD)
		say(("The milk is still cold (%d°C)." if milk_temp < COLD_MAX_C else "The milk is only warm (%d°C), not steamed yet.") % roundi(milk_temp)
			+ " Hold on the pitcher longer to steam it.")
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
	var t := temp_range()
	temp_meter.show_value(milk_temp / 90.0, t.x / 90.0, t.y / 90.0)  # the thermometer reads 0-90 °C
	temp_label.text = "%d°C" % roundi(milk_temp)
	var c := Color("#36251D")
	if milk_temp >= t.x and milk_temp <= t.y:
		c = Color("#3E9E3E")
	elif milk_temp > t.y:
		c = Color("#C8463C")
	temp_label.add_theme_color_override("font_color", c)
	var f := foam_range()
	froth_meter.show_value(milk_foam, f.x, f.y)
	steam_pitcher.position = Vector2(4, 200.0 - pitcher_depth * 110.0)
	var steaming := steam_state == SteamState.STEAMING
	var now := Time.get_ticks_msec() / 1000.0
	for i in steam_puffs.size():  # visual only: clouds rise from the rim and fade
		var k := fmod(now * 0.9 + i / 3.0, 1.0)
		var puff := steam_puffs[i]
		puff.visible = steaming
		puff.position = Vector2(snappedf(56.0 + [-30.0, 26.0, -6.0][i] + sin(now * 3.0 + i) * 6.0, 3.0), snappedf(steam_pitcher.position.y - 6.0 - k * 60.0, 3.0))
		puff.modulate.a = 1.0 - k
	steam_milk.set_milk(true, milk_temp, milk_foam)  # warms and froths as you steam


## Pours whatever is in the pitcher: the drink keeps the real temperature and foam (the
## score judges them against the recipe). Only steamed milk into a ceramic cup gets latte
## art; cold or merely warm milk is poured flat, as its tag said.
func pour_milk(c: Cup) -> void:
	c.drink.milk_temp = milk_temp
	c.drink.milk_foam = milk_foam
	var heat := milk_heat()
	var poured_temp := roundi(milk_temp)
	Sfx.play("pump", 0.05, -2.0)
	set_milk(MilkState.EMPTY)
	milk_temp = 5.0
	milk_foam = 0.0
	pitcher.texture = tex("pitcher")
	return_pitcher()
	update_cup_visual(c)
	if heat == "steamed" and c.kind == "cup":  # steamed milk into a ceramic cup: latte art time
		art_cup = c
		art_panel.start()
		return
	match heat:
		"cold":
			say("Poured cold milk over the coffee.")
		"warm":
			say("Poured warm milk (%d°C). It was never steamed, so it went in flat." % poured_temp)
		_:
			say("Poured the steamed milk.")
	changed.emit()


## The latte art round ended (poured, skipped or timed out: LatteArtPanel.result). A skip or
## timeout keeps the lowest score and is noted in the drink (art_result), so the cup shows no
## pattern and the mentor doesn't call it lopsided.
func on_art_finished(score: float) -> void:
	var skipped := art_panel.result  # "" = poured
	if art_cup and art_cup in cups:
		art_cup.drink.art = score
		if skipped != "":
			art_cup.drink.art_result = skipped
		update_cup_visual(art_cup)
	if skipped == "skipped":
		say("Latte art skipped.")
	elif skipped == "timeout":
		say("Time's up! Latte art skipped.")
		Sfx.play("fail", 0.0)
	else:
		say("Beautiful rosetta!" if score >= 0.8 else "Nice pattern, a little lopsided." if score >= 0.5 else "The milk spread unevenly...")
		Sfx.play("perfect" if score >= 0.8 else "good" if score >= 0.5 else "fail", 0.0)
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
	Sfx.play("ice")
	changed.emit()


# ---------- input ----------

func local(screen_pos: Vector2) -> Vector2:
	return (screen_pos - world.position) / SCALE


func hit(s: Sprite2D, p: Vector2) -> bool:
	return s != null and Rect2(s.position, s.texture.get_size()).grow(2).has_point(p)


## A drag or a held grinder must always end on mouse-up, even when the pointer is over a
## button (Grind -/+, Toppings): buttons would otherwise swallow the release and leave the
## item stuck to the pointer or the grinder running.
func _input(event: InputEvent) -> void:
	if (dragging or grinding) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed and is_visible_in_tree():
		release()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or steam_panel.visible or art_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := local(event.position)
		if event.pressed:
			press(p)
		else:
			release()
	elif event is InputEventMouseMotion:
		if dragging:
			dragging.position = local(event.position) + drag_offset
		update_hover(event.position)


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
	for i in 2:  # the brew buttons (knobs above the group heads): start/stop that group's shot
		if "knob%d" % i in under:
			Sfx.buzz(20)  # a button press you can feel
			toggle_brew(i)
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
	for i in SYRUPS.size():
		if syrup_rect(i).has_point(p):
			add_syrup(SYRUPS[i])
			return
	for i in TOPPINGS.size():
		if topping_rect(i).has_point(p):
			add_topping(TOPPINGS[i])
			return


## Syrups and toppings go into the cup touched last, or the first cup on a slot.
func topping_cup() -> Cup:
	var c := extras_cup()
	if c == null:
		say("Bring a drink with espresso in it first. It goes on a mat in the middle.")
	return c


## The cup syrups, toppings and Undo act on (see topping_cup), or null; says nothing.
func extras_cup() -> Cup:
	if active_cup and active_cup.spot.begins_with("slot") and not active_cup.drink.is_empty():
		return active_cup
	for c in cups:
		if c.spot.begins_with("slot") and not c.drink.is_empty():
			return c
	return null


func add_syrup(s: String) -> void:
	var c := topping_cup()
	if c == null:
		return
	c.drink.syrups[s] = int(c.drink.syrups.get(s, 0)) + 1
	c.extras_log.append(["syrup", s])
	var want := int(recipe.get("syrups", {}).get(s, 0))
	if guide_on and c.drink.syrups[s] > want:  # one too many: point at Undo (guided orders only, so no spoilers; one panel line)
		say(("Too many pumps of %s. Tap Undo." if want > 0 else "No %s in this recipe. Tap Undo.") % s.replace("_", " "))
	else:
		say("1 pump of %s (%d total)." % [s.replace("_", " "), c.drink.syrups[s]])
	Sfx.play("pump", 0.1)
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
	c.extras_log.append(["topping", t])
	if guide_on and not t in recipe.get("toppings", []):  # wrong topping: point at Undo (guided orders only)
		say("No %s in this recipe. Tap Undo." % t.replace("_", " "))
	Sfx.play("shake", 0.1)
	update_cup_visual(c)
	changed.emit()


## The Undo button: takes back the last syrup pump or topping added to the current cup
## (newest first, one pump at a time). Only that cup's own additions, never below zero.
func undo_extra() -> void:
	var c := extras_cup()
	while c and not c.extras_log.is_empty():
		var last: Array = c.extras_log.pop_back()
		var item: String = last[1]
		var label := item.replace("_", " ")
		if last[0] == "syrup" and int(c.drink.syrups.get(item, 0)) > 0:
			c.drink.syrups[item] = int(c.drink.syrups[item]) - 1
			if c.drink.syrups[item] == 0:
				c.drink.syrups.erase(item)  # as if it was never added
			say("Took back 1 pump of %s (%d left)." % [label, int(c.drink.syrups.get(item, 0))])
		elif last[0] == "topping" and item in c.drink.toppings:
			c.drink.toppings.erase(item)
			say("Took the %s off." % label)
		else:
			continue  # no longer in the drink: nothing to take back for this entry
		update_cup_visual(c)
		changed.emit()
		return


func refresh_undo() -> void:
	var c := extras_cup()
	undo_button.visible = page == 1
	undo_button.disabled = c == null or c.extras_log.is_empty()


## A new empty cup centred on `at`.
func new_cup(kind: String, at: Vector2) -> Cup:
	var c := Cup.new()
	c.kind = kind
	c.sprite = sprite(CUPS[kind].tex, Vector2.ZERO)
	c.sprite.position = at - c.sprite.texture.get_size() / 2
	c.sprite.z_index = 2
	var inside: Rect2 = CUPS[kind].inside
	c.liquid = CupLiquid.new(c.sprite.texture, inside, kind == "cup")  # the ceramic cup shows its top
	c.sprite.add_child(c.liquid)
	c.ice_layer = Node2D.new()
	c.sprite.add_child(c.ice_layer)
	c.garnish = Node2D.new()
	c.sprite.add_child(c.garnish)
	var anchor: Vector2 = CUPS[kind].anchor
	var w: float = CUPS[kind].base_w
	c.shadow = rect(Color(0, 0, 0, 0.28), anchor + Vector2(-w / 2.0, -1), Vector2(w, 2), c.sprite)
	c.shadow.show_behind_parent = true
	c.shadow.hide()
	c.spot = "counter"
	cups.append(c)
	active_cup = c
	return c


## Puts a cup on a zone's snap point (tray or slot).
## Puts a cup on a zone's snap point. On a scale pad the cup's own anchor (base centre)
## goes on the pad, so every cup type stands on it, centred under the spouts, drawn
## behind the locked portafilter, with a small contact shadow. On a topping slot the
## cup is centred.
func put_cup(c: Cup, spot: String) -> void:
	c.spot = spot
	Sfx.play("clink", 0.1, -4.0)
	var offset: Vector2 = CUPS[c.kind].anchor if spot.begins_with("tray") else c.sprite.texture.get_size() / 2
	settle_look(c)
	create_tween().tween_property(c.sprite, "position", snap(spot) - offset, 0.1)


## Draw order + shadow for where a cup is: on a scale pad it sits behind the locked
## portafilter (z 1 < 2) with its contact shadow; anywhere else it is drawn above things.
func settle_look(c: Cup) -> void:
	var on_tray := c.spot.begins_with("tray")
	c.sprite.z_index = 1 if on_tray else 2
	c.shadow.visible = on_tray


func start_drag(s: Sprite2D, p: Vector2) -> void:
	if s == pitcher and pitcher_tween:
		pitcher_tween.kill()
	dragging = s
	drag_offset = s.position - p
	drag_start = s.position
	s.z_index = 3
	for pf in pfs:
		if pf.sprite == s:
			pf.shadow.hide()  # lifted off the mat
	var held := cup_of(s)
	if held:
		held.shadow.hide()


func release() -> void:
	if tooltip:
		tooltip.hide()
		milk_hover.hide()
	if grinding:
		grinding = false
		changed.emit()
	if dragging == null:
		return
	var s := dragging
	dragging = null
	var c := cup_of(s)
	var p := pf_of(s)
	s.z_index = 2 if c else (1 if s == pitcher else (2 if p and p.spot.begins_with("group") else 0))
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
			Sfx.play("knock")
		place_pf(p, "mat" if pf_at("mat") == null else p.spot)
		return
	for spot in PF_SPOTS:
		if spot in under and pf_at(spot) == null:
			place_pf(p, spot)
			return
	place_pf(p, p.spot)


func place_pf(p: Portafilter, spot: String) -> void:
	p.spot = spot
	p.sprite.z_index = 2 if spot.begins_with("group") else 0  # locked: drawn over the cup below it
	p.shadow.visible = spot == "mat"
	Sfx.play("clink", 0.05, -10.0)
	create_tween().tween_property(p.sprite, "position", snap(spot) - PF_BASKET, 0.12)
	update_pf(p)


## A cup dropped back on the rack or the plastic cup stack goes back there. If it held a drink
## (or ice) that is poured away first: the cup and everything in it belong to that one drink
## (Cup.drink, yield, ice, liquid, latte art), so removing it resets exactly that drink and
## nothing else. Nothing is served or scored; the rack gives out a fresh, empty cup.
func discard_cup(c: Cup) -> void:
	var had_drink := not c.drink.is_empty() or c.ice
	remove_cup(c)
	if had_drink:
		Sfx.play("clink", 0.1, -4.0)
		say("Drink discarded. Cup ready to reuse.")


## `at` = cup centre.
func drop_cup(c: Cup, at: Vector2) -> void:
	var under := zones_at(at)
	if ("serve" if page == 0 else "serve2") in under:
		if c.drink.is_empty():
			say("The cup is empty.")
		else:
			var d := c.drink.duplicate(true)
			remove_cup(c)
			Sfx.play("serve")
			served.emit(d)
			return
	if page == 1:
		var slot := c.spot if c.spot.begins_with("slot") else "slot%d" % maxi(free_slot(), 0)
		put_cup(c, slot)
		return
	if "ice" in under:
		add_ice(c)
		c.sprite.position = drag_start
		settle_look(c)  # back where it was (maybe on a scale pad)
		return
	for i in 2:
		var tray := "tray%d" % i
		if tray in under:
			var there := cup_at(tray)
			if there == null or there == c:  # free, or put back on its own scale
				put_cup(c, tray)
			else:
				say("There's already a cup on that scale.")
				c.sprite.position = drag_start
				settle_look(c)
			return
	if "rack" in under or "iced_stack" in under:
		discard_cup(c)
	else:
		c.sprite.position.y = clampf(c.sprite.position.y, 110.0, 310.0)
		c.spot = "counter"


## `at` = pitcher centre.
func drop_pitcher(at: Vector2) -> void:
	var under := zones_at(at)
	if "fridge" in under:
		if milk_heat() == "cold":
			say("The pitcher is already full of cold milk.")
		else:  # empty, or old warm / steamed milk poured away (as before): fresh cold milk
			say("Poured away the old milk and refilled with cold milk." if milk_state != MilkState.EMPTY
				else "Cold milk added! Steam it at the wand, or pour it cold for iced drinks.")
			milk_temp = 5.0
			milk_foam = 0.0
			set_milk(MilkState.COLD)
			float_text("Cold milk added!")
			Sfx.play("clink", 0.05, -6.0)
	elif "steam" in under:
		if milk_state == MilkState.EMPTY:
			say("The pitcher is empty. Fill it at the COLD MILK fridge first.")
		else:
			pitcher.position = snap("steam") - pitcher.texture.get_size() / 2
			open_steam()
			return
	else:
		for c in cups:
			if hit(c.sprite, at):
				if milk_state == MilkState.EMPTY:
					say("The pitcher is empty. Fill it at the COLD MILK fridge first.")
				elif c.drink.is_empty():
					say("Pull the espresso into the cup before adding milk.")
				else:
					pour_milk(c)
					return
				break
	return_pitcher()


# ---------- visuals and feedback ----------

## Heights (px of the cup's inside) of coffee (x) and milk (y) for a shot of `yield_g`,
## with or without milk. Used for the cups here and the customer's order bubble.
static func drink_levels(kind: String, yield_g: float, milk: bool) -> Vector2:
	var inside: Rect2 = CUPS[kind].inside
	var coffee_h := clampf(yield_g / CUP_FULL_G, 0.0, 1.0) * inside.size.y
	if kind == "iced":
		coffee_h *= 0.6  # a tall cup: the shot only fills the bottom
	var milk_h := 0.0
	if milk:
		milk_h = inside.size.y * (0.75 if kind == "iced" else 1.0) - coffee_h * 0.4
		coffee_h *= 0.4
	return Vector2(coffee_h, milk_h)


func update_cup_visual(c: Cup) -> void:
	var inside: Rect2 = CUPS[c.kind].inside
	var levels := drink_levels(c.kind, c.yield_g, c.drink.get("milk_temp", -1.0) >= 0.0)
	var coffee_h := levels.x
	var milk_h := levels.y
	c.liquid.set_drink(coffee_h, milk_h, c.drink)
	for n in c.ice_layer.get_children():
		n.queue_free()
	if c.ice:  # a few cubes, the top one floating at the drink's surface
		var top_y := minf(inside.end.y - coffee_h - milk_h - 3.0, inside.end.y - 33.0)
		for k in 4:
			rect(Color("#D8F1FA", 0.85), Vector2(inside.position.x + 2 + (k % 2) * 9, roundf(top_y) + k * 8), Vector2(7, 6), c.ice_layer)
	for n in c.garnish.get_children():
		n.queue_free()
	var top := Vector2(inside.position.x + inside.size.x / 2, inside.position.y)
	if c.kind == "cup" and c.drink.has("art") and not c.drink.has("art_result"):  # latte-art heart once poured, off-centre if poured badly (none if skipped)
		var off := Vector2((1.0 - c.drink.art) * 8.0, 0)
		var heart := Color("#B97F52") if c.drink.get("milk_foam", 0.0) >= CupLiquid.CAPPUCCINO_FOAM else CupLiquid.FOAM  # brown on a foam cap, white on latte
		for px in [Vector2(-2, 1), Vector2(1, 1), Vector2(-3, 2), Vector2(-1, 2), Vector2(0, 2), Vector2(2, 2), Vector2(-2, 3), Vector2(-1, 3), Vector2(0, 3), Vector2(1, 3), Vector2(-1, 4), Vector2(0, 4)]:
			rect(heart, top + px + off, Vector2(1, 1), c.garnish)
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


## The portafilter furthest along (tamped > dosed > empty > used), preferring one that is
## already where its next step happens: empty or dosed in the grinder fork, dosed on the
## mat, tamped in a group head. (An empty one parked in a group head is not progress.)
func hint_pf() -> Portafilter:
	var best: Portafilter = null
	var best_rank := -1
	for p in pfs:
		var placed := (p.state in [PfState.EMPTY, PfState.DOSED] and p.spot == "fork") \
			or (p.state == PfState.DOSED and p.spot == "mat") \
			or (p.state == PfState.TAMPED and p.spot.begins_with("group"))
		var rank: int = [1, 2, 3, 0][p.state] * 2 + int(placed)
		if rank > best_rank:
			best = p
			best_rank = rank
	return best


## The guide's step list for the current recipe (recipe-specific steps only when needed).
func objective_steps() -> Array[String]:
	var steps: Array[String] = ["grind", "tamp", "lock", "cup", "brew"]
	var iced: bool = recipe.get("ice", false)
	if iced:
		steps.append("ice")
	if recipe.has("milk"):
		steps.append("fill")
		if not iced:
			steps.append("steam")
		steps.append("pour")
		if not iced and recipe.get("cup", "glass") == "cup":  # hot milk into a ceramic cup
			steps.append("art")
	if not recipe.get("syrups", {}).is_empty() or not recipe.get("toppings", []).is_empty():
		steps.append("extras")
	steps.append("serve")
	return steps


## What the player should do next, worked out from the live station state (so it only
## moves on after a real, successful action). Keys: id (step), step, total, title,
## text (one short line for the objective panel, no exact measurements: the "hints"
## assist level), full (the same step spelled out with the recipe's target values: the
## "full" assist level), hint (more detail for the Hint button), target (equipment to
## highlight: see guide_rect; "" = none).
func objective() -> Dictionary:
	var want_cup: String = recipe.get("cup", "glass")
	var cup_name: String = CUPS[want_cup].label
	var cup_place: String = "the stack by the machine" if want_cup == "iced" else \
		"the %s of the rack" % ("left" if want_cup == "cup" else "right")
	var t_min: int = int(recipe.get("extraction_time_min_s", 0))
	var t_max: int = int(recipe.get("extraction_time_max_s", 0))
	var o := {}
	for g in groups:
		if g.state == ShotState.EXTRACTING:
			o = obj("brew", "Pull the shot", "Tap the brew button again when the marker is in the green zone.",
				"Watch the bar under the cup. Stop at about %d g: too early tastes sour, too late tastes burnt." % recipe.target_yield_g,
				"knob%d" % g.index,
				"Tap the brew button again at about %d g, in the green zone (%d–%d s)." % [recipe.target_yield_g, t_min, t_max])
	if art_panel.visible:
		o = obj("art", "Create latte art", "Tap when the pitcher is over the middle of the cup.",
			"Watch the pitcher swing above the cup and tap as it passes the middle mark. The closer to the middle, the better the pattern.", "",
			"Tap once as the swinging pitcher passes the middle mark: the closer, the better.")
	var c := hint_cup()
	if not o.is_empty():
		pass
	elif c == null or c.drink.is_empty():
		var p := hint_pf()
		if p.state == PfState.USED:
			o = obj("grind", "Empty the portafilter", "Drag the used portafilter onto the black knock box.",
				"The knock box is the small black box right of the tamping mat. Drop the portafilter on it to knock out the old coffee puck.", "knock",
				"The grounds are used: drop the portafilter on the black knock box to empty it.")
		elif p.dose_g < recipe.dose_g - 1.0:
			if p.spot != "fork":
				o = obj("grind", "Grind the coffee", "Drag a portafilter under the grinder spout.",
					"The grinder is on the far left. Drag a portafilter (one waits on the black mat) under its spout until it snaps in.", "fork",
					"Drag a portafilter from the black mat under the grinder spout, then grind %d g into it." % recipe.dose_g)
			else:
				var text := "Hold the grinder to fill the portafilter to the recipe dose."
				var full := "Press and hold the grinder until the scale shows %d g, then let go." % recipe.dose_g
				if grind != int(recipe.grind_ideal):  # say the grind first: it decides the shot's timing
					text = "Check the grind setting, then hold the grinder to fill the portafilter."
					full = "Set the grind to %d with − / +, then press and hold the grinder until the scale shows %d g." % [recipe.grind_ideal, recipe.dose_g]
				o = obj("grind", "Grind the coffee", text,
					"Press and hold the grinder body. Watch the grams bubble and let go at about %d g. Set the grind with - and + under the grinder: %d gives a %d–%d second shot (coarser runs faster, finer slower)." % [recipe.dose_g, recipe.grind_ideal, recipe.extraction_time_min_s, recipe.extraction_time_max_s], "grinder",
					full)
		elif p.state != PfState.TAMPED:
			if p.spot != "mat":
				o = obj("tamp", "Tamp the coffee", "Move the portafilter onto the black tamping mat.",
					"The tamping mat is the black rubber mat under the grinder. Drop the portafilter on it.", "mat",
					"Drag the filled portafilter onto the black tamping mat, next to the tamper.")
			else:
				o = obj("tamp", "Tamp the coffee", "Tap the tamper to press the coffee flat.",
					"The tamper stands on the mat next to the portafilter. Tap it once to press the grounds flat and even.", "tamper",
					"Tap the tamper once to press the grounds flat, so the water flows evenly.")
		else:
			var g := group_of(p)
			if g == null:
				var free := 0 if pf_at("group0") == null else 1
				o = obj("lock", "Attach the portafilter", "Place the portafilter beneath the espresso machine.",
					"Move the prepared portafilter beneath one of the two group heads (the round heads in the middle of the machine) until it snaps into position.",
					"group%d" % free,
					"Drag the tamped portafilter under the %s group head until it snaps in." % ["left", "right"][free])
			elif c == null:
				var where := "plastic cups stand left of the machine" if want_cup == "iced" else \
					"%s are on the %s of the rack on top of the machine" % ["latte cups" if want_cup == "cup" else "glasses", "left" if want_cup == "cup" else "right"]
				o = obj("cup", "Get a cup", "Take a %s and put it under the portafilter." % cup_name,
					"The %s. Drag one onto the scale under the portafilter you locked in." % where,
					"iced_stack" if want_cup == "iced" else ("rack_cups" if want_cup == "cup" else "rack_glasses"),
					"Take a %s from %s and put it on the %s scale." % [cup_name, cup_place, ["left", "right"][g.index]])
			elif c.spot != "tray%d" % g.index:
				var full := "Put the %s on the %s scale, under your portafilter." % [CUPS[c.kind].label, ["left", "right"][g.index]]
				if c.kind != want_cup:  # not blocked, but the recipe check will mark it down
					full = "Put the %s on the %s scale. This drink needs a %s." % [CUPS[c.kind].label, ["left", "right"][g.index], cup_name]
				o = obj("cup", "Get a cup", "Put the %s on the scale under the portafilter." % CUPS[c.kind].label,
					"Drag the cup onto the steel scale under the group head where your portafilter is.", "tray%d" % g.index,
					full)
			else:
				o = obj("brew", "Pull the shot", "Tap the brew button above the portafilter to start.",
					"Tap the round brew button above your portafilter (tapping the portafilter works too). A bar appears under the cup: tap again when the marker is in the green zone.", "knob%d" % g.index,
					"Tap the brew button to start. Stop at about %d g, in the green zone (%d–%d s)." % [recipe.target_yield_g, t_min, t_max])
	elif recipe.get("ice", false) and not c.ice:
		o = obj("ice", "Add ice", "Drop the cup on the ICE bin.",
			"The ice bin is the steel tray at the bottom of the fridge, under the COLD MILK door. Drag the cup onto it.", "ice",
			"Drag the cup onto the ICE bin under the fridge. It comes back with ice.")
	elif recipe.has("milk") and c.drink.milk_temp < 0.0:
		var iced: bool = recipe.get("ice", false)
		if milk_state == MilkState.EMPTY:
			o = obj("fill", "Fill the pitcher", "Find the COLD MILK fridge on the right side of the counter.",
				"The cold milk source is on the right side of the counter, directly above the ice station. Move your empty pitcher there.", "fridge",
				"Drag the empty pitcher onto the COLD MILK door to fill it. %s" % (
					"Iced drinks use it cold." if iced else "Then steam it to %d–%d°C." % [recipe.milk.temp_min, recipe.milk.temp_max]))
		elif iced and milk_heat() != "cold":  # warmed or steamed milk would melt the ice: start again
			o = obj("fill", "Fill the pitcher", "This milk isn't cold. Refill the pitcher at the COLD MILK fridge.",
				"Iced drinks need milk straight from the fridge. Drag the pitcher onto the COLD MILK door to pour the warm milk away and refill it.", "fridge",
				"Drag the pitcher onto the COLD MILK door: it pours the %d°C milk away and refills it cold." % roundi(milk_temp))
		elif iced or milk_state == MilkState.STEAMED:
			o = obj("pour", "Pour the milk", "Cold milk added! Pour it into the cup." if iced else "Milk is ready! Pour it into the cup.",
				"Drag the pitcher onto the cup. %s" % ("Iced drinks use cold milk, so no steaming." if iced else "Then tap over the middle of the cup for latte art."), "cup",
				"Drag the pitcher onto the cup to pour the cold milk. Iced drinks are not steamed." if iced else
				"Drag the pitcher onto the cup to pour the %d°C milk%s." % [roundi(milk_temp), ", then tap for latte art" if c.kind == "cup" else ""])
		else:
			var full := "Drag the pitcher under the steam wand, hold to heat it to %d–%d°C, then press Done." % [recipe.milk.temp_min, recipe.milk.temp_max]
			if foam_range().x >= CupLiquid.CAPPUCCINO_FOAM:  # cappuccino: much more froth
				full = "Steam at the wand to %d–%d°C, holding the pitcher low for longer: lots of froth." % [recipe.milk.temp_min, recipe.milk.temp_max]
			var warm := milk_heat() == "warm"  # steamed a little, but stopped under STEAMED_MIN_C
			if warm:
				full = "The milk is only %d°C. Steam it again at the wand to %d–%d°C, then press Done." % [roundi(milk_temp), recipe.milk.temp_min, recipe.milk.temp_max]
			o = obj("steam", "Steam the milk", "The milk is only warm. Steam it more at the wand." if warm else "Cold milk added! Move the pitcher to the steam wand.",
				"Drag the pitcher under the steam wand (the metal arm right of the machine). Hold on the pitcher to steam: low adds froth, high only heats. Aim for %d–%d°C, then press Done." % [recipe.milk.temp_min, recipe.milk.temp_max], "steam",
				full)
	else:
		var need := []  # what is still missing, by name (hints)
		var need_full := []  # with amounts and what is left (full)
		var first := ""
		for s in recipe.get("syrups", {}):
			var have := int(c.drink.syrups.get(s, 0))
			var want := int(recipe.syrups[s])
			if have < want:
				var syrup: String = s.replace("_", " ")
				need.append(syrup)
				need_full.append("%d pump%s of %s%s" % [want, "" if want == 1 else "s", syrup, "" if have == 0 else " (%d more)" % (want - have)])
				first = "syrup:" + s if first == "" else first
		for t in recipe.get("toppings", []):
			if not t in c.drink.toppings:
				need.append(t.replace("_", " "))
				need_full.append(t.replace("_", " "))
				first = "topping:" + t if first == "" else first
		if not need.is_empty():
			o = obj("extras", "Add the extras", ("Tap 'Toppings >' and add: %s." if page == 0 else "Add: %s.") % ", ".join(need),
				"Syrups and toppings are on the topping page. Make sure the cup is on a mat there, then tap each bottle once per pump and each container once.",
				"toppings_button" if page == 0 else first,
				("Tap 'Toppings >', then add %s." if page == 0 else "One tap per pump or topping: %s.") % ", ".join(need_full))
		else:
			o = obj("serve", "Serve the drink", "Serve the completed drink to the customer.",
				"Drag the finished drink into the dashed SERVE area.", "serve" if page == 0 else "serve2",
				"The drink is complete. Drag it into the dashed SERVE box.")
	var steps := objective_steps()
	o.step = steps.find(o.id) + 1
	o.total = steps.size()
	return o


## `full` = the detailed line for the "full" assist level ("" = same as `text`).
func obj(id: String, title: String, text: String, hint: String, target: String, full := "") -> Dictionary:
	return {"id": id, "title": title, "text": text, "full": full if full != "" else text, "hint": hint, "target": target}


## Kept for older callers: the detailed hint for the current objective.
func next_hint() -> String:
	return objective().hint


func say(text: String) -> void:
	message.emit(text)


func once(text: String) -> void:
	if warned != text:
		warned = text
		say(text)


func update_pf(p: Portafilter) -> void:
	p.sprite.texture = tex("portafilter_" + ["empty", "dosed", "tamped", "used"][p.state])


func _exit_tree() -> void:  # leaving the game (e.g. back to the title): silence the loops
	for s in ["grind", "pour", "steam"]:
		Sfx.loop(s, false)


## Slides the pitcher back to its spot; grabbing it again cancels the slide (start_drag),
## so the slide can never pull it out from under the player's finger.
func return_pitcher() -> void:
	if pitcher_tween:
		pitcher_tween.kill()
	pitcher_tween = create_tween()
	pitcher_tween.tween_property(pitcher, "position", PITCHER_HOME, 0.15)


# ---------- guide highlight ----------

## A soft pulsing outline and a small bobbing arrow on the equipment for the current
## objective (CafeShift sets guide_on per order: off for expert orders and for the parts
## of a vague order that would give the drink away; guide_strong: the arrow only on
## "full" assist orders, "hints" gets the outline alone).
func build_guide() -> void:
	guide_box = Panel.new()
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color("#FFE066")
	s.set_border_width_all(2)
	guide_box.add_theme_stylebox_override("panel", s)
	guide_box.mouse_filter = MOUSE_FILTER_IGNORE
	guide_box.z_index = 4
	world.add_child(guide_box)
	guide_arrow = Polygon2D.new()
	guide_arrow.polygon = PackedVector2Array([Vector2(-6, -9), Vector2(6, -9), Vector2(0, 0)])
	guide_arrow.color = Color("#FFE066")
	guide_arrow.z_index = 4
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(-6, -9), Vector2(6, -9), Vector2(0, 0), Vector2(-6, -9)])
	outline.width = 1.0
	outline.default_color = Color("#36251D")
	guide_arrow.add_child(outline)
	world.add_child(guide_arrow)
	guide_box.hide()
	guide_arrow.hide()


## Called whenever the station changes: picks the highlight target from objective().
func refresh_guide() -> void:
	guide_target = objective().target if guide_on and not recipe.is_empty() else ""


func zone_rect(zone_name: String) -> Rect2:
	var z: SnapZone = zones[zone_name]
	return Rect2(z.position, ((z.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size)


## World rect (base px) of a guide target, or an empty rect when it isn't on screen.
func guide_rect(t: String) -> Rect2:
	match t:
		"fridge":
			return MILK_SOURCE
		"fork":  # where the basket goes: centred under the spout, rim to the bottom of the basket
			var basket_top: Vector2 = PF_SPOTS.fork + PF_RIM
			return Rect2(basket_top + Vector2(-PF_BASKET_HALF_W, -2),
				Vector2(PF_BASKET_HALF_W * 2.0, pf_bounds.end.y - PF_RIM.y + 2))
		"grinder":  # the press area, trimmed to the drawn grinder body (centred on it)
			return zone_rect("grinder").intersection(grinder_bounds)
		"knock":  # the drawn box (its drop zone is 10 px more forgiving all round)
			return Rect2(KNOCK_AT, tex("knock_box").get_size())
	if t in zones:
		return zone_rect(t)
	match t:
		"tamper":
			return Rect2(tamper.position, tamper.texture.get_size())
		"rack_cups":
			return Rect2(RACK_AT, Vector2(100, 70))
		"rack_glasses":
			return Rect2(RACK_AT + Vector2(100, 0), Vector2(100, 70))
		"iced_stack":
			return Rect2(ICED_STACK_AT, Vector2(34, 70))
		"cup":
			var c := hint_cup()
			return Rect2(c.sprite.position, c.sprite.texture.get_size()) if c else Rect2()
		"toppings_button":
			return Rect2((to_toppings.position - world.position) / SCALE, to_toppings.size / SCALE)
	if t.begins_with("syrup:"):
		var i := SYRUPS.find(t.trim_prefix("syrup:"))
		return syrup_rect(i)
	if t.begins_with("topping:"):
		var i := TOPPINGS.find(t.trim_prefix("topping:"))
		return topping_rect(i)
	return Rect2()


## Follows moving targets (cups, the tamper) and pulses gently; hidden while dragging the
## highlighted thing or when a popup is open.
func update_guide() -> void:
	var r := guide_rect(guide_target) if guide_target != "" else Rect2()
	var on := r.size != Vector2.ZERO and not steam_panel.visible and not art_panel.visible
	guide_box.visible = on
	guide_arrow.visible = on and guide_strong
	if not on:
		return
	var pulse := 0.55 + 0.45 * sin(hover_t * 4.0)
	guide_box.position = r.position - Vector2.ONE * GUIDE_PAD
	guide_box.size = r.size + Vector2.ONE * GUIDE_PAD * 2.0
	guide_box.modulate.a = pulse
	guide_arrow.position = Vector2(r.get_center().x, r.position.y - GUIDE_PAD - 1 - absf(sin(hover_t * 3.0)) * 4.0)


## The shot falls from the portafilter's spouts into the cup's opening (a little past the
## rim, so it disappears inside), or down to the scale pad when there is no cup.
func set_stream(g: Group, c: Cup) -> void:
	var end_y := cup_stand(g.index).y
	if c:
		end_y = c.sprite.position.y + float(CUPS[c.kind].rim_y) + 4.0
	g.stream.size.y = maxf(end_y - g.stream.position.y, 2.0)


## A pixel-art gauge for the steam popup (drawn, 3 screen px per art px): a rounded tube with
## tick marks, the target band (pale green, darker edge lines, a green bracket beside the tube that
## stays visible when the fill covers the band), the fill (turns green inside the band) and a
## pointer at the level. `bulb` = thermometer bulb at the bottom. Visual only.
class Meter extends Control:
	const U := 3.0
	const TRACK := Rect2(18, 9, 24, 288)  # the inside of the tube
	const OUTLINE := Color("#3A2416")
	const GREEN := Color("#4E9A3A")
	var bulb := false
	var value := 0.0
	var lo := 0.0
	var hi := 1.0
	var fill := Color.RED
	var fill_hi := Color.RED
	var fill_lo := Color.RED

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(60, 345)
		size = custom_minimum_size

	func colors(base: Color, light: Color, dark: Color) -> void:
		fill = base
		fill_hi = light
		fill_lo = dark

	func show_value(v: float, low: float, high: float) -> void:
		v = clampf(v, 0.0, 1.0)
		if v != value or low != lo or high != hi:
			value = v
			lo = low
			hi = high
			queue_redraw()

	## Rounded box: two overlapping rects leave each corner pixel open.
	func box(r: Rect2, c: Color) -> void:
		draw_rect(Rect2(r.position.x + U, r.position.y, r.size.x - 2.0 * U, r.size.y), c)
		draw_rect(Rect2(r.position.x, r.position.y + U, r.size.x, r.size.y - 2.0 * U), c)

	func level_y(v: float) -> float:
		return snappedf(TRACK.end.y - clampf(v, 0.0, 1.0) * TRACK.size.y, U)

	## Pixel disc by rows (the thermometer bulb).
	func disc(centre: Vector2, r: float, c: Color) -> void:
		var y := -r
		while y < r:
			var half := snappedf(sqrt(maxf(r * r - (y + U / 2.0) * (y + U / 2.0), 0.0)), U)
			draw_rect(Rect2(centre.x - half, centre.y + y, half * 2.0, U), c)
			y += U

	func _draw() -> void:
		var inside := value >= lo and value <= hi
		var base := Color("#7CC95A") if inside else fill
		var light := Color("#B5E78F") if inside else fill_hi
		var dark := GREEN if inside else fill_lo
		var bulb_c := Vector2(TRACK.get_center().x, TRACK.end.y + 24.0)
		# tube and bulb outline, then the glass
		box(TRACK.grow(2.0 * U), OUTLINE)
		if bulb:
			disc(bulb_c, 24.0, OUTLINE)
		box(TRACK.grow(U), Color("#FBF4EA"))
		draw_rect(TRACK, Color("#FFFFFF"))
		draw_rect(Rect2(TRACK.position, Vector2(U, TRACK.size.y)), Color("#EADCC3"))  # inner shadow
		for i in range(1, 10):  # a tick every 10 %
			draw_rect(Rect2(TRACK.end.x - 2.0 * U, level_y(i / 10.0), (3.0 if i == 5 else 2.0) * U - U, U), Color("#D9C7A8"))
		# target band
		var top := level_y(hi)
		var bottom := level_y(lo)
		draw_rect(Rect2(TRACK.position.x, top, TRACK.size.x, bottom - top), Color("#D7F2BF"))
		# fill
		var fy := level_y(value)
		if bulb:
			disc(bulb_c, 18.0, base)
			disc(bulb_c + Vector2(-6, -6), 6.0, light)
		if fy < TRACK.end.y or bulb:
			var col := Rect2(TRACK.position.x + U, fy, TRACK.size.x - 2.0 * U, TRACK.end.y - fy + (U * 4.0 if bulb else 0.0))
			draw_rect(col, base)
			draw_rect(Rect2(col.position.x, col.position.y, U, col.size.y), light)  # shine
			draw_rect(Rect2(col.end.x - U, col.position.y, U, col.size.y), dark)
			draw_rect(Rect2(col.position.x, fy, col.size.x, U), light)  # surface
		# band edges over everything, and the bracket outside the tube
		for y in [top, bottom - U]:
			draw_rect(Rect2(TRACK.position.x, y, TRACK.size.x, U), GREEN)
		var bx := TRACK.position.x - 5.0 * U
		draw_rect(Rect2(bx, top, U, bottom - top), GREEN)
		draw_rect(Rect2(bx, top, 2.0 * U, U), GREEN)
		draw_rect(Rect2(bx, bottom - U, 2.0 * U, U), GREEN)
		# pointer at the level, right of the tube
		var tip := TRACK.end.x + 2.0 * U + U
		var widths := [U, 2.0 * U, 3.0 * U, 2.0 * U, U]
		for i in widths.size():
			var w: float = widths[i]
			draw_rect(Rect2(tip + 3.0 * U - w, fy - 2.0 * U + i * U, w, U), OUTLINE)
