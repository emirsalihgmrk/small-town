class_name SellHand
extends Node
## Pazarda sepetten ürünü parmakla çekip müşteriye verme. Sepete basıp parmak biraz kayınca, müşterinin
## henüz verilmemiş isteklerinden sepette bulunan ilki (balondaki sırayla) sepetin ağzından çıkar ve
## parmağı izler. Müşterinin (ya da balonunun) üstünde bırakılırsa müşteriye uçar ve ortak sepetten düşer;
## başka yerde bırakılırsa sepete geri uçar. Müşteri yokken ya da isteği tamamken hiçbir şey çıkmaz.
## Kaydırmadan bırakılan dokunuş sepete dokunmak sayılır (sepet menüsü açılır). Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki sepete basış önce buraya ulaşsın.

const NO_TOUCH: int = -1
const NO_SLOT: int = -1
## Parmak bu kadar kaymadan ürün çıkmaz; daha azı sepete dokunmak sayılır.
const DRAG_START_DISTANCE: float = 24.0
## Ürünün parmağa göre yeri: parmak ürünü örtmesin.
const HOLD_OFFSET: Vector2 = Vector2(0.0, -70.0)
## Ürün parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
## Ürünün en uzun kenarı sepetteyken ve taşınırken bu boyda görünür.
const BASKET_SIZE: float = 60.0
const CARRY_SIZE: float = 120.0
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
const GIVE_TIME: float = 0.22
const FADE_TIME: float = 0.12

@export var basket: BasketView
@export var customer: Customer
## Taşınan ürün burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer
## Verilebilecek ürünlerin resimleri (Items kimliği -> resmi).
@export var item_textures: Dictionary[StringName, Texture2D] = {}

var _touch_index: int = NO_TOUCH
var _start: Vector2
## Parmak bu basışta ürün çıkaramadı; bırakınca sepet menüsü açılmasın.
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


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: ürünü sepete geri gönder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			if _held != null:
				customer.set_highlighted(false)
				_return()


func _move(point: Vector2) -> void:
	if _held == null:
		if not _refused and point.distance_to(_start) >= DRAG_START_DISTANCE:
			_lift(point)
		return
	_target = _to_screen(point) + HOLD_OFFSET
	customer.set_highlighted(customer.contains(point))


func _release(point: Vector2) -> void:
	if _held == null:
		if not _refused:
			basket.tap()
		return
	if customer.can_receive() and customer.contains(point):
		_give()
	else:
		customer.set_highlighted(false)
		_return()


## İstenen ürün sepetin ağzından çıkıp parmağa doğru büyüyerek gelir.
func _lift(point: Vector2) -> void:
	_refused = true
	if not customer.can_receive():
		return
	for slot: int in customer.open_slots():
		if basket.take_out(customer.wanted(slot)):
			_slot = slot
			break
	if _slot == NO_SLOT:
		return
	_refused = false
	_held = Sprite2D.new()
	_held.texture = item_textures.get(customer.wanted(_slot))
	drag_layer.add_child(_held)
	_held.position = _to_screen(basket.mouth())
	_held.scale = _size_scale(BASKET_SIZE)
	_target = _to_screen(point) + HOLD_OFFSET
	create_tween().tween_property(_held, ^"scale", _size_scale(CARRY_SIZE), LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ürün müşterinin göğsüne uçup küçülerek kaybolur; yuva o anda dolu sayılır.
func _give() -> void:
	var held: Sprite2D = _held
	var slot: int = _slot
	_held = null
	_slot = NO_SLOT
	basket.hand_over(customer.wanted(slot))
	customer.receive(slot)
	var tween: Tween = held.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(held, ^"position", _to_screen(customer.hand_point()), GIVE_TIME)
	tween.parallel().tween_property(held, ^"scale", held.scale * 0.5, GIVE_TIME)
	tween.tween_property(held, ^"modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(held.queue_free)


## Ürün kavissiz, küçülerek sepetin ağzına döner ve sepete düşer.
func _return() -> void:
	var held: Sprite2D = _held
	var item: StringName = customer.wanted(_slot)
	var basket_scale: Vector2 = _size_scale(BASKET_SIZE)
	_held = null
	_slot = NO_SLOT
	var tween: Tween = held.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(basket.mouth()), RETURN_TIME)
	tween.tween_property(held, ^"scale", basket_scale, RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		held.queue_free()
		basket.put_back(item))


## Taşınan ürünün en uzun kenarı size olsun diye gereken ölçek.
func _size_scale(size: float) -> Vector2:
	if _held == null or _held.texture == null:
		return Vector2.ONE
	return Vector2.ONE * (size / maxf(_held.texture.get_width(), _held.texture.get_height()))


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
