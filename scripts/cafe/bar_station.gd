class_name BarStation
extends Node2D
## Hands-on espresso bar, barista POV (Barista Simulator style, in 2D).
## Drag the portafilter, tamper and cup between equipment; nothing forces an order,
## mistakes show up in the shot. Coordinates are 640x360 base pixels and must match
## tools/gen_art.gd bar(); the node is scaled x2 by its parent.

signal served(shot: Dictionary)  ## cup with coffee dropped on the pass
signal changed  ## bar state changed (mentor hints refresh)
signal message(text: String)  ## immediate feedback, e.g. "Lock the portafilter first."

const SPRITE_PATH := "res://assets/sprites/%s.png"
const MAX_YIELD_G := 70.0
const COFFEE := Color("#4A2A18")
const LCD_TEXT := Color("#24402A")

## Rest positions (sprite top-left).
const PF_SPOTS := {
	"fork": Vector2(129, 246),  # basket under the grinder spout
	"mat": Vector2(178, 276),  # on the tamping mat
	"group": Vector2(376, 227),  # locked into the group head
}
const PF_BASKET := Vector2(14, 8)  # basket centre inside the portafilter sprite
const TAMPER_REST := Vector2(244, 266)
const TAMPER_FOOT := Vector2(9, 26)  # bottom centre of the tamper sprite
const CUP_STACK := Vector2(514, 262)
const CUP_TRAY := Vector2(374, 258)
const CUP_PASS := Vector2(584, 260)
const CUP_INSIDE := Rect2(3, 2, 26, 18)
const DIAL_CENTER := Vector2(95, 165)

## Drop zones, tested against the dragged item's centre.
const ZONES := {
	"fork": Rect2(110, 220, 80, 60),
	"mat": Rect2(160, 255, 90, 50),
	"group": Rect2(340, 200, 110, 50),
	"knock": Rect2(4, 250, 60, 55),
	"tray": Rect2(340, 240, 110, 60),
	"pass": Rect2(556, 190, 84, 110),
	"stack": Rect2(506, 240, 48, 62),
}

var recipe: Dictionary
var dispense_g_per_s := 4.0
var sim_speed := 2.0

# Portafilter
var grind := 8
var dose_g := 0.0
var shot_grind := 8  # grind setting the grounds in the basket were made at
var tamped := false
var used := false
var pf_spot := "mat"

# Cup (one in play at a time)
var cup: Sprite2D
var cup_fill: ColorRect
var cup_spot := ""  # "tray", "counter" or "" while held
var cup_yield := 0.0
var cup_shot := {}  # set once a shot has landed in the cup

# Machine
var grinding := false
var extracting := false
var sim_time := 0.0
var flow := 0.0

# Input
var dragging: Sprite2D
var drag_offset := Vector2.ZERO
var turning_dial := false
var warned := ""

var pf: Sprite2D
var tamper: Sprite2D
var dial: Sprite2D
var dial_label: Label
var grinder_btn: TextureButton
var brew_btn: TextureButton
var grounds_stream: ColorRect
var shot_stream: Node2D
var dose_lcd: Label
var cup_lcd: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite("bar_background", Vector2.ZERO)
	grounds_stream = rect_node(self, COFFEE, Vector2(142, 226), Vector2(2, 23))
	grounds_stream.hide()
	tamper = sprite("tamper", TAMPER_REST)
	tamper.z_index = 1  # stays above the portafilter while tamping
	pf = sprite("pf_empty", PF_SPOTS.mat)
	dial = sprite("dial", DIAL_CENTER, true)
	dial_label = label(Vector2(116, 140), 10, Color("#F5E7CA"))
	grinder_btn = button("grinder_button", Vector2(83, 200))
	grinder_btn.button_down.connect(func():
		grinding = true
		warned = "")
	grinder_btn.button_up.connect(func():
		grinding = false
		changed.emit())
	brew_btn = button("brew_button", Vector2(440, 152))
	brew_btn.pressed.connect(toggle_brew)
	shot_stream = Node2D.new()
	rect_node(shot_stream, COFFEE, Vector2(385, 243), Vector2(1, 19))
	rect_node(shot_stream, COFFEE, Vector2(394, 243), Vector2(1, 19))
	shot_stream.hide()
	add_child(shot_stream)
	dose_lcd = label(Vector2(76, 274), 9, LCD_TEXT)
	cup_lcd = label(Vector2(365, 281), 8, LCD_TEXT)
	set_grind(grind)


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


