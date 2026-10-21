class_name EspressoStation
extends Control
## Front-view 2D espresso station (Good Coffee, Great Coffee style) in pixel art.
## Drag the portafilter grinder -> tamping mat -> group head, tap the tamper, drag a
## glass from the rack onto the drip tray, tap the group head to pull the shot and tap
## again when the marker is in the green zone, then drag the drink to the serve area.
## Nothing forces an order; mistakes show in the shot. Same API as Bar3D.
## World is 640x360 base pixels drawn x2; sprites come from res://assets/art/ (ART_LIST.md).

signal served(shot: Dictionary)
signal changed
signal message(text: String)

const ART := "res://assets/art/%s.png"
const SCALE := 2
const MAX_YIELD_G := 70.0
const CUP_FULL_G := 40.0
const COFFEE := Color("#4A2A18")

# Where things sit (sprite top-left, base px). Must match the art in ART_LIST.md.
const GRINDER_AT := Vector2(12, 70)
const BAG_AT := Vector2(104, 182)
const MAT_AT := Vector2(8, 292)
const KNOCK_AT := Vector2(150, 306)
const MACHINE_AT := Vector2(205, 46)
const RACK_AT := Vector2(255, 14)
const PITCHERS_AT := Vector2(512, 60)
const FRIDGE_AT := Vector2(570, 116)
const TAMPER_REST := Vector2(108, 262)
const SERVE_RECT := Rect2(452, 286, 108, 66)
const PF_SPOTS := {
	"fork": Vector2(26, 196),  # under the grinder spout
	"mat": Vector2(40, 270),  # on the tamping mat
	"group": Vector2(238, 196),  # locked into the left group head
}
const PF_BASKET := Vector2(46, 14)  # basket centre inside the portafilter sprite
const TRAY_SPOT := Vector2(258, 262)  # glass on the left drip-tray scale
const GLASS_INSIDE := Rect2(5, 6, 26, 26)  # glass interior inside cup_espresso.png
const DIAL_AT := Vector2(8, 252)  # grind -/+ buttons under the grinder
const SHOT_BAR := Rect2(232, 330, 90, 8)  # timing bar under the left scale

var recipe: Dictionary
var dispense_g_per_s := 4.0
var sim_speed := 2.0

var grind := 8
var dose_g := 0.0
var shot_grind := 8
var tamped := false
var used := false
var pf_spot := "mat"

var cup: Sprite2D
var cup_fill: ColorRect
var cup_spot := ""
var cup_yield := 0.0
var cup_shot := {}

var grinding := false
var extracting := false
var sim_time := 0.0
var flow := 0.0

var dragging: Sprite2D
var drag_offset := Vector2.ZERO
var warned := ""

var world: Node2D
var grinder: Sprite2D
var pf: Sprite2D
var tamper: Sprite2D
var grounds_stream: ColorRect
var shot_stream: ColorRect
var shot_bar: Control
var shot_marker: ColorRect
var shot_green: ColorRect
var grind_label: Label
var dose_bubble: Label
var cup_bubble: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	sprite("station_bg", Vector2.ZERO)
	grinder = sprite("grinder", GRINDER_AT)
	sprite("bean_bag", BAG_AT)
	sprite("tamp_mat", MAT_AT)
	sprite("knock_box", KNOCK_AT)
	sprite("machine", MACHINE_AT)
	sprite("cups_rack", RACK_AT)
	sprite("pitcher_rack", PITCHERS_AT)
	sprite("milk_fridge", FRIDGE_AT)
	serve_area()
	grounds_stream = rect(COFFEE, Vector2(60, 186), Vector2(2, 18))
	grounds_stream.hide()
	shot_stream = rect(COFFEE, Vector2(285, 216), Vector2(2, 50))
	shot_stream.hide()
	pf = sprite("portafilter_empty", PF_SPOTS.mat)
	tamper = sprite("tamper", TAMPER_REST)
	tamper.z_index = 1
	build_shot_bar()
	build_grind_buttons()
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


func serve_area() -> void:
	var c := Color("#C9A27E")
	for x in range(int(SERVE_RECT.position.x), int(SERVE_RECT.end.x), 6):
		rect(c, Vector2(x, SERVE_RECT.position.y), Vector2(3, 1))
		rect(c, Vector2(x, SERVE_RECT.end.y), Vector2(3, 1))
	for y in range(int(SERVE_RECT.position.y), int(SERVE_RECT.end.y), 6):
		rect(c, Vector2(SERVE_RECT.position.x, y), Vector2(1, 3))
		rect(c, Vector2(SERVE_RECT.end.x, y), Vector2(1, 3))
	var l := Label.new()
	l.text = "SERVE"
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", c)
	l.position = SERVE_RECT.position + Vector2(36, 50)
	world.add_child(l)


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


