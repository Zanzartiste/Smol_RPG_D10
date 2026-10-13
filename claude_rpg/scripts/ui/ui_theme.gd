class_name UITheme
extends RefCounted
## Thème de l'interface, ambiance « Baldur's Gate 3 » : fonds sombres, bordures dorées, texte parchemin.

const BG := Color("#14110f")
const PANEL := Color("#211c18")
const BORDER := Color("#8a6d3b")
const BORDER_HOVER := Color("#d4b06a")
const TEXT := Color("#e8dcc4")
const TEXT_DIM := Color("#8c8273")
const GOLD := Color("#d4b06a")
const GOOD := Color("#8fbf6a")
const BAD := Color("#d9694a")


static func build() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "serif"])
	t.default_font = font
	t.default_font_size = 18

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 2, 14))
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())

	t.set_stylebox("normal", "Button", _box(Color("#2b241e"), Color("#6b5532"), 1, 10))
	t.set_stylebox("hover", "Button", _box(Color("#3a3027"), BORDER_HOVER, 1, 10))
	t.set_stylebox("pressed", "Button", _box(Color("#4a3c2e"), BORDER_HOVER, 1, 10))
	t.set_stylebox("hover_pressed", "Button", _box(Color("#55452f"), BORDER_HOVER, 1, 10))
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_stylebox("disabled", "Button", _box(Color("#1c1815"), Color("#3a3128"), 1, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)

	t.set_stylebox("normal", "LineEdit", _box(Color("#16120f"), Color("#6b5532"), 1, 8))
	t.set_stylebox("focus", "LineEdit", _box(Color("#16120f"), BORDER_HOVER, 1, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("caret_color", "LineEdit", GOLD)

	# Infobulles : fond très sombre et opaque, pour bien lire le texte.
	var tooltip := _box(Color("#0b0907"), BORDER, 1, 10)
	tooltip.bg_color.a = 0.97
	t.set_stylebox("panel", "TooltipPanel", tooltip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	t.set_type_variation("SectionLabel", "Label")
	t.set_color("font_color", "SectionLabel", GOLD)
	t.set_font_size("font_size", "SectionLabel", 20)

	t.set_type_variation("TitleLabel", "Label")
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_font_size("font_size", "TitleLabel", 26)
	return t


static func _box(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(margin)
	return box