func _process(delta: float) -> void:
	grounds_stream.visible = grinding
	if grinding:
		var into_basket := pf_spot == "fork" and dragging != pf
		grounds_stream.size.y = 23 if into_basket else 74
		if not into_basket:
			once("Put the portafilter under the grinder first. Coffee is going everywhere!")
		elif used:
			once("There are used grounds in the basket. Knock them out first.")
		else:
			dose_g += dispense_g_per_s * delta
			shot_grind = grind
			tamped = false
			update_pf()
	dose_lcd.text = "%.1fg" % dose_g if pf_spot == "fork" else "0.0g"

	if extracting:
		var step := delta * sim_speed
		sim_time += step
		if cup and cup_spot == "tray":
			cup_yield += flow * step
			update_cup_fill()
		cup_lcd.text = "%.1fg %02ds" % [cup_yield, int(sim_time)]
		if sim_time * flow >= MAX_YIELD_G:
			toggle_brew()


# ---------- machine ----------

func toggle_brew() -> void:
	if extracting:
		extracting = false
		shot_stream.hide()
		brew_btn.texture_normal = tex("brew_button")
		used = true
		update_pf()
		if cup_yield > 0.0:
			cup_shot = {"dose": dose_g, "grind": shot_grind, "tamped": tamped,
				"yield": cup_yield, "time": sim_time}
		else:
			say("The shot went down the drain. Put a cup on the scale before brewing.")
		changed.emit()
		return
	if pf_spot != "group":
		say("Lock the portafilter into the machine first.")
	elif used:
		say("Those grounds are already used. Knock them out and grind fresh coffee.")
	elif dose_g < 0.5:
		say("The portafilter is empty. Grind some coffee first.")
	elif not cup_shot.is_empty():
		say("That cup already has coffee. Serve it first.")
	else:
		flow = EspressoModel.flow_rate(recipe, dose_g, shot_grind, tamped)
		extracting = true
		sim_time = 0.0
		shot_stream.show()
		brew_btn.texture_normal = tex("brew_button_pressed")
		if cup == null or cup_spot != "tray":
			say("No cup under the machine! The coffee is going down the drain.")
		changed.emit()


func set_grind(value: int) -> void:
	grind = clampi(value, 1, 10)
	dial.rotation_degrees = lerpf(-135.0, 135.0, (grind - 1) / 9.0)
	dial_label.text = str(grind)


# ---------- drag and drop ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := local(event.position)
		if event.pressed:
			press(p)
		else:
			release()
	elif event is InputEventMouseMotion:
		var p := local(event.position)
		if dragging:
			dragging.position = p + drag_offset
		elif turning_dial:
			turn_dial(p)


func local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func hit(s: Sprite2D, p: Vector2) -> bool:
	return s != null and Rect2(s.position, s.texture.get_size()).grow(3).has_point(p)


func press(p: Vector2) -> void:
	if hit(cup, p):
		if extracting and cup_spot == "tray":
			say("Wait for the shot to finish.")
		else:
			start_drag(cup, p)
	elif hit(tamper, p):
		start_drag(tamper, p)
	elif hit(pf, p):
		if extracting:
			say("Wait for the shot to finish.")
		else:
			start_drag(pf, p)
	elif ZONES.stack.has_point(p):
		if cup:
			say("You already have a cup out.")
		else:
			cup = new_cup()
			start_drag(cup, p)
	elif p.distance_to(DIAL_CENTER) < 18:
		turning_dial = true
		turn_dial(p)


func start_drag(s: Sprite2D, p: Vector2) -> void:
	dragging = s
	drag_offset = s.position - p
	s.z_index = 5
	if s == cup:
		cup_spot = ""


func release() -> void:
	turning_dial = false
	if dragging == null:
		return
	var s := dragging
	dragging = null
	s.z_index = 0
	if s == pf:
		drop_pf(pf.position + PF_BASKET)
	elif s == tamper:
		drop_tamper(tamper.position + TAMPER_FOOT)
	elif s == cup:
		drop_cup(cup.position + cup.texture.get_size() / 2)
	changed.emit()


func turn_dial(p: Vector2) -> void:
	var v := p - DIAL_CENTER
	var deg := clampf(rad_to_deg(atan2(v.x, -v.y)), -135.0, 135.0)
	var value := roundi(remap(deg, -135.0, 135.0, 1.0, 10.0))
	if value != grind:
		set_grind(value)
		changed.emit()


