class_name CounterScreen
extends Control
## Front counter in 2D pixel art (Good Coffee, Great Coffee style): café background,
## waist-up customer and mentor behind the counter, the served drink on the pass.
## World is 640x360 base pixels drawn x2; sprites come from res://assets/art/.

const ART := "res://assets/art/%s.png"
const SCALE := 2
const CUSTOMER_AT := Vector2(200, 96)
const MENTOR_AT := Vector2(470, 96)
const OFFSTAGE := Vector2(-150, 96)
const CUP_AT := Vector2(482, 262)  # on the green pass mat
const COFFEE := Color("#4A2A18")

var world: Node2D
var mentor: Sprite2D
var customer: Sprite2D
var customer_look := ""
var served_cup: Sprite2D
var emote_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	sprite("counter_bg", Vector2.ZERO)
	mentor = sprite("char_mentor", MENTOR_AT)
	customer = sprite("char_student", OFFSTAGE)
	customer.hide()
	sprite("counter_front", Vector2(0, 240))
	served_cup = sprite("cup_espresso", CUP_AT)
	var fill := ColorRect.new()
	fill.color = COFFEE
	fill.position = Vector2(5, 14)
	fill.size = Vector2(26, 18)
	served_cup.add_child(fill)
	served_cup.hide()
	emote_label = Label.new()
	emote_label.add_theme_font_size_override("font_size", 40)
	emote_label.add_theme_color_override("font_color", Color("#FFE066"))
	emote_label.add_theme_color_override("font_outline_color", Color("#36251D"))
	emote_label.add_theme_constant_override("outline_size", 10)
	emote_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(emote_label)


func tex(n: String) -> Texture2D:
	return load(ART % n)


func sprite(n: String, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(n)
	s.centered = false
	s.position = at
	world.add_child(s)
	return s


## Customer slides in from the left and fades in; returns the tween to await.
func customer_enter(look: String) -> Tween:
	customer_look = look
	customer.texture = tex("char_" + look)
	customer.position = OFFSTAGE
	customer.modulate.a = 0.0
	customer.show()
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(customer, "position", CUSTOMER_AT, 0.7)
	t.tween_property(customer, "modulate:a", 1.0, 0.5)
	return t


func customer_leave() -> Tween:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(customer, "position", OFFSTAGE, 0.6)
	t.tween_property(customer, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(customer.hide)
	return t


func set_happy(on: bool) -> void:
	if customer_look != "":
		customer.texture = tex("char_" + customer_look + ("_happy" if on else ""))


func set_mentor_happy(on: bool) -> void:
	mentor.texture = tex("char_mentor" + ("_happy" if on else ""))


## Small hop on whoever is speaking (null = the player, nobody hops).
func hop(who: Node) -> void:
	if who == null:
		return
	var s := who as Sprite2D
	var base_y := MENTOR_AT.y if s == mentor else CUSTOMER_AT.y
	var t := create_tween()
	t.tween_property(s, "position:y", base_y - 4, 0.08)
	t.tween_property(s, "position:y", base_y, 0.12)


## Shows a short reaction above someone's head for a moment.
func emote(who: Node, text: String, time := 1.6) -> void:
	if who == null:
		return
	var s := who as Sprite2D
	emote_label.text = text
	emote_label.reset_size()
	emote_label.position = (s.position + Vector2(78, 8)) * SCALE
	emote_label.show()
	var t := create_tween()
	t.tween_interval(time)
	t.tween_callback(emote_label.hide)


func show_served_cup(kind := "glass") -> void:
	served_cup.texture = tex("cup_latte" if kind == "cup" else "cup_espresso")
	var fill: ColorRect = served_cup.get_child(0)
	fill.position = Vector2(11, 3) if kind == "cup" else Vector2(5, 14)
	fill.size = Vector2(30, 7) if kind == "cup" else Vector2(26, 18)
	fill.color = Color("#E9D2B0") if kind == "cup" else COFFEE
	served_cup.show()


func hide_served_cup() -> void:
	served_cup.hide()
