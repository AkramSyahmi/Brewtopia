class_name Bar3D
extends Control
## First-person espresso bar (Barista Simulator style) in the 3D pixel-art look.
## The 3D world renders into a low-res SubViewport (nearest filter) for crisp pixels.
## Drag the portafilter, tamper and cup; press the grinder button, turn the dial,
## press the brew button. Nothing forces an order; mistakes show in the shot.
## Same API as the older 2D BarStation so CafeShift can drive either.

signal served(shot: Dictionary)  ## cup with coffee dropped on the serve tray
signal changed  ## bar state changed (mentor hints refresh)
signal message(text: String)  ## immediate feedback

const PIXEL_SCALE := 3  # 1280x720 window -> 426x240 render
const COUNTER_Y := 0.95
const LIFT := 0.07  # how high a dragged item floats above the counter
const SNAP := 0.11  # XZ distance (m) that counts as "dropped on" a spot
const MAX_YIELD_G := 70.0
const CUP_FULL_G := 40.0
const EYE := Vector3(-0.05, 1.72, 0.85)
const EYE_PITCH := -32.0

const MACHINE_AT := Vector3(0.18, COUNTER_Y, -0.36)
const GRINDER_AT := Vector3(-0.42, COUNTER_Y, -0.36)
const MAT_AT := Vector3(-0.2, COUNTER_Y, -0.04)
const KNOCK_AT := Vector3(-0.72, COUNTER_Y, -0.12)
const STACK_AT := Vector3(0.62, COUNTER_Y, -0.28)
const SERVE_AT := Vector3(0.64, COUNTER_Y, -0.04)
const TAMPER_REST := Vector3(-0.02, COUNTER_Y, -0.02)

var recipe: Dictionary
var dispense_g_per_s := 4.0
var sim_speed := 2.0

# Portafilter state
var grind := 8
var dose_g := 0.0
var shot_grind := 8
var tamped := false
var used := false
var pf_spot := "mat"

# Cup (one in play)
var cup: Node3D
var cup_spot := ""
var cup_yield := 0.0
var cup_shot := {}

var grinding := false
var extracting := false
var sim_time := 0.0
var flow := 0.0

# Input
var dragging: Node3D
var drag_offset := Vector3.ZERO
var turning_dial := false
var dial_start_x := 0.0
var dial_start_grind := 8
var hovered: Node3D
var warned := ""

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var machine: Node3D
var grinder: Node3D
var pf: Node3D
var tamper: Node3D
var spots := {}
var highlight: ShaderMaterial
var container: SubViewportContainer
var view := "pov"
var mentor: Node3D
var customer: Node3D
var served_cup: Node3D
var dose_bubble: Label  # big readable scale readouts floating over the equipment
var cup_bubble: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = PIXEL_SCALE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.own_world_3d = true
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)

	highlight = ShaderMaterial.new()
	highlight.shader = IsoKit.OUTLINE_SHADER
	highlight.set_shader_parameter("color", Color("#FFE066"))
	highlight.set_shader_parameter("width_px", 1.0)

	build_room()
	machine = Props.espresso_machine(world, MACHINE_AT)
	grinder = Props.grinder(world, GRINDER_AT)
	Props.tamp_mat(world, MAT_AT)
	Props.knock_box(world, KNOCK_AT)
	Props.cup_stack(world, STACK_AT)
	Props.serve_tray(world, SERVE_AT)
	Props.milk(world, Vector3(0.9, COUNTER_Y, -0.3))
	Props.pitcher(world, Vector3(0.9, COUNTER_Y, -0.12))

	spots = {
		"fork": grinder.to_global(Vector3(0, 0.115, 0.1)),
		"mat": MAT_AT + Vector3(0, 0.03, 0),
		"group": machine.to_global(Vector3(0, 0.215, 0.13)),
		"tray": machine.to_global(Vector3(0, 0.113, 0.13)),
	}
	pf = Props.portafilter(world)
	pf.position = spots.mat
	pickable(pf, "pf", Vector3(0.11, 0.05, 0.3), Vector3(0, 0, 0.09))
	tamper = Props.tamper(world)
	tamper.position = TAMPER_REST
	pickable(tamper, "tamper", Vector3(0.07, 0.14, 0.07), Vector3(0, 0.07, 0))
	pickable(grinder.get_node("GrindButton"), "grind_button", Vector3(0.04, 0.04, 0.04))
	pickable(grinder.get_node("Dial"), "dial", Vector3(0.07, 0.07, 0.04))
	pickable(machine.get_node("BrewButton"), "brew_button", Vector3(0.06, 0.06, 0.04))
	var stack_area := Props.node(world, STACK_AT)
	pickable(stack_area, "stack", Vector3(0.22, 0.2, 0.18), Vector3(0, 0.08, 0))
	set_grind(grind)
	update_pf()
	dose_bubble = bubble()
	mentor = add_person("mentor", CafeRoom.MENTOR_SPOT)
	mentor.rotation_degrees.y = 25.0
	cup_bubble = bubble()


