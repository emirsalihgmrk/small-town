class_name IngredientHand
extends Node
## Sepetten malzemeyi parmakla çekip kaseye götürme. Sepete basıp parmak biraz kayınca, kasede seçili
## tarifin henüz konmamış malzemelerinden sepette bulunan ilki (tarifteki sırayla) sepetin ağzından çıkar
## ve parmağı izler. Kasenin üstünde bırakılırsa kaseye dökülür ve ortak sepetten düşer; başka yerde
## bırakılırsa sepete geri uçar.
## Kaydırmadan bırakılan dokunuş sepete dokunmak sayılır (sepet menüsü açılır). Tarif seçilmemişse
## no_recipe, gereken malzemelerin hiçbiri sepette yoksa missing yayılır; kase doluysa hiçbir şey çıkmaz.
## Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki sepete basış önce buraya ulaşsın.

signal no_recipe
signal missing

const NO_TOUCH: int = -1
const NO_SLOT: int = -1
## Parmak bu kadar kaymadan malzeme çıkmaz; daha azı sepete dokunmak sayılır.
const DRAG_START_DISTANCE: float = 24.0
## Malzemenin parmağa göre yeri: parmak malzemeyi örtmesin.
const HOLD_OFFSET: Vector2 = Vector2(0.0, -70.0)
## Malzeme parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
const BASKET_SCALE: float = 0.55
const CARRY_SCALE: float = 0.95
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
## Dökerken malzeme kasenin bu kadar üstünde durur, eğilir ve silkelenir.
const POUR_POINT: Vector2 = Vector2(0.0, -190.0)
const POUR_MOVE_TIME: float = 0.18
## Malzemenin dökülürken ne kadar eğildiği: demetin başakları, yumurtanın ağzı, havucun ucu, şişenin ağzı
## kaseye baksın.
const POUR_TILT_DEGREES: Dictionary[StringName, float] = {
	Items.WHEAT: 125.0,
	Items.EGG: 180.0,
	Items.CARROT: 150.0,
	Items.MILK: 135.0,
}
const POUR_SHAKE_DEGREES: float = 12.0
const POUR_SHAKE_TIME: float = 0.09
const FADE_TIME: float = 0.2

@export var basket: BasketView
@export var bowl: MixingBowl
## Taşınan malzeme burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer

var _touch_index: int = NO_TOUCH
var _start: Vector2
## Parmak bu basışta malzeme çıkaramadı; bırakınca sepet menüsü açılmasın.
var _refused: bool = false
var _held: Sprite2D
var _slot: int = NO_SLOT
var _target: Vector2


func _process(delta: float) -> void:
	if _held != null:
		_held.position = _held.position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


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


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: malzemeyi sepete geri gönder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			if _held != null:
				bowl.set_highlighted(false)
				_return()


func _move(point: Vector2) -> void:
	if _held == null:
		if not _refused and point.distance_to(_start) >= DRAG_START_DISTANCE:
			_lift(point)
		return
	_target = _to_screen(point) + HOLD_OFFSET
	bowl.set_highlighted(bowl.contains(point))


func _release(point: Vector2) -> void:
	if _held == null:
		if not _refused:
			basket.tap()
		return
	if bowl.contains(point):
		_pour()
	else:
		bowl.set_highlighted(false)
		_return()


## Gereken malzeme sepetin ağzından çıkıp parmağa doğru büyüyerek gelir.
func _lift(point: Vector2) -> void:
	_refused = true
	if not bowl.has_recipe():
		no_recipe.emit()
		return
	if bowl.is_complete():
		return
	for slot: int in bowl.open_slots():
		if basket.take_out(bowl.ingredient(slot)):
			_slot = slot
			break
	if _slot == NO_SLOT:
		missing.emit()
		return
	_refused = false
	_held = Sprite2D.new()
	_held.texture = basket.item_textures.get(bowl.ingredient(_slot))
	drag_layer.add_child(_held)
	_held.position = _to_screen(basket.mouth())
	_held.scale = Vector2.ONE * BASKET_SCALE
	_target = _to_screen(point) + HOLD_OFFSET
	create_tween().tween_property(_held, ^"scale", Vector2.ONE * CARRY_SCALE, LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Malzeme kasenin üstüne gelir, eğilip silkelenir ve kaybolur; yuva o anda dolu sayılır.
func _pour() -> void:
	var held: Sprite2D = _held
	var item: StringName = bowl.ingredient(_slot)
	_held = null
	basket.hand_over(item)
	bowl.add(_slot)
	_slot = NO_SLOT
	var tilt: float = deg_to_rad(POUR_TILT_DEGREES.get(item, 0.0))
	var shake: float = deg_to_rad(POUR_SHAKE_DEGREES)
	var tween: Tween = held.create_tween()
	tween.tween_property(held, ^"position", _to_screen(bowl.to_global(POUR_POINT)), POUR_MOVE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(held, ^"rotation", tilt, POUR_MOVE_TIME)
	for i: int in 2:
		tween.tween_property(held, ^"rotation", tilt - shake, POUR_SHAKE_TIME)
		tween.tween_property(held, ^"rotation", tilt, POUR_SHAKE_TIME)
	tween.tween_property(held, ^"modulate:a", 0.0, FADE_TIME)
	tween.parallel().tween_property(held, ^"scale", Vector2.ONE * BASKET_SCALE, FADE_TIME)
	tween.tween_callback(held.queue_free)


## Malzeme kavissiz, küçülerek sepetin ağzına döner ve sepete düşer.
func _return() -> void:
	var held: Sprite2D = _held
	var item: StringName = bowl.ingredient(_slot)
	_held = null
	_slot = NO_SLOT
	var tween: Tween = held.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(basket.mouth()), RETURN_TIME)
	tween.tween_property(held, ^"scale", Vector2.ONE * BASKET_SCALE, RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		held.queue_free()
		basket.put_back(item))


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
