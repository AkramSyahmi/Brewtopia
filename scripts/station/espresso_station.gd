class_name EspressoStation
extends Control
## Front-view 2D bar in pixel art (Good Coffee, Great Coffee style), two pages:
##  1. Espresso: grinder, tamper, 2-group machine, cup rack, milk pitcher, steam wand, fridge.
##  2. Toppings: syrup pumps and topping containers.
## Drag the portafilter grinder -> mat -> group head, tap the tamper, take a glass or a
## latte cup from the rack, tap the group head to pull the shot (timing bar with a green
## zone), fill the pitcher at the fridge, steam it under the wand (thermometer), pour it
## into the cup, add syrups/toppings, then drag the drink into the SERVE area.
## Nothing forces an order; mistakes show in the score. World = 640x360 base px drawn x2;
## sprites come from res://assets/art/ (see ART_LIST.md).

signal served(drink: Dictionary)
signal changed
signal message(text: String)

const ART := "res://assets/art/%s.png"
const SCALE := 2
const PAGE_W := 640.0
const MAX_YIELD_G := 70.0
const CUP_FULL_G := 40.0
const COFFEE := Color("#4A2A18")
const MILK := Color("#F3E6D2")

# Espresso page (sprite top-left, base px). Must match the art in ART_LIST.md.
const GRINDER_AT := Vector2(12, 70)
const BAG_AT := Vector2(104, 182)
const MAT_AT := Vector2(8, 292)
const KNOCK_AT := Vector2(150, 306)
const MACHINE_AT := Vector2(205, 46)
const RACK_AT := Vector2(255, 14)
const PITCHERS_AT := Vector2(512, 60)
const FRIDGE_AT := Vector2(570, 116)
const TAMPER_REST := Vector2(108, 262)
const PITCHER_HOME := Vector2(492, 250)
const STEAM_ZONE := Rect2(430, 170, 80, 90)  # under the steam wand
const SERVE_RECT := Rect2(452, 296, 108, 58)
const PF_SPOTS := {
	"fork": Vector2(26, 196),  # under the grinder spout
	"mat": Vector2(40, 270),  # on the tamping mat
	"group": Vector2(238, 196),  # locked into the left group head
}
const PF_BASKET := Vector2(46, 14)  # basket centre inside the portafilter sprite
const TRAY_CENTRE := Vector2(276, 280)  # where a cup sits on the left drip-tray scale
const DIAL_AT := Vector2(8, 252)  # grind -/+ buttons under the grinder
const SHOT_BAR := Rect2(232, 330, 90, 8)  # timing bar under the left scale
const PARK_CENTRE := Vector2(410, 296)  # where a cup waits when it comes back from toppings

# Topping page (base px, page origin at x = 640)
const SYRUPS := ["vanilla", "caramel", "chocolate", "pandan", "gula_melaka"]
const TOPPINGS := ["cream", "choc_chips", "cinnamon"]
const SYRUP_AT := Vector2(130, 30)  # first bottle; bottles every 80 px
const TOPPING_AT := Vector2(40, 250)  # first container; every 80 px
const SLOT_CENTRE := Vector2(320, 270)  # cup slot on the topping page
const SERVE2_RECT := Rect2(470, 250, 120, 80)

## Cup kinds: sprite and the rectangle inside it where the drink shows.
const CUPS := {
	"glass": {"tex": "cup_espresso", "inside": Rect2(6, 8, 24, 24), "label": "glass"},
	"cup": {"tex": "cup_latte", "inside": Rect2(11, 3, 30, 7), "label": "latte cup"},
}

var recipe: Dictionary
var dispense_g_per_s := 4.0
var sim_speed := 2.0
var green_zone_g := 2.0  # +/- grams of the green zone (Shot Timer upgrade widens it)
var steam_rate := 12.0  # degrees C per second while steaming (Steam Control slows it)

# Portafilter
var grind := 8
var dose_g := 0.0
var shot_grind := 8
var tamped := false
var used := false
var pf_spot := "mat"