func drop_pf(c: Vector2) -> void:
	if ZONES.knock.has_point(c):
		if dose_g > 0.0 or used:
			dose_g = 0.0
			tamped = false
			used = false
			say("Knocked out the old grounds.")
		place_pf("mat")
		return
	for spot in ["fork", "mat", "group"]:
		if ZONES[spot].has_point(c):
			place_pf(spot)
			return
	place_pf(pf_spot)  # not a valid spot: slide back


func place_pf(spot: String) -> void:
	pf_spot = spot
	create_tween().tween_property(pf, "position", PF_SPOTS[spot], 0.15)
	update_pf()


func drop_tamper(foot: Vector2) -> void:
	if foot.distance_to(pf.position + PF_BASKET) < 22:
		if pf_spot == "group":
			say("Take the portafilter out of the machine before tamping.")
		elif used:
			say("Those grounds are used. Knock them out first.")
		elif dose_g < 0.5:
			say("There's nothing to tamp yet.")
		else:
			var press_at := pf.position + PF_BASKET - TAMPER_FOOT + Vector2(0, -2)
			var t := create_tween()
			t.tween_property(tamper, "position", press_at, 0.1)
			t.tween_property(tamper, "position", press_at + Vector2(0, 4), 0.15)
			t.tween_callback(func():
				tamped = true
				update_pf()
				say("Tamped! Nice and level.")
				changed.emit())
			t.tween_property(tamper, "position", TAMPER_REST, 0.2)
			return
	create_tween().tween_property(tamper, "position", TAMPER_REST, 0.15)


func drop_cup(c: Vector2) -> void:
	if ZONES.pass.has_point(c):
		if cup_shot.is_empty():
			say("The cup is empty.")
		else:
			cup.position = CUP_PASS
			cup_spot = "pass"
			served.emit(cup_shot.duplicate())
			return
	if ZONES.tray.has_point(c):
		cup.position = CUP_TRAY
		cup_spot = "tray"
	elif ZONES.stack.has_point(c) and cup_shot.is_empty():
		clear_cup()
	else:
		cup.position.y = clampf(cup.position.y, 236.0, 278.0)  # leave it on the counter
		cup_spot = "counter"


# ---------- feedback ----------

## What a mentor would suggest next, from the current bar state.
func next_hint() -> String:
	if extracting:
		return "Watch the scale under the cup. Press the brew button again at about %d g." % recipe.target_yield_g
	if not cup_shot.is_empty():
		return "Drag the cup to the PASS on the right to serve it."
	if used:
		return "Drag the portafilter to the knock box on the left to empty the old grounds."
	if dose_g < recipe.dose_g - 1.0:
		if pf_spot != "fork":
			return "Drag the portafilter under the grinder spout."
		return "Turn the dial to set the grind, then hold the red button until the scale shows about %d g." % recipe.dose_g
	if not tamped:
		if pf_spot != "mat":
			return "Move the portafilter onto the black tamping mat."
		return "Drag the tamper onto the coffee to press it flat."
	if pf_spot != "group":
		return "Lock the portafilter into the machine's group head."
	if cup == null or cup_spot != "tray":
		return "Take a cup from the stack and put it on the scale under the machine."
	return "Press the green brew button to start the shot."


func say(text: String) -> void:
	message.emit(text)


func once(text: String) -> void:
	if warned != text:
		warned = text
		say(text)


func update_pf() -> void:
	var state := "used" if used else "tamped" if tamped else "dosed" if dose_g > 0.5 else "empty"
	pf.texture = tex("pf_" + state)


func update_cup_fill() -> void:
	var h := clampf(cup_yield / 40.0, 0.0, 1.0) * CUP_INSIDE.size.y
	cup_fill.position.y = CUP_INSIDE.end.y - h
	cup_fill.size.y = h


# ---------- building ----------

func tex(sprite_name: String) -> Texture2D:
	return load(SPRITE_PATH % sprite_name)


func sprite(sprite_name: String, pos: Vector2, centered := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(sprite_name)
	s.centered = centered
	s.position = pos
	add_child(s)
	return s


func new_cup() -> Sprite2D:
	var c := sprite("cup_mid", CUP_STACK)
	cup_fill = rect_node(c, COFFEE, Vector2(CUP_INSIDE.position.x, CUP_INSIDE.end.y),
		Vector2(CUP_INSIDE.size.x, 0))
	cup_yield = 0.0
	cup_shot = {}
	return c


func rect_node(parent: Node, color: Color, pos: Vector2, size_px: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size_px
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func button(sprite_name: String, pos: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex(sprite_name)
	b.texture_pressed = tex(sprite_name + "_pressed")
	b.position = pos
	add_child(b)
	return b


func label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