func build_grind_buttons() -> void:
	var box := HBoxContainer.new()
	box.position = DIAL_AT * SCALE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(34, 34)
	minus.pressed.connect(func(): set_grind(grind - 1))
	box.add_child(minus)
	grind_label = Label.new()
	grind_label.add_theme_font_size_override("font_size", 18)
	grind_label.add_theme_color_override("font_color", Color("#36251D"))
	grind_label.custom_minimum_size = Vector2(70, 34)
	grind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(grind_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(34, 34)
	plus.pressed.connect(func(): set_grind(grind + 1))
	box.add_child(plus)


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
	l.position = at * SCALE
	l.show()


# ---------- order lifecycle (same API as Bar3D) ----------

func start_order(new_recipe: Dictionary) -> void:
	recipe = new_recipe
	clear_cup()
	changed.emit()


func clear_cup() -> void:
	if cup:
		cup.queue_free()
	cup = null
	cup_spot = ""
	cup_yield = 0.0
	cup_shot = {}
	shot_bar.hide()


func set_grind(value: int) -> void:
	grind = clampi(value, 1, 10)
	grind_label.text = "Grind %d" % grind
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
	if recipe and (grinding or (pf_spot == "fork" and dragging != pf)):
		show_bubble(dose_bubble, GRINDER_AT + Vector2(100, 120), dose_g, recipe.dose_g)
	else:
		dose_bubble.hide()

	if extracting:
		var step := delta * sim_speed
		sim_time += step
		if cup and cup_spot == "tray":
			cup_yield += flow * step
			update_cup_fill()
		if sim_time * flow >= MAX_YIELD_G:
			toggle_brew()
	if recipe and cup and cup_spot == "tray" and (extracting or cup_yield > 0.0):
		show_bubble(cup_bubble, Vector2(330, 236), cup_yield, recipe.target_yield_g,
			"  ·  %d s" % int(sim_time))
		shot_bar.show()
		var w := SHOT_BAR.size.x
		shot_green.position.x = (recipe.target_yield_g - 2.0) / MAX_YIELD_G * w
		shot_green.size.x = 4.0 / MAX_YIELD_G * w
		shot_marker.position.x = clampf(cup_yield / MAX_YIELD_G * w, 0.0, w - 2.0)
	else:
		cup_bubble.hide()


# ---------- machine ----------

func toggle_brew() -> void:
	if extracting:
		extracting = false
		shot_stream.hide()
		used = true
		update_pf()
		if cup_yield > 0.0:
			cup_shot = {"dose": dose_g, "grind": shot_grind, "tamped": tamped,
				"yield": cup_yield, "time": sim_time}
		else:
			say("The shot went down the drain. Put a glass under the group head before brewing.")
		changed.emit()
		return
	if pf_spot != "group":
		say("Lock the portafilter into the group head first.")
	elif used:
		say("Those grounds are already used. Knock them out and grind fresh coffee.")
	elif dose_g < 0.5:
		say("The portafilter is empty. Grind some coffee first.")
	elif not cup_shot.is_empty():
		say("That glass already has coffee. Serve it first.")
	else:
		flow = EspressoModel.flow_rate(recipe, dose_g, shot_grind, tamped)
		extracting = true
		sim_time = 0.0
		shot_stream.show()
		if cup == null or cup_spot != "tray":
			say("No glass under the machine! The coffee is going down the drain.")
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


# ---------- input ----------

func local(screen_pos: Vector2) -> Vector2:
	return screen_pos / SCALE


func hit(s: Sprite2D, p: Vector2) -> bool:
	return s != null and Rect2(s.position, s.texture.get_size()).grow(2).has_point(p)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
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
	if hit(cup, p):
		if extracting and cup_spot == "tray":
			say("Wait for the shot to finish.")
		else:
			start_drag(cup, p)
	elif hit(pf, p):
		if extracting:
			say("Wait for the shot to finish.")
		else:
			start_drag(pf, p)
	elif hit(tamper, p):
		tamp()
	elif Rect2(RACK_AT + Vector2(100, 0), Vector2(100, 70)).has_point(p):
		if cup:
			say("You already have a glass out.")
		else:
			cup = sprite("cup_espresso", p - Vector2(18, 18))
			cup_fill = rect(COFFEE, Vector2(GLASS_INSIDE.position.x, GLASS_INSIDE.end.y),
				Vector2(GLASS_INSIDE.size.x, 0), cup)
			cup_yield = 0.0
			cup_shot = {}
			cup.z_index = 2
			start_drag(cup, p)
	elif Rect2(MACHINE_AT + Vector2(60, 150), Vector2(80, 60)).has_point(p):
		toggle_brew()  # tap the left group head
	elif Rect2(GRINDER_AT + Vector2(10, 60), Vector2(76, 120)).has_point(p):
		grinding = true
		warned = ""


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
	s.z_index = 2 if s == cup else 0
	if s == pf:
		drop_pf(pf.position + PF_BASKET)
	elif s == cup:
		drop_cup(cup.position + cup.texture.get_size() / 2)
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
	if SERVE_RECT.has_point(c):
		if cup_shot.is_empty():
			say("The glass is empty.")
		else:
			cup_spot = "serve"
			served.emit(cup_shot.duplicate())
			return
	if c.distance_to(TRAY_SPOT + Vector2(18, 18)) < 30:
		create_tween().tween_property(cup, "position", TRAY_SPOT, 0.1)
		cup_spot = "tray"
	elif Rect2(RACK_AT, Vector2(200, 70)).has_point(c) and cup_shot.is_empty():
		clear_cup()
	else:
		cup.position.y = clampf(cup.position.y, 110.0, 320.0)
		cup_spot = "counter"


# ---------- feedback ----------

func next_hint() -> String:
	if extracting:
		return "Watch the bar under the glass. Tap the group head again when the marker is in the green zone (about %d g)." % recipe.target_yield_g
	if not cup_shot.is_empty():
		return "Drag the glass into the dashed SERVE area."
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
		return "Take a glass from the rack on top of the machine and put it under the left group head."
	return "Tap the group head to start the shot."


func say(text: String) -> void:
	message.emit(text)


func once(text: String) -> void:
	if warned != text:
		warned = text
		say(text)


func update_pf() -> void:
	pf.texture = tex("portafilter_" + ("used" if used else "tamped" if tamped else "dosed" if dose_g > 0.5 else "empty"))


func update_cup_fill() -> void:
	var h := clampf(cup_yield / CUP_FULL_G, 0.0, 1.0) * GLASS_INSIDE.size.y
	cup_fill.position.y = GLASS_INSIDE.end.y - h
	cup_fill.size.y = h
