class_name ShipJoystick
extends Control
## Floating on-screen joystick (Kenney mobile controls textures).
##
## Put your thumb anywhere inside this control's area: the stick appears under
## the finger and steers the ship. Uses raw touch events so it supports
## multi-touch (steer + fire at the same time). The mouse also works on a PC
## because "emulate touch from mouse" is enabled in Project Settings.

const PAD_TEXTURE := "res://assets/ui/mobile_controls/joystick_circle_pad_highlight.png"
const NUB_TEXTURE := "res://assets/ui/mobile_controls/joystick_circle_nub_highlight.png"

## Stick travel in pixels.
@export var radius: float = 100.0
@export var dead_zone: float = 0.08

## x: right (+), y: up (+), length 0..1
var value: Vector2 = Vector2.ZERO

var _finger: int = -1
var _pad: TextureRect
var _nub: TextureRect
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad = _make_texture(PAD_TEXTURE, 220.0)
	_nub = _make_texture(NUB_TEXTURE, 100.0)
	_show_idle()
	resized.connect(_show_idle)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and get_global_rect().has_point(touch.position):
			_finger = touch.index
			_center = touch.position - global_position
			_update_value(touch.position)
			_pad.modulate.a = 0.9
			_nub.modulate.a = 1.0
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			value = Vector2.ZERO
			_show_idle()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_update_value(drag.position)


func _update_value(screen_position: Vector2) -> void:
	var offset := screen_position - (global_position + _center)
	var limited := offset.limit_length(radius)
	var normalised := limited / radius
	value = Vector2(normalised.x, -normalised.y)
	if value.length() < dead_zone:
		value = Vector2.ZERO
	_pad.position = _center - _pad.size * 0.5
	_nub.position = _center + limited - _nub.size * 0.5


func _show_idle() -> void:
	_center = Vector2(180.0, maxf(size.y - 160.0, 200.0))
	_pad.position = _center - _pad.size * 0.5
	_nub.position = _center - _nub.size * 0.5
	_pad.modulate.a = 0.4
	_nub.modulate.a = 0.5


func _make_texture(path: String, pixel_size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(pixel_size, pixel_size)
	rect.size = Vector2(pixel_size, pixel_size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
