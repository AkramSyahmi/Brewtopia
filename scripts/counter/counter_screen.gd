class_name CounterScreen
extends Control
## The café while the player is idle (talking, waiting, serving): the 3D café rendered as
## isometric pixel art, cut away like a dollhouse so the whole room is visible
## (Bar3D in its "iso" view). Customers walk in from the door to the front counter.
## On top: a compact pixel speech bubble beside the customer's head with the drink they
## want (cup + a short spoken order). Drinks are made at the separate 2D station
## (EspressoStation). The customer's patience is kept by CafeShift (it sets Service %
## and tips); it has no bar here.

const ART := "res://assets/art/%s.png"
const CUP_BOX := Vector2(56, 56)  # fits every station cup at its own size (1:1, no scaling)
const BUBBLE_TEXT_W := 196.0  # order text column; fixed, so wrapped text has its height at once
const POINTER_W := 27.0  # bubble_pointer.png width (its tip is in the middle)
const MARGIN := 8.0  # keep this far inside the screen
const HUD_BOTTOM := 56.0  # the top HUD row ends here (Recipes, Menu, ORDER)
const HEAD_CENTRE_M := 0.92  # chibi head: centre height and on-screen size (metres), see head_rect
const HEAD_SIZE_M := Vector2(0.84, 0.48)
const POP_S := 0.2  # bubble appear (fade + rise + scale-in)
const FADE_S := 0.12  # bubble disappear
const RISE_PX := 6.0
const QUEUE_SPOT := CafeRoom.QUEUE_SPOT  # next customer waits here
const EVENING := Color(1.0, 0.92, 0.86)  # warm light used by the station screens
const INK := Color("#3B2314")  # dark brown text on the cream bubble

var cafe: Bar3D
var mentor: Node3D
var customer: Node3D
var queue_person: Node3D
var order_bubble: PanelContainer  # cream pixel sign; sized by its contents
var order_pointer: TextureRect
var order_cup: TextureRect
var order_liquid: CupLiquid
var order_q: Label  # "?" for a vague order
var order_name: Label  # the spoken order ("Latte, please!")
var order_extras: Label  # "With 2 pumps of gula melaka and cinnamon on top."
var avoid_rects := func() -> Array: return []  # UI panels (screen rects) the bubble should stay off; set by CafeShift
var bubble_tween: Tween  # the one pop-in / fade-out running (replaced, never stacked)
var bubble_rise := 0.0  # px the bubble sits lower while popping in
var bubble_leaving := false  # fading out
var order_key := ""  # the order on show, so the same order does not pop in twice


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	cafe = Bar3D.new()
	add_child(cafe)
	cafe.set_view("iso", false)
	mentor = cafe.mentor
	build_order_bubble()


## Follows the customer: their head, from the 3D model, projected to screen px.
func _process(_delta: float) -> void:
	customer = cafe.customer
	if order_bubble.visible and customer:
		place_bubble(head_rect(customer))


## The customer's head on screen. The Kenney chibi head is big: its centre is about 0.92 m
## up and it shows about 0.84 x 0.48 m (measured on screen). Scaled by how many screen px a
## metre is at the customer, so it follows any position and zoom.
func head_rect(p: Node3D) -> Rect2:
	var to_screen := func(v: Vector3) -> Vector2:
		return cafe.camera.unproject_position(p.global_transform * v) * cafe.container.stretch_shrink
	var centre: Vector2 = to_screen.call(Vector3(0, HEAD_CENTRE_M, 0))
	var px_per_m: float = (to_screen.call(Vector3.ZERO) as Vector2).distance_to(to_screen.call(Vector3.UP))
	var size := HEAD_SIZE_M * px_per_m
	return Rect2(centre - size / 2.0, size)


