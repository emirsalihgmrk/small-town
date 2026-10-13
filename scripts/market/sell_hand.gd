class_name SellHand
extends Node
## Pazarda reyondan ürünü parmakla alıp müşteriye verme. Bir kasaya ya da raf bölmesine (StockBin) basınca,
## orada ürün varsa en üstteki ürün kalkıp parmağı izler. Müşterinin (ya da balonunun) üstünde bırakılırsa:
## müşteri o ürünü istiyorsa ürün müşteriye uçar ve ortak sepetten düşer; istemiyorsa müşteri başını sallar
## ve ürün yerine geri uçar. Başka yerde bırakılırsa ya da müşteri ürün almıyorsa ürün yerine döner.
## Tek parmak izlenir. Boş reyona basış yok sayılır (sahnedeki diğer dokunulabilirlere geçer).
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki reyona basış önce buraya ulaşsın.

const NO_TOUCH: int = -1
## Ürün parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
## Ürünün en uzun kenarı taşınırken bu boyda görünür.
const CARRY_SIZE: float = 120.0
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
const GIVE_TIME: float = 0.22
const FADE_TIME: float = 0.12

@export var bins: Array[StockBin] = []
@export var customer: Customer
## Taşınan ürün burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer

var _touch_index: int = NO_TOUCH
var _held: Sprite2D
var _bin: StockBin
var _target: Vector2
## Ürünün parmağa göre yeri (Finger.lift): parmak ürünü örtmesin; müşteriye bırakma ürünün görünen yerine ya da parmağa göre.
var _offset: Vector2


func _process(delta: float) -> void:
	if _held != null:
		_held.position = _held.position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var point: Vector2 = _to_world(touch.position)
			var bin: StockBin = _bin_at(point)
			if bin != null:
				_touch_index = touch.index
				_lift(bin, point)
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


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: ürünü yerine geri gönder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			if _held != null:
				customer.set_highlighted(false)
				_return()


## İçinde ürün olan ve noktayı içeren reyon; yoksa null.
func _bin_at(point: Vector2) -> StockBin:
	for bin: StockBin in bins:
		if bin.contains(point) and bin.has_stock():
			return bin
	return null


func _move(point: Vector2) -> void:
	if _held == null:
		return
	_target = _to_screen(point) + _offset
	customer.set_highlighted(customer.can_receive() and (customer.contains(point + _offset) or customer.contains(point)))


func _release(point: Vector2) -> void:
	if _held == null:
		return
	if not (customer.can_receive() and (customer.contains(point + _offset) or customer.contains(point))):
		customer.set_highlighted(false)
		_return()
		return
	var slot: int = customer.slot_for(_bin.item)
	if slot == -1:
		customer.refuse()
		_return()
	else:
		_give(slot)


## En üstteki ürün reyondan kalkıp parmağa doğru büyüyerek gelir.
func _lift(bin: StockBin, point: Vector2) -> void:
	var start: Vector2 = bin.top_point()
	if not bin.take_out():
		return
	_bin = bin
	_offset = Finger.lift(get_viewport())
	_held = Sprite2D.new()
	_held.texture = bin.texture
	drag_layer.add_child(_held)
	_held.position = _to_screen(start)
	_held.scale = bin.size_scale(bin.item_size)
	_target = _to_screen(point) + _offset
	create_tween().tween_property(_held, ^"scale", bin.size_scale(CARRY_SIZE), LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ürün müşterinin göğsüne uçup küçülerek kaybolur; yuva o anda dolu sayılır.
func _give(slot: int) -> void:
	var held: Sprite2D = _held
	_held = null
	_bin.hand_over()
	_bin = null
	customer.receive(slot)
	var tween: Tween = held.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(held, ^"position", _to_screen(customer.hand_point()), GIVE_TIME)
	tween.parallel().tween_property(held, ^"scale", held.scale * 0.5, GIVE_TIME)
	tween.tween_property(held, ^"modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(held.queue_free)


## Ürün küçülerek reyondaki yerine uçar ve oraya konur.
func _return() -> void:
	var held: Sprite2D = _held
	var bin: StockBin = _bin
	_held = null
	_bin = null
	var tween: Tween = held.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(bin.return_point()), RETURN_TIME)
	tween.tween_property(held, ^"scale", bin.size_scale(bin.item_size), RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		held.queue_free()
		bin.put_back())


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
