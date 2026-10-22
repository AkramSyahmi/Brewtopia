class_name CounterScreen
extends Control
## The café while the player is idle (talking, waiting, serving): the 3D café rendered as
## isometric pixel art, cut away like a dollhouse so the whole room is visible
## (Bar3D in its "iso" view). Customers walk in from the door to the front counter.
## On top: an order bubble with drink icons and a yellow patience bar that follows the
## customer. Drinks are made at the separate 2D station (EspressoStation).

const ART := "res://assets/art/%s.png"
const SCALE := 2  # overlay art is drawn x2
const BUBBLE_OFFSET := Vector2(-150, -60)  # bubble top-left from the customer's head (base px), to its left
const BUBBLE_SIZE := Vector2(132, 140)
const QUEUE_SPOT := CafeRoom.QUEUE_SPOT  # next customer waits here
const COFFEE := Color("#4A2A18")
const EVENING := Color(1.0, 0.92, 0.86)  # warm light used by the station screens

var cafe: Bar3D
var overlay: Node2D  # 2D bits drawn over the 3D café
var mentor: Node3D
var customer: Node3D
var queue_person: Node3D
var order_bubble: Node2D
var order_icons: Node2D
var patience_fill: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	cafe = Bar3D.new()
	add_child(cafe)
	cafe.set_view("iso", false)
	mentor = cafe.mentor
	overlay = Node2D.new()
	overlay.scale = Vector2(SCALE, SCALE)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(overlay)
	build_order_bubble()


func _process(_delta: float) -> void:
	customer = cafe.customer
	if order_bubble.visible and customer:
		var head := cafe.camera.unproject_position(customer.position + Vector3(0, 1.1, 0))  # chibi head height
		var at := head * cafe.container.stretch_shrink / SCALE + BUBBLE_OFFSET
		order_bubble.position = at.clamp(Vector2(4, 26), Vector2(636, 356) - BUBBLE_SIZE)  # stay on screen, below the HUD


func tex(n: String) -> Texture2D:
	return load(ART % n)


func sprite(n: String, at: Vector2, s := 1.0, parent: Node = null) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex(n)
	sp.centered = false
	sp.position = at
	sp.scale = Vector2(s, s)
	(parent if parent else overlay).add_child(sp)
	return sp


## Grey order bubble with the drink icons and a yellow patience bar.
func build_order_bubble() -> void:
	order_bubble = Node2D.new()
	overlay.add_child(order_bubble)
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
	var tail := Polygon2D.new()  # points down-right at the customer
	tail.polygon = PackedVector2Array([Vector2(BUBBLE_SIZE.x - 30, BUBBLE_SIZE.y - 1),
		Vector2(BUBBLE_SIZE.x + 8, BUBBLE_SIZE.y + 22), Vector2(BUBBLE_SIZE.x - 10, BUBBLE_SIZE.y - 1)])
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
## `count` > 1 draws a second cup behind the first. A vague order shows only a "?".
func show_order(recipe: Dictionary, count := 1, vague := false) -> void:
	for c in order_icons.get_children():
		c.queue_free()
	if vague:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 72)
		q.add_theme_color_override("font_color", Color("#F5E7CA"))
		q.position = Vector2(48, 10)
		order_icons.add_child(q)
		set_patience(1.0)
		order_bubble.show()
		return
	var cup_kind: String = recipe.get("cup", "glass")
	var inside: Rect2 = EspressoStation.CUPS[cup_kind].inside
	for k in range(count - 1, -1, -1):
		var cup := sprite(EspressoStation.CUPS[cup_kind].tex, Vector2(36 - k * 18, 18 - k * 6), 1.2, order_icons)
		var fill := ColorRect.new()
		fill.color = Color("#E9D2B0") if recipe.has("milk") else COFFEE
		fill.position = inside.position + Vector2(0, inside.size.y * 0.3)
		fill.size = Vector2(inside.size.x, inside.size.y * 0.7)
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


## Shows the decorations the player bought (SaveGame.DECOR ids) in the café.
func set_decor(ids: Array) -> void:
	cafe.set_decor(ids)


func hide_order() -> void:
	order_bubble.hide()


## The next customer waits by the door, facing the counter ("" = nobody waiting).
func show_queue(look: String) -> void:
	if queue_person:
		queue_person.queue_free()
		queue_person = null
	if look != "":
		queue_person = cafe.add_person(look, QUEUE_SPOT)
		queue_person.rotation_degrees.y = CafeRoom.CUSTOMER_FACING


## Customer walks in from the door to the counter; returns the tween to await.
func customer_enter(look: String) -> Tween:
	show_queue("")  # the waiting customer is the one walking up now
	var t := cafe.customer_enter(look)
	customer = cafe.customer
	return t


func customer_leave() -> Tween:
	hide_order()
	customer = null
	return cafe.customer_leave()


## The 3D characters have one face; reactions show as emotes instead.
func set_happy(_on: bool) -> void:
	pass


func set_mentor_happy(_on: bool) -> void:
	pass


## Small hop on whoever is speaking (null = the player, nobody hops).
func hop(who: Node) -> void:
	cafe.hop(who)


## Shows a short reaction above someone's head for a moment.
func emote(who: Node, text: String, time := 1.6) -> void:
	cafe.emote(who, text, time)


func show_served_cup(_kind := "glass") -> void:
	cafe.show_served_cup()


func hide_served_cup() -> void:
	cafe.hide_served_cup()
