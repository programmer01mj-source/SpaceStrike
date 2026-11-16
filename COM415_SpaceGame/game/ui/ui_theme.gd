class_name UiTheme
extends RefCounted
## Builds the game's UI theme in code from the Kenney UI pack.
## To restyle every button, change the texture paths below.

const FONT_PATH := "res://assets/ui/font/KenneyFuture.ttf"
const BUTTON_NORMAL := "res://assets/ui/kenney_ui/blue_button02.png"
const BUTTON_HOVER := "res://assets/ui/kenney_ui/blue_button00.png"
const BUTTON_PRESSED := "res://assets/ui/kenney_ui/blue_button01.png"
const BUTTON_DISABLED := "res://assets/ui/kenney_ui/grey_button00.png"

const COLOR_ACCENT := Color(0.35, 0.85, 1.0)
const COLOR_PANEL := Color(0.04, 0.06, 0.14, 0.88)


static func create() -> Theme:
	var theme := Theme.new()
	var font := load(FONT_PATH) as Font
	if font != null:
		theme.default_font = font
	theme.default_font_size = 22
	theme.set_stylebox("normal", "Button", _button_box(BUTTON_NORMAL))
	theme.set_stylebox("hover", "Button", _button_box(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _button_box(BUTTON_PRESSED))
	theme.set_stylebox("focus", "Button", _button_box(BUTTON_HOVER))
	theme.set_stylebox("disabled", "Button", _button_box(BUTTON_DISABLED))
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color(0.85, 0.95, 1.0))
	theme.set_font_size("font_size", "Button", 24)
	theme.set_stylebox("panel", "PanelContainer", panel_box())
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	return theme


static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL
	box.border_color = COLOR_ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(14)
	return box


static func bar_fill_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	return box


static func bar_background_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	box.border_color = Color(1, 1, 1, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box


static func _button_box(texture_path: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(texture_path) as Texture2D
	box.texture_margin_left = 12.0
	box.texture_margin_right = 12.0
	box.texture_margin_top = 10.0
	box.texture_margin_bottom = 14.0
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 14.0
	return box
