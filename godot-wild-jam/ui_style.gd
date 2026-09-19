class_name UIStyle
extends RefCounted

const BG_DEEP := Color(0.055, 0.075, 0.102)
const BG_PANEL := Color(0.078, 0.102, 0.133)
const BG_BUTTON := Color(0.118, 0.145, 0.188)
const BG_HOVER := Color(0.165, 0.200, 0.251)
const BG_PRESS := Color(0.086, 0.110, 0.141)
const BG_OFF := Color(0.090, 0.110, 0.133)

const LINE := Color(0.239, 0.290, 0.361)
const LINE_HOT := Color(0.369, 0.478, 0.620)

const TEXT := Color(0.788, 0.831, 0.878)
const TEXT_DIM := Color(0.404, 0.451, 0.510)
const TEXT_HOT := Color(1.0, 0.776, 0.302)
const ACCENT := Color(1.0, 0.776, 0.302)


static func flat(bg: Color, border: Color, width := 2, radius := 4,
		pad_x := 14, pad_y := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func style_button(b: Button) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", flat(BG_BUTTON, LINE))
	b.add_theme_stylebox_override("hover", flat(BG_HOVER, LINE_HOT))
	b.add_theme_stylebox_override("pressed", flat(BG_PRESS, LINE_HOT))
	b.add_theme_stylebox_override("disabled", flat(BG_OFF, Color(0.157, 0.184, 0.216)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", TEXT_HOT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)


static func style_panel(p: PanelContainer, pad := 22) -> void:
	var s := flat(BG_PANEL, LINE, 2, 6, pad, pad)
	s.bg_color.a = 0.96
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size = 14
	p.add_theme_stylebox_override("panel", s)


static func style_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.11, 0.14, 0.85)
	bg.set_corner_radius_all(3)
	bg.set_border_width_all(1)
	bg.border_color = LINE

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.286, 0.749, 0.616)
	fill.set_corner_radius_all(3)

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


static func outline(l: Label, size := 4) -> void:
	# labels sit straight on the 3D scene, so they need an outline to stay legible
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_color_override("font_color", Color.WHITE)