# Cup (one in play)
var cup: Sprite2D
var cup_kind := ""
var cup_spot := ""
var cup_yield := 0.0
var drink := {}  # filled once a shot lands in the cup; milk/syrups/toppings added later
var coffee_fill: ColorRect
var milk_fill: ColorRect
var garnish: Node2D

# Milk
var pitcher: Sprite2D
var pitcher_milk := false
var milk_temp := 5.0
var steaming := false

var grinding := false
var extracting := false
var sim_time := 0.0
var flow := 0.0
var page := 0

var dragging: Sprite2D
var drag_offset := Vector2.ZERO
var warned := ""

var world: Node2D
var pf: Sprite2D
var tamper: Sprite2D
var grounds_stream: ColorRect
var shot_stream: ColorRect
var shot_bar: Control
var shot_marker: ColorRect
var shot_green: ColorRect
var grind_box: Control
var grind_label: Label
var dose_bubble: Label
var cup_bubble: Label
var steam_panel: PanelContainer
var thermo_fill: ColorRect
var thermo_green: ColorRect
var temp_label: Label
var to_toppings: Button
var to_espresso: Button
var add_ins: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.modulate = CounterScreen.EVENING  # same warm evening light as the counter
	add_child(world)
	build_espresso_page()
	build_topping_page()
	build_shot_bar()
	build_grind_buttons()
	build_steam_panel()
	build_nav()
	dose_bubble = bubble()
	cup_bubble = bubble()
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


func build_espresso_page() -> void:
	sprite("station_bg", Vector2.ZERO)
	sprite("grinder", GRINDER_AT)
	sprite("bean_bag", BAG_AT)
	sprite("tamp_mat", MAT_AT)
	sprite("knock_box", KNOCK_AT)
	sprite("machine", MACHINE_AT)
	sprite("cups_rack", RACK_AT)
	sprite("pitcher_rack", PITCHERS_AT)
	sprite("milk_fridge", FRIDGE_AT)
	dashed(SERVE_RECT, Color("#C9A27E"))
	world_label("SERVE", SERVE_RECT.position + Vector2(38, 44), 10, Color("#C9A27E"))
	grounds_stream = rect(COFFEE, Vector2(60, 186), Vector2(2, 18))
	grounds_stream.hide()
	shot_stream = rect(COFFEE, Vector2(285, 216), Vector2(2, 50))
	shot_stream.hide()
	pf = sprite("portafilter_empty", PF_SPOTS.mat)
	tamper = sprite("tamper", TAMPER_REST)
	tamper.z_index = 1
	pitcher = sprite("pitcher", PITCHER_HOME)
	pitcher.z_index = 1


func build_topping_page() -> void:
	sprite("topping_bg", Vector2(PAGE_W, 0))
	for i in SYRUPS.size():
		sprite("syrup_" + SYRUPS[i], Vector2(PAGE_W, 0) + SYRUP_AT + Vector2(i * 80, 0))
		world_label(SYRUPS[i].replace("_", " ").capitalize(), Vector2(PAGE_W, 0) + SYRUP_AT + Vector2(i * 80 - 6, 112),
			8, Color("#F5E7CA"))
	for i in TOPPINGS.size():
		sprite("topping_" + TOPPINGS[i], Vector2(PAGE_W, 0) + TOPPING_AT + Vector2(i * 80, 0))
		world_label(TOPPINGS[i].replace("_", " ").capitalize(), Vector2(PAGE_W, 0) + TOPPING_AT + Vector2(i * 80, 54),
			8, Color("#F5E7CA"))
	dashed(Rect2(SERVE2_RECT.position + Vector2(PAGE_W, 0), SERVE2_RECT.size), Color("#C9A27E"))
	world_label("SERVE", SERVE2_RECT.position + Vector2(PAGE_W + 44, 60), 10, Color("#C9A27E"))
	add_ins = world_label("", Vector2(PAGE_W + 250, 190), 9, Color("#F5E7CA"))


