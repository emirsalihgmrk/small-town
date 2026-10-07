class_name FeedHand
extends Node
## Sepetten buğday demetini parmakla çekip yemliğe götürme. Sepete basıp parmak biraz kayınca demet
## sepetin ağzından çıkar ve parmağı izler. Boş yemliğin üstünde bırakılırsa yemliğe dökülür ve ortak
## sepetten düşer; başka yerde (ya da dolu yemlikte) bırakılırsa sepete geri uçar. Kaydırmadan bırakılan
## dokunuş sepete dokunmak sayılır (sepet menüsü açılır). Sepette buğday yoksa demet çıkmaz, no_wheat
## yayılır. Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki sepete basış önce buraya ulaşsın.

signal no_wheat

const NO_TOUCH: int = -1
## Parmak bu kadar kaymadan demet çıkmaz; daha azı sepete dokunmak sayılır.
const DRAG_START_DISTANCE: float = 24.0
## Demetin parmağa göre yeri: parmak demeti örtmesin.
const HOLD_OFFSET: Vector2 = Vector2(0.0, -70.0)
## Demet parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
const BASKET_SCALE: float = 0.55
const CARRY_SCALE: float = 0.95
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
## Dökerken demet yemliğin bu kadar üstünde durur ve başakları aşağı bakacak şekilde eğilir.
const POUR_POINT: Vector2 = Vector2(0.0, -150.0)
const POUR_MOVE_TIME: float = 0.18
const POUR_TILT_DEGREES: float = 125.0
const POUR_SHAKE_DEGREES: float = 12.0
const POUR_SHAKE_TIME: float = 0.09
const FADE_TIME: float = 0.2

@export var basket: BasketView
@export var feeder: Feeder
## Taşınan demet burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer
@export var wheat_texture: Texture2D

var _touch_index: int = NO_TOUCH
var _start: Vector2
## Parmak bu basışta demet çıkaramadı (sepette buğday yok); bırakınca sepet menüsü açılmasın.
var _refused: bool = false
var _bundle: Sprite2D
var _target: Vector2


func _process(delta: float) -> void:
	if _bundle != null:
		_bundle.position = _bundle.position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var point: Vector2 = _to_world(touch.position)
			if basket.contains(point):
				_touch_index = touch.index
				_start = point
				_refused = false
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


func _move(point: Vector2) -> void:
	if _bundle == null:
		if not _refused and point.distance_to(_start) >= DRAG_START_DISTANCE:
			_lift(point)
		return
	_target = _to_screen(point) + HOLD_OFFSET
	feeder.set_highlighted(not feeder.full and feeder.contains(point))


func _release(point: Vector2) -> void:
	if _bundle == null:
		if not _refused:
			basket.tap()
		return
	if not feeder.full and feeder.contains(point):
		_pour()
	else:
		feeder.set_highlighted(false)
		_return()


## Demet sepetin ağzından çıkıp parmağa doğru büyüyerek gelir.
func _lift(point: Vector2) -> void:
	if not basket.take_out(Items.WHEAT):
		_refused = true
		no_wheat.emit()
		return
	_bundle = Sprite2D.new()
	_bundle.texture = wheat_texture
	drag_layer.add_child(_bundle)
	_bundle.position = _to_screen(basket.mouth())
	_bundle.scale = Vector2.ONE * BASKET_SCALE
	_target = _to_screen(point) + HOLD_OFFSET
	create_tween().tween_property(_bundle, ^"scale", Vector2.ONE * CARRY_SCALE, LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Demet yemliğin üstüne gelir, eğilip silkelenir ve kaybolur; yemlik o anda dolu sayılır.
func _pour() -> void:
	var bundle: Sprite2D = _bundle
	_bundle = null
	basket.hand_over(Items.WHEAT)
	feeder.fill()
	var tween: Tween = bundle.create_tween()
	tween.tween_property(bundle, ^"position", _to_screen(feeder.to_global(POUR_POINT)), POUR_MOVE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bundle, ^"rotation", deg_to_rad(POUR_TILT_DEGREES), POUR_MOVE_TIME)
	for i: int in 2:
		tween.tween_property(bundle, ^"rotation", deg_to_rad(POUR_TILT_DEGREES - POUR_SHAKE_DEGREES), POUR_SHAKE_TIME)
		tween.tween_property(bundle, ^"rotation", deg_to_rad(POUR_TILT_DEGREES), POUR_SHAKE_TIME)
	tween.tween_property(bundle, ^"modulate:a", 0.0, FADE_TIME)
	tween.parallel().tween_property(bundle, ^"scale", Vector2.ONE * BASKET_SCALE, FADE_TIME)
	tween.tween_callback(bundle.queue_free)


## Demet kavissiz, küçülerek sepetin ağzına döner ve sepete düşer.
func _return() -> void:
	var bundle: Sprite2D = _bundle
	_bundle = null
	var tween: Tween = bundle.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bundle, ^"position", _to_screen(basket.mouth()), RETURN_TIME)
	tween.tween_property(bundle, ^"scale", Vector2.ONE * BASKET_SCALE, RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		bundle.queue_free()
		basket.put_back(Items.WHEAT))


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
