class_name HayHand
extends Node
## Saman yığınından bir tutam saman çekip yemliğe götürme. Yığına basıp parmak biraz kayınca yığının
## tepesinden bir tutam çıkar ve parmağı izler. Dolu olmayan yemliğin üstünde bırakılırsa yemliğe düşer;
## başka yerde (ya da dolu yemlikte) bırakılırsa yığına geri uçar. Saman hiç tükenmez, sepetle ilgisi yoktur.
## Kaydırmadan bırakılan dokunuş yığına dokunmak sayılır (yığın hışırdar). Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir.

const NO_TOUCH: int = -1
## Parmak bu kadar kaymadan tutam çıkmaz; daha azı yığına dokunmak sayılır.
const DRAG_START_DISTANCE: float = 24.0
## Tutamın parmağa göre yeri: parmak tutamı örtmesin.
const HOLD_OFFSET: Vector2 = Vector2(0.0, -60.0)
## Tutam parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
const PILE_SCALE: float = 0.5
const CARRY_SCALE: float = 1.0
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
## Bırakırken tutam yemliğin bu kadar üstüne gelir, biraz eğilip silkelenir.
const DROP_POINT: Vector2 = Vector2(0.0, -170.0)
const DROP_MOVE_TIME: float = 0.18
const DROP_TILT_DEGREES: float = 30.0
const DROP_SHAKE_DEGREES: float = 12.0
const DROP_SHAKE_TIME: float = 0.09
const FADE_TIME: float = 0.2

@export var hay_pile: HayPile
@export var manger: Manger
## Taşınan tutam burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer
@export var tuft_texture: Texture2D

var _touch_index: int = NO_TOUCH
var _start: Vector2
var _tuft: Sprite2D
var _target: Vector2


func _process(delta: float) -> void:
	if _tuft != null:
		_tuft.position = _tuft.position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var point: Vector2 = _to_world(touch.position)
			if hay_pile.contains(point):
				_touch_index = touch.index
				_start = point
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release(_to_world(touch.position))
			_touch_index = NO_TOUCH
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_move(_to_world(drag.position))
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: tutamı yığına geri gönder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			if _tuft != null:
				manger.set_highlighted(false)
				_return()


func _move(point: Vector2) -> void:
	if _tuft == null:
		if point.distance_to(_start) >= DRAG_START_DISTANCE:
			_lift(point)
		return
	_target = _to_screen(point) + HOLD_OFFSET
	manger.set_highlighted(manger.can_fill() and manger.contains(point))


func _release(point: Vector2) -> void:
	if _tuft == null:
		hay_pile.rustle()
		return
	if manger.can_fill() and manger.contains(point):
		_drop()
	else:
		manger.set_highlighted(false)
		_return()


## Tutam yığının tepesinden çıkıp parmağa doğru büyüyerek gelir.
func _lift(point: Vector2) -> void:
	hay_pile.rustle()
	_tuft = Sprite2D.new()
	_tuft.texture = tuft_texture
	drag_layer.add_child(_tuft)
	_tuft.position = _to_screen(hay_pile.top())
	_tuft.scale = Vector2.ONE * PILE_SCALE
	_target = _to_screen(point) + HOLD_OFFSET
	create_tween().tween_property(_tuft, ^"scale", Vector2.ONE * CARRY_SCALE, LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tutam yemliğin üstüne gelir, eğilip silkelenir ve kaybolur; yemlik o anda dolu sayılır.
func _drop() -> void:
	var tuft: Sprite2D = _tuft
	_tuft = null
	manger.fill()
	var tween: Tween = tuft.create_tween()
	tween.tween_property(tuft, ^"position", _to_screen(manger.to_global(DROP_POINT)), DROP_MOVE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tuft, ^"rotation", deg_to_rad(DROP_TILT_DEGREES), DROP_MOVE_TIME)
	for i: int in 2:
		tween.tween_property(tuft, ^"rotation", deg_to_rad(DROP_TILT_DEGREES - DROP_SHAKE_DEGREES), DROP_SHAKE_TIME)
		tween.tween_property(tuft, ^"rotation", deg_to_rad(DROP_TILT_DEGREES), DROP_SHAKE_TIME)
	tween.tween_property(tuft, ^"modulate:a", 0.0, FADE_TIME)
	tween.parallel().tween_property(tuft, ^"scale", Vector2.ONE * PILE_SCALE, FADE_TIME)
	tween.tween_callback(tuft.queue_free)


## Tutam küçülerek yığının tepesine döner ve yığına karışır.
func _return() -> void:
	var tuft: Sprite2D = _tuft
	_tuft = null
	var tween: Tween = tuft.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tuft, ^"position", _to_screen(hay_pile.top()), RETURN_TIME)
	tween.tween_property(tuft, ^"scale", Vector2.ONE * PILE_SCALE, RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		tuft.queue_free()
		hay_pile.rustle())


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