## Puts the bubble near the customer's head (`face`, a screen rect): tries spots above,
## above-left/right and beside it (plus spots just clear of each UI panel in avoid_rects),
## clamped inside the screen under the HUD, and keeps the one that covers least of the
## head and the panels while staying close. The pointer aims at the head.
func place_bubble(face: Rect2) -> void:
	var s := order_bubble.size
	var lo := Vector2(MARGIN, HUD_BOTTOM + 4)
	var hi := get_viewport_rect().size - Vector2(MARGIN, MARGIN) - s
	var head := Vector2(face.get_center().x, face.position.y + 8.0)  # top of the head
	var blocked: Array = avoid_rects.call()
	var xs := [head.x - s.x / 2.0, face.end.x - s.x, face.position.x, face.position.x - 12.0 - s.x, face.end.x + 12.0]  # above (centred, left, right) / beside
	var ys := [face.position.y - 14.0 - s.y, face.get_center().y - s.y / 2.0]  # above the head / level with it
	for b: Rect2 in blocked:  # also try just beside and just below each panel
		xs.append(b.position.x - 8.0 - s.x)
		xs.append(b.end.x + 8.0)
		ys.append(b.end.y + 8.0)
	var best := Vector2.ZERO
	var best_cost := INF
	for x: float in xs:
		for y: float in ys:
			var p := Vector2(x, y).clamp(lo, hi)
			var r := Rect2(p, s)
			var cost := 4.0 * overlap(r, face) + 0.5 * p.distance_to(head - Vector2(s.x / 2.0, s.y))
			if r.position.y > face.get_center().y:
				cost += 120.0  # below the head reads as someone else talking: last resort
			for b: Rect2 in blocked:
				cost += 3.0 * overlap(r, b)
			if cost < best_cost:
				best_cost = cost
				best = p
	order_bubble.position = (best + Vector2(0, bubble_rise)).round()  # (bubble_rise: pop-in offset)
	# The pointer (drawn pointing down) goes on the edge facing the head: the bottom when
	# the head is below the bubble, else the side the head is on, turned to face it.
	var mid := Vector2(clampf(head.x, best.x + 30.0, best.x + s.x - 30.0), best.y + s.y + 1.5)  # pointer centre
	var turn := 0.0
	var side_y := clampf(face.get_center().y, best.y + 24.0, best.y + s.y - 24.0)
	if best.x + s.x <= face.position.x + 12.0:  # bubble left of the head
		mid = Vector2(best.x + s.x + 1.5, side_y)
		turn = -PI / 2.0
	elif best.x >= face.end.x - 12.0:  # bubble right of the head
		mid = Vector2(best.x - 1.5, side_y)
		turn = PI / 2.0
	elif best.y >= face.end.y - 12.0:  # bubble below the head: pointer on top, pointing up
		mid = Vector2(clampf(head.x, best.x + 30.0, best.x + s.x - 30.0), best.y - 1.5)
		turn = PI
	order_pointer.rotation = turn
	order_pointer.position = (mid + Vector2(0, bubble_rise) - order_pointer.size / 2.0).round()


static func overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return i.size.x * i.size.y


