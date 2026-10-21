class_name CounterScreen
extends Control
## Front counter, laid out like the reference café sim: an evening KL skyline through the
## window, customers' heads and shoulders behind a dark wooden counter, an order bubble
## with drink icons and a yellow patience bar, and the bar equipment along the counter.
## World is 640x360 base pixels drawn x2 with a warm evening tint; art from res://assets/art/.

const ART := "res://assets/art/%s.png"
const SCALE := 2
const CUSTOMER_AT := Vector2(200, 58)
const MENTOR_AT := Vector2(470, 70)
const OFFSTAGE := Vector2(-150, 58)
const BUBBLE_AT := Vector2(52, 40)  # order bubble, left of the customer
const BUBBLE_SIZE := Vector2(132, 140)
const CUP_AT := Vector2(306, 238)  # served drink on the work mat
const COFFEE := Color("#4A2A18")
const EVENING := Color(1.0, 0.92, 0.86)  # warm light over everything

var world: Node2D
var mentor: Sprite2D
var customer: Sprite2D
var queue_shadow: Sprite2D  # the next customer waiting behind
var customer_look := ""
var served_cup: Sprite2D
var emote_label: Label
var order_bubble: Node2D
var order_icons: Node2D
var patience_fill: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.modulate = EVENING
	add_child(world)
	sprite("counter_bg", Vector2.ZERO)
	queue_shadow = sprite("char_office", Vector2(318, 74))
	queue_shadow.modulate = Color(0.45, 0.38, 0.5)
	queue_shadow.scale = Vector2(0.85, 0.85)
	queue_shadow.hide()
	mentor = sprite("char_mentor", MENTOR_AT)
	customer = sprite("char_student", OFFSTAGE)
	customer.hide()
	sprite("counter_front", Vector2(0, 200))
	decorate_counter()
	served_cup = sprite("cup_espresso", CUP_AT)
	var fill := ColorRect.new()
	fill.color = COFFEE
	fill.position = Vector2(5, 14)
	fill.size = Vector2(26, 18)
	served_cup.add_child(fill)
	served_cup.hide()
	build_order_bubble()
	emote_label = Label.new()
	emote_label.add_theme_font_size_override("font_size", 40)
	emote_label.add_theme_color_override("font_color", Color("#FFE066"))
	emote_label.add_theme_color_override("font_outline_color", Color("#36251D"))
	emote_label.add_theme_constant_override("outline_size", 10)
	emote_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(emote_label)


func tex(n: String) -> Texture2D:
	return load(ART % n)


func sprite(n: String, at: Vector2, s := 1.0, parent: Node = null) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex(n)
	sp.centered = false
	sp.position = at
	sp.scale = Vector2(s, s)
	(parent if parent else world).add_child(sp)
	return sp


## Bar equipment along the counter (decor here; drinks are made at the station).
func decorate_counter() -> void:
	sprite("machine", Vector2(6, 176), 0.44)
	sprite("pitcher", Vector2(150, 236), 0.8)
	sprite("cup_latte", Vector2(160, 214), 0.6)
	for i in 4:
		sprite("syrup_" + ["vanilla", "gula_melaka", "pandan", "chocolate"][i], Vector2(470 + i * 38, 196), 0.8)
	for i in 3:  # cups on the shelf under the counter
		sprite("cup_latte", Vector2(14 + i * 44, 318), 0.7)
		sprite("cup_espresso", Vector2(178 + i * 40, 320), 0.8)
	sprite("bean_bag", Vector2(586, 300), 0.8)


## Grey order bubble with the drink icons and a yellow patience bar (reference style).
func build_order_bubble() -> void:
	order_bubble = Node2D.new()
	order_bubble.position = BUBBLE_AT
	world.add_child(order_bubble)
	var frame := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#8C8A94")
	s.border_color = Color("#2A2430")
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", s)
	frame.size = BUBBLE_SIZE
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	order_bubble.add_child(frame)
	var tail := Polygon2D.new()  # points at the customer
	tail.polygon = PackedVector2Array([Vector2(BUBBLE_SIZE.x - 1, 60), Vector2(BUBBLE_SIZE.x + 10, 70),
		Vector2(BUBBLE_SIZE.x - 1, 80)])
	tail.color = Color("#8C8A94")
	order_bubble.add_child(tail)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color("#2A2430")
	bar_bg.position = Vector2(6, 8)
	bar_bg.size = Vector2(8, BUBBLE_SIZE.y - 16)
	order_bubble.add_child(bar_bg)
	patience_fill = ColorRect.new()
	patience_fill.color = Color("#E8D44A")
	patience_fill.position = Vector2(7, 9)
	patience_fill.size = Vector2(6, BUBBLE_SIZE.y - 18)
	order_bubble.add_child(patience_fill)
	order_icons = Node2D.new()
	order_bubble.add_child(order_icons)
	order_bubble.hide()


## Shows what the customer wants: the cup, plus small icons for syrups and toppings.
func show_order(recipe: Dictionary) -> void:
	for c in order_icons.get_children():
		c.queue_free()
	var cup_kind: String = recipe.get("cup", "glass")
	var cup := sprite("cup_latte" if cup_kind == "cup" else "cup_espresso", Vector2(36, 18), 1.2, order_icons)
	var fill := ColorRect.new()
	fill.color = Color("#E9D2B0") if recipe.has("milk") else COFFEE
	fill.position = Vector2(11, 3) if cup_kind == "cup" else Vector2(5, 14)
	fill.size = Vector2(30, 7) if cup_kind == "cup" else Vector2(26, 18)
	cup.add_child(fill)
	var x := 24.0
	for s in recipe.get("syrups", {}):
		for i in int(recipe.syrups[s]):
			sprite("syrup_" + s, Vector2(x, 82), 0.4, order_icons)
			x += 20
	for t in recipe.get("toppings", []):
		sprite("topping_" + t, Vector2(x, 92), 0.4, order_icons)
		x += 30
	set_patience(1.0)
	order_bubble.show()


func set_patience(p: float) -> void:
	var h := (BUBBLE_SIZE.y - 18) * clampf(p, 0.0, 1.0)
	patience_fill.position.y = 9 + (BUBBLE_SIZE.y - 18) - h
	patience_fill.size.y = h
	patience_fill.color = Color("#E8D44A") if p > 0.3 else Color("#E0603A")


func hide_order() -> void:
	order_bubble.hide()


func show_queue(look: String) -> void:
	if look == "":
		queue_shadow.hide()
	else:
		queue_shadow.texture = tex("char_" + look)
		queue_shadow.show()


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
	hide_order()
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
	emote_label.position = (s.position + Vector2(78, 4)) * SCALE
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
