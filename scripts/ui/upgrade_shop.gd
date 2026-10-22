class_name UpgradeShop
extends PanelContainer
## Shop overlay (GCGC style) with two tabs:
##  - Upgrades: each machine upgrade shows its level bar, what it does and the next price.
##  - Decor: café decorations; each shows up in the café and adds 5% to tips.
## Buying spends money from the save and writes it.

signal bought

var save: Dictionary
var rows := {}
var decor_rows := {}
var money_label: Label
var upgrades_page: VBoxContainer
var decor_page: VBoxContainer


func _ready() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#FBF4EA")
	s.border_color = Color("#65422F")
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(24)
	add_theme_stylebox_override("panel", s)
	position = Vector2(190, 60)
	custom_minimum_size = Vector2(900, 600)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	for tab in ["Upgrades", "Decor"]:
		var b := Button.new()
		b.text = tab
		b.custom_minimum_size = Vector2(170, 52)
		b.pressed.connect(show_tab.bind(tab))
		top.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(spacer)
	money_label = text("", 26, Color("#3E7E3E"))
	top.add_child(money_label)

	upgrades_page = VBoxContainer.new()
	upgrades_page.add_theme_constant_override("separation", 18)
	col.add_child(upgrades_page)
	for id in SaveGame.UPGRADES:
		var u: Dictionary = SaveGame.UPGRADES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		upgrades_page.add_child(row)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(520, 0)
		row.add_child(info)
		info.add_child(text(u.name, 26, Color("#36251D")))
		info.add_child(text(u.desc, 17, Color("#65422F")))
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 4)
		info.add_child(bar)
		var cells := []
		for i in 3:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(60, 14)
			bar.add_child(cell)
			cells.append(cell)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(220, 64)
		buy.pressed.connect(func():
			if SaveGame.buy(save, id):
				SaveGame.write(save)
				bought.emit()
			refresh())
		row.add_child(buy)
		rows[id] = {"cells": cells, "buy": buy}

	decor_page = VBoxContainer.new()
	decor_page.add_theme_constant_override("separation", 10)
	col.add_child(decor_page)
	decor_page.add_child(text("Each decoration makes customers tip 5% more.", 18, Color("#65422F")))
	for id in SaveGame.DECOR:
		var d: Dictionary = SaveGame.DECOR[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		decor_page.add_child(row)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(520, 0)
		row.add_child(info)
		info.add_child(text(d.name, 24, Color("#36251D")))
		info.add_child(text(d.desc, 16, Color("#65422F")))
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(220, 56)
		buy.pressed.connect(func():
			if SaveGame.buy_decor(save, id):
				SaveGame.write(save)
				bought.emit()
			refresh())
		row.add_child(buy)
		decor_rows[id] = buy

	var fill := Control.new()
	fill.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(fill)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(220, 56)
	close.pressed.connect(hide)
	col.add_child(close)
	show_tab("Upgrades")
	hide()


func text(t: String, size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	return l


func show_tab(tab: String) -> void:
	upgrades_page.visible = tab == "Upgrades"
	decor_page.visible = tab == "Decor"


func open(data: Dictionary) -> void:
	save = data
	refresh()
	show()


func refresh() -> void:
	money_label.text = "RM %d" % save.money
	for id in rows:
		var lvl: int = save.upgrades[id]
		for i in 3:
			rows[id].cells[i].color = Color("#6BD46B") if i < lvl else Color("#D8CFC4")
		var cost := SaveGame.next_cost(save, id)
		var b: Button = rows[id].buy
		b.text = "MAX" if cost < 0 else "Level up  RM %d" % cost
		b.disabled = cost < 0 or save.money < cost
	for id in decor_rows:
		var b: Button = decor_rows[id]
		var owned: bool = id in save.decor
		b.text = "Owned" if owned else "Buy  RM %d" % SaveGame.DECOR[id].cost
		b.disabled = owned or save.money < SaveGame.DECOR[id].cost
