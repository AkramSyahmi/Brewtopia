class_name RecipeBook
extends PanelContainer
## Recipe book overlay (GCGC style): a list of drinks on the left, ingredients and
## steps for the selected drink on the right. Reads data/recipes/*.json.

const RECIPES := ["double_espresso_training", "latte", "gula_melaka_latte", "iced_latte", "cappuccino",
	"iced_gula_melaka_latte", "mocha", "kopi_susu_ais", "caramel_macchiato"]  # menu order
const RECIPE_PATH := "res://data/recipes/%s.json"

var buttons := {}  # id -> {button, recipe}
var name_label: Label
var ingredients: Label
var steps: Label


func _ready() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#FBF4EA")
	s.border_color = Color("#65422F")
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(24)
	add_theme_stylebox_override("panel", s)
	position = Vector2(140, 70)
	custom_minimum_size = Vector2(1000, 580)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	add_child(row)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(280, 0)
	list.add_theme_constant_override("separation", 10)
	row.add_child(list)
	var heading := text("Recipe Book", 30, Color("#BE895B"))
	list.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 8)
	scroll.add_child(entries)
	for id in RECIPES:
		var r := EspressoModel.load_recipe(RECIPE_PATH % id)
		var b := Button.new()
		b.text = r.display_name
		b.custom_minimum_size = Vector2(250, 48)
		b.pressed.connect(show_recipe.bind(r))
		entries.add_child(b)
		buttons[id] = {"button": b, "recipe": r}
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(260, 56)
	close.pressed.connect(hide)
	list.add_child(close)

	var page := VBoxContainer.new()
	page.custom_minimum_size = Vector2(620, 0)
	page.add_theme_constant_override("separation", 14)
	row.add_child(page)
	name_label = text("", 36, Color("#E0A030"))
	page.add_child(name_label)
	ingredients = text("", 22, Color("#36251D"))
	page.add_child(ingredients)
	steps = text("", 20, Color("#65422F"))
	steps.autowrap_mode = TextServer.AUTOWRAP_WORD
	steps.custom_minimum_size = Vector2(620, 0)
	page.add_child(steps)
	show_recipe(EspressoModel.load_recipe(RECIPE_PATH % RECIPES[0]))
	hide()


func text(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


## Shows the book with recipes above the player's level locked.
func open(level: int) -> void:
	for id in buttons:
		var b: Button = buttons[id].button
		var r: Dictionary = buttons[id].recipe
		var need := int(r.get("unlock_level", 1))
		b.disabled = need > level
		b.text = r.display_name if need <= level else "Locked  (Lv %d)" % need
	show()


func show_recipe(r: Dictionary) -> void:
	name_label.text = r.display_name
	ingredients.text = "\n".join(r.get("ingredients", []).map(func(i): return "•  " + i))
	steps.text = r.get("steps", "")