## GCGC-style timing bar: the marker shows the yield, stop it in the green zone.
func build_shot_bar() -> void:
	shot_bar = Control.new()
	shot_bar.position = SHOT_BAR.position
	shot_bar.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(shot_bar)
	rect(Color("#36251D"), Vector2(-1, -1), SHOT_BAR.size + Vector2(2, 2), shot_bar)
	rect(Color("#9BA39E"), Vector2.ZERO, SHOT_BAR.size, shot_bar)
	shot_green = rect(Color("#6BD46B"), Vector2.ZERO, Vector2(8, SHOT_BAR.size.y), shot_bar)
	shot_marker = rect(Color("#FFFFFF"), Vector2(0, -2), Vector2(2, SHOT_BAR.size.y + 4), shot_bar)
	shot_bar.hide()


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
	grind_label.add_theme_color_override("font_color", Color("#F5E7CA"))
	grind_label.custom_minimum_size = Vector2(70, 34)
	grind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(grind_label)
	var plus := small_button("+", Vector2(34, 34))
	plus.pressed.connect(func(): set_grind(grind + 1))
	box.add_child(plus)


## GCGC-style steaming popup: a thermometer with a green zone; hold to steam.
func build_steam_panel() -> void:
	steam_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#F5ECE2")
	s.border_color = Color("#65422F")
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(18)
	steam_panel.add_theme_stylebox_override("panel", s)
	steam_panel.position = Vector2(760, 120)
	steam_panel.z_index = 10  # above the world sprites (pitcher, cups)
	steam_panel.custom_minimum_size = Vector2(440, 420)
	add_child(steam_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	steam_panel.add_child(row)
	var thermo := Control.new()
	thermo.custom_minimum_size = Vector2(70, 380)
	row.add_child(thermo)
	rect(Color("#65422F"), Vector2(20, 0), Vector2(34, 330), thermo)
	rect(Color("#FFFFFF"), Vector2(24, 4), Vector2(26, 322), thermo)
	thermo_green = rect(Color("#6BD46B"), Vector2(24, 0), Vector2(26, 10), thermo)
	thermo_fill = rect(Color("#D9534F"), Vector2(30, 300), Vector2(14, 20), thermo)
	var bulb := rect(Color("#D9534F"), Vector2(14, 326), Vector2(46, 46), thermo)
	bulb.color = Color("#D9534F")
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
	help.text = "Hold the button. Let go when\nthe red line is in the green zone."
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("#65422F"))
	col.add_child(help)
	var hold := small_button("Hold to steam", Vector2(240, 80))
	hold.button_down.connect(func(): steaming = true)
	hold.button_up.connect(func():
		steaming = false
		changed.emit())
	col.add_child(hold)
	var done := small_button("Done", Vector2(240, 60))
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


func bubble() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 26)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#36251D", 0.92)
	s.border_color = Color("#BE895B")
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	l.add_theme_stylebox_override("normal", s)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.hide()
	add_child(l)
	return l


## Shows grams against the target near a base-pixel point; green when close, red when over.
func show_bubble(l: Label, at: Vector2, grams: float, target: float, extra := "") -> void:
	l.text = "%.1f g / %d g%s" % [grams, int(target), extra]
	var c := Color("#F5E7CA")
	if absf(grams - target) <= 0.5:
		c = Color("#9FE08A")
	elif grams > target + 1.0:
		c = Color("#FF8A7A")
	l.add_theme_color_override("font_color", c)
	l.reset_size()
	l.position = (at + world.position / SCALE) * SCALE
	l.show()


# ---------- order lifecycle ----------

func start_order(new_recipe: Dictionary) -> void:
	recipe = new_recipe
	clear_cup()
	go_page(0, false)
	changed.emit()


func clear_cup() -> void:
	if cup:
		cup.queue_free()
	cup = null
	cup_kind = ""
	cup_spot = ""
	cup_yield = 0.0
	drink = {}
	shot_bar.hide()


func set_grind(value: int) -> void:
	grind = clampi(value, 1, 10)
	grind_label.text = "Grind %d" % grind
	changed.emit()


