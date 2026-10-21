class_name UpgradeShop
extends PanelContainer
## Upgrade shop overlay (GCGC style): each upgrade shows its level bar, what it does and
## the price of the next level. Buying spends money from the save and writes it.

signal bought

var save: Dictionary
var rows := {}
var money_label: Label


func _ready() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#FBF4EA")
	s.border_color = Color("#65422F")
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(24)
	add_theme_stylebox_override("panel", s)
	position = Vector2(190, 80)
	custom_minimum_size = Vector2(900, 560)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var heading := text("Upgrades", 32, Color("#BE895B"))
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(heading)
	money_label = text("", 26, Color("#3E7E3E"))
	top.add_child(money_label)
	for id in SaveGame.UPGRADES:
		var u: Dictionary = SaveGame.UPGRADES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		col.add_child(row)
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
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(220, 56)
	close.pressed.connect(hide)
	col.add_child(close)
	hide()


func text(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


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
