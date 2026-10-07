class_name DoughHand
extends Node
## Hazır hamuru parmakla kaseden fırına götürme. Hamur olmuş kaseye basıp parmak biraz kayınca hamur,
## tarifin çiğ hali olarak (somun, kurabiye, kek) kaseden çıkar ve parmağı izler. Boş fırının üstünde
## bırakılırsa fırının ağzına uçar, kase boşalır ve fırın pişirmeye başlar; başka yerde bırakılırsa kaseye
## geri döner. Fırın doluyken fırına bırakılan hamur geri döner ve fırın sallanır. Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki kaseye basış önce buraya ulaşsın.

const NO_TOUCH: int = -1
## Parmak bu kadar kaymadan hamur çıkmaz.
const DRAG_START_DISTANCE: float = 24.0
## Hamurun parmağa göre yeri: parmak hamuru örtmesin.
const HOLD_OFFSET: Vector2 = Vector2(0.0, -70.0)
## Hamur parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
## Kaseden çıkarken fırındaki boyunun bu oranında başlar.
const LIFT_START_SCALE: float = 0.6
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
## Hamurun fırının ağzına uçma süresi; kapak hamur varınca kapanır.
const INTO_OVEN_TIME: float = 0.25

@export var bowl: MixingBowl
@export var oven: Oven
## Taşınan hamur burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer

var _touch_index: int = NO_TOUCH
var _start: Vector2
var _held: Sprite2D
var _recipe: StringName
var _target: Vector2


func _process(delta: float) -> void:
	if _held != null:
		_held.position = _held.position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var point: Vector2 = _to_world(touch.position)
			if bowl.has_dough() and bowl.contains(point):
				_touch_index = touch.index
				_start = point
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			if _held != null:
				_release(_to_world(touch.position))
			_touch_index = NO_TOUCH
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_move(_to_world(drag.position))
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: hamuru kaseye geri koy.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			if _held != null:
				oven.set_highlighted(false)
				_return()


func _move(point: Vector2) -> void:
	if _held == null:
		if point.distance_to(_start) >= DRAG_START_DISTANCE:
			_lift(point)
		return
	_target = _to_screen(point) + HOLD_OFFSET
	oven.set_highlighted(oven.can_bake() and oven.contains(point))


func _release(point: Vector2) -> void:
	oven.set_highlighted(false)
	if oven.contains(point):
		if oven.can_bake():
			_put_in_oven()
			return
		oven.nudge()
	_return()


## Hamur kaseden çıkıp parmağa doğru büyüyerek gelir.
func _lift(point: Vector2) -> void:
	_recipe = bowl.recipe
	if not bowl.lift_dough():
		return
	var carry: float = oven.product_scale(_recipe)
	_held = Sprite2D.new()
	_held.texture = oven.raw_texture(_recipe)
	drag_layer.add_child(_held)
	_held.position = _to_screen(bowl.dough_point())
	_held.scale = Vector2.ONE * carry * LIFT_START_SCALE
	_target = _to_screen(point) + HOLD_OFFSET
	create_tween().tween_property(_held, ^"scale", Vector2.ONE * carry, LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hamur fırının ağzına uçar; kase o anda boşalır, fırın pişirmeye başlar.
func _put_in_oven() -> void:
	var held: Sprite2D = _held
	_held = null
	bowl.clear()
	oven.bake(_recipe, INTO_OVEN_TIME)
	var tween: Tween = held.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(oven.product_point()), INTO_OVEN_TIME)
	tween.tween_callback(held.queue_free)


## Hamur küçülerek kaseye döner.
func _return() -> void:
	var held: Sprite2D = _held
	_held = null
	var tween: Tween = held.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(bowl.dough_point()), RETURN_TIME)
	tween.tween_property(held, ^"scale", held.scale * LIFT_START_SCALE, RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		held.queue_free()
		bowl.put_back_dough())


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