func go_page(p: int, animate := true) -> void:
	page = p
	to_toppings.visible = p == 0
	to_espresso.visible = p == 1
	grind_box.visible = p == 0
	if cup and dragging != cup:
		var target := SLOT_CENTRE + Vector2(PAGE_W, 0) if p == 1 else PARK_CENTRE
		cup.position = target - cup.texture.get_size() / 2
		cup_spot = "slot" if p == 1 else "counter"
	var x := -PAGE_W * SCALE * p
	if animate:
		create_tween().tween_property(world, "position:x", x, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		world.position.x = x
	changed.emit()


# ---------- per-frame ----------

func _process(delta: float) -> void:
	grounds_stream.visible = grinding
	if grinding:
		if pf_spot != "fork" or dragging == pf:
			once("Put the portafilter under the grinder first. Coffee is going everywhere!")
		elif used:
			once("There are used grounds in the basket. Knock them out first.")
		else:
			dose_g += dispense_g_per_s * delta
			shot_grind = grind
			tamped = false
			update_pf()
	if page == 0 and recipe and (grinding or (pf_spot == "fork" and dragging != pf)):
		show_bubble(dose_bubble, GRINDER_AT + Vector2(100, 120), dose_g, recipe.dose_g)
	else:
		dose_bubble.hide()

	if extracting:
		var step := delta * sim_speed
		sim_time += step
		if cup and cup_spot == "tray":
			cup_yield += flow * step
			update_cup_visual()
		if sim_time * flow >= MAX_YIELD_G:
			toggle_brew()
	if page == 0 and recipe and cup and cup_spot == "tray" and (extracting or cup_yield > 0.0):
		show_bubble(cup_bubble, Vector2(330, 236), cup_yield, recipe.target_yield_g, "  ·  %d s" % int(sim_time))
		shot_bar.show()
		var w := SHOT_BAR.size.x
		shot_green.position.x = (recipe.target_yield_g - green_zone_g) / MAX_YIELD_G * w
		shot_green.size.x = 2.0 * green_zone_g / MAX_YIELD_G * w
		shot_marker.position.x = clampf(cup_yield / MAX_YIELD_G * w, 0.0, w - 2.0)
	else:
		cup_bubble.hide()
		if not extracting:
			shot_bar.hide()

	if steaming:
		milk_temp = minf(milk_temp + steam_rate * delta, 90.0)
	if steam_panel.visible:
		update_thermometer()


# ---------- machine and milk ----------

func toggle_brew() -> void:
	if extracting:
		extracting = false
		shot_stream.hide()
		used = true
		update_pf()
		if cup_yield > 0.0:
			drink = {"dose": dose_g, "grind": shot_grind, "tamped": tamped, "yield": cup_yield,
				"time": sim_time, "cup": cup_kind, "milk_temp": -1.0, "syrups": {}, "toppings": []}
		else:
			say("The shot went down the drain. Put a cup under the group head before brewing.")
		changed.emit()
		return
	if pf_spot != "group":
		say("Lock the portafilter into the group head first.")
	elif used:
		say("Those grounds are already used. Knock them out and grind fresh coffee.")
	elif dose_g < 0.5:
		say("The portafilter is empty. Grind some coffee first.")
	elif not drink.is_empty():
		say("That cup already has coffee in it.")
	else:
		flow = EspressoModel.flow_rate(recipe, dose_g, shot_grind, tamped)
		extracting = true
		sim_time = 0.0
		shot_stream.show()
		if cup == null or cup_spot != "tray":
			say("No cup under the machine! The coffee is going down the drain.")
		changed.emit()


func tamp() -> void:
	if pf_spot != "mat":
		say("Put the portafilter on the tamping mat first.")
	elif used:
		say("Those grounds are used. Knock them out first.")
	elif dose_g < 0.5:
		say("There's nothing to tamp yet.")
	else:
		var press_at := pf.position + PF_BASKET - Vector2(20, 52)
		var t := create_tween()
		t.tween_property(tamper, "position", press_at, 0.12)
		t.tween_property(tamper, "position", press_at + Vector2(0, 5), 0.12)
		t.tween_callback(func():
			tamped = true
			update_pf()
			say("Tamped! Nice and level.")
			changed.emit())
		t.tween_property(tamper, "position", TAMPER_REST, 0.2)


func open_steam() -> void:
	to_toppings.hide()
	steam_panel.show()
	update_thermometer()


func close_steam() -> void:
	to_toppings.visible = page == 0
	steaming = false
	steam_panel.hide()
	create_tween().tween_property(pitcher, "position", PITCHER_HOME, 0.15)
	say("Milk steamed to %d°C." % roundi(milk_temp))
	changed.emit()


func update_thermometer() -> void:
	var h := 322.0
	var to_y := func(t: float) -> float: return 4.0 + h * (1.0 - clampf(t / 90.0, 0.0, 1.0))
	var lo: float = recipe.milk.temp_min if recipe.has("milk") else 60.0
	var hi: float = recipe.milk.temp_max if recipe.has("milk") else 65.0
	thermo_green.position.y = to_y.call(hi)
	thermo_green.size.y = to_y.call(lo) - to_y.call(hi)
	thermo_fill.position.y = to_y.call(milk_temp)
	thermo_fill.size.y = 330.0 - thermo_fill.position.y
	temp_label.text = "%d°C" % roundi(milk_temp)
	var c := Color("#36251D")
	if milk_temp >= lo and milk_temp <= hi:
		c = Color("#3E9E3E")
	elif milk_temp > hi:
		c = Color("#C8463C")
	temp_label.add_theme_color_override("font_color", c)


func pour_milk() -> void:
	drink.milk_temp = milk_temp
	pitcher_milk = false
	milk_temp = 5.0
	pitcher.texture = tex("pitcher")
	create_tween().tween_property(pitcher, "position", PITCHER_HOME, 0.15)
	update_cup_visual()
	say("Poured the milk. Latte art: a little heart!")
	changed.emit()


# ---------- input ----------

func local(screen_pos: Vector2) -> Vector2:
	return (screen_pos - world.position) / SCALE


func hit(s: Sprite2D, p: Vector2) -> bool:
	return s != null and Rect2(s.position, s.texture.get_size()).grow(2).has_point(p)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or steam_panel.visible:
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
	if page == 1:
		press_toppings(p)
		return
	if hit(cup, p):
		if extracting and cup_spot == "tray":
			say("Wait for the shot to finish.")
		else:
			start_drag(cup, p)
	elif hit(pitcher, p):
		start_drag(pitcher, p)
	elif hit(pf, p):
		if extracting:
			say("Wait for the shot to finish.")
		else:
			start_drag(pf, p)
	elif hit(tamper, p):
		tamp()
	elif Rect2(RACK_AT, Vector2(200, 70)).has_point(p):
		if cup:
			say("You already have a cup out.")
		else:
			var kind := "cup" if p.x < RACK_AT.x + 100 else "glass"
			new_cup(kind, p)
			start_drag(cup, p)
	elif Rect2(MACHINE_AT + Vector2(60, 150), Vector2(80, 60)).has_point(p):
		toggle_brew()  # tap the left group head
	elif Rect2(GRINDER_AT + Vector2(10, 60), Vector2(76, 120)).has_point(p):
		grinding = true
		warned = ""


func press_toppings(p: Vector2) -> void:
	if hit(cup, p):
		start_drag(cup, p)
		return
	var base := Vector2(PAGE_W, 0)
	for i in SYRUPS.size():
		if Rect2(base + SYRUP_AT + Vector2(i * 80, 0), Vector2(44, 96)).has_point(p):
			add_syrup(SYRUPS[i])
			return
	for i in TOPPINGS.size():
		if Rect2(base + TOPPING_AT + Vector2(i * 80, 0), Vector2(70, 50)).has_point(p):
			add_topping(TOPPINGS[i])
			return


func add_syrup(s: String) -> void:
	if drink.is_empty() or cup_spot != "slot":
		say("Bring a drink with espresso in it first. It goes on the mat in the middle.")
		return
	drink.syrups[s] = int(drink.syrups.get(s, 0)) + 1
	say("1 pump of %s (%d total)." % [s.replace("_", " "), drink.syrups[s]])
	update_cup_visual()
	changed.emit()


func add_topping(t: String) -> void:
	if drink.is_empty() or cup_spot != "slot":
		say("Bring a drink with espresso in it first. It goes on the mat in the middle.")
		return
	if t in drink.toppings:
		say("It already has %s." % t.replace("_", " "))
		return
	drink.toppings.append(t)
	update_cup_visual()
	changed.emit()


func new_cup(kind: String, p: Vector2) -> void:
	cup_kind = kind
	cup = sprite(CUPS[kind].tex, p - Vector2(18, 18))
	cup.z_index = 2
	var inside: Rect2 = CUPS[kind].inside
	coffee_fill = rect(COFFEE, Vector2(inside.position.x, inside.end.y), Vector2(inside.size.x, 0), cup)
	milk_fill = rect(MILK, inside.position, Vector2(inside.size.x, 0), cup)
	garnish = Node2D.new()
	cup.add_child(garnish)
	cup_yield = 0.0
	drink = {}


func start_drag(s: Sprite2D, p: Vector2) -> void:
	dragging = s
	drag_offset = s.position - p
	s.z_index = 3
	if s == cup:
		cup_spot = ""


func release() -> void:
	if grinding:
		grinding = false
		changed.emit()
	if dragging == null:
		return
	var s := dragging
	dragging = null
	s.z_index = 2 if s == cup else (1 if s == pitcher else 0)
	if s == pf:
		drop_pf(pf.position + PF_BASKET)
	elif s == cup:
		drop_cup(cup.position + cup.texture.get_size() / 2)
	elif s == pitcher:
		drop_pitcher(pitcher.position + pitcher.texture.get_size() / 2)
	changed.emit()


func drop_pf(c: Vector2) -> void:
	if Rect2(KNOCK_AT, Vector2(56, 44)).grow(10).has_point(c):
		if dose_g > 0.0 or used:
			dose_g = 0.0
			tamped = false
			used = false
			say("Knocked out the old grounds.")
		place_pf("mat")
		return
	for spot in ["fork", "group", "mat"]:
		if c.distance_to(PF_SPOTS[spot] + PF_BASKET) < 34:
			place_pf(spot)
			return
	place_pf(pf_spot)


func place_pf(spot: String) -> void:
	pf_spot = spot
	create_tween().tween_property(pf, "position", PF_SPOTS[spot], 0.12)
	update_pf()


func drop_cup(c: Vector2) -> void:
	var serve_rect := SERVE_RECT if page == 0 else Rect2(SERVE2_RECT.position + Vector2(PAGE_W, 0), SERVE2_RECT.size)
	if serve_rect.grow(6).has_point(c):
		if drink.is_empty():
			say("The cup is empty.")
		else:
			cup_spot = "serve"
			served.emit(drink.duplicate(true))
			return
	if page == 1:
		cup.position = SLOT_CENTRE + Vector2(PAGE_W, 0) - cup.texture.get_size() / 2
		cup_spot = "slot"
	elif c.distance_to(TRAY_CENTRE) < 32:
		create_tween().tween_property(cup, "position", TRAY_CENTRE - cup.texture.get_size() / 2, 0.1)
		cup_spot = "tray"
	elif Rect2(RACK_AT, Vector2(200, 70)).has_point(c) and drink.is_empty():
		clear_cup()
	else:
		cup.position.y = clampf(cup.position.y, 110.0, 310.0)
		cup_spot = "counter"


func drop_pitcher(c: Vector2) -> void:
	if Rect2(FRIDGE_AT, Vector2(70, 240)).has_point(c):
		pitcher_milk = true
		milk_temp = 5.0
		pitcher.texture = tex("pitcher")
		say("Filled the pitcher with cold milk.")
	elif STEAM_ZONE.has_point(c):
		if not pitcher_milk:
			say("The pitcher is empty. Fill it with milk from the fridge first.")
		else:
			pitcher.position = STEAM_ZONE.get_center() - pitcher.texture.get_size() / 2
			open_steam()
			return
	elif hit(cup, c):
		if not pitcher_milk:
			say("The pitcher is empty.")
		elif drink.is_empty():
			say("Pull the espresso into the cup before adding milk.")
		else:
			pour_milk()
			return
	create_tween().tween_property(pitcher, "position", PITCHER_HOME, 0.15)


# ---------- visuals and feedback ----------

func update_cup_visual() -> void:
	if cup == null:
		return
	var inside: Rect2 = CUPS[cup_kind].inside
	var coffee_h := clampf(cup_yield / CUP_FULL_G, 0.0, 1.0) * inside.size.y
	var milk_h := 0.0
	if drink.get("milk_temp", -1.0) >= 0.0:
		milk_h = inside.size.y - coffee_h * 0.4
		coffee_h *= 0.4
	coffee_fill.position.y = inside.end.y - coffee_h
	coffee_fill.size.y = coffee_h
	milk_fill.position.y = inside.end.y - coffee_h - milk_h
	milk_fill.size.y = milk_h
	for c in garnish.get_children():
		c.queue_free()
	var top := Vector2(inside.position.x + inside.size.x / 2, inside.position.y)
	if milk_h > 0.0:  # tiny latte-art heart
		for px in [Vector2(-2, 1), Vector2(1, 1), Vector2(-3, 2), Vector2(-1, 2), Vector2(0, 2), Vector2(2, 2), Vector2(-2, 3), Vector2(-1, 3), Vector2(0, 3), Vector2(1, 3), Vector2(-1, 4), Vector2(0, 4)]:
			rect(Color("#B97F52"), top + px, Vector2(1, 1), garnish)
	var colors := {"cream": Color("#FFFFFF"), "choc_chips": Color("#3A1E10"), "cinnamon": Color("#A0623A")}
	for i in drink.get("toppings", []).size():
		var t: String = drink.toppings[i]
		for k in 4:
			rect(colors[t], top + Vector2(-6 + k * 4, -2 - i * 2), Vector2(2, 2), garnish)
	var lines := []
	for s in drink.get("syrups", {}):
		lines.append("%s x%d" % [s.replace("_", " "), drink.syrups[s]])
	for t in drink.get("toppings", []):
		lines.append(t.replace("_", " "))
	add_ins.text = "\n".join(lines)


func next_hint() -> String:
	var wants_milk := recipe.has("milk")
	var want_cup: String = recipe.get("cup", "glass")
	if extracting:
		return "Watch the bar under the cup. Tap the group head again when the marker is in the green zone (about %d g)." % recipe.target_yield_g
	if drink.is_empty():
		if used:
			return "Drag the portafilter to the black knock box to empty the old grounds."
		if dose_g < recipe.dose_g - 1.0:
			if pf_spot != "fork":
				return "Drag the portafilter under the grinder."
			return "Set the grind with - and +, then press and hold the grinder until the scale shows about %d g." % recipe.dose_g
		if not tamped:
			if pf_spot != "mat":
				return "Move the portafilter onto the black tamping mat."
			return "Tap the tamper to press the coffee flat."
		if pf_spot != "group":
			return "Drag the portafilter up into the left group head."
		if cup == null or cup_spot != "tray":
			return "Take a %s from the rack on top of the machine (%s side) and put it under the left group head." % [
				CUPS[want_cup].label, "left" if want_cup == "cup" else "right"]
		return "Tap the group head to start the shot."
	if wants_milk and drink.milk_temp < 0.0:
		if not pitcher_milk:
			return "Drag the milk pitcher onto the fridge to fill it with milk."
		if milk_temp < recipe.milk.temp_min:
			return "Drag the pitcher under the steam wand and steam it to %d–%d°C." % [recipe.milk.temp_min, recipe.milk.temp_max]
		return "Drag the pitcher onto the cup to pour the milk."
	var need := []
	for s in recipe.get("syrups", {}):
		if int(drink.syrups.get(s, 0)) < int(recipe.syrups[s]):
			need.append("%d pumps of %s" % [recipe.syrups[s], s.replace("_", " ")])
	for t in recipe.get("toppings", []):
		if not t in drink.toppings:
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


func update_pf() -> void:
	pf.texture = tex("portafilter_" + ("used" if used else "tamped" if tamped else "dosed" if dose_g > 0.5 else "empty"))