func bubble() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color("#F5E7CA"))
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#36251D", 0.9)
	s.border_color = Color("#BE895B")
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	l.add_theme_stylebox_override("normal", s)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.hide()
	add_child(l)
	return l


## Shows `grams` against `target` above a 3D point; green when close, red when over.
func show_bubble(l: Label, at: Vector3, grams: float, target: float, extra := "", centred := true) -> void:
	l.text = "%.1f g  /  %d g%s" % [grams, int(target), extra]
	var c := Color("#F5E7CA")
	if absf(grams - target) <= 0.5:
		c = Color("#9FE08A")
	elif grams > target + 1.0:
		c = Color("#FF8A7A")
	l.add_theme_color_override("font_color", c)
	l.reset_size()
	var p := camera.unproject_position(at) * container.stretch_shrink
	l.position = p - Vector2(l.size.x / 2.0 if centred else 0.0, l.size.y / 2.0)
	l.show()


func build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#A89A8A")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#FFE9D0")
	e.ambient_light_energy = 0.3
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 0.75
	sun.light_color = Color("#FFF1DC")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	world.add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.9, -0.1)
	lamp.omni_range = 2.2
	lamp.light_energy = 0.5
	lamp.light_color = Color("#FFD9A0")
	world.add_child(lamp)

	camera = Camera3D.new()
	camera.fov = 44
	camera.position = EYE
	camera.rotation_degrees = Vector3(EYE_PITCH, 0, 0)
	world.add_child(camera)

	CafeRoom.build(world)


# ---------- views and characters ----------

const ISO_TARGET := Vector3(0.1, 0.6, 1.2)
const ISO_PITCH := 30.0
const ISO_YAW := 45.0
const ISO_DIST := 18.0
const ISO_FOV := 16.0
const LOOKS := {
	"mentor": {"skin": Color("#C68B5E"), "hair": Color("#2A1B14"), "hair_style": "bun",
		"shirt": Color("#EFE6D8"), "pants": Color("#3A3F4E"), "apron": Color("#8FAE6A")},
	"student": {"skin": Color("#E2B48A"), "hair_style": "cap", "cap": Color("#C0504D"),
		"shirt": Color("#5B7DB1"), "pants": Color("#2F3A55")},
	"office": {"skin": Color("#8D5A3B"), "hair": Color("#1E1410"), "shirt": Color("#E9E4D8"),
		"pants": Color("#3A3F4E")},
	"enthusiast": {"skin": Color("#D9A57A"), "hair": Color("#5A4033"), "shirt": Color("#7A4E6E"),
		"pants": Color("#4A3B30"), "glasses": true, "beard": true},
}


## Moves the camera between the isometric café overview ("iso") and the barista's eyes
## ("pov"). Brewing input only works in "pov".
func set_view(v: String, animate := true) -> void:
	view = v
	set_hover(null)
	dose_bubble.hide()
	cup_bubble.hide()
	var to_pos := EYE
	var to_rot := Vector3(EYE_PITCH, 0, 0)
	var to_fov := 44.0
	if v == "iso":
		var p := deg_to_rad(ISO_PITCH)
		var y := deg_to_rad(ISO_YAW)
		to_pos = ISO_TARGET + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * ISO_DIST
		to_rot = Vector3(-ISO_PITCH, ISO_YAW, 0)
		to_fov = ISO_FOV
	container.stretch_shrink = 2 if v == "iso" else PIXEL_SCALE  # finer pixels for the wide view
	if not animate:
		camera.position = to_pos
		camera.rotation_degrees = to_rot
		camera.fov = to_fov
		return
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(camera, "position", to_pos, 1.1)
	t.tween_property(camera, "rotation_degrees", to_rot, 1.1)
	t.tween_property(camera, "fov", to_fov, 1.1)


