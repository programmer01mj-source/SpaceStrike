class_name TouchButton
extends Control
## Round on-screen button that is "held" while a finger is on it (FIRE, BOOST).

const TEXTURE := "res://assets/ui/mobile_controls/button_circle_highlight.png"

var is_held: bool = false
var label_text: String = "FIRE"
var tint: Color = Color(1.0, 0.4, 0.3)

var _finger: int = -1
var _icon: TextureRect
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = TextureRect.new()
	_icon.texture = load(TEXTURE) as Texture2D
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.text = label_text
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and _hit_area().has_point(touch.position):
			_finger = touch.index
			is_held = true
			_refresh()
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			is_held = false
			_refresh()


func release() -> void:
	_finger = -1
	is_held = false
	_refresh()


## The touchable area is a little bigger than the picture, which is easier on thumbs.
func _hit_area() -> Rect2:
	return get_global_rect().grow(14.0)


func _refresh() -> void:
	if _icon == null:
		return
	_icon.modulate = tint if not is_held else tint.lightened(0.45)
	_icon.modulate.a = 0.95 if is_held else 0.7
	_label.text = label_text