func label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Compact cream speech bubble: drink picture | spoken order, and a stepped pointer.
## A PanelContainer sized by its contents (fixed text width).
func build_order_bubble() -> void:
	order_bubble = PanelContainer.new()
	order_bubble.add_theme_stylebox_override("panel", PixelUI.cream_panel(10))
	order_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	order_bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(order_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	order_bubble.add_child(row)
	var pic := Control.new()  # fixed box: the cup (or "?") never stretches the bubble
	pic.custom_minimum_size = CUP_BOX
	pic.size_flags_vertical = SIZE_SHRINK_CENTER
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(pic)
	order_cup = TextureRect.new()
	order_cup.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED  # its own pixel size: crisp, never stretched
	order_cup.size = CUP_BOX
	order_cup.mouse_filter = MOUSE_FILTER_IGNORE
	pic.add_child(order_cup)
	order_q = label(pic, 44, Color("#6A3E1F"))
	order_q.text = "?"
	order_q.size = CUP_BOX
	order_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.custom_minimum_size.x = BUBBLE_TEXT_W
	text.size_flags_vertical = SIZE_SHRINK_CENTER
	text.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(text)
	order_name = label(text, 17, INK)
	order_name.add_theme_font_override("font", PixelUI.font(700))
	order_extras = label(text, 14, Color("#6A3E1F"))
	for l: Label in [order_name, order_extras]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = BUBBLE_TEXT_W
	order_pointer = TextureRect.new()
	order_pointer.texture = load(PixelUI.HUD % "bubble_pointer")
	order_pointer.mouse_filter = MOUSE_FILTER_IGNORE
	order_pointer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	order_pointer.size = Vector2(POINTER_W, 15)
	order_pointer.pivot_offset = order_pointer.size / 2.0  # turns about its centre (see place_bubble)
	add_child(order_pointer)
	order_bubble.visibility_changed.connect(func(): order_pointer.visible = order_bubble.visible)
	order_bubble.hide()


## Shows what the customer wants: the cup with the drink in it and a short spoken order
## built from the order's recipe ("Two Lattes, please!" + "With 2 pumps of gula melaka and
## cinnamon on top."). A vague order shows only a "?" and gives nothing away.
func show_order(recipe: Dictionary, count := 1, vague := false) -> void:
	var key := "%s|%d|%s" % [recipe.get("display_name", ""), count, vague]
	if order_bubble.visible and key == order_key and not bubble_leaving:
		return  # already showing this order: no second pop-in
	order_key = key
	order_q.visible = vague
	order_cup.visible = not vague
	if order_liquid:
		order_liquid.queue_free()
		order_liquid = null
	if vague:
		order_name.text = "Hmm, let me think..."
		order_extras.text = "Listen to what I'd like!"
	else:
		var kind: String = recipe.get("cup", "glass")
		var cup: Dictionary = EspressoStation.CUPS[kind]
		order_cup.texture = load(ART % cup.tex)
		var milk: bool = recipe.has("milk")
		var looks := {"milk_temp": (5.0 if recipe.get("ice", false) else 62.0) if milk else -1.0,
			"milk_foam": (recipe.milk.get("foam_min", 0.25) + recipe.milk.get("foam_max", 0.4)) / 2.0 if milk else 0.0,
			"syrups": recipe.get("syrups", {})}
		var levels := EspressoStation.drink_levels(kind, recipe.target_yield_g, milk)
		order_liquid = CupLiquid.new(order_cup.texture, cup.inside, kind == "cup")
		order_liquid.position = ((CUP_BOX - order_cup.texture.get_size()) / 2.0).floor()  # where KEEP_CENTERED draws it
		order_liquid.set_drink(levels.x, levels.y, looks)
		order_liquid.coffee = levels.x  # shown full at once (no pour animation here)
		order_liquid.milk = levels.y
		order_cup.add_child(order_liquid)
		var drink_name: String = recipe.display_name
		if count > 1:
			drink_name = "Two %s" % (drink_name if drink_name.ends_with("s") else drink_name + "s")
		order_name.text = "%s, please!" % drink_name
		var extras: Array[String] = []
		for s in recipe.get("syrups", {}):
			var n := int(recipe.syrups[s])
			extras.append("%d pump%s of %s" % [n, "" if n == 1 else "s", s.replace("_", " ")])
		for t in recipe.get("toppings", []):
			extras.append(t.replace("_", " ") + " on top")
		order_extras.text = "" if extras.is_empty() else "With %s." % join_and(extras)
	order_extras.visible = order_extras.text != ""
	order_bubble.reset_size()
	pop_in()


## Appear: a quick fade, a 6 px rise and a small scale-in from the bubble's bottom.
## One tween at a time: any running one (pop or fade) is replaced.
func pop_in() -> void:
	if bubble_tween:
		bubble_tween.kill()
	bubble_leaving = false
	order_bubble.pivot_offset = Vector2(order_bubble.size.x / 2.0, order_bubble.size.y)
	bubble_look(0.0)
	order_bubble.show()
	bubble_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bubble_tween.tween_method(bubble_look, 0.0, 1.0, POP_S)


## 0 = hidden (clear, 6 px low, 94%), 1 = shown.
func bubble_look(t: float) -> void:
	order_bubble.modulate.a = t
	order_pointer.modulate.a = t
	order_bubble.scale = Vector2.ONE * lerpf(0.94, 1.0, t)
	bubble_rise = (1.0 - t) * RISE_PX


static func join_and(items: Array[String]) -> String:
	if items.size() == 1:
		return items[0]
	return ", ".join(items.slice(0, items.size() - 1)) + " and " + items[-1]


## Shows the decorations the player bought (SaveGame.DECOR ids) in the café.
func set_decor(ids: Array) -> void:
	cafe.set_decor(ids)


## Disappear: a short fade, then hidden. Only the bubble: the order itself is untouched.
func hide_order() -> void:
	if not order_bubble.visible or bubble_leaving:
		return
	if bubble_tween:
		bubble_tween.kill()
	bubble_leaving = true
	order_key = ""
	bubble_tween = create_tween()
	bubble_tween.tween_method(bubble_look, order_bubble.modulate.a, 0.0, FADE_S)
	bubble_tween.tween_callback(func():
		order_bubble.hide()
		bubble_leaving = false)


## The next customer walks in from off-screen (round behind the one at the counter) and waits
## by the table, facing the counter ("" = nobody waiting: anyone in line walks back out).
func show_queue(look: String) -> void:
	if queue_person:
		var gone := queue_person
		cafe.walk_path(gone, [CafeRoom.ENTRANCE], false).tween_callback(gone.queue_free)
		queue_person = null
	if look != "":
		queue_person = cafe.add_person(look, CafeRoom.ENTRANCE)
		var t := cafe.walk_path(queue_person, [CafeRoom.QUEUE_WAY, QUEUE_SPOT])
		t.tween_property(queue_person, "rotation_degrees:y", CafeRoom.CUSTOMER_FACING, 0.25)


## The next customer walks up to the counter: the one waiting in line if there is one (the same
## person, no swap), else a new one from off-screen. Returns the tween to await.
func customer_enter(look: String) -> Tween:
	var walker: Node3D = null
	if queue_person and queue_person.get_meta("look") == look:
		walker = queue_person
		queue_person = null
	else:
		show_queue("")  # someone else is in line (orders skipped): they leave, the right one comes in
	var t := cafe.customer_enter(look, walker)
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


## The mentor turns to the player while she talks to them, else back to the customer (Bar3D).
func mentor_face(to_player: bool) -> void:
	cafe.mentor_face(to_player)


## Shows a short reaction above someone's head for a moment.
func emote(who: Node, text: String, time := 1.6) -> void:
	cafe.emote(who, text, time)


func show_served_cup(_kind := "glass") -> void:
	cafe.show_served_cup()


func hide_served_cup() -> void:
	cafe.hide_served_cup()