func add_person(look_name: String, at: Vector3) -> Node3D:
	var p := Props.person(world, LOOKS[look_name])
	p.position = at
	return p


## Walks a person along the floor to `to`, facing the way they walk, with a small bob.
func walk(p: Node3D, to: Vector3, time := 1.6) -> Tween:
	var d := to - p.position
	p.rotation_degrees.y = rad_to_deg(atan2(d.x, d.z))
	var body: Node3D = p.get_node("Body")
	var bob := create_tween().set_loops(int(time / 0.3))
	bob.tween_property(body, "position:y", 0.04, 0.15)
	bob.tween_property(body, "position:y", 0.0, 0.15)
	var t := create_tween()
	t.tween_property(p, "position", to, time)
	return t


func customer_enter(look_name: String) -> Tween:
	if customer:
		customer.queue_free()
	customer = add_person(look_name, CafeRoom.DOOR_SPOT)
	var t := walk(customer, CafeRoom.CUSTOMER_SPOT)
	t.tween_property(customer, "rotation_degrees:y", 180.0, 0.25)
	return t


func customer_leave() -> Tween:
	var t := walk(customer, CafeRoom.DOOR_SPOT)
	var leaving := customer
	customer = null
	t.tween_callback(leaving.queue_free)
	return t


## Small hop on whoever is speaking.
func hop(p: Node3D) -> void:
	if p == null:
		return
	var body: Node3D = p.get_node("Body")
	var t := create_tween()
	t.tween_property(body, "position:y", 0.08, 0.08)
	t.tween_property(body, "position:y", 0.0, 0.12)


func emote(p: Node3D, text: String, time := 1.6) -> void:
	if p == null:
		return
	var e: Label3D = p.get_node("Emote")
	e.text = text
	var t := create_tween()
	t.tween_interval(time)
	t.tween_callback(func(): e.text = "")


## The finished drink waiting on the front counter for the customer.
func show_served_cup() -> void:
	hide_served_cup()
	served_cup = Props.cup(world)
	served_cup.position = CafeRoom.SERVE_SPOT
	Props.set_cup_level(served_cup, 0.9)


func hide_served_cup() -> void:
	if served_cup:
		served_cup.queue_free()
	served_cup = null


# ---------- per-frame simulation ----------

func _process(delta: float) -> void:
	var stream: Node3D = grinder.get_node("GroundsStream")
	stream.visible = grinding
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
	(grinder.get_node("LCD") as Label3D).text = "%.1fg" % (dose_g if pf_spot == "fork" else 0.0)
	if view == "pov" and recipe and (grinding or (pf_spot == "fork" and dragging != pf)):
		show_bubble(dose_bubble, grinder.to_global(Vector3(0.13, 0.22, 0.1)), dose_g, recipe.dose_g, "", false)
	else:
		dose_bubble.hide()
	if view == "pov" and recipe and cup and cup_spot == "tray" and (extracting or cup_yield > 0.0):
		show_bubble(cup_bubble, machine.to_global(Vector3(0, -0.02, 0.32)), cup_yield,
			recipe.target_yield_g, "   ·   %d s" % int(sim_time))
	else:
		cup_bubble.hide()

	if extracting:
		var step := delta * sim_speed
		sim_time += step
		if cup and cup_spot == "tray":
			cup_yield += flow * step
			Props.set_cup_level(cup, cup_yield / CUP_FULL_G)
		(machine.get_node("ScaleLCD") as Label3D).text = "%.1fg %02ds" % [cup_yield, int(sim_time)]
		if sim_time * flow >= MAX_YIELD_G:
			toggle_brew()


# ---------- order lifecycle ----------

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
	(machine.get_node("ScaleLCD") as Label3D).text = "0.0g"


func set_grind(value: int) -> void:
	grind = clampi(value, 1, 10)
	var dial: Node3D = grinder.get_node("Dial")
	dial.rotation_degrees = Vector3(90, lerpf(-135.0, 135.0, (grind - 1) / 9.0), 0)


func toggle_brew() -> void:
	var streams: Node3D = machine.get_node("ShotStream")
	if extracting:
		extracting = false
		streams.hide()
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
		streams.show()
		if cup == null or cup_spot != "tray":
			say("No cup under the machine! The coffee is going down the drain.")
		changed.emit()


# ---------- picking and drag & drop ----------

func pickable(target: Node3D, item: String, size: Vector3, offset := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.set_meta("item", item)
	body.set_meta("target", target)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Collision boxes ignore the target's rotation so the sizes stay in world terms.
	box.size = size
	shape.shape = box
	shape.position = offset
	body.add_child(shape)
	target.add_child(body)
	body.top_level = target.rotation != Vector3.ZERO
	if body.top_level:
		body.global_position = target.global_position + offset
		shape.position = Vector3.ZERO


func ray_from(screen_pos: Vector2) -> Array:
	var p := screen_pos / container.stretch_shrink
	return [camera.project_ray_origin(p), camera.project_ray_normal(p)]


func pick(screen_pos: Vector2) -> StaticBody3D:
	var r := ray_from(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * 10.0)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.collider if hit and hit.collider is StaticBody3D else null


func on_plane(screen_pos: Vector2, height: float) -> Vector3:
	var r := ray_from(screen_pos)
	var hit = Plane(Vector3.UP, height).intersects_ray(r[0], r[1])
	return hit if hit != null else Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or view != "pov":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press(event.position)
		else:
			release()
	elif event is InputEventMouseMotion:
		if dragging:
			var p := on_plane(event.position, COUNTER_Y + LIFT)
			dragging.global_position = p + drag_offset
		elif turning_dial:
			var steps := int((event.position.x - dial_start_x) / 30.0)
			if dial_start_grind + steps != grind:
				set_grind(dial_start_grind + steps)
				changed.emit()
		else:
			var body := pick(event.position)
			set_hover(body.get_meta("target") if body else null)


func set_hover(target: Node3D) -> void:
	if hovered == target:
		return
	if hovered:
		apply_overlay(hovered, null)
	hovered = target
	if hovered:
		apply_overlay(hovered, highlight)


func apply_overlay(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		n.material_overlay = m
	for c in n.get_children():
		apply_overlay(c, m)


func press(screen_pos: Vector2) -> void:
	var body := pick(screen_pos)
	if body == null:
		return
	var item: String = body.get_meta("item")
	match item:
		"pf":
			if extracting:
				say("Wait for the shot to finish.")
			else:
				start_drag(pf, screen_pos)
		"tamper":
			start_drag(tamper, screen_pos)
		"cup":
			if extracting and cup_spot == "tray":
				say("Wait for the shot to finish.")
			else:
				start_drag(cup, screen_pos)
		"stack":
			if cup:
				say("You already have a cup out.")
			else:
				start_drag(take_cup(), screen_pos)
		"grind_button":
			grinding = true
			warned = ""
		"dial":
			turning_dial = true
			dial_start_x = screen_pos.x
			dial_start_grind = grind
		"brew_button":
			toggle_brew()


func take_cup() -> Node3D:
	cup = Props.cup(world)
	cup.position = STACK_AT + Vector3(0, 0.12, 0)
	pickable(cup, "cup", Vector3(0.1, 0.08, 0.1), Vector3(0, 0.04, 0))
	cup_yield = 0.0
	cup_shot = {}
	return cup


func start_drag(n: Node3D, screen_pos: Vector2) -> void:
	dragging = n
	var p := on_plane(screen_pos, COUNTER_Y + LIFT)
	drag_offset = Vector3(n.global_position.x - p.x, 0, n.global_position.z - p.z)
	drag_offset.y = 0.0
	n.global_position = Vector3(n.global_position.x, COUNTER_Y + LIFT, n.global_position.z)
	if n == cup:
		cup_spot = ""


func release() -> void:
	if grinding:
		grinding = false
		changed.emit()
	turning_dial = false
	if dragging == null:
		return
	var n := dragging
	dragging = null
	if n == pf:
		drop_pf()
	elif n == tamper:
		drop_tamper()
	elif n == cup:
		drop_cup()
	changed.emit()


func near(a: Vector3, b: Vector3) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < SNAP


func move_to(n: Node3D, to: Vector3, time := 0.12) -> Tween:
	var t := create_tween()
	t.tween_property(n, "global_position", to, time).set_trans(Tween.TRANS_SINE)
	return t


func drop_pf() -> void:
	var at := pf.global_position
	if near(at, KNOCK_AT):
		if dose_g > 0.0 or used:
			dose_g = 0.0
			tamped = false
			used = false
			say("Knocked out the old grounds.")
		place_pf("mat")
		return
	for spot in ["fork", "group", "mat"]:
		if near(at, spots[spot]):
			place_pf(spot)
			return
	place_pf(pf_spot)


func place_pf(spot: String) -> void:
	pf_spot = spot
	move_to(pf, spots[spot])
	update_pf()


func drop_tamper() -> void:
	if near(tamper.global_position, pf.global_position):
		if pf_spot == "group":
			say("Take the portafilter out of the machine before tamping.")
		elif used:
			say("Those grounds are used. Knock them out first.")
		elif dose_g < 0.5:
			say("There's nothing to tamp yet.")
		else:
			var above := pf.global_position + Vector3(0, 0.03, 0)
			var t := create_tween()
			t.tween_property(tamper, "global_position", above + Vector3(0, 0.02, 0), 0.1)
			t.tween_property(tamper, "global_position", above, 0.15)
			t.tween_callback(func():
				tamped = true
				update_pf()
				say("Tamped! Nice and level.")
				changed.emit())
			t.tween_property(tamper, "global_position", TAMPER_REST, 0.2)
			return
	move_to(tamper, TAMPER_REST)


func drop_cup() -> void:
	var at := cup.global_position
	if near(at, SERVE_AT):
		if cup_shot.is_empty():
			say("The cup is empty.")
		else:
			move_to(cup, SERVE_AT + Vector3(0, 0.017, 0))
			cup_spot = "serve"
			served.emit(cup_shot.duplicate())
			return
	if near(at, spots.tray):
		move_to(cup, spots.tray)
		cup_spot = "tray"
	elif near(at, STACK_AT) and cup_shot.is_empty():
		clear_cup()
	else:
		move_to(cup, Vector3(at.x, COUNTER_Y, at.z))
		cup_spot = "counter"


# ---------- feedback ----------

## What a mentor would suggest next, from the current bar state.
func next_hint() -> String:
	if extracting:
		return "Watch the scale under the cup. Press the green brew button again at about %d g." % recipe.target_yield_g
	if not cup_shot.is_empty():
		return "Drag the cup onto the green SERVE tray on the right."
	if used:
		return "Drag the portafilter to the black knock box on the left to empty the old grounds."
	if dose_g < recipe.dose_g - 1.0:
		if pf_spot != "fork":
			return "Drag the portafilter under the grinder."
		return "Drag the wooden dial to set the grind, then hold the red button until the scale shows about %d g." % recipe.dose_g
	if not tamped:
		if pf_spot != "mat":
			return "Move the portafilter onto the black tamping mat."
		return "Drag the tamper onto the coffee to press it flat."
	if pf_spot != "group":
		return "Lock the portafilter into the machine's group head."
	if cup == null or cup_spot != "tray":
		return "Take a cup from the cup stack and put it on the scale under the machine."
	return "Press the green brew button to start the shot."


func say(text: String) -> void:
	message.emit(text)


func once(text: String) -> void:
	if warned != text:
		warned = text
		say(text)


func update_pf() -> void:
	Props.set_portafilter_state(pf, "used" if used else "tamped" if tamped else "dosed" if dose_g > 0.5 else "empty")
